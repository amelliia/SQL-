# Retail Data Cleaning and Cohort Analysis

The main goal of this cohort analysis is to track customer retention and churn patterns over time.
By grouping customers based on the month of their first purchase we can measure how long customers remain active after joining, how quickly customers drop off and to see if newer cohorts behave differently from older ones.

The analysis was done using SQL for data preparation and Power BI for visualization.

## Data Cleaning

### Setting Up a Stage Table
I copied the raw online_retail table and made a staging table called retail_staging. This step preserved the raw data while giving me a safe working copy for cleaning the data. 
### Removing NULL Values 
I checked for NULLs in each column. The only column with gaps was CustomerID. About 135k rows didn’t have a customer ID so I dropped those because customer-level tracking wouldn’t be possible otherwise.
### Checking Negative Values 
I checked Quantity and UnitPrice for negative numbers. The Quantity column contained 10,624 negative records, most likely returns or entry mistakes. To keep the dataset consistent, I only kept rows with positive values for both Quantity and UnitPrice. 
### Removing Duplicates
To deal with duplicate records, I used the ROW_NUMBER() function. I grouped the data by invoice number, stock code, description, quantity, price, customer ID, and country. Each row in a group was then given a sequence number based on the invoice date. I kept only the first entry from each group and removed the rest, which ensured that only unique transactions remained. 
### Final Dataset 
Once I completed all the cleaning steps, I created a new table called retail. This table includes only rows where CustomerID is not NULL, all quantities and prices are positive, and all duplicate records have been removed. The dataset is now clean and ready for analysis.

## Cohort Analysis

### Creating Cohort View 
I identified each customer’s first purchase date and rounded it to the first day of that month. This created a Cohort Date, grouping customers who first purchased in the same month.
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

To calculate monthly retention, I counted how many unique customers were active in each CohortIndex and divided that by the total cohort size.
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


I used Power BI to create a heatmap that shows retention by monthly cohorts. 

#### Retenetion Heatmap Insights:

This analysis groups customers into cohorts based on the month of their first purchase. For example, the January 2011 cohort shows that only about 24% of users returned in the second month. By the third month, retention had dropped to 33%, highlighting a steep initial decline. Overall, most cohorts lose over half of their customers within the first month, after which retention stabilizes around 20–30%.

One exception is the December 2010 cohort. Unlike the others, this group held onto customers much longer, with nearly half of them still active by month eleven—the highest retention observed across all cohorts. It’s possible that holiday promotions or seasonal factors played a role in keeping those customers engaged

<img width="1495" height="630" alt="Image" src="https://github.com/user-attachments/assets/a142dfad-1fa1-4d46-bd9f-4cdc8d160f16" />

### Cohort Revenue Growth

Finally, I looked at revenue trends by cohort. This shows not only retention but also whether customers are spending more over time.
```
CREATE VIEW CohortRevenue AS
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

#### Average Revenue per Customer Heatmap Insights:

<img width="1495" height="630" alt="Image" src="https://github.com/user-attachments/assets/16914283-0457-47ec-bfd2-82606a803095" />

```
CREATE VIEW CohortRevenueGrowth AS
SELECT
    cr.Cohort_Date,
    cr.CohortIndex,
    cr.TotalRevenue,
    SUM(cr.TotalRevenue) 
        OVER (PARTITION BY cr.Cohort_Date ORDER BY cr.CohortIndex) AS CumulativeRevenue
FROM CohortRevenue cr 
ORDER BY cr.Cohort_Date, cr.CohortIndex;
```

#### Cohort Monthly and Culumative Revenue Insights:

<img width="1495" height="770" alt="Image" src="https://github.com/user-attachments/assets/af22d02e-f630-4e37-b3a7-0917bf7e83a2" />

