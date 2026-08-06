-- ==================================================================
-- GOLD LAYER
-- Rule of thumb: gold is aggregated and shaped for a specific
-- consumer (a dashboard, a report). This is what analysts/BI tools
-- query — they should never need to touch bronze or silver directly.
-- ==================================================================

select
    date_trunc('day', order_date)  as order_day,
    count(distinct order_id)       as total_orders,
    count(distinct customer_id)    as unique_customers,
    sum(order_amount)              as total_revenue,
    avg(order_amount)              as avg_order_value
from {{ ref('silver_orders') }}
group by 1
order by 1
