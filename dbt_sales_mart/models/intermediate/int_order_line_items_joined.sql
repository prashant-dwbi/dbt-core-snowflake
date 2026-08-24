with line_items as (

    select * from {{ ref('int_lineitem_revenue') }}

),

orders as (

    select * from {{ ref('stg_tpch_orders') }}

)

select
    line_items.order_key,
    line_items.line_number,
    orders.customer_key,
    line_items.part_key,
    line_items.supplier_key,
    orders.order_date,
    orders.order_status,
    orders.order_priority,
    line_items.quantity,
    line_items.extended_price,
    line_items.discount_pct,
    line_items.tax_pct,
    line_items.return_flag,
    line_items.line_status,
    line_items.ship_date,
    line_items.net_revenue,
    line_items.gross_revenue
from line_items
left join orders on line_items.order_key = orders.order_key
