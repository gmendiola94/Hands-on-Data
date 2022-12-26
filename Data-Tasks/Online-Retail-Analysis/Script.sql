----------------------------------------------------------------------------------------
-- Task : Online Retail Store initial investigation, profiling and final report extracts
-- Author : Gianmarco Mendiola Colan
-- Created on : 09/2021
-- Engine : Microsoft SQL Server 18
----------------------------------------------------------------------------------------


---------------------------------------------------------------------------------
-- DATASET DDL 
---------------------------------------------------------------------------------

USE [ONLINE_RETAIL_SCHEMA]
GO;

CREATE TABLE [dbo].[online_retail](
	[Invoice] [varchar](50) NULL,
	[StockCode] [varchar](50) NULL,
	[Description] [varchar](50) NULL,
	[Quantity] [varchar](50) NULL,
	[InvoiceDate] [varchar](50) NULL,
	[Price] [varchar](50) NULL,
	[Customer ID] [varchar](50) NULL,
	[Country] [varchar](50) NULL
) ON [PRIMARY];
GO


---------------------------------------------------------------------------------
-- DUPLICATE DATA 
---------------------------------------------------------------------------------
SELECT  COUNT(*)
FROM [dbo].[online_retail];

--DUPLICATED ROWS
--CREATE TABLE WITHOUT DUPLICATES
SELECT  Invoice
       ,StockCode
       ,Description
       ,Quantity
       ,InvoiceDate
       ,Price
       ,"Customer ID"
       ,Country 
-- INTO [online_retail_non_dup]
FROM [dbo].[online_retail]
GROUP BY  Invoice
         ,StockCode
         ,Description
         ,Quantity
         ,InvoiceDate
         ,Price
         ,"Customer ID"
         ,Country
HAVING COUNT(*) > 1
ORDER BY 1, 2;

--NUMBER OF DUPLICATE ROWS
SELECT  (SELECT  COUNT(*)
		FROM [online_retail])-
		(SELECT  COUNT(*)
		FROM [online_retail_non_dup]) AS DUP_DIFF;

--- DUPLICATE ROWS, QUANTITIES WERE NOT AGGREGATED ON THE SAME TRANSACTION WITH EQUAL TIMESTAMP
SELECT  *
FROM [dbo].[online_retail]
WHERE INVOICE = '536446'
    AND STOCKCODE = '21651';

SELECT  Invoice
       ,StockCode
       ,Description
       ,Quantity
       ,InvoiceDate
       ,Price
       ,"Customer ID"
       ,Country
FROM [dbo].[online_retail]
WHERE Quantity > 1
GROUP BY  Invoice
         ,StockCode
         ,Description
         ,Quantity
         ,InvoiceDate
         ,Price
         ,"Customer ID"
         ,Country
HAVING COUNT(*) > 3
ORDER BY 1, 2;


SELECT  MAX (INVOICEDATE)
       ,MIN(INVOICEDATE)
FROM [online_retail_2];

