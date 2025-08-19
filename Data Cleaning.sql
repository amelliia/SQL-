-- Cleaning online retail data, handling NULLs, negative values, and duplicates


-- Create a staging table to preserve raw data

CREATE TABLE retail_staging LIKE online_retail;

-- Copy all data from raw table to staging table
INSERT INTO retail_staging
SELECT *
FROM online_retail;

SELECT * 
FROM retail_staging;


-- Check for NULL values in each column
SELECT
    SUM(CASE WHEN InvoiceNo IS NULL THEN 1 ELSE 0 END) AS Null_InvoiceNo,
    SUM(CASE WHEN StockCode IS NULL THEN 1 ELSE 0 END) AS Null_StockCode,
    SUM(CASE WHEN Description IS NULL THEN 1 ELSE 0 END) AS Null_Description,
    SUM(CASE WHEN Quantity IS NULL THEN 1 ELSE 0 END) AS Null_Quantity,
    SUM(CASE WHEN InvoiceDate IS NULL THEN 1 ELSE 0 END) AS Null_InvoiceDate,
    SUM(CASE WHEN UnitPrice IS NULL THEN 1 ELSE 0 END) AS Null_UnitPrice,
    SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) AS Null_CustomerID,
    SUM(CASE WHEN Country IS NULL THEN 1 ELSE 0 END) AS Null_Country
FROM retail_staging; 
-- CustomerID contains 135,080 NULLs nd the rest do not contain NULL values


-- Check for negative values in Quantity column
SELECT *
FROM retail_staging
WHERE Quantity < 0;

SELECT COUNT(*) AS NegativeQuantityCount
FROM retail_staging
WHERE Quantity < 0;
-- There are 10624 rows with negative values in the Quantity column


-- Clean data and create final retail table
CREATE TABLE retail AS
WITH CTE AS (
    -- Remove rows with NULL CustomerID
    SELECT * 
    FROM retail_staging
    WHERE CustomerID IS NOT NULL
), 
quantity_price AS (
    -- Keep only positive Quantity and UnitPrice
    SELECT *
    FROM CTE
    WHERE Quantity > 0 AND UnitPrice > 0
),
duplicates AS (
    -- Identify duplicates
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country
               ORDER BY InvoiceDate
           ) AS RowNum
    FROM quantity_price
)
-- Keep only the first occurrence of duplicates
SELECT *
FROM duplicates
WHERE RowNum = 1;


-- Inspect cleaned table
SELECT *
FROM retail;
