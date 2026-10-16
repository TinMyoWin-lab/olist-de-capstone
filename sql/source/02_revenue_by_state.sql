-- Q1: Revenue (SUM of price) by customer_state for delivered orders. Top 10 states.
SELECT
    c.customer_state,
    SUM(oi.price) AS revenue
FROM orders AS o
JOIN customers AS c
    ON o.customer_id = c.customer_id
JOIN order_items AS oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY revenue DESC
LIMIT 10;

-- Q2: How many orders have no review at all? (anti-join)
SELECT
    COUNT(*) AS orders_without_reviews
FROM orders AS o
LEFT JOIN order_reviews AS r
    ON o.order_id = r.order_id
WHERE r.order_id IS NULL;

-- Q3: Top 10 product categories in English by items sold. Why LEFT JOIN to the translation?
-- Why LEFT JOIN? Some categories (pc_gamer, NULL, ...) are missing from category_translation.
-- INNER JOIN will drop those rows. LEFT JOIN keeps every row

SELECT
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name
    ) AS category_name,
    COUNT(*) AS items_sold
FROM order_items AS oi
JOIN products AS p
    ON oi.product_id = p.product_id
LEFT JOIN category_translation AS ct
    ON p.product_category_name = ct.product_category_name
GROUP BY category_name
ORDER BY items_sold DESC
LIMIT 10;

-- Q4. What share of order items were sold by a seller in the same state as the customer?
SELECT
    COUNT(*) AS same_state_items,
    (SELECT COUNT(*) FROM order_items) AS total_items,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM order_items), 2) AS same_state_percentage
FROM order_items AS oi
JOIN orders AS o
    ON oi.order_id = o.order_id
JOIN customers AS c
    ON o.customer_id = c.customer_id
JOIN sellers AS s
    ON oi.seller_id = s.seller_id
WHERE s.seller_state = c.customer_state;


-- Q5. For 5 orders, show item revenue and payment total side by side — without fan-out.
SELECT
    item_totals.order_id,
    item_totals.item_revenue,
    payment_totals.payment_total
FROM (
    SELECT
        order_id,
        SUM(price) AS item_revenue
    FROM order_items
    GROUP BY order_id
) AS item_totals
JOIN (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total
    FROM order_payments
    GROUP BY order_id
) AS payment_totals
    ON item_totals.order_id = payment_totals.order_id
ORDER BY item_totals.order_id
LIMIT 5;


-- Q6. Find orders where payments differ from price + freight by more than 1.00.
SELECT
    p.order_id,
    SUM(p.payment_value) AS payment_total,
    i.item_total
FROM order_payments AS p
JOIN (
    SELECT order_id, SUM(price + freight_value) AS item_total
    FROM order_items
    GROUP BY order_id
) AS i
    ON p.order_id = i.order_id
GROUP BY p.order_id, i.item_total
HAVING ABS(SUM(p.payment_value) - i.item_total) > 1.00;