DROP TABLE [online_retail_2];
WITH UNIQUE_DESCRIPTIONS AS
(
	SELECT  STOCKCODE
	       ,DESCRIPTION
	       ,SUM_QUANTITY
	       ,ROW_NUMBER() OVER ( PARTITION BY STOCKCODE ORDER BY SUM_QUANTITY DESC) RANKING
	FROM
	(
		SELECT  UPPER(STOCKCODE)AS STOCKCODE
		       ,DESCRIPTION
		       ,SUM(CAST(QUANTITY AS INTEGER)) SUM_QUANTITY
		FROM [online_retail_non_dup]
		WHERE LEN(INVOICE) = 6
		AND CAST(PRICE AS FLOAT) > 0
		AND CAST(QUANTITY AS FLOAT) > 0
		AND UPPER(STOCKCODE) not like '%TEST%'
		AND RTRIM(LTRIM(STOCKCODE)) <> 'ADJUST'
		AND LEN(STOCKCODE) IN (5, 6, 7, 8)
		AND COUNTRY <> 'Unspecified'
		GROUP BY  UPPER(STOCKCODE)
		         ,DESCRIPTION
	)S
)
SELECT  INVOICE
       ,UPPER(A.STOCKCODE)STOCKCODE
       ,B.DESCRIPTION
       ,CAST(QUANTITY                                AS INTEGER) QUANTITY
       ,CAST(PRICE                                   AS FLOAT) PRICE
       ,CAST(INVOICEDATE                             AS DATE) INVOICEDATE
       ,CAST(PRICE AS FLOAT)*CAST(QUANTITY           AS INTEGER) AMOUNT
       ,DATEPART(YEAR,CAST(INVOICEDATE               AS DATETIME)) YEARDATE
       ,DATEPART(MONTH,CAST(INVOICEDATE              AS DATETIME)) MONTHYEAR
       ,DATEPART(HOUR,CAST(INVOICEDATE               AS DATETIME)) HOURDAY
       ,DATENAME(WEEKDAY,CAST(INVOICEDATE            AS DATETIME)) DAYWEEK
       ,CAST(CAST("CUSTOMER ID" AS FLOAT)AS INTEGER) AS CUSTOMERID
       ,DATEDIFF(mm,(
                SELECT  MAX(CAST(INVOICEDATE AS DATE))
                FROM [online_retail_non_dup] MD
                WHERE MD."CUSTOMER ID" = A."CUSTOMER ID" ) , CAST('2011-12-09' AS DATE)) RECENCY_MONTHS 
        ,CASE WHEN country = 'RSA' THEN 'South Africa' WHEN country = 'EIRE' THEN 'Ireland' else country end AS  COUNTRY
        ,CASE WHEN LEN("CUSTOMER ID") = 0 THEN 0 ELSE 1 END REG_CUSTOMER 
INTO [online_retail_2]
FROM [online_retail_non_dup] A
JOIN UNIQUE_DESCRIPTIONS B
ON UPPER(A.STOCKCODE) = UPPER(B.STOCKCODE) AND RANKING = 1
WHERE LEN(INVOICE) = 6
    AND CAST(PRICE AS FLOAT) > 0
    AND CAST(QUANTITY AS FLOAT) > 0
    AND UPPER(A.STOCKCODE) not like '%TEST%'
    AND RTRIM(LTRIM(A.STOCKCODE)) <> 'ADJUST'
    AND LEN(A.STOCKCODE) IN (5, 6, 7, 8)
    AND COUNTRY <> 'Unspecified'; -- AND LEN([Customer ID]) <> 0;

SELECT  invoice
       ,COUNT(*)
FROM [online_retail_2]
WHERE DAYWEEK = 'Saturday'
GROUP BY  invoice;

SELECT  MAX(CAST(INVOICEDATE AS DATE))
FROM [online_retail_non_dup]
WHERE CAST(CAST("CUSTOMER ID" AS FLOAT)AS INTEGER) = 16436;

---------------------------------------------------------------------------------
-- WATERFALL VIEW 
---------------------------------------------------------------------------------
--initial: 1067371
--drop dup: 1033036
--drop null customer id: 797885
--drop prices or quantities less or equal 0: 779425 (INCL. CANCELED INVOICE WITH NEG VALUES)
--exclude irrelevant stockcodes: 85994
--drop Unspecified country: 85919
SELECT  COUNT(*)
FROM [online_retail_non_dup]
WHERE LEN([Customer ID]) <> 0
    AND CAST(QUANTITY AS FLOAT) > 0
    AND CAST(PRICE AS FLOAT) > 0
    AND UPPER(STOCKCODE) not like '%TEST%'
    AND RTRIM(LTRIM(STOCKCODE)) <> 'ADJUST'
    AND (LEN(STOCKCODE) IN (5, 6, 7, 8))
    AND COUNTRY <> 'Unspecified';

SELECT  *
FROM [online_retail_non_dup]
WHERE LEN(STOCKCODE) = 5;

--------------------------------------------------------------------------------- 
-- INITIAL PROFILING
---------------------------------------------------------------------------------

-- MUST FILTER POSITIVE QUANTITIES AND PRICES
-- NEGATIVE PRICE OR QUANTITIES
SELECT  COUNT(*)
FROM [online_retail_non_dup]
WHERE CAST(PRICE AS FLOAT) <= 0 OR CAST(QUANTITY AS FLOAT) <= 0;

-- NULL CUSTOMERS
SELECT  country
       ,COUNT(*)
