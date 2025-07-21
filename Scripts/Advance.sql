Use DataWarehouseAnalytics;

-- CHANGE OVER TIME

-- Task: Analyze Sales Performance Over Time
SELECT 
    YEAR(order_date) AS order_year,
    MONTH(order_date) AS order_month,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM fact_sales
WHERE order_date IS NOT NULL
  AND YEAR(order_date) BETWEEN 2000 AND 2030  
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date);

-- CUMULATIVE ANALYSIS

-- TASK: Calculate the total sales per month and the running total of sales over time
SELECT
    order_date,
    total_sales,
    SUM(total_sales) OVER (ORDER BY order_date) AS running_total_sales,
    AVG(ROUND(avg_price)) OVER (ORDER BY order_date) AS moving_average_price
FROM (
    SELECT
        YEAR(order_date) AS order_date,
        SUM(sales_amount) AS total_sales,
        AVG(price) AS avg_price
    FROM fact_sales
    WHERE order_date IS NOT NULL
      AND YEAR(order_date) BETWEEN 2000 AND 2030
    GROUP BY YEAR(order_date)
) AS t;

-- PERFORMANCE ANALYSIS

-- TASK: Analyze the yearly performance of products by comparing their sales to both the average sales performance of the product and the previous year
-- calculate total sales for each product every year
WITH yearly_product_sales AS (
    SELECT
        YEAR(f.order_date) AS order_year,
        p.product_name,
        SUM(f.sales_amount) AS current_sales
    FROM fact_sales f
    LEFT JOIN dim_products p
        ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
      AND YEAR(f.order_date) BETWEEN 2000 AND 2030
    GROUP BY 
        YEAR(f.order_date),
        p.product_name
)
-- perform analysis on the yearly sales data
SELECT
    order_year,
    product_name,
    current_sales,
    AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
    -- how much current year sales is from the product average
    current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS diff_avg,
    CASE 
        WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Avg'
        WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Avg'
        ELSE 'Avg'
    END AS avg_change,
    -- Year-over-Year Analysis
    LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS py_sales,
    current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS diff_py,
    CASE 
        WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
        WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
        ELSE 'No Change'
    END AS py_change
FROM yearly_product_sales
ORDER BY product_name, order_year;

-- PART-TO-WHOLE PROPORTIONAL

-- TASK: Which categories contribute the most to overall sales?
-- Get total sales per category
WITH category_sales AS (
    SELECT
        p.category,
        SUM(f.sales_amount) AS total_sales
    FROM fact_sales f
    LEFT JOIN dim_products p ON p.product_key = f.product_key
    WHERE f.sales_amount IS NOT NULL
    GROUP BY p.category
)

-- Calculate overall sales and percentage contribution
SELECT
    category,
    total_sales,
    SUM(total_sales) OVER () AS overall_sales,
    ROUND((total_sales / SUM(total_sales) OVER ()) * 100, 2) AS percentage_of_total
FROM category_sales
ORDER BY total_sales DESC;

-- DATA SEGMNETATION

-- TASK: Segment products into cost ranges and count how many products fall into each segment
-- Categorize products based on cost ranges
WITH product_segments AS (
    SELECT
        product_key,
        product_name,
        cost,
        CASE 
            WHEN cost < 100 THEN 'Below 100'
            WHEN cost BETWEEN 100 AND 500 THEN '100-500'
            WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
            ELSE 'Above 1000'
        END AS cost_range
    FROM dim_products
)

-- Count how many products fall in each cost range
SELECT 
    cost_range,
    COUNT(product_key) AS total_products
FROM product_segments
GROUP BY cost_range
ORDER BY total_products DESC;

-- TASK :Group customers into three segments based on their spending behavior:
--          VIP: Customers with at least 12 months of history and spending more than €5,000.
--          Regular: Customers with at least 12 months of history but spending €5,000 or less.
--          New: Customers with a lifespan less than 12 months.
--       And find the total number of customers by each group
WITH customer_spending AS (
    SELECT
        f.customer_key,
        SUM(f.sales_amount) AS total_spending,
        MIN(f.order_date) AS first_order,
        MAX(f.order_date) AS last_order,
        PERIOD_DIFF(
            EXTRACT(YEAR_MONTH FROM MAX(f.order_date)),
            EXTRACT(YEAR_MONTH FROM MIN(f.order_date))
        ) AS lifespan
    FROM fact_sales f
    WHERE f.order_date IS NOT NULL 
      AND YEAR(f.order_date) BETWEEN 2000 AND 2030
    GROUP BY f.customer_key
)

SELECT 
    customer_segment,
    COUNT(customer_key) AS total_customers
FROM (
    SELECT 
        customer_key,
        CASE 
            WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
            WHEN lifespan >= 12 AND total_spending <= 5000 THEN 'Regular'
            ELSE 'New'
        END AS customer_segment
    FROM customer_spending
) AS segmented_customers
GROUP BY customer_segment
ORDER BY total_customers DESC;

