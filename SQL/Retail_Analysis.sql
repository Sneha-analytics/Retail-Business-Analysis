CREATE DATABASE retail_analysis;
USE retail_analysis;
CREATE TABLE superstore (
    Row_ID INT,
    Order_ID VARCHAR(20),
    Order_Date DATE,
    Ship_Date DATE,
    Ship_Mode VARCHAR(50),
    Customer_ID VARCHAR(20),
    Customer_Name VARCHAR(100),
    Segment VARCHAR(50),
    Country VARCHAR(50),
    City VARCHAR(50),
    State VARCHAR(50),
    Postal_Code VARCHAR(20),
    Region VARCHAR(50),
    Product_ID VARCHAR(20),
    Category VARCHAR(50),
    Sub_Category VARCHAR(50),
    Product_Name VARCHAR(200),
    Sales DECIMAL(10,2),
    Quantity INT,
    Discount DECIMAL(5,2),
    Profit DECIMAL(10,2)
);

SELECT * FROM superstore LIMIT 10;

-- Handle missing / null values
SELECT 
    SUM(CASE WHEN `Order_ID` IS NULL THEN 1 ELSE 0 END) AS null_orderid,
    SUM(CASE WHEN `Sales` IS NULL THEN 1 ELSE 0 END) AS null_sales,
    SUM(CASE WHEN `Profit` IS NULL THEN 1 ELSE 0 END) AS null_profit,
    SUM(CASE WHEN `Category` IS NULL THEN 1 ELSE 0 END) AS null_category
FROM superstore;
DELETE FROM superstore
WHERE `Order ID` IS NULL OR Sales IS NULL OR Profit IS NULL;

-- Trim text fields & normalize case
UPDATE superstore SET 
  Customer_Name = TRIM(Customer_Name),
  Product_Name  = TRIM(Product_Name),
  State = TRIM(State);

-- Basic EDA SQL
-- Totals and quick KPIs:
SELECT 
  COUNT(DISTINCT Order_ID) AS total_orders,
  COUNT(DISTINCT Customer_ID) AS total_customers,
  SUM(Sales) AS total_sales,
  SUM(Profit) AS total_profit,
  AVG(Discount) AS avg_discount
FROM superstore;

-- Top categories & subcategories:
SELECT Category, SUM(Sales) sales, SUM(Profit) profit, 
       (SUM(Profit)/NULLIF(SUM(Sales),0))*100 AS profit_margin_pct
FROM superstore
GROUP BY Category
ORDER BY sales DESC;

-- Top products by sales:
SELECT Product_Name, SUM(Sales) AS total_sales
FROM superstore
GROUP BY Product_Name
ORDER BY total_sales DESC
LIMIT 20;

-- Monthly trend :
SELECT DATE_FORMAT(Order_Date, '%Y-%m') AS ym, SUM(Sales) sales, SUM(Profit) profit
FROM superstore
GROUP BY ym
ORDER BY ym;

-- Profit margin & discount impact
-- Profit margin by Category & SubCategory:
SELECT Category, Sub_Category,
       SUM(Sales) AS sales,
       SUM(Profit) AS profit,
       (SUM(Profit)/NULLIF(SUM(Sales),0))*100 AS profit_margin_pct
FROM superstore
GROUP BY Category, Sub_Category
ORDER BY profit_margin_pct DESC;

-- Average Discount per Category
SELECT 
    Category, Sub_Category,
    AVG(Discount) * 100 AS avg_discount_pct
FROM superstore
GROUP BY Category, Sub_Category
ORDER BY avg_discount_pct DESC;

-- Discount buckets (how discount affects margin)
SELECT
  CASE 
    WHEN Discount = 0 THEN 'No Discount'
    WHEN Discount BETWEEN 0.0001 AND 0.1 THEN '0-10%'
    WHEN Discount BETWEEN 0.1001 AND 0.2 THEN '10-20%'
    WHEN Discount BETWEEN 0.2001 AND 0.4 THEN '20-40%'
    ELSE '40%+'
  END AS disc_bucket,
  COUNT(*) AS 'rows',
  SUM(Sales) AS sales,
  SUM(Profit) AS profit,
  (SUM(Profit)/NULLIF(SUM(Sales),0))*100 AS profit_margin_pct
FROM superstore
GROUP BY disc_bucket
ORDER BY profit_margin_pct;

-- Unit price (derived) and its relation
SELECT Product_ID, Product_Name,
       SUM(Quantity) total_qty,
       SUM(Sales) total_sales,
       (SUM(Sales)/NULLIF(SUM(Quantity),0)) AS avg_price_per_unit,
       SUM(Profit) total_profit
FROM superstore
GROUP BY Product_ID, Product_Name
ORDER BY total_profit DESC;

-- Seasonality and product behaviour
-- Monthly seasonality by category
SELECT Category, MONTH(Order_Date) AS month, SUM(Sales) sales, SUM(Profit) profit
FROM superstore
GROUP BY Category, month
ORDER BY Category, month;

-- Sales per SKU per Month (Velocity)
SELECT 
    Product_ID,
    Product_Name,
    COUNT(DISTINCT DATE_FORMAT(Order_Date, '%Y-%m')) AS active_months,
    SUM(Quantity) AS total_qty,
    SUM(Quantity) / NULLIF(COUNT(DISTINCT DATE_FORMAT(Order_Date, '%Y-%m')),0) AS avg_monthly_qty
FROM superstore
GROUP BY Product_ID, Product_Name
ORDER BY avg_monthly_qty DESC;

-- Avg daily sales
SELECT 
    Sub_Category,
    SUM(Sales) / COUNT(DISTINCT Order_Date) AS avg_daily_sales
FROM superstore
GROUP BY Sub_Category;


-- Inventory / slow-moving items
SELECT Product_ID, Product_Name,
       SUM(Quantity) total_qty,
       SUM(Sales) total_sales,
       SUM(Profit) AS total_profit,
       (SUM(Profit) / NULLIF(SUM(Sales),0)) * 100 AS profit_margin_pct,
       MAX(Order_Date) last_sale_date,
       DATEDIFF('2017-12-28', MAX(Order_Date)) AS days_since_last_sale
FROM superstore
GROUP BY Product_ID, Product_Name
HAVING total_qty <= 10 OR days_since_last_sale > 180
ORDER BY days_since_last_sale DESC;

-- Overstocked items
SELECT Product_ID, Product_Name,
       SUM(Quantity) AS total_qty,
       SUM(Sales) AS total_sales,
       SUM(Profit) AS total_profit,
       (SUM(Profit) / NULLIF(SUM(Sales),0)) * 100 AS profit_margin_pct
FROM superstore
GROUP BY Product_ID, Product_Name
HAVING total_qty >=150 AND profit_margin_pct <= 5
ORDER BY total_qty DESC;

-- top products contributing ~80% of profit.
WITH profit_ranked AS (
    SELECT 
        Product_ID,
        Product_Name,
        SUM(Profit) AS total_profit
    FROM superstore
    GROUP BY Product_ID, Product_Name
),
profit_sorted AS (
    SELECT *,
           RANK() OVER (ORDER BY total_profit DESC) AS rnk,
           SUM(total_profit) OVER () AS grand_total_profit,
           SUM(total_profit) OVER (ORDER BY total_profit DESC) AS running_profit
    FROM profit_ranked
)
SELECT 
    Product_ID,
    Product_Name,
    total_profit,
    (running_profit / grand_total_profit) * 100 AS cumulative_profit_pct
FROM profit_sorted
WHERE (running_profit / grand_total_profit) <= 0.80
ORDER BY total_profit DESC;



