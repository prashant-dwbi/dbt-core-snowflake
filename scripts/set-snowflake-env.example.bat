@echo off
REM Template for setting Snowflake credentials as environment variables for dbt.
REM
REM Usage:
REM   1. Copy this file to set-snowflake-env.bat (gitignored, so real secrets never get committed).
REM   2. Fill in your actual values below.
REM   3. Run it in your cmd.exe session so the variables land there: scripts\set-snowflake-env.bat

set SNOWFLAKE_ACCOUNT=<account_locator>
set SNOWFLAKE_USER=<your_username>
set SNOWFLAKE_AUTHENTICATOR=externalbrowser
set SNOWFLAKE_ROLE=<your_role>
set SNOWFLAKE_DATABASE=<your_database>
set SNOWFLAKE_WAREHOUSE=<your_warehouse>
set SNOWFLAKE_SCHEMA=<your_schema>

echo Snowflake env vars set for this session.
