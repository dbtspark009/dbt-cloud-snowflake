-- ============================================================
-- setup_raw_data.sql
-- Run this ONCE, manually, in a Snowflake worksheet.
-- This simulates what a real ingestion tool (Snowpipe, Fivetran,
-- Airbyte, etc.) would already have loaded for you.
-- dbt does NOT create this table — dbt only reads/transforms it.
--
-- NOTE ON ENVIRONMENTS:
-- RAW data is intentionally NOT duplicated per dev/qa/prod. In a real
-- warehouse, ingestion lands data ONCE in a shared RAW schema, and it
-- is dbt's BRONZE/SILVER/GOLD models (built by dbt) that get separate
-- copies per environment (DEV_BRONZE, QA_BRONZE, PROD_BRONZE, etc.).
-- Dev/QA/CI can either point at this same shared RAW schema (common
-- for small teams) or at a masked/sampled clone of it (common once
-- you have PII — see the "going further" notes in README.md).
-- ============================================================

CREATE DATABASE IF NOT EXISTS DEMO_DB;
CREATE SCHEMA IF NOT EXISTS DEMO_DB.RAW;          -- shared landing zone, source of "bronze"

CREATE OR REPLACE TABLE DEMO_DB.RAW.ORDERS (
    order_id      VARCHAR,
    customer_id   VARCHAR,
    order_status  VARCHAR,      -- 'completed', 'cancelled', 'pending'
    order_amount  FLOAT,
    order_date    TIMESTAMP_NTZ
);

INSERT INTO DEMO_DB.RAW.ORDERS VALUES
    ('ord_1', 'cust_1', 'completed',  120.50, '2026-08-01 10:15:00'),
    ('ord_2', 'cust_2', 'completed',   45.00, '2026-08-01 11:02:00'),
    ('ord_3', 'cust_1', 'cancelled',   75.25, '2026-08-02 09:40:00'),
    ('ord_4', 'cust_3', 'completed',  210.00, '2026-08-02 14:22:00'),
    ('ord_5', 'cust_2', 'pending',     30.00, '2026-08-03 08:05:00'),
    ('ord_6', 'cust_3', 'completed',   99.99, '2026-08-03 16:47:00'),
    ('ord_7', 'cust_1', 'completed',  150.00, '2026-08-03 18:10:00'),
    -- a deliberate duplicate row, so silver layer has something to dedupe
    ('ord_1', 'cust_1', 'completed',  120.50, '2026-08-01 10:15:00');
