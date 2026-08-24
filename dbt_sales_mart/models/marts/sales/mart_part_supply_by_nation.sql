select
    part_key,
    part_name,
    brand,
    part_type,
    nation_name,
    region_name,
    count(distinct supplier_key) as supplier_count,
    sum(available_quantity) as total_available_quantity,
    min(supply_cost) as min_supply_cost,
    avg(supply_cost) as avg_supply_cost,
    max(supply_cost) as max_supply_cost
from {{ ref('int_partsupp_enriched') }}
group by 1, 2, 3, 4, 5, 6
order by 1, 5
