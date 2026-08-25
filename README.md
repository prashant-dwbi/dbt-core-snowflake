# Sales Analytics Mart Project

This is a dbt-core project that builds a sales analytics mart on Snowflake from the sample TPC-H dataset, with a full CI/CD pipeline and Airflow orchestration.

For step-by-step setup, pipeline configuration, and operational procedures, see the [**Runbook**](docs/RUNBOOK.md). For provisioning a brand-new Snowflake account, see [`snowflake/README.md`](snowflake/README.md).

## Overview

The project transforms TPC-H sample data (`SNOWFLAKE_SAMPLE_DATA`) into a sales mart of customers, suppliers, parts, orders, and pre-aggregated reporting tables — following dbt's standard staging → intermediate → marts layering. It ships with:

- A CI pipeline that slim-builds and lints every pull request
- A CD pipeline that deploys to production on merge, behind a manual approval gate, and publishes docs
- An ephemeral, per-PR Airflow (Astronomer/Cosmos) run that exercises the actual orchestration path, not just `dbt build`

## Tools & technologies

| Category | Tool |
|---|---|
| Transformation | [dbt-core](https://github.com/dbt-labs/dbt-core) + [dbt-snowflake](https://github.com/dbt-labs/dbt-snowflake) |
| Warehouse | [Snowflake](https://www.snowflake.com/) (separate `DEV` / `CI` / `STAGE` / `PROD` databases/schemas) |
| Orchestration | [Apache Airflow](https://airflow.apache.org/) via [Astronomer Astro CLI](https://www.astronomer.io/docs/astro/cli/overview) + [astronomer-cosmos](https://astronomer.github.io/astronomer-cosmos/) |
| CI/CD | [GitHub Actions](https://docs.github.com/actions) |
| Linting | [sqlfluff](https://sqlfluff.com/) (`dbt` templater) |
| Auth | Snowflake key-pair auth (CI/CD/stage service accounts), SSO/`externalbrowser` (local dev) |
| Package management | dbt packages via [`dependencies.yml`](dbt_sales_mart/dependencies.yml) (`dbt_utils`) |

## Process followed

1. **Model layering** — raw TPC-H tables are staged 1:1 (`stg_tpch_*`), reshaped/enriched in an intermediate layer, and exposed as dimension/fact/aggregate tables in `marts`. Downstream layers only ever `ref()` the layer directly below them.
2. **Environment isolation** — every stage of the pipeline writes to its own Snowflake database or schema (dev, per-PR CI schema, per-PR stage database, production), each behind its own least-privilege service account.
3. **Change-scoped CI** — pull requests only rebuild changed models and their downstream dependents (slim CI via `state:modified+`), deferring unbuilt refs to production data.
4. **Gated promotion** — merges to `main` require a manual approval before touching production, after which docs are published automatically.
5. **Orchestration parity** — the same Cosmos-based Airflow DAG that would run in production is exercised against an isolated schema on every PR, so orchestration issues surface before merge, not after.

## High-level design (HLD)

```mermaid
flowchart LR
    dev[Developer] -->|opens PR| pr[Pull Request]

    subgraph "On every PR"
        pr --> ci[dbt-ci.yml<br/>slim dbt build + sqlfluff lint]
        pr --> stage[dbt-airflow-stage.yml<br/>ephemeral Airflow run]
    end

    ci --> ciDb[(SALES_MART_DEV.CI)]
    stage --> stageDb[(SALES_MART_STAGE.&lt;branch schema&gt;)]

    pr -->|merge to main| cd[dbt-cd.yml]
    cd -->|manual approval gate| prod[(SALES_MART_PROD)]
    cd --> docs[dbt docs generate] --> pages[GitHub Pages]
    cd -->|publish manifest| manifest[[previous_release_artifacts branch]]
    manifest -.->|state:modified+ / --defer| ci

    prodSrc[(SNOWFLAKE_SAMPLE_DATA<br/>TPC-H)] --> ci
    prodSrc --> stage
    prodSrc --> cd
```

## Low-level design (LLD): dbt model DAG

```mermaid
flowchart LR
    subgraph staging
        s_cust[stg_tpch_customers]
        s_ord[stg_tpch_orders]
        s_line[stg_tpch_lineitems]
        s_nat[stg_tpch_nations]
        s_reg[stg_tpch_regions]
        s_sup[stg_tpch_suppliers]
        s_part[stg_tpch_parts]
        s_psup[stg_tpch_partsupps]
    end

    subgraph intermediate
        i_rev[int_lineitem_revenue]
        i_join[int_order_line_items_joined]
        i_psup[int_partsupp_enriched]
    end

    subgraph marts
        m_nat[dim_nations]
        m_cust[dim_customers]
        m_sup[dim_suppliers]
        m_part[dim_parts]
        m_fli[fct_order_line_items]
        m_ord[fct_orders]
        m_salesq[mart_sales_by_nation_quarter]
        m_psupn[mart_part_supply_by_nation]
    end

    s_line --> i_rev
    i_rev --> i_join
    s_ord --> i_join
    i_join --> m_fli

    s_psup --> i_psup
    s_part --> i_psup
    s_sup --> i_psup
    s_nat --> i_psup
    s_reg --> i_psup
    i_psup --> m_psupn

    s_nat --> m_nat
    s_reg --> m_nat
    s_cust --> m_cust
    m_nat --> m_cust
    s_sup --> m_sup
    m_nat --> m_sup
    s_part --> m_part

    s_ord --> m_ord
    m_fli --> m_ord
    m_ord --> m_salesq
    m_cust --> m_salesq
```

## Entity-relationship diagram (ERD)

The mart layer forms a standard star schema around orders and order line items:

```mermaid
erDiagram
    DIM_NATIONS {
        int nation_key PK
        string nation_name
        string region_name
    }
    DIM_CUSTOMERS {
        int customer_key PK
        string customer_name
        string market_segment
        int nation_key FK
    }
    DIM_SUPPLIERS {
        int supplier_key PK
        string supplier_name
        int nation_key FK
    }
    DIM_PARTS {
        int part_key PK
        string part_name
        string brand
        string part_type
    }
    FCT_ORDERS {
        int order_key PK
        int customer_key FK
        date order_date
        string order_status
        decimal net_revenue
        decimal gross_revenue
    }
    FCT_ORDER_LINE_ITEMS {
        int order_key FK
        int line_number PK
        int part_key FK
        int supplier_key FK
        decimal net_revenue
        decimal gross_revenue
    }
    MART_SALES_BY_NATION_QUARTER {
        string nation_name PK
        string region_name
        date order_quarter PK
        int order_count
        int customer_count
        decimal net_revenue
        decimal gross_revenue
        decimal avg_order_value
    }
    MART_PART_SUPPLY_BY_NATION {
        int part_key PK
        string part_name
        string brand
        string part_type
        string nation_name PK
        string region_name
        int supplier_count
        decimal total_available_quantity
        decimal min_supply_cost
        decimal avg_supply_cost
        decimal max_supply_cost
    }

    DIM_NATIONS ||--o{ DIM_CUSTOMERS : "located in"
    DIM_NATIONS ||--o{ DIM_SUPPLIERS : "located in"
    DIM_CUSTOMERS ||--o{ FCT_ORDERS : places
    FCT_ORDERS ||--o{ FCT_ORDER_LINE_ITEMS : contains
    DIM_PARTS ||--o{ FCT_ORDER_LINE_ITEMS : "ordered as"
    DIM_SUPPLIERS ||--o{ FCT_ORDER_LINE_ITEMS : fulfills
    FCT_ORDERS ||--o{ MART_SALES_BY_NATION_QUARTER : "rolled up into"
    DIM_CUSTOMERS ||--o{ MART_SALES_BY_NATION_QUARTER : "grouped by nation of"
    DIM_PARTS ||--o{ MART_PART_SUPPLY_BY_NATION : "rolled up into"
    DIM_SUPPLIERS ||--o{ MART_PART_SUPPLY_BY_NATION : "grouped by nation of"
```

`mart_sales_by_nation_quarter` and `mart_part_supply_by_nation` are pre-aggregated reporting tables derived from the star schema above — their "primary key" is really a grouping key (nation/quarter, part/nation), not a natural entity identifier, so treat their PK markers as grain rather than a true row identity.

## Repository layout

| Path | Purpose |
|---|---|
| [`dbt_sales_mart/`](dbt_sales_mart/) | The dbt project (models, tests, `dependencies.yml`, `profiles.yml`) |
| [`ci/`](ci/), [`cd/`](cd/) | Secrets-free dbt profiles used by the CI and CD workflows |
| [`.github/workflows/`](.github/workflows/) | `dbt-ci.yml`, `dbt-cd.yml`, `dbt-airflow-stage.yml` |
| [`airflow/`](airflow/) | Astro/Airflow project running the dbt project as a Cosmos DAG |
| [`snowflake/`](snowflake/) | One-time SQL to provision Snowflake objects for a new account/environment |
| [`scripts/`](scripts/) | Setup and CI helper scripts |
| [`docs/RUNBOOK.md`](docs/RUNBOOK.md) | Full setup and operational instructions |