/* ===============================================================================
   Customer Report
   ===============================================================================
   Purpose:
    - This report consolidates key customer metrics and behaviors

Highlights:
    1. Gathers essential fields such as names, ages, and transaction details.
	2. Segments customers into categories (VIP, Regular, New) and age groups.
    3. Aggregates customer-level metrics:
	   - total orders
	   - total sales
	   - total quantity purchased
	   - total products
	   - lifespan (in months)
    4. Calculates valuable KPIs:
	    - recency (months since last order)
		- average order value
		- average monthly spend
=============================================================================== */


/*=============================================================================
Create Report: gold.report_customers
=============================================================================*/

-- Drop existing view if exists
DROP VIEW IF EXISTS gold_report_customers;

-- Create the customer report view
CREATE VIEW gold_report_customers AS

WITH base_query AS (
    -- 1. Base query: join sales and customer details
    SELECT
        f.order_number,
        f.product_key,
        f.order_date,
        f.sales_amount,
        f.quantity,
        c.customer_key,
        c.customer_number,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        TIMESTAMPDIFF(YEAR, c.birthdate, CURDATE()) AS age
    FROM fact_sales f
    LEFT JOIN dim_customers c
        ON c.customer_key = f.customer_key
    WHERE f.order_date IS NOT NULL
      AND YEAR(f.order_date) BETWEEN 2000 AND 2030
),

customer_aggregation AS (
    -- 2. Aggregate customer-level metrics
    SELECT 
        customer_key,
        customer_number,
        customer_name,
        age,
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT product_key) AS total_products,
        MAX(order_date) AS last_order_date,
        -- Lifespan in months (avoid 1210 error by checking for valid dates)
        TIMESTAMPDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
    FROM base_query
    GROUP BY 
        customer_key,
        customer_number,
        customer_name,
        age
)

-- 3. Final output with KPIs and segments
SELECT
    customer_key,
    customer_number,
    customer_name,
    age,

    -- Age group segmentation
    CASE 
        WHEN age < 20 THEN 'Under 20'
        WHEN age BETWEEN 20 AND 29 THEN '20-29'
        WHEN age BETWEEN 30 AND 39 THEN '30-39'
        WHEN age BETWEEN 40 AND 49 THEN '40-49'
        ELSE '50 and above'
    END AS age_group,

    -- Customer segmentation
    CASE 
        WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,

    last_order_date,

    -- Recency in months
    TIMESTAMPDIFF(MONTH, last_order_date, CURDATE()) AS recency,

    total_orders,
    total_sales,
    total_quantity,
    total_products,
    lifespan,

    -- Average Order Value (AOV)
    CASE 
        WHEN total_orders = 0 THEN 0
        ELSE ROUND(total_sales / total_orders, 2)
    END AS avg_order_value,

    -- Average Monthly Spend
    CASE 
        WHEN lifespan = 0 THEN total_sales
        ELSE ROUND(total_sales / lifespan, 2)
    END AS avg_monthly_spend

FROM customer_aggregation;

SELECT *
FROM gold_report_customers;

-- Drop view if it already exists
DROP VIEW IF EXISTS gold_report_products;

-- Create product report view
CREATE VIEW gold_report_products AS

WITH base_query AS (
    -- 1. Base Query: joins sales with product details
    SELECT
        f.order_number,
        f.order_date,
        f.customer_key,
        f.sales_amount,
        f.quantity,
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost
    FROM fact_sales f
    LEFT JOIN dim_products p
        ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
      AND YEAR(f.order_date) BETWEEN 2000 AND 2030
),

product_aggregations AS (
    -- 2. Aggregated metrics for each product
    SELECT
        product_key,
        product_name,
        category,
        subcategory,
        cost,
        TIMESTAMPDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan,
        MAX(order_date) AS last_sale_date,
        COUNT(DISTINCT order_number) AS total_orders,
        COUNT(DISTINCT customer_key) AS total_customers,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        ROUND(AVG(sales_amount / NULLIF(quantity, 0)), 1) AS avg_selling_price
    FROM base_query
    GROUP BY
        product_key,
        product_name,
        category,
        subcategory,
        cost
)

-- 3. Final Output
SELECT
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    last_sale_date,
    TIMESTAMPDIFF(MONTH, last_sale_date, CURDATE()) AS recency_in_months,

    -- Segment products based on revenue
    CASE
        WHEN total_sales > 50000 THEN 'High-Performer'
        WHEN total_sales >= 10000 THEN 'Mid-Range'
        ELSE 'Low-Performer'
    END AS product_segment,

    lifespan,
    total_orders,
    total_sales,
    total_quantity,
    total_customers,
    avg_selling_price,

    -- Average Order Revenue (AOR)
    CASE
        WHEN total_orders = 0 THEN 0
        ELSE ROUND(total_sales / total_orders, 2)
    END AS avg_order_revenue,

    -- Average Monthly Revenue
    CASE
        WHEN lifespan = 0 THEN total_sales
        ELSE ROUND(total_sales / lifespan, 2)
    END AS avg_monthly_revenue

FROM product_aggregations;

SELECT *
FROM gold_report_products;

