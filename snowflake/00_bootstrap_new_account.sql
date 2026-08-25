-- 00_bootstrap_new_account.sql
--
-- One-time setup for a brand-new Snowflake account (e.g. after a trial
-- account expires and a new one is created). Run this FIRST, as
-- ACCOUNTADMIN or a role with equivalent privileges, before:
--   01_setup_ci.sql
--   02_setup_cd.sql
--   03_setup_stage_and_slim_ci.sql
--
-- Creates only what's shared across every environment: the warehouse, the
-- non-prod database, sample data access, and a role for interactive
-- developer (SSO) access. SALES_MART_PROD and SALES_MART_STAGE are created
-- by 02_setup_cd.sql and 03_setup_stage_and_slim_ci.sql respectively.

CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Shared warehouse for dbt_sales_mart (dev, CI, CD, stage)';

CREATE DATABASE IF NOT EXISTS SALES_MART_DEV
  COMMENT = 'Personal developer schemas and the CI service account schema live here';

-- ── Interactive developer access (SSO / externalbrowser, per README section 5) ──

CREATE ROLE IF NOT EXISTS DBT_DEV_ROLE;

GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE DBT_DEV_ROLE;
GRANT USAGE ON DATABASE SALES_MART_DEV TO ROLE DBT_DEV_ROLE;
GRANT CREATE SCHEMA ON DATABASE SALES_MART_DEV TO ROLE DBT_DEV_ROLE;
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE_SAMPLE_DATA TO ROLE DBT_DEV_ROLE;

-- Repeat per developer: grant the role to their Snowflake user, then either
-- let dbt create their personal schema automatically on first `dbt run`, or
-- pre-create one explicitly:
--   GRANT ROLE DBT_DEV_ROLE TO USER <snowflake_username>;
--   CREATE SCHEMA IF NOT EXISTS SALES_MART_DEV.<PERSONAL_SCHEMA_NAME>;
--   GRANT ALL ON SCHEMA SALES_MART_DEV.<PERSONAL_SCHEMA_NAME> TO ROLE DBT_DEV_ROLE;