FROM [online_retail_non_dup]
WHERE LEN([Customer ID]) = 0
GROUP BY  country
ORDER BY 2 desc;

SELECT  LEN([Customer ID])
FROM [online_retail_non_dup]
GROUP BY  LEN([Customer ID]);

-- TESTS TRANSACTIONS AND ADJUST
SELECT  COUNT(*)
FROM [online_retail]
WHERE upper(stockcode) like '%TEST%' OR RTRIM(LTRIM(STOCKCODE)) = 'ADJUST';

-- CANCELED INVOICES
SELECT  LEN(INVOICE)
       ,COUNT(*)
FROM [online_retail]
GROUP BY LEN(INVOICE);

SELECT COUNT(*)
FROM [online_retail]
WHERE LEN(INVOICE) = 7;

SELECT LEN(stockcode)
       ,COUNT(*)
FROM [online_retail_non_dup]
GROUP BY  LEN(stockcode)
ORDER BY 2 DESC;

-- GIFTS/BANK/COMISSION/DOTCOM/BAD DEBT ADJUSTEMENTS POSTAGE CHARGES EXCLUDED
SELECT  *
FROM
(
	SELECT  LEN(stockcode) largo
	       ,STOCKCODE
	       ,DESCRIPTION
	       ,price
	       ,ROW_NUMBER() OVER (PARTITION BY LEN(stockcode) ORDER BY STOCKCODE ) ORDEN
	FROM [online_retail]
) y
WHERE y.orden < 20
ORDER BY 1, 4;

SELECT  COUNT(*)
FROM online_retail
WHERE (LEN(STOCKCODE) NOT IN (6, 7, 8));


--------------------------------------------------------------------------------- 
-- DATA ISSUES
---------------------------------------------------------------------------------
-- INCOMPLETE DESCRIPTIONS
SELECT  LEN(DESCRIPTION)
       ,COUNT(*)
FROM [online_retail_2]
GROUP BY  LEN(DESCRIPTION)
ORDER BY 2;

SELECT  *
FROM [online_retail_2]
WHERE LEN(DESCRIPTION) IN (15)
ORDER BY LEN(DESCRIPTION);

-- MULTIPLES DESCRIPTIONS FOR SAME STOCKCODE MAY DIFFICULT VIS --------------------------
SELECT  STOCKCODE
       ,DESCRIPTION
       ,SUMQUANTITY
       ,ROW_NUMBER() OVER ( PARTITION BY STOCKCODE ORDER BY SUMQUANTITY DESC) ORDEN
FROM
(
	SELECT  STOCKCODE
	       ,DESCRIPTION
	       ,SUM(QUANTITY) SUMQUANTITY
	FROM [online_retail_2]
	GROUP BY  STOCKCODE
	         ,DESCRIPTION
) S
ORDER BY 1;

--- DATA VALIDATIONS ON CODE LENGTHS ----------------------------------------------------

SELECT  LEN(INVOICE)
       ,COUNT(*)
FROM [online_retail_2]
GROUP BY  LEN(INVOICE);

SELECT  *
FROM
(
	SELECT  LEN(STOCKCODE) AS STOCKLENGTH
	       ,STOCKCODE
	       ,DESCRIPTION
	       ,PRICE
	       ,ROW_NUMBER() OVER (PARTITION BY LEN(STOCKCODE) ORDER BY STOCKCODE ) AS ORDEN
	FROM [online_retail_2]
) y
WHERE y.orden < 5;

SELECT  COUNTRY
       ,MAX(PRICE) AS MAXP
       ,MAX(QUANTITY) AS MAXQ
       ,MIN(PRICE) AS MINP
       ,MIN(QUANTITY) AS MINQ
       ,SUM(AMOUNT)/COUNT(DISTINCT CUSTOMERID) AS SPENDING_PU
       ,MAX(AMOUNT) AS MAXAMOUNT
       ,COUNT(DISTINCT CUSTOMERID) CUSTOMERS
FROM [online_retail_2]
GROUP BY  COUNTRY
ORDER BY COUNT(*) DESC;

SELECT  COUNTRY
       ,MAX(PRICE) AS MAXP
       ,MAX(QUANTITY) AS MAXQ
       ,MIN(PRICE) AS MINP
       ,MIN(QUANTITY) AS MINQ
       ,SUM(AMOUNT)/COUNT(DISTINCT CUSTOMERID) AS SPENDING_PU
       ,MAX(AMOUNT)
       ,COUNT(DISTINCT CUSTOMERID) CUSTOMERS
