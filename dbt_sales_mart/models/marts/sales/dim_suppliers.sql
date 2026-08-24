with suppliers as (

    select * from {{ ref('stg_tpch_suppliers') }}

),

nations as (

    select * from {{ ref('dim_nations') }}

)

select
    suppliers.supplier_key,
    suppliers.supplier_name,
    suppliers.supplier_address,
    suppliers.supplier_phone,
    suppliers.account_balance,
    nations.nation_name,
    nations.region_name
from suppliers
left join nations on suppliers.nation_key = nations.nation_key
