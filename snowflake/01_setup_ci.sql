-- 01_setup_ci.sql
--
-- One-time setup for the dbt-ci.yml workflow (.github/workflows/dbt-ci.yml).
-- Mirrors README.md section 8. Run after 00_bootstrap_new_account.sql.
--
-- Generate the key pair first (run locally, not committed):
--   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
--   openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub

CREATE ROLE IF NOT EXISTS DBT_CI_ROLE;

CREATE USER IF NOT EXISTS DBT_CI_SVC
  RSA_PUBLIC_KEY = '<base64 body of rsa_key.pub>'
  DEFAULT_ROLE = DBT_CI_ROLE
  DEFAULT_WAREHOUSE = COMPUTE_WH
  COMMENT = 'Service account for GitHub Actions dbt CI';

GRANT ROLE DBT_CI_ROLE TO USER DBT_CI_SVC;

GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE DBT_CI_ROLE;
GRANT USAGE ON DATABASE SALES_MART_DEV TO ROLE DBT_CI_ROLE;
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE_SAMPLE_DATA TO ROLE DBT_CI_ROLE;

CREATE SCHEMA IF NOT EXISTS SALES_MART_DEV.CI;
GRANT ALL ON SCHEMA SALES_MART_DEV.CI TO ROLE DBT_CI_ROLE;
GRANT CREATE TABLE, CREATE VIEW ON SCHEMA SALES_MART_DEV.CI TO ROLE DBT_CI_ROLE;

-- Slim CI (dbt build --defer --favor-state) needs read access to production
-- so unbuilt/unmodified model refs resolve against real data — see
-- 03_setup_stage_and_slim_ci.sql for that grant (added once dbt-cd.yml has
-- run at least once and SALES_MART_PROD exists).
