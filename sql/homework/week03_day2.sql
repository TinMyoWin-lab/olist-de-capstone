-- Week 3 · Day 2 homework — types, NULLs, dates, strings

-- Q1. NULL audit: count NULLs in product_category_name
--     and product_weight_g.
SELECT
    COUNT(*) AS total_products,
    COUNT(*) - COUNT(product_category_name) AS null_category_count,
    COUNT(*) - COUNT(product_weight_g) AS null_weight_count
FROM raw.products;

-- Q2. For each month of purchase, what is the average delivery
--     time, and how many orders (and what percentage) were
--     delivered within 30 days of purchase?
WITH delivered AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp)::date AS purchase_month,
        o.order_delivered_customer_date::date
            - o.order_purchase_timestamp::date AS delivery_days
    FROM raw.orders AS o
    WHERE o.order_status = 'delivered'
        AND o.order_purchase_timestamp IS NOT NULL
        AND o.order_delivered_customer_date IS NOT NULL
)
SELECT
    purchase_month,
    COUNT(*) AS delivered_orders,
    ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
    SUM(CASE WHEN delivery_days <= 30 THEN 1 ELSE 0 END)
        AS delivered_within_30_days,
    ROUND(100.0 * AVG((delivery_days <= 30)::integer), 2)
        AS within_30_days_pct
FROM delivered
GROUP BY purchase_month
ORDER BY purchase_month;

-- Q3. On which day of the week do customers place the most orders?
--     Show each weekday's name and number, and the total orders
--     for that day, sorted from busiest to quietest.
SELECT
    EXTRACT(DOW FROM o.order_purchase_timestamp)::integer AS weekday_number,
    TO_CHAR(o.order_purchase_timestamp, 'FMDay') AS weekday_name,
    COUNT(*) AS total_orders
FROM raw.orders AS o
WHERE o.order_purchase_timestamp IS NOT NULL
GROUP BY
    EXTRACT(DOW FROM o.order_purchase_timestamp)::integer,
    TO_CHAR(o.order_purchase_timestamp, 'FMDay')
ORDER BY total_orders DESC, weekday_number;

-- Q4. What is the total revenue for each product category,
--     shown with its English name? If there is no English
--     translation, show Portuguese; if no category, show 'unknown'.
SELECT
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'unknown'
    ) AS category_name,
    ROUND(SUM(oi.price), 2) AS total_revenue
FROM raw.order_items AS oi
LEFT JOIN raw.products AS p
    ON p.product_id = oi.product_id
LEFT JOIN raw.category_translation AS ct
    ON ct.product_category_name = p.product_category_name
GROUP BY
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'unknown'
    )
ORDER BY total_revenue DESC NULLS LAST, category_name;

-- Q5. Group delivered orders by delivery speed. Show each group's
--     order count and percentage of the total.
--     Fast: 7 days or less; Normal: 8-14 days;
--     Slow: 15-30 days; Very slow: more than 30 days.
WITH delivered AS (
    SELECT
        o.order_delivered_customer_date::date
            - o.order_purchase_timestamp::date AS delivery_days
    FROM raw.orders AS o
    WHERE o.order_status = 'delivered'
        AND o.order_purchase_timestamp IS NOT NULL
        AND o.order_delivered_customer_date IS NOT NULL
),
delivery_groups AS (
    SELECT
        CASE
            WHEN delivery_days <= 7 THEN 'Fast'
            WHEN delivery_days <= 14 THEN 'Normal'
            WHEN delivery_days <= 30 THEN 'Slow'
            ELSE 'Very slow'
        END AS delivery_speed
    FROM delivered
)
SELECT
    delivery_speed,
    COUNT(*) AS order_count,
    ROUND(
        100.0 * COUNT(*) / NULLIF((SELECT COUNT(*) FROM delivered), 0),
        2
    ) AS percentage_of_total
FROM delivery_groups
GROUP BY delivery_speed
ORDER BY CASE delivery_speed
    WHEN 'Fast' THEN 1
    WHEN 'Normal' THEN 2
    WHEN 'Slow' THEN 3
    WHEN 'Very slow' THEN 4
END;
