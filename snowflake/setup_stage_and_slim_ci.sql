-- One-time Snowflake setup for:
--   1. Slim CI (dbt-ci.yml) — DBT_CI_ROLE needs read access to SALES_MART_PROD
--      so `dbt build --defer --favor-state` can resolve refs for models that
--      weren't rebuilt in the PR's isolated CI schema.
--   2. The per-PR Airflow stage job (dbt-airflow-stage.yml) — a new,
--      dedicated, least-privilege service account scoped only to a new
--      SALES_MART_STAGE database.
--
-- Run as a role with sufficient privileges (e.g. ACCOUNTADMIN or SYSADMIN).

-- ── 1. Slim CI: read-only grant so DBT_CI_ROLE can defer to production ──

GRANT USAGE ON DATABASE SALES_MART_PROD TO ROLE DBT_CI_ROLE;
GRANT USAGE ON ALL SCHEMAS IN DATABASE SALES_MART_PROD TO ROLE DBT_CI_ROLE;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE SALES_MART_PROD TO ROLE DBT_CI_ROLE;
GRANT SELECT ON ALL TABLES IN DATABASE SALES_MART_PROD TO ROLE DBT_CI_ROLE;
GRANT SELECT ON FUTURE TABLES IN DATABASE SALES_MART_PROD TO ROLE DBT_CI_ROLE;
GRANT SELECT ON ALL VIEWS IN DATABASE SALES_MART_PROD TO ROLE DBT_CI_ROLE;
GRANT SELECT ON FUTURE VIEWS IN DATABASE SALES_MART_PROD TO ROLE DBT_CI_ROLE;

-- ── 2. Per-PR Airflow stage environment ──
--
-- Generate a dedicated key pair first (run locally, not committed — same
-- pattern as the CI/CD service accounts):
--   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key_stage.p8 -nocrypt
--   openssl rsa -in rsa_key_stage.p8 -pubout -out rsa_key_stage.pub

CREATE DATABASE IF NOT EXISTS SALES_MART_STAGE;

CREATE ROLE IF NOT EXISTS DBT_STAGE_ROLE;

CREATE USER IF NOT EXISTS DBT_STAGE_SVC
  RSA_PUBLIC_KEY = '<base64 body of rsa_key_stage.pub>'
  DEFAULT_ROLE = DBT_STAGE_ROLE
  DEFAULT_WAREHOUSE = COMPUTE_WH
  COMMENT = 'Service account for the ephemeral per-PR Airflow stage job';

GRANT ROLE DBT_STAGE_ROLE TO USER DBT_STAGE_SVC;

GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE DBT_STAGE_ROLE;
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE_SAMPLE_DATA TO ROLE DBT_STAGE_ROLE;

GRANT USAGE ON DATABASE SALES_MART_STAGE TO ROLE DBT_STAGE_ROLE;
GRANT CREATE SCHEMA ON DATABASE SALES_MART_STAGE TO ROLE DBT_STAGE_ROLE;
GRANT ALL ON FUTURE SCHEMAS IN DATABASE SALES_MART_STAGE TO ROLE DBT_STAGE_ROLE;
GRANT ALL ON FUTURE TABLES IN DATABASE SALES_MART_STAGE TO ROLE DBT_STAGE_ROLE;
GRANT ALL ON FUTURE VIEWS IN DATABASE SALES_MART_STAGE TO ROLE DBT_STAGE_ROLE;
