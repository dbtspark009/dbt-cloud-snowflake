-- ==================================================================
-- BRONZE LAYER
-- Rule of thumb: bronze does almost nothing. Rename/cast columns,
-- maybe add a load timestamp. No filtering, no deduping, no joins.
-- This preserves a faithful, queryable copy of the raw source.
-- Materialized as a VIEW (see dbt_project.yml) since it's cheap
-- and always reflects the current raw table.
-- ==================================================================

select
    order_id,
    customer_id,
    order_status,
    order_amount::float          as order_amount,
    order_date::timestamp_ntz    as order_date,
    current_timestamp()          as _loaded_at   -- lineage/debugging helper
from {{ source('raw', 'orders') }}
