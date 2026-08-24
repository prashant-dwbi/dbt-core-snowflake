select
    part_key,
    part_name,
    manufacturer,
    brand,
    part_type,
    part_size,
    container,
    retail_price
from {{ ref('stg_tpch_parts') }}
