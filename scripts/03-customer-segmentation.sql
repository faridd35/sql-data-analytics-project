-- ============================================================
-- Customer Segmentation & Behavior Analysis
-- Project  : SQL Data Analytics & BI Dashboard
-- Layer    : Gold (Views)
-- ============================================================

-- ============================================================
-- 1. CUSTOMER OVERVIEW
--    Basic profile of all customers who have made purchases
-- ============================================================

SELECT
    c.customer_key,
    CONCAT(c.first_name, ' ', c.last_name)  AS customer_name,
    c.country,
    c.gender,
    c.marital_status,
    DATEDIFF(YEAR, c.birthdate, GETDATE())  AS age,
    MIN(f.order_date)                        AS first_order_date,
    MAX(f.order_date)                        AS last_order_date,
    DATEDIFF(MONTH, MIN(f.order_date), MAX(f.order_date)) AS customer_lifespan_months,
    COUNT(DISTINCT f.order_number)           AS total_orders,
    SUM(f.sales_amount)                      AS total_revenue,
    SUM(f.quantity)                          AS total_quantity,
    ROUND(AVG(CAST(f.sales_amount AS FLOAT)), 2) AS avg_order_value
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY
    c.customer_key,
    c.first_name,
    c.last_name,
    c.country,
    c.gender,
    c.marital_status,
    c.birthdate
ORDER BY total_revenue DESC;


-- ============================================================
-- 2. CUSTOMER SEGMENTATION — BY SPEND
--    Classify customers into VIP / Regular / New
--    based on lifespan and total revenue
-- ============================================================

WITH customer_summary AS (
    SELECT
        c.customer_key,
        CONCAT(c.first_name, ' ', c.last_name)      AS customer_name,
        c.country,
        c.gender,
        DATEDIFF(MONTH, MIN(f.order_date), MAX(f.order_date)) AS lifespan_months,
        SUM(f.sales_amount)                          AS total_revenue
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c ON f.customer_key = c.customer_key
    GROUP BY
        c.customer_key,
        c.first_name,
        c.last_name,
        c.country,
        c.gender
)
SELECT
    customer_key,
    customer_name,
    country,
    gender,
    lifespan_months,
    total_revenue,
    CASE
        WHEN lifespan_months >= 12 AND total_revenue > 5000 THEN 'VIP'
        WHEN lifespan_months >= 6  AND total_revenue > 1000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment
FROM customer_summary
ORDER BY total_revenue DESC;


-- ============================================================
-- 3. SEGMENT SUMMARY
--    How many customers per segment? What's their revenue share?
-- ============================================================

WITH customer_summary AS (
    SELECT
        c.customer_key,
        DATEDIFF(MONTH, MIN(f.order_date), MAX(f.order_date)) AS lifespan_months,
        SUM(f.sales_amount)                                    AS total_revenue
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c ON f.customer_key = c.customer_key
    GROUP BY c.customer_key
),
segmented AS (
    SELECT
        customer_key,
        total_revenue,
        CASE
            WHEN lifespan_months >= 12 AND total_revenue > 5000 THEN 'VIP'
            WHEN lifespan_months >= 6  AND total_revenue > 1000 THEN 'Regular'
            ELSE 'New'
        END AS customer_segment
    FROM customer_summary
)
SELECT
    customer_segment,
    COUNT(customer_key)  AS total_customers,
    SUM(total_revenue)   AS total_revenue,
    ROUND(
        100.0 * SUM(total_revenue) / SUM(SUM(total_revenue)) OVER (),
        2
    )                    AS revenue_share_pct
FROM segmented
GROUP BY customer_segment
ORDER BY total_revenue DESC;


-- ============================================================
-- 4. CUSTOMER RANKING — TOP 10 BY REVENUE
--    Who are the highest-value customers?
-- ============================================================

SELECT TOP 10
    c.customer_key,
    CONCAT(c.first_name, ' ', c.last_name)  AS customer_name,
    c.country,
    SUM(f.sales_amount)                      AS total_revenue,
    COUNT(DISTINCT f.order_number)           AS total_orders,
    RANK() OVER (ORDER BY SUM(f.sales_amount) DESC) AS revenue_rank
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY
    c.customer_key,
    c.first_name,
    c.last_name,
    c.country
