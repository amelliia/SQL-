# Retail Data Cleaning and Cohort Analysis

## Data Cleaning 
<details>
  
### Setting up a stage table
I copied the raw online_retail table and made a staging table called retail_staging. This step preserved the raw data while giving me a safe working copy for cleaning the data.

### Checking and removing NULL values
I checked for NULLs in each column. The only field with gaps was CustomerID, with around 135,080 missing entries.
I excluded those rows from the dataset.

### Checking for negative values
I checked Quantity and UnitPrice for negative numbers. The Quantity column contained 10,624 negative records, most likely returns or entry mistakes.
To keep the dataset consistent, I only kept rows with positive values for both Quantity and UnitPrice. 

### Removing Duplicates
To deal with duplicate records, I used the ROW_NUMBER() function. I grouped the data by invoice number, stock code, description, quantity, price, customer ID, and country.
Each row in a group was then given a sequence number based on the invoice date. I kept only the first entry from each group and removed the rest, which ensured that only unique transactions remained.

### Once I completed all the cleaning steps, I created a new table called retail. 
This table includes only rows where CustomerID is not NULL, all quantities and prices are positive, and all duplicate records have been removed. The dataset is now clean and ready for analysis.
