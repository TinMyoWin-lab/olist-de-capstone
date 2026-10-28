-- Week 4 · Day 2 homework — window functions lab, questions 3 to 5 (Week 4 Day 1 slides)

-- Q3. Running revenue per seller: how each seller's revenue adds up over time, order by order.
WITH seller_orders AS (
    SELECT
        oi.seller_id,
        oi.order_id,
        o.order_purchase_timestamp,
        SUM(oi.price + oi.freight_value) AS order_revenue
    FROM order_items AS oi
    JOIN orders AS o
        ON oi.order_id = o.order_id
    GROUP BY oi.seller_id, oi.order_id, o.order_purchase_timestamp
)
SELECT
    seller_id,
    order_id,
    order_purchase_timestamp,
    order_revenue,
    SUM(order_revenue) OVER (
        PARTITION BY seller_id
        ORDER BY order_purchase_timestamp, order_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_revenue
FROM seller_orders
ORDER BY seller_id, order_purchase_timestamp;

-- Q4. Share of money by payment type: what percentage of all money paid came from each payment type?
SELECT
    op.payment_type,
    SUM(op.payment_value) AS total_paid,
    ROUND(100.0 * SUM(op.payment_value) / SUM(SUM(op.payment_value)) OVER (), 1) AS pct_of_total
FROM order_payments AS op
GROUP BY op.payment_type
ORDER BY total_paid DESC;

-- Q5. Items priced above their category average: order items whose price is higher than the average price in their product category.
--     Products with no category are left out.
WITH item_avg AS (
    SELECT
        oi.order_id,
        oi.product_id,
        p.product_category_name AS category,
        oi.price,
        AVG(oi.price) OVER (PARTITION BY p.product_category_name) AS category_avg
    FROM order_items AS oi
    JOIN products AS p
        ON oi.product_id = p.product_id
    WHERE p.product_category_name IS NOT NULL
)
SELECT
    order_id,
    product_id,
    category,
    price,
    ROUND(category_avg, 2) AS category_avg
FROM item_avg
WHERE price > category_avg
ORDER BY category, price DESC;