ORDER BY revenue_rank;


-- ============================================================
-- 5. REVENUE BY COUNTRY & GENDER
--    Geographic and demographic revenue breakdown
-- ============================================================

-- By country
SELECT
    c.country,
    COUNT(DISTINCT f.customer_key)  AS total_customers,
    SUM(f.sales_amount)             AS total_revenue,
    ROUND(
        100.0 * SUM(f.sales_amount) / SUM(SUM(f.sales_amount)) OVER (),
        2
    )                               AS revenue_share_pct
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.country
ORDER BY total_revenue DESC;

-- By gender
SELECT
    c.gender,
    COUNT(DISTINCT f.customer_key)  AS total_customers,
    SUM(f.sales_amount)             AS total_revenue,
    ROUND(
        100.0 * SUM(f.sales_amount) / SUM(SUM(f.sales_amount)) OVER (),
        2
    )                               AS revenue_share_pct
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.gender
ORDER BY total_revenue DESC;

-- By marital status
SELECT
    c.marital_status,
    COUNT(DISTINCT f.customer_key)  AS total_customers,
    SUM(f.sales_amount)             AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.marital_status
ORDER BY total_revenue DESC;


-- ============================================================
-- 6. CUSTOMER AGE GROUP ANALYSIS
--    Which age groups generate the most revenue?
-- ============================================================

WITH customer_age AS (
    SELECT
        c.customer_key,
        DATEDIFF(YEAR, c.birthdate, GETDATE()) AS age,
        f.sales_amount
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c ON f.customer_key = c.customer_key
    WHERE c.birthdate IS NOT NULL
)
SELECT
    CASE
        WHEN age < 25                THEN 'Under 25'
        WHEN age BETWEEN 25 AND 34  THEN '25 - 34'
        WHEN age BETWEEN 35 AND 44  THEN '35 - 44'
        WHEN age BETWEEN 45 AND 54  THEN '45 - 54'
        WHEN age BETWEEN 55 AND 64  THEN '55 - 64'
        ELSE '65+'
    END                             AS age_group,
    COUNT(DISTINCT customer_key)    AS total_customers,
    SUM(sales_amount)               AS total_revenue,
    ROUND(AVG(CAST(sales_amount AS FLOAT)), 2) AS avg_order_value
FROM customer_age
GROUP BY
    CASE
        WHEN age < 25                THEN 'Under 25'
        WHEN age BETWEEN 25 AND 34  THEN '25 - 34'
        WHEN age BETWEEN 35 AND 44  THEN '35 - 44'
        WHEN age BETWEEN 45 AND 54  THEN '45 - 54'
        WHEN age BETWEEN 55 AND 64  THEN '55 - 64'
        ELSE '65+'
    END
ORDER BY total_revenue DESC;


-- ============================================================
-- 7. CUSTOMER RETENTION — FIRST vs. REPEAT BUYERS
--    How many customers placed more than one order?
-- ============================================================

WITH order_counts AS (
    SELECT
        customer_key,
        COUNT(DISTINCT order_number) AS total_orders
    FROM gold.fact_sales
    GROUP BY customer_key
)
SELECT
    CASE
        WHEN total_orders = 1 THEN 'One-time Buyer'
        WHEN total_orders BETWEEN 2 AND 5 THEN 'Repeat Buyer'
        ELSE 'Loyal Buyer'
    END                     AS buyer_type,
    COUNT(customer_key)     AS total_customers,
    ROUND(
        100.0 * COUNT(customer_key) / SUM(COUNT(customer_key)) OVER (),
        2
    )                       AS customer_share_pct
FROM order_counts
GROUP BY
    CASE
        WHEN total_orders = 1 THEN 'One-time Buyer'
        WHEN total_orders BETWEEN 2 AND 5 THEN 'Repeat Buyer'
        ELSE 'Loyal Buyer'
    END
ORDER BY total_customers DESC;