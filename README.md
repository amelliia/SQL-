# Retail Data Cleaning and Cohort Analysis

The goal of this project was to perform a cohort analysis to understand customer retention and churn patterns over time. By grouping customers based on the month of their first purchase, we can observe how long customers stay active, identify drop-off points, and examine whether newer cohorts behave differently from older ones. SQL was used for data preparation, and Power BI for visualization.

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

I identified each customer’s first purchase date and rounded it to the first day of that month to define a Cohort_Date. Grouping customers this way allows tracking each cohort’s behavior over time.

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
CohortIndex represents the number of months since the customer’s first purchase. Year and month columns support time-based reporting.

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

To calculate monthly retention, I counted how many unique customers were active in each Cohort Index and divided that by the total cohort size.
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

- Most cohorts see a sharp decline in the first month with more than half of customers not returning
- After that initial decline, retention stabilizes to around 20–30% in the following months
- The December 2010 cohort stands out as nearly half of these customers were still active by the eleventh month. This could be due to holiday promotions or seasonal shopping behavior

<img width="1495" height="630" alt="Image" src="https://github.com/user-attachments/assets/a142dfad-1fa1-4d46-bd9f-4cdc8d160f16" />

### Cohort Revenue Analysis

To understand not just retention but spending behavior, I calculated revenue trends by cohort.

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
- In several cohorts (e.g., Jan 2011, Aug 2011), average revenue per customer actually increased in later months compared to month 0. This indicates that retained customers tend to spend more over time, offsetting the overall decline in active users.
- Cohorts that joined around holiday months like December or August tend to deliver much higher revenue per customer, suggesting that acquisition during seasonal peaks brings in more valuable customers.
- Even when retention declines sharply, average revenue per customer often holds steady or climbs (e.g., Jan 2011, Feb 2011). This highlights that losing low-value customers can make the remaining base look stronger in revenue terms.
- 
<img width="1495" height="630" alt="Image" src="https://github.com/user-attachments/assets/16914283-0457-47ec-bfd2-82606a803095" />

### Cumulative Revenue
To examine long-term value, I calculated cumulative revenue for each cohort.

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
- Despite the sharp drop from month 1, revenue per month stabilizes around $0.5M–$0.6M, indicating that loyal customers continue to generate a steady revenue stream.
- Most Revenue ((about 25% of total revenue)came in over came in the first month, showing the importance of the acquisition month.

<img width="1495" height="770" alt="Image" src="https://github.com/user-attachments/assets/af22d02e-f630-4e37-b3a7-0917bf7e83a2" />

### Conclusion

This cohort analysis revealed clear patterns in customer retention, spending behavior, and long-term revenue growth. The retention analysis showed that most customers churn quickly, with more than half not returning after their first purchase. However, after this initial drop, retention stabilizes at around 20–30%, highlighting the presence of a loyal customer base that continues to engage with the business.

 While overall retention declines, the average revenue per customer increases for many cohorts over time. This means that the customers who remain are not only more loyal but also more valuable. Seasonal cohorts such as December 2010 and August 2011 stood out, demonstrating both stronger retention and higher average spending, suggesting that acquisition timing during peak shopping periods significantly influences customer value. Targeted acquisition during seasonal peaks and strategies to nurture high-value loyal customers can maximize long-term profitability and sustain revenue growth.
