-- ============================================================
-- Sales Trends Analysis
-- Project  : SQL Data Analytics & BI Dashboard
-- Layer    : Gold (Views)
-- ============================================================

-- ============================================================
-- 1. MONTHLY REVENUE TREND
--    How does revenue change month by month?
-- ============================================================

SELECT
    YEAR(order_date)                        AS order_year,
    MONTH(order_date)                       AS order_month,
    DATENAME(MONTH, order_date)             AS month_name,
    SUM(sales_amount)                       AS total_revenue,
    COUNT(DISTINCT order_number)            AS total_orders,
    COUNT(DISTINCT customer_key)            AS total_customers,
    SUM(quantity)                           AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY
    YEAR(order_date),
    MONTH(order_date),
    DATENAME(MONTH, order_date)
ORDER BY order_year, order_month;


-- ============================================================
-- 2. YEARLY REVENUE TREND
--    Aggregate view for year-level reporting
-- ============================================================

SELECT
    YEAR(order_date)             AS order_year,
    SUM(sales_amount)            AS total_revenue,
    COUNT(DISTINCT order_number) AS total_orders,
    COUNT(DISTINCT customer_key) AS total_customers,
    AVG(sales_amount)            AS avg_order_value
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY order_year;


-- ============================================================
-- 3. MONTH-OVER-MONTH (MoM) GROWTH
--    Is revenue growing or shrinking vs. previous month?
-- ============================================================

WITH monthly_revenue AS (
    SELECT
        YEAR(order_date)            AS order_year,
        MONTH(order_date)           AS order_month,
        DATENAME(MONTH, order_date) AS month_name,
        SUM(sales_amount)           AS total_revenue
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY
        YEAR(order_date),
        MONTH(order_date),
        DATENAME(MONTH, order_date)
)
SELECT
    order_year,
    order_month,
    month_name,
    total_revenue,
    LAG(total_revenue) OVER (ORDER BY order_year, order_month) AS prev_month_revenue,
    total_revenue - LAG(total_revenue) OVER (ORDER BY order_year, order_month) AS mom_change,
    ROUND(
        100.0 * (total_revenue - LAG(total_revenue) OVER (ORDER BY order_year, order_month))
              / NULLIF(LAG(total_revenue) OVER (ORDER BY order_year, order_month), 0),
        2
    ) AS mom_growth_pct
FROM monthly_revenue
ORDER BY order_year, order_month;


-- ============================================================
-- 4. YEAR-OVER-YEAR (YoY) GROWTH
--    How does each month compare to the same month last year?
-- ============================================================

WITH monthly_revenue AS (
    SELECT
        YEAR(order_date)            AS order_year,
        MONTH(order_date)           AS order_month,
        DATENAME(MONTH, order_date) AS month_name,
        SUM(sales_amount)           AS total_revenue
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY
        YEAR(order_date),
        MONTH(order_date),
        DATENAME(MONTH, order_date)
)
SELECT
    order_year,
    order_month,
    month_name,
    total_revenue,
    LAG(total_revenue, 12) OVER (ORDER BY order_year, order_month) AS same_month_last_year,
    total_revenue - LAG(total_revenue, 12) OVER (ORDER BY order_year, order_month) AS yoy_change,
    ROUND(
        100.0 * (total_revenue - LAG(total_revenue, 12) OVER (ORDER BY order_year, order_month))
              / NULLIF(LAG(total_revenue, 12) OVER (ORDER BY order_year, order_month), 0),
        2
    ) AS yoy_growth_pct
FROM monthly_revenue
ORDER BY order_year, order_month;


-- ============================================================
-- 5. RUNNING TOTAL (Cumulative Revenue)
--    Tracks total revenue accumulated over time
-- ============================================================

SELECT
    order_date,
    daily_revenue,
    SUM(daily_revenue) OVER (ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total_revenue,
    AVG(daily_revenue) OVER (ORDER BY order_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)         AS moving_avg_7day
FROM (
    SELECT
        order_date,
        SUM(sales_amount) AS daily_revenue
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY order_date
) AS daily
ORDER BY order_date;


-- ============================================================
-- 6. SEASONALITY ANALYSIS
--    Which months consistently perform best across years?
-- ============================================================

SELECT
    MONTH(order_date)           AS order_month,
    DATENAME(MONTH, order_date) AS month_name,
    SUM(sales_amount)           AS total_revenue,
    ROUND(AVG(CAST(sales_amount AS FLOAT)), 2) AS avg_revenue_per_year,
    COUNT(DISTINCT YEAR(order_date)) AS years_present
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY
    MONTH(order_date),
    DATENAME(MONTH, order_date)
ORDER BY order_month;


-- ============================================================
-- 7. REVENUE BY WEEKDAY
--    Are there patterns based on day of the week?
-- ============================================================

SELECT
    DATEPART(WEEKDAY, order_date)    AS weekday_number,
    DATENAME(WEEKDAY, order_date)    AS weekday_name,
    COUNT(DISTINCT order_number)     AS total_orders,
    SUM(sales_amount)                AS total_revenue,
    ROUND(AVG(CAST(sales_amount AS FLOAT)), 2) AS avg_revenue_per_day
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY
    DATEPART(WEEKDAY, order_date),
    DATENAME(WEEKDAY, order_date)
ORDER BY weekday_number;