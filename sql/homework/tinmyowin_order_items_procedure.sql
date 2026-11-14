CREATE TABLE IF NOT EXISTS staging.order_items (
    order_id           TEXT NOT NULL,
    order_item_id      INT NOT NULL,
    product_id         TEXT,
    seller_id          TEXT,
    shipping_limit_ts  TIMESTAMP,
    price              NUMERIC(10,2),
    freight_value      NUMERIC(10,2),
    total_amount       NUMERIC(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

CREATE OR REPLACE PROCEDURE staging.load_order_items_incremental()
LANGUAGE plpgsql AS $$
DECLARE
    v_run_id    UUID := gen_random_uuid();
    v_log_id    BIGINT;
    v_wm_from   TIMESTAMP;
    v_wm_to     TIMESTAMP;
    v_read      INT := 0;
    v_rejected  INT := 0;
    v_loaded    INT := 0;
BEGIN
    INSERT INTO staging.etl_control (table_name, last_loaded_ts)
    VALUES ('order_items', TIMESTAMP '1900-01-01')
    ON CONFLICT (table_name) DO NOTHING;

    SELECT last_loaded_ts INTO v_wm_from
    FROM staging.etl_control
    WHERE table_name = 'order_items'
    FOR UPDATE;

    v_wm_to := v_wm_from;

    INSERT INTO staging.etl_log (
        run_id, step_name, started_at, status, watermark_from
    )
    VALUES (
        v_run_id, 'load_order_items_incremental',
        clock_timestamp(), 'RUNNING', v_wm_from
    )
    RETURNING log_id INTO v_log_id;

    BEGIN
        DROP TABLE IF EXISTS pg_temp.tmp_order_items_delta;
        CREATE TEMP TABLE tmp_order_items_delta ON COMMIT DROP AS
        SELECT
            d.*,
            CASE
                WHEN d.order_id IS NULL OR d.order_item_id IS NULL
                    THEN 'NULL_KEY'
                WHEN d.price IS NULL OR d.price <= 0
                    THEN 'INVALID_PRICE'
                WHEN d.freight_value < 0
                    THEN 'NEGATIVE_FREIGHT'
                WHEN NOT EXISTS (
                    SELECT 1 FROM staging.orders AS o
                    WHERE o.order_id = d.order_id
                ) THEN 'ORPHAN_ORDER'
                WHEN NOT EXISTS (
                    SELECT 1 FROM staging.products AS p
                    WHERE p.product_id = d.product_id
                ) THEN 'ORPHAN_PRODUCT'
            END AS dq_reason
        FROM (
            SELECT DISTINCT ON (r.order_id, r.order_item_id)
                r.order_id,
                r.order_item_id,
                r.product_id,
                r.seller_id,
                r.shipping_limit_date AS shipping_limit_ts,
                r.price,
                r.freight_value,
                r.price + r.freight_value AS total_value
            FROM raw.order_items AS r
            WHERE r.shipping_limit_date > v_wm_from
            ORDER BY r.order_id, r.order_item_id, r.shipping_limit_date DESC
        ) AS d;

        SELECT COUNT(*), COUNT(*) FILTER (WHERE dq_reason IS NOT NULL)
        INTO v_read, v_rejected
        FROM tmp_order_items_delta;

        INSERT INTO staging.rejected_rows (
            run_id, table_name, business_key, reason, row_data
        )
        SELECT
            v_run_id,
            'order_items',
            t.order_id || '-' || t.order_item_id::text,
            t.dq_reason,
            to_jsonb(t) - 'dq_reason'
        FROM tmp_order_items_delta AS t
        WHERE t.dq_reason IS NOT NULL;

        INSERT INTO staging.order_items (
            order_id, order_item_id, product_id, seller_id,
            shipping_limit_ts, price, freight_value, total_amount
        )
        SELECT
            order_id, order_item_id, product_id, seller_id,
            shipping_limit_ts, price, freight_value, total_value
        FROM tmp_order_items_delta
        WHERE dq_reason IS NULL
        ON CONFLICT (order_id, order_item_id) DO UPDATE
        SET product_id        = EXCLUDED.product_id,
            seller_id         = EXCLUDED.seller_id,
            shipping_limit_ts = EXCLUDED.shipping_limit_ts,
            price             = EXCLUDED.price,
            freight_value     = EXCLUDED.freight_value,
            total_amount      = EXCLUDED.total_amount;
        GET DIAGNOSTICS v_loaded = ROW_COUNT;

        IF v_read > 0 THEN
            SELECT MAX(shipping_limit_ts) INTO v_wm_to
            FROM tmp_order_items_delta;

            UPDATE staging.etl_control
            SET last_loaded_ts = v_wm_to
            WHERE table_name = 'order_items';
        END IF;

        UPDATE staging.etl_log
        SET status = 'SUCCESS',
            finished_at = clock_timestamp(),
            rows_read = v_read,
            rows_loaded = v_loaded,
            rows_rejected = v_rejected,
            watermark_to = v_wm_to
        WHERE log_id = v_log_id;

        RAISE NOTICE 'order_items incremental: read %, loaded %, rejected %, watermark % -> %',
            v_read, v_loaded, v_rejected, v_wm_from, v_wm_to;

    EXCEPTION WHEN OTHERS THEN
        UPDATE staging.etl_log
        SET status = 'FAILED',
            finished_at = clock_timestamp(),
            rows_read = 0,
            rows_loaded = 0,
            rows_rejected = 0,
            watermark_to = v_wm_from,
            message = SQLERRM || format(
                ' (attempted: read=%s, loaded=%s, rejected=%s; rolled back)',
                v_read, v_loaded, v_rejected
            )
        WHERE log_id = v_log_id;

        RAISE WARNING 'load_order_items_incremental FAILED: %', SQLERRM;
    END;
END;
$$;
