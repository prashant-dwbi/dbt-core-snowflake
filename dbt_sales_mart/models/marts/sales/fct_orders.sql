with orders as (

    select * from {{ ref('stg_tpch_orders') }}

),

line_items as (

    select * from {{ ref('fct_order_line_items') }}

),

order_aggregates as (

    select
        order_key,
        count(*) as line_item_count,
        sum(quantity) as total_quantity,
        sum(net_revenue) as net_revenue,
        sum(gross_revenue) as gross_revenue
    from line_items
    group by order_key

)

select
    orders.order_key,
    orders.customer_key,
    orders.order_date,
    orders.order_status,
    orders.order_priority,
    orders.clerk_name,
    orders.total_price,
    order_aggregates.line_item_count,
    order_aggregates.total_quantity,
    order_aggregates.net_revenue,
    order_aggregates.gross_revenue
from orders
left join order_aggregates on orders.order_key = order_aggregates.order_key
