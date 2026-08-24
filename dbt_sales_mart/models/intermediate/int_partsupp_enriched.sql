with partsupp as (

    select * from {{ ref('stg_tpch_partsupps') }}

),

parts as (

    select * from {{ ref('stg_tpch_parts') }}

),

suppliers as (

    select * from {{ ref('stg_tpch_suppliers') }}

),

nations as (

    select * from {{ ref('stg_tpch_nations') }}

),

regions as (

    select * from {{ ref('stg_tpch_regions') }}

)

select
    partsupp.part_key,
    partsupp.supplier_key,
    partsupp.available_quantity,
    partsupp.supply_cost,
    parts.part_name,
    parts.brand,
    parts.part_type,
    suppliers.supplier_name,
    nations.nation_name,
    regions.region_name
from partsupp
left join parts on partsupp.part_key = parts.part_key
left join suppliers on partsupp.supplier_key = suppliers.supplier_key
left join nations on suppliers.nation_key = nations.nation_key
left join regions on nations.region_key = regions.region_key
