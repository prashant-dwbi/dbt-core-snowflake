# Snowflake setup scripts

One-time SQL for provisioning this project's Snowflake objects, meant to be run in order. All account/database/warehouse names match what the rest of the repo (`ci/profiles.yml`, `cd/profiles.yml`, `dbt_sales_mart/profiles.yml`, and the GitHub Actions workflows) already expects — nothing here needs renaming to line up with the code.

Run as `ACCOUNTADMIN` or an equivalent role, in this order:

1. **`00_bootstrap_new_account.sql`** — the shared warehouse (`COMPUTE_WH`), the non-prod database (`SALES_MART_DEV`), and a role for interactive/SSO developer access. Start here on a brand-new account (e.g. after a trial expires and a new one is created).
2. **`01_setup_ci.sql`** — the `dbt-ci.yml` GitHub Actions workflow's service account (`DBT_CI_SVC` / `DBT_CI_ROLE`) and its isolated `SALES_MART_DEV.CI` schema. Mirrors README.md section 8.
3. **`02_setup_cd.sql`** — the `dbt-cd.yml` workflow's production database (`SALES_MART_PROD`) and service account (`DBT_PROD_SVC` / `DBT_PROD_ROLE`). Mirrors README.md section 9.
4. **`03_setup_stage_and_slim_ci.sql`** — grants `DBT_CI_ROLE` read access to `SALES_MART_PROD` (needed for slim CI's `dbt build --defer --favor-state`), plus the per-PR Airflow stage environment (`SALES_MART_STAGE`, `DBT_STAGE_SVC` / `DBT_STAGE_ROLE`). Mirrors README.md section 12. Run this one last — it references `SALES_MART_PROD`, which script 2 creates.

Each service-account script expects an RSA key pair generated locally first (commands are in the script's header comment) — never commit the private key; only the corresponding GitHub Actions secret should hold it.
