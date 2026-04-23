-- ============================================================
-- Exploratory Data Analysis (EDA)
-- Project  : SQL Data Analytics & BI Dashboard
-- Layer    : Gold (Views)
-- ============================================================

-- ============================================================
-- 1. DATABASE EXPLORATION
--    Understand what tables/views exist and their structure
-- ============================================================

-- List all objects in the gold schema
SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'gold'
ORDER BY TABLE_NAME;

-- Inspect columns of each gold view
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'gold'
ORDER BY TABLE_NAME, ORDINAL_POSITION;

-- ============================================================
-- 2. DIMENSIONS EXPLORATION
--    Understand the range and uniqueness of dimension values
-- ============================================================

-- ── dim_customers ────────────────────────────────────────────

-- Total number of customers
SELECT COUNT(*) AS total_customers
FROM gold.dim_customers;

-- Distinct countries
SELECT DISTINCT country
FROM gold.dim_customers
ORDER BY country;

-- Gender distribution
SELECT
    gender,
    COUNT(*) AS total
FROM gold.dim_customers
GROUP BY gender;

-- Marital status distribution
SELECT
    marital_status,
    COUNT(*) AS total
FROM gold.dim_customers
GROUP BY marital_status;

-- Age range of customers (as of today)
SELECT
    MIN(DATEDIFF(YEAR, birthdate, GETDATE())) AS min_age,
    MAX(DATEDIFF(YEAR, birthdate, GETDATE())) AS max_age,
    AVG(DATEDIFF(YEAR, birthdate, GETDATE())) AS avg_age
FROM gold.dim_customers
WHERE birthdate IS NOT NULL;


-- ── dim_products ─────────────────────────────────────────────

-- Total number of active products
SELECT COUNT(*) AS total_products
FROM gold.dim_products;

-- Distinct categories and subcategories
SELECT
    category,
    COUNT(DISTINCT subcategory) AS total_subcategories,
    COUNT(*)                    AS total_products
FROM gold.dim_products
GROUP BY category
ORDER BY total_products DESC;

-- Product line distribution
SELECT
    product_line,
    COUNT(*) AS total_products
FROM gold.dim_products
GROUP BY product_line
ORDER BY total_products DESC;

-- Cost range by category
SELECT
    category,
    MIN(cost) AS min_cost,
    MAX(cost) AS max_cost,
    AVG(cost) AS avg_cost
FROM gold.dim_products
GROUP BY category
ORDER BY avg_cost DESC;


-- ============================================================
-- 3. FACT TABLE EXPLORATION
--    Understand the scope and scale of the sales data
-- ============================================================

-- Date range of orders
SELECT
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date,
    DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS months_of_data
FROM gold.fact_sales;

-- Total rows (order lines)
SELECT COUNT(*) AS total_order_lines
FROM gold.fact_sales;

-- Total unique orders
SELECT COUNT(DISTINCT order_number) AS total_orders
FROM gold.fact_sales;

-- Null check on key columns
SELECT
    SUM(CASE WHEN order_number  IS NULL THEN 1 ELSE 0 END) AS null_order_number,
    SUM(CASE WHEN product_key   IS NULL THEN 1 ELSE 0 END) AS null_product_key,
    SUM(CASE WHEN customer_key  IS NULL THEN 1 ELSE 0 END) AS null_customer_key,
    SUM(CASE WHEN order_date    IS NULL THEN 1 ELSE 0 END) AS null_order_date,
    SUM(CASE WHEN sales_amount  IS NULL THEN 1 ELSE 0 END) AS null_sales_amount,
    SUM(CASE WHEN quantity      IS NULL THEN 1 ELSE 0 END) AS null_quantity
FROM gold.fact_sales;


-- ============================================================
-- 4. MAGNITUDE METRICS
--    High-level business numbers
-- ============================================================

-- Overall KPIs
SELECT
    COUNT(DISTINCT f.order_number)  AS total_orders,
    COUNT(DISTINCT f.customer_key)  AS total_customers,
    COUNT(DISTINCT f.product_key)   AS total_products,
    SUM(f.sales_amount)             AS total_revenue,
    SUM(f.quantity)                 AS total_quantity,
    AVG(f.price)                    AS avg_unit_price
FROM gold.fact_sales f;

-- Revenue by country
SELECT
    c.country,
    SUM(f.sales_amount) AS total_revenue,
    COUNT(DISTINCT f.customer_key) AS total_customers
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.country
ORDER BY total_revenue DESC;

-- Revenue by category
SELECT
    p.category,
    SUM(f.sales_amount) AS total_revenue,
    COUNT(DISTINCT f.order_number) AS total_orders
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.category
ORDER BY total_revenue DESC;

-- Revenue by year
SELECT
    YEAR(f.order_date)  AS order_year,
    SUM(f.sales_amount) AS total_revenue,
    COUNT(DISTINCT f.order_number) AS total_orders
FROM gold.fact_sales f
GROUP BY YEAR(f.order_date)
ORDER BY order_year;


-- ============================================================
-- 5. RANKING EXPLORATION
--    Quick top/bottom snapshots
-- ============================================================

-- Top 5 products by revenue
SELECT TOP 5
    p.product_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.product_name
ORDER BY total_revenue DESC;

-- Bottom 5 products by revenue
SELECT TOP 5
    p.product_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.product_name
ORDER BY total_revenue ASC;

-- Top 5 customers by revenue
SELECT TOP 5
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.country,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.first_name, c.last_name, c.country
ORDER BY total_revenue DESC;