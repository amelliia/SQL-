

-- Cohort view: assign each customer to a cohort based on first purchase
CREATE VIEW cohort AS
SELECT
    CustomerID,
    MIN(DATE(InvoiceDate)) AS FirstPurchaseDate,
    CAST(DATE_FORMAT(MIN(InvoiceDate), '%Y-%m-01') AS DATE) AS Cohort_Date
FROM retail
GROUP BY CustomerID;


-- Transactions view: join cohort info with all transactions
CREATE VIEW transactions AS
SELECT
    r.CustomerID,
    r.InvoiceNo,
    r.InvoiceDate,
    r.Quantity,
    r.UnitPrice,
    (r.Quantity * r.UnitPrice) AS Revenue,  -- negative for returns
    c.Cohort_Date,
    YEAR(r.InvoiceDate) AS InvoiceYear,
    MONTH(r.InvoiceDate) AS InvoiceMonth,
    YEAR(c.Cohort_Date) AS CohortYear,
    MONTH(c.Cohort_Date) AS CohortMonth,
    TIMESTAMPDIFF(MONTH, c.Cohort_Date, r.InvoiceDate) + 1 AS CohortIndex
FROM retail r
JOIN cohort c
    ON r.CustomerID = c.CustomerID;


--  Retention view: calculate monthly retention per cohort
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


CREATE VIEW CohortRevenueGrowth AS
SELECT
    cr.Cohort_Date,
    cr.CohortIndex,
    cr.TotalRevenue,
    SUM(cr.TotalRevenue) 
        OVER (PARTITION BY cr.Cohort_Date ORDER BY cr.CohortIndex) AS CumulativeRevenue
FROM CohortRevenue cr 
ORDER BY cr.Cohort_Date, cr.CohortIndex;