FROM [online_retail_2]
WHERE CUSTOMERID <> 0
GROUP BY COUNTRY
ORDER BY SUM(AMOUNT)/COUNT(DISTINCT CUSTOMERID) DESC;


--------------------------------------------------------------------------------- 
-- AGGREGATED EXTRACTS 
---------------------------------------------------------------------------------

-- INVOICE REPORT ---------------------------------------------------------------

DROP TABLE online_retail_invoice;
WITH rpt_inv AS
(
	SELECT  COUNTRY
	       ,INVOICE
	       ,INVOICEDATE
	       ,YEARDATE
	       ,MONTHYEAR
	       ,HOURDAY
	       ,DAYWEEK
	       ,SUM(amount) AS TOTAL_SALESAMOUNT
	       ,SUM(QUANTITY) AS TOTAL_QUANTITY
	FROM [online_retail_2]
	GROUP BY  COUNTRY
	         ,INVOICE
	         ,INVOICEDATE
	         ,YEARDATE
	         ,MONTHYEAR
	         ,HOURDAY
	         ,DAYWEEK
)
SELECT  * into online_retail_invoice
FROM rpt_inv;


-- CUSTOMER REPORT (CAMPAIGNS) ------------------------------------------------------

DROP TABLE online_retail_customer;
WITH rpt_cus AS
(
	SELECT  CUSTOMERID
	       ,RECENCY_MONTHS
	       ,COUNTRY
	       ,COUNT(INVOICE) AS NUMBER_INVOICES
	       ,AVG(Invoice_amount) AS  AVG_INVOICEAMOUNT
	       ,SUM(Invoice_amount) AS  TOTAL_SALESAMOUNT
	       ,AVG(TOTAL_QUANTITY) AS  AVG_INVOICEQUANTITY
	       ,SUM(TOTAL_QUANTITY) AS  TOTAL_QUANTITY
	       ,ROUND((
	SELECT  SUM(amount)
	FROM [online_retail_2] s
	WHERE s.CUSTOMERID = i.CUSTOMERID
	AND s.COUNTRY = i.COUNTRY)/ (
	SELECT  SUM(amount)
	FROM [online_retail_2] s
	WHERE s.COUNTRY = i.COUNTRY), 6 ) PCT_COUNTRY
	FROM
	(
		SELECT  CUSTOMERID
		       ,RECENCY_MONTHS
		       ,COUNTRY
		       ,INVOICE
		       ,SUM (amount) AS INVOICE_AMOUNT
		       ,SUM (QUANTITY) AS TOTAL_QUANTITY
		FROM [online_retail_2]
		WHERE REG_CUSTOMER = 1
		GROUP BY  CUSTOMERID
		         ,RECENCY_MONTHS
		         ,COUNTRY
		         ,INVOICE
	) i
	GROUP BY  CUSTOMERID
	         ,RECENCY_MONTHS
	         ,COUNTRY
)
SELECT  *
INTO online_retail_customer
FROM rpt_cus;

SELECT  yeardate
       ,MAX(invoicedate)
FROM [online_retail_2]
WHERE yeardate IN ('2010', '2011')
    AND monthyear = 12
GROUP BY  yeardate;


-- PRODUCT REPORT --------------------------------------------------------------------

DROP TABLE online_retail_product;
WITH rpt_prod AS
(
	SELECT  COUNTRY
	       ,STOCKCODE
	       ,DESCRIPTION
	       ,YEARDATE
	       ,MONTHYEAR
	       ,DATENAME(MONTH,INVOICEDATE) AS MONTH_NAME
	       ,SUM(QUANTITY) AS TOTAL_QUANTITY
	       ,SUM(amount) AS TOTAL_AMOUNT
	FROM [online_retail_2]
	GROUP BY  COUNTRY
	         ,STOCKCODE
	         ,DESCRIPTION
	         ,YEARDATE
	         ,MONTHYEAR
	         ,DATENAME(MONTH,INVOICEDATE)
)
SELECT  * 
INTO online_retail_product
FROM rpt_prod;