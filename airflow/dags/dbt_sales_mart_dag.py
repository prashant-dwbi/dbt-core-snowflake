from datetime import datetime
from pathlib import Path

from cosmos import DbtDag, ExecutionConfig, ProfileConfig, ProjectConfig

DBT_PROJECT_PATH = Path("/usr/local/airflow/dbt_sales_mart")

profile_config = ProfileConfig(
    profile_name="dbt_sales_mart",
    target_name="dev",
    profiles_yml_filepath=DBT_PROJECT_PATH / "profiles.yml",
)

execution_config = ExecutionConfig(
    dbt_executable_path="/usr/local/airflow/dbt_venv/bin/dbt",
)

dbt_sales_mart_dag = DbtDag(
    project_config=ProjectConfig(DBT_PROJECT_PATH),
    profile_config=profile_config,
    execution_config=execution_config,
    schedule=None,
    start_date=datetime(2026, 1, 1),
    catchup=False,
    dag_id="dbt_sales_mart",
)
