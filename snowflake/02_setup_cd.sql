-- 02_setup_cd.sql
--
-- One-time setup for the dbt-cd.yml workflow (.github/workflows/dbt-cd.yml).
-- Mirrors README.md section 9. Run after 00_bootstrap_new_account.sql (and
-- 01_setup_ci.sql, since 03_setup_stage_and_slim_ci.sql grants DBT_CI_ROLE
-- access to the SALES_MART_PROD database created here).
--
-- Generate a second, separate key pair (keep it distinct from the CI key):
--   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key_prod.p8 -nocrypt
--   openssl rsa -in rsa_key_prod.p8 -pubout -out rsa_key_prod.pub

CREATE DATABASE IF NOT EXISTS SALES_MART_PROD;
CREATE SCHEMA IF NOT EXISTS SALES_MART_PROD.MARTS;

CREATE ROLE IF NOT EXISTS DBT_PROD_ROLE;

CREATE USER IF NOT EXISTS DBT_PROD_SVC
  RSA_PUBLIC_KEY = '<base64 body of rsa_key_prod.pub>'
  DEFAULT_ROLE = DBT_PROD_ROLE
  DEFAULT_WAREHOUSE = COMPUTE_WH
  COMMENT = 'Service account for GitHub Actions dbt CD (production deploys)';

GRANT ROLE DBT_PROD_ROLE TO USER DBT_PROD_SVC;

GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE DBT_PROD_ROLE;
GRANT USAGE ON DATABASE SALES_MART_PROD TO ROLE DBT_PROD_ROLE;
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE_SAMPLE_DATA TO ROLE DBT_PROD_ROLE;

GRANT ALL ON SCHEMA SALES_MART_PROD.MARTS TO ROLE DBT_PROD_ROLE;
GRANT CREATE TABLE, CREATE VIEW ON SCHEMA SALES_MART_PROD.MARTS TO ROLE DBT_PROD_ROLE;
