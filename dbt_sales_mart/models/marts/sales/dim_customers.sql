with customers as (

    select * from {{ ref('stg_tpch_customers') }}

),

nations as (

    select * from {{ ref('dim_nations') }}

)

select
    customers.customer_key,
    customers.customer_name,
    customers.customer_address,
    customers.customer_phone,
    customers.account_balance,
    customers.market_segment,
    nations.nation_name,
    nations.region_name
from customers
left join nations on customers.nation_key = nations.nation_key
