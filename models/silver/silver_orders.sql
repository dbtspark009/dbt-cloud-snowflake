-- ==================================================================
-- SILVER LAYER
-- Rule of thumb: silver is where cleaning + business logic happens —
-- dedupe, filter out junk, standardize values. Still row-level detail,
-- not aggregated yet. Always reference bronze via ref(), never source()
-- directly — this is what lets dbt build the dependency graph (DAG)
-- and run models in the correct order.
-- ==================================================================

with deduped as (
    select
        *,
        row_number() over (
            partition by order_id
            order by _loaded_at desc
        ) as row_num
    from {{ ref('bronze_orders') }}
)

select
    order_id,
    customer_id,
    order_status,
    order_amount,
    order_date
from deduped
where row_num = 1                                            -- drop duplicate rows
  and order_status in ({{ "'" ~ var('valid_order_statuses') | join("','") ~ "'" }})  -- drop cancelled orders
