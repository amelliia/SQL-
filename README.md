# Retail Data Cleaning and Cohort Analysis

The main goal of this cohort analysis is to track customer retention and churn patterns over time.
By grouping customers based on the month of their first purchase we can measure how long customers remain active after joining and how quickly customers drop off.
Do newer cohorts behave differently from older ones?  
Does a campaign lead to stronger retention compared to previous months?  

## Data Cleaning 

### Setting Up a Stage Table
I copied the raw online_retail table and made a staging table called retail_staging. This step preserved the raw data while giving me a safe working copy for cleaning the data. 
### Removing NULL Values 
I checked for NULLs in each column. The only field with gaps was CustomerID, with around 135,080 missing entries. I excluded those rows from the dataset.
### Checking Negative Values 
I checked Quantity and UnitPrice for negative numbers. The Quantity column contained 10,624 negative records, most likely returns or entry mistakes. To keep the dataset consistent, I only kept rows with positive values for both Quantity and UnitPrice. 
### Removing Duplicates
To deal with duplicate records, I used the ROW_NUMBER() function. I grouped the data by invoice number, stock code, description, quantity, price, customer ID, and country. Each row in a group was then given a sequence number based on the invoice date. I kept only the first entry from each group and removed the rest, which ensured that only unique transactions remained. 
### Final Dataset 
Once I completed all the cleaning steps, I created a new table called retail. This table includes only rows where CustomerID is not NULL, all quantities and prices are positive, and all duplicate records have been removed. The dataset is now clean and ready for analysis. how to make it ingitbub that

## Cohort Analysis

### Creating Cohort View 
FirstPurchaseDate identifies when the customer made their first-ever transaction. Cohort_Date rounds this to the first day of the month, grouping all customers who joined in the same month together.
This allows us to track the behavior of each cohort over time.

```
CREATE VIEW cohort AS
SELECT
    CustomerID,
    MIN(DATE(InvoiceDate)) AS FirstPurchaseDate,
    CAST(DATE_FORMAT(MIN(InvoiceDate), '%Y-%m-01') AS DATE) AS Cohort_Date
FROM retail
GROUP BY CustomerID;
```
###  Creating Cohort Index and Transaction View
I created a transactions view to combine all purchase records with the cohort information. Each transaction now knows which cohort the customer belongs to.
CohortIndex represents the number of months since the customer’s first purchase. Year and month columns help with time-based reporting.

```
CREATE VIEW transactions AS
SELECT
    r.CustomerID,
    r.InvoiceNo,
    r.InvoiceDate,
    r.Quantity,
    r.UnitPrice,
    (r.Quantity * r.UnitPrice) AS Revenue,
    c.Cohort_Date,
    YEAR(r.InvoiceDate) AS InvoiceYear,
    MONTH(r.InvoiceDate) AS InvoiceMonth,
    YEAR(c.Cohort_Date) AS CohortYear,
    MONTH(c.Cohort_Date) AS CohortMonth,
    TIMESTAMPDIFF(MONTH, c.Cohort_Date, r.InvoiceDate) + 1 AS CohortIndex
FROM retail r
JOIN cohort c
    ON r.CustomerID = c.CustomerID;
```

### Retention view to calculate monthly retention for each cohort

Counts active customers per cohort per month.
Divides by the total cohort size to get percentage retention.
The result is a table showing how retention changes month by month for each cohort.

```
CREATE VIEW retention AS
SELECT
    t.Cohort_Date,
    t.CohortIndex,
    COUNT(DISTINCT t.CustomerID) AS ActiveCustomers,
    ROUND(
        COUNT(DISTINCT t.CustomerID) / 
        (SELECT COUNT(DISTINCT CustomerID) 
         FROM cohort 
         WHERE Cohort_Date = t.Cohort_Date) * 100, 1
    ) AS RetentionRate
FROM transactions t
GROUP BY t.Cohort_Date, t.CohortIndex
ORDER BY t.Cohort_Date, t.CohortIndex;
```

I made a heatmap in Power Bi to visualise retention.
<img width="1585" height="665" alt="Image" src="https://github.com/user-attachments/assets/3dd241fe-74c7-4fbe-ac29-71bd7c6ddc69" />

### Cohort Revenue Growth

```
CREATE OR REPLACE VIEW CohortRevenue AS
SELECT
    t.Cohort_Date,
    t.CohortIndex,
    SUM(t.Revenue) AS TotalRevenue,
    COUNT(DISTINCT t.CustomerID) AS ActiveCustomers,
    ROUND(SUM(t.Revenue) / COUNT(DISTINCT t.CustomerID), 2) AS RevenuePerCustomer
FROM transactions t
GROUP BY t.Cohort_Date, t.CohortIndex
ORDER BY t.Cohort_Date, t.CohortIndex;
```
<img width="1585" height="685" alt="Image" src="https://github.com/user-attachments/assets/f670a18e-c140-45e0-85bc-0605d2ef75b3" />
