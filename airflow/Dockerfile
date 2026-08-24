FROM astrocrpublic.azurecr.io/runtime:3.3-5

# dbt runs in its own virtualenv, separate from Airflow's, so dbt-snowflake's
# dependency pins can't collide with the Airflow/provider package versions.
RUN python -m venv /usr/local/airflow/dbt_venv && \
    /usr/local/airflow/dbt_venv/bin/pip install --no-cache-dir dbt-snowflake
