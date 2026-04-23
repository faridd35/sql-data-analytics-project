-- ============================================================
-- Product Performance Analysis
-- Project  : SQL Data Analytics & BI Dashboard
-- Layer    : Gold (Views)
-- ============================================================

-- ============================================================
-- 1. PRODUCT OVERVIEW
--    Full performance summary per product
-- ============================================================

SELECT
    p.product_key,
    p.product_name,
    p.category,
    p.subcategory,
    p.product_line,
    p.cost,
    COUNT(DISTINCT f.order_number)               AS total_orders,
    SUM(f.quantity)                              AS total_quantity,
    SUM(f.sales_amount)                          AS total_revenue,
    ROUND(AVG(CAST(f.sales_amount AS FLOAT)), 2) AS avg_order_value,
    SUM(f.sales_amount) - (p.cost * SUM(f.quantity)) AS total_profit
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY
    p.product_key,
    p.product_name,
    p.category,
    p.subcategory,
    p.product_line,
    p.cost
ORDER BY total_revenue DESC;


-- ============================================================
-- 2. TOP & BOTTOM 5 PRODUCTS BY REVENUE
--    Identify best and worst performers
-- ============================================================

-- Top 5
SELECT TOP 5
    p.product_name,
    p.category,
    SUM(f.sales_amount) AS total_revenue,
    'Top 5' AS performance_label
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.product_name, p.category
ORDER BY total_revenue DESC;

-- Bottom 5
SELECT TOP 5
    p.product_name,
    p.category,
    SUM(f.sales_amount) AS total_revenue,
    'Bottom 5' AS performance_label
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.product_name, p.category
ORDER BY total_revenue ASC;

-- Combined Top & Bottom in one result (useful for Power BI)
WITH product_revenue AS (
    SELECT
        p.product_name,
        p.category,
        SUM(f.sales_amount) AS total_revenue,
        RANK() OVER (ORDER BY SUM(f.sales_amount) DESC) AS rank_top,
        RANK() OVER (ORDER BY SUM(f.sales_amount) ASC)  AS rank_bottom
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p ON f.product_key = p.product_key
    GROUP BY p.product_name, p.category
)
SELECT
    product_name,
    category,
    total_revenue,
    CASE
        WHEN rank_top    <= 5 THEN 'Top 5'
        WHEN rank_bottom <= 5 THEN 'Bottom 5'
    END AS performance_label
FROM product_revenue
WHERE rank_top <= 5 OR rank_bottom <= 5
ORDER BY total_revenue DESC;


-- ============================================================
-- 3. REVENUE BY CATEGORY & SUBCATEGORY
--    Hierarchical breakdown of product performance
-- ============================================================

-- By category
SELECT
    p.category,
    COUNT(DISTINCT p.product_key)   AS total_products,
    COUNT(DISTINCT f.order_number)  AS total_orders,
    SUM(f.quantity)                 AS total_quantity,
    SUM(f.sales_amount)             AS total_revenue,
    ROUND(
        100.0 * SUM(f.sales_amount) / SUM(SUM(f.sales_amount)) OVER (),
        2
    ) AS revenue_share_pct
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.category
ORDER BY total_revenue DESC;

-- By subcategory
SELECT
    p.category,
    p.subcategory,
    SUM(f.quantity)     AS total_quantity,
    SUM(f.sales_amount) AS total_revenue,
    ROUND(
        100.0 * SUM(f.sales_amount) / SUM(SUM(f.sales_amount)) OVER (PARTITION BY p.category),
        2
    ) AS revenue_share_within_category_pct
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.category, p.subcategory
ORDER BY p.category, total_revenue DESC;


-- ============================================================
-- 4. PRODUCT PERFORMANCE vs. AVERAGE (Benchmark)
--    Is a product above or below the overall average?
-- ============================================================

WITH product_revenue AS (
    SELECT
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        SUM(f.sales_amount) AS total_revenue
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p ON f.product_key = p.product_key
    GROUP BY
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory
)
SELECT
    product_key,
    product_name,
    category,
    subcategory,
    total_revenue,
    AVG(total_revenue) OVER ()  AS overall_avg_revenue,
    total_revenue - AVG(total_revenue) OVER () AS diff_from_avg,
    CASE
        WHEN total_revenue >= AVG(total_revenue) OVER () THEN 'Above Average'
        ELSE 'Below Average'
    END AS performance_vs_avg
FROM product_revenue
ORDER BY total_revenue DESC;


-- ============================================================
-- 5. PRODUCT PERFORMANCE BY PRODUCT LINE
--    Compare revenue across product lines
-- ============================================================

SELECT
    p.product_line,
    COUNT(DISTINCT p.product_key)  AS total_products,
    SUM(f.quantity)                AS total_quantity,
    SUM(f.sales_amount)            AS total_revenue,
    ROUND(AVG(CAST(f.sales_amount AS FLOAT)), 2) AS avg_revenue_per_order,
    ROUND(
        100.0 * SUM(f.sales_amount) / SUM(SUM(f.sales_amount)) OVER (),
        2
    ) AS revenue_share_pct
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.product_line
ORDER BY total_revenue DESC;


-- ============================================================
-- 6. PRODUCT SALES TREND OVER TIME
--    Track monthly revenue per category
-- ============================================================

SELECT
    YEAR(f.order_date)              AS order_year,
    MONTH(f.order_date)             AS order_month,
    DATENAME(MONTH, f.order_date)   AS month_name,
    p.category,
    SUM(f.sales_amount)             AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p ON f.product_key = p.product_key
WHERE f.order_date IS NOT NULL
GROUP BY
    YEAR(f.order_date),
    MONTH(f.order_date),
    DATENAME(MONTH, f.order_date),
    p.category
ORDER BY order_year, order_month, total_revenue DESC;


-- ============================================================
-- 7. PROFIT ANALYSIS BY PRODUCT
--    Estimate profit margin (revenue - cost * quantity)
-- ============================================================

WITH product_profit AS (
    SELECT
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost,
        SUM(f.quantity)     AS total_quantity,
        SUM(f.sales_amount) AS total_revenue,
        SUM(f.sales_amount) - (p.cost * SUM(f.quantity)) AS total_profit
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p ON f.product_key = p.product_key
    GROUP BY
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost
)
SELECT
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    total_revenue,
    total_profit,
    ROUND(
        100.0 * total_profit / NULLIF(total_revenue, 0),
        2
    ) AS profit_margin_pct,
    CASE
        WHEN 100.0 * total_profit / NULLIF(total_revenue, 0) >= 50 THEN 'High Margin'
        WHEN 100.0 * total_profit / NULLIF(total_revenue, 0) >= 20 THEN 'Medium Margin'
        ELSE 'Low Margin'
    END AS margin_category
FROM product_profit
ORDER BY profit_margin_pct DESC;