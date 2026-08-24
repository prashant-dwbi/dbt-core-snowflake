with orders as (

    select * from {{ ref('fct_orders') }}

),

customers as (

    select * from {{ ref('dim_customers') }}

)

select
    customers.nation_name,
    customers.region_name,
    date_trunc('quarter', orders.order_date) as order_quarter,
    count(distinct orders.order_key) as order_count,
    count(distinct orders.customer_key) as customer_count,
    sum(orders.net_revenue) as net_revenue,
    sum(orders.gross_revenue) as gross_revenue,
    sum(orders.net_revenue) / nullif(count(distinct orders.order_key), 0) as avg_order_value
from orders
left join customers on orders.customer_key = customers.customer_key
group by 1, 2, 3
order by 1, 2, 3
