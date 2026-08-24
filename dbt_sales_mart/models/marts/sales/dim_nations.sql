with nations as (

    select * from {{ ref('stg_tpch_nations') }}

),

regions as (

    select * from {{ ref('stg_tpch_regions') }}

)

select
    nations.nation_key,
    nations.nation_name,
    regions.region_key,
    regions.region_name
from nations
left join regions on nations.region_key = regions.region_key
