BEGIN;

CREATE TEMP TABLE watermark_backup ON COMMIT DROP AS
SELECT * FROM staging.etl_control WHERE table_name = 'order_items';

CALL staging.load_orders_incremental();

CREATE TEMP TABLE test_ids ON COMMIT DROP AS
SELECT
    (SELECT o.order_id FROM staging.orders AS o
     WHERE NOT EXISTS (
         SELECT 1 FROM staging.order_items AS i
         WHERE i.order_id = o.order_id AND i.order_item_id >= 900
     ) LIMIT 1) AS order_id,
    (SELECT product_id FROM staging.products LIMIT 1) AS product_id;

ALTER TABLE raw.order_items RENAME TO order_items_original;
CREATE TABLE raw.order_items AS
SELECT * FROM raw.order_items_original WITH NO DATA;

INSERT INTO staging.etl_control (table_name, last_loaded_ts)
VALUES ('order_items', '2029-12-31')
ON CONFLICT (table_name) DO UPDATE SET last_loaded_ts = '2029-12-31';

INSERT INTO raw.order_items (
    order_id, order_item_id, product_id, shipping_limit_date, price, freight_value
)
SELECT
    CASE WHEN v.item_id = 901 THEN NULL
         WHEN v.item_id = 904 THEN 'missing_order'
         ELSE t.order_id END,
    v.item_id,
    CASE WHEN v.item_id = 905 THEN 'missing_product' ELSE t.product_id END,
    v.shipping_date,
    v.price,
    v.freight
FROM test_ids AS t
CROSS JOIN (VALUES
    (900, TIMESTAMP '2030-01-01', 100, 10),
    (901, TIMESTAMP '2030-01-01',  10,  1),
    (902, TIMESTAMP '2030-01-01',   0,  1),
    (903, TIMESTAMP '2030-01-01',  10, -1),
    (904, TIMESTAMP '2030-01-01',  10,  1),
    (905, TIMESTAMP '2030-01-01',  10,  1),
    (906, TIMESTAMP '2030-01-01',  20,  2),
    (906, TIMESTAMP '2030-01-02',  30,  3)
) AS v(item_id, shipping_date, price, freight);

CALL staging.load_order_items_incremental();

SELECT order_item_id, price, freight_value, total_amount, shipping_limit_ts
FROM staging.order_items
WHERE order_id = (SELECT order_id FROM test_ids)
    AND order_item_id IN (900, 906)
ORDER BY order_item_id;

SELECT business_key, reason
FROM staging.rejected_rows
WHERE run_id = (
    SELECT run_id FROM staging.etl_log
    WHERE step_name = 'load_order_items_incremental'
    ORDER BY log_id DESC LIMIT 1
)
ORDER BY reason;

SELECT 'Initial load' AS test, status, rows_read, rows_loaded, rows_rejected,
    rows_read = rows_loaded + rows_rejected AS counts_match
FROM staging.etl_log
WHERE step_name = 'load_order_items_incremental'
ORDER BY log_id DESC LIMIT 1;

CALL staging.load_order_items_incremental();

SELECT 'Second run' AS test, status, rows_read,
    rows_read = 0 AS no_new_rows,
    watermark_from = watermark_to AS watermark_unchanged,
    rows_read = rows_loaded + rows_rejected AS counts_match
FROM staging.etl_log
WHERE step_name = 'load_order_items_incremental'
ORDER BY log_id DESC LIMIT 1;

INSERT INTO raw.order_items (
    order_id, order_item_id, product_id, shipping_limit_date, price, freight_value
)
SELECT t.order_id, v.item_id, t.product_id, TIMESTAMP '2030-01-03', v.price, 1
FROM test_ids AS t
CROSS JOIN (VALUES (907, 10), (908, 0)) AS v(item_id, price);

ALTER TABLE staging.order_items RENAME TO order_items_before_failure;
CALL staging.load_order_items_incremental();
ALTER TABLE staging.order_items_before_failure RENAME TO order_items;

SELECT 'Forced failure' AS test, status, message,
    watermark_from = watermark_to AS log_watermark_unchanged,
    (SELECT last_loaded_ts FROM staging.etl_control WHERE table_name = 'order_items')
        = watermark_from AS control_watermark_unchanged,
    rows_read = rows_loaded + rows_rejected AS counts_match,
    NOT EXISTS (
        SELECT 1 FROM staging.rejected_rows AS r WHERE r.run_id = l.run_id
    ) AS rejects_rolled_back
FROM staging.etl_log AS l
WHERE step_name = 'load_order_items_incremental'
ORDER BY log_id DESC LIMIT 1;

DELETE FROM staging.etl_control WHERE table_name = 'order_items';
INSERT INTO staging.etl_control (table_name, last_loaded_ts)
SELECT table_name, last_loaded_ts FROM watermark_backup;

SELECT table_name, last_loaded_ts
FROM staging.etl_control
WHERE table_name = 'order_items';

ROLLBACK;
