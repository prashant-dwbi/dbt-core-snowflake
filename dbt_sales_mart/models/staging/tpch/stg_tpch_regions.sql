with source as (

    select * from {{ source('tpch', 'region') }}

)

select
    r_regionkey as region_key,
    r_name as region_name,
    r_comment as region_comment
from source
