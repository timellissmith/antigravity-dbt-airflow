import os
from datetime import datetime, timedelta
from airflow import DAG
from cosmos import DbtDag, ProjectConfig, ProfileConfig, RenderConfig
from cosmos.constants import TestBehavior

# Define the connection to dbt profile
# In CI, we override these to use DuckDB
# The default path is for the local environment
DBT_PROJECT_PATH = os.getenv(
    "DBT_PROJECT_PATH", "/home/vscode/workspace/antigravity_project"
)
DEFAULT_PROFILES_YML = os.path.join(DBT_PROJECT_PATH, "profiles.yml")
profile_config = ProfileConfig(
    profile_name="antigravity",
    target_name=os.getenv("DBT_TARGET", "prod"),
    profiles_yml_filepath=os.getenv(
        "DBT_PROFILES_YML", os.path.join(DBT_PROJECT_PATH, "profiles.yml")
    ),
)

# Deployment DAG: Builds the Medallion layers and runs associated tests
antigravity_pipeline = DbtDag(
    project_config=ProjectConfig(DBT_PROJECT_PATH),
    profile_config=profile_config,
    render_config=RenderConfig(
        select=["tag:deploy"],
        test_behavior=TestBehavior.AFTER_EACH,
    ),
    dag_id="antigravity_pipeline",
    start_date=datetime(2026, 3, 1),
    schedule="@daily",
    catchup=False,
    default_args={
        "retries": 1,
        "retry_delay": timedelta(minutes=5),
    },
)

from cosmos.operators.local import DbtTestLocalOperator

# Quality Audit DAG: Runs production tests periodically
with DAG(
    dag_id="antigravity_data_quality_audit",
    start_date=datetime(2026, 3, 1),
    schedule="@hourly",
    catchup=False,
    default_args={
        "retries": 1,
        "retry_delay": timedelta(minutes=5),
    },
) as quality_audit_dag:

    run_prod_tests = DbtTestLocalOperator(
        task_id="run_prod_tests",
        project_dir=DBT_PROJECT_PATH,
        profile_config=profile_config,
        select=["tag:prod_test"],
    )
