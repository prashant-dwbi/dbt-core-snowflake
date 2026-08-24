select
    order_key,
    line_number,
    part_key,
    supplier_key,
    quantity,
    extended_price,
    discount_pct,
    tax_pct,
    return_flag,
    line_status,
    ship_date,
    extended_price * (1 - discount_pct) as net_revenue,
    extended_price * (1 - discount_pct) * (1 + tax_pct) as gross_revenue
from {{ ref('stg_tpch_lineitems') }}
