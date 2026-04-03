import os
from datetime import datetime, timedelta
from dotenv import load_dotenv
from airflow import DAG
from cosmos import DbtDag, ProjectConfig, ProfileConfig, RenderConfig, ExecutionConfig
from cosmos.constants import TestBehavior

# Load environment variables from .env file if it exists
load_dotenv(override=True)

current_dir = os.path.dirname(__file__)

# Define the dbt executable path (use bundled fusion binary if available)
DBT_EXECUTABLE = os.path.join(current_dir, "bin/dbtf")
if not os.path.exists(DBT_EXECUTABLE):
    # Try dbtf (Fusion) then dbt (Core)
    import subprocess
    try:
        subprocess.run(["which", "dbtf"], check=True, capture_output=True)
        DBT_EXECUTABLE = "dbtf"
    except subprocess.CalledProcessError:
        DBT_EXECUTABLE = "dbt"

execution_config = ExecutionConfig(
    dbt_executable_path=DBT_EXECUTABLE,
)

# Define the connection to dbt profile
# In CI, we use BigQuery
# Local: ../antigravity_project, Composer: ./antigravity_project
DBT_PROJECT_PATH = os.getenv("DBT_PROJECT_PATH")
if not DBT_PROJECT_PATH:
    if os.path.exists(os.path.join(current_dir, "antigravity_project")):
        DBT_PROJECT_PATH = os.path.join(current_dir, "antigravity_project")
    else:
        DBT_PROJECT_PATH = os.path.join(current_dir, "../antigravity_project")

DEFAULT_PROFILES_YML = os.path.join(DBT_PROJECT_PATH, "profiles.yml")

# Ensure required environment variables for dbt are set for local execution
os.environ.setdefault("GCP_SCHEMA", "main")
os.environ.setdefault("GCP_PROJECT_ID", "")

IS_COMPOSER = os.path.exists("/home/airflow/gcs/dags")
DBT_TARGET = os.getenv("DBT_TARGET", "prod" if IS_COMPOSER else "dev")

profile_config = ProfileConfig(
    profile_name="antigravity",
    target_name=DBT_TARGET,
    profiles_yml_filepath=os.getenv(
        "DBT_PROFILES_YML", os.path.join(DBT_PROJECT_PATH, "profiles.yml")
    ),
)

# Deployment DAG: Builds the Medallion layers and runs associated tests
antigravity_pipeline = DbtDag(
    project_config=ProjectConfig(DBT_PROJECT_PATH),
    profile_config=profile_config,
    execution_config=execution_config,
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
antigravity_pipeline.doc_md = """
### Antigravity Pipeline
This DAG builds the Medallion layers for the Antigravity research project using **dbt-fusion**.

**Workflow:**
1. **Bronze**: Raw data from dbt seeds (telemetry, researchers).
2. **Silver**: Cleaned and standardized data models.
3. **Gold**: Business-ready fact and dimension tables for BigQuery analysis.

**Tests:** Runs associated data tests after each model execution.
"""

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
    quality_audit_dag.doc_md = """
### Quality Audit DAG
This DAG runs periodic production data quality tests using **dbt-fusion**.

It executes a suite of tests tagged with `prod_test` to ensure:
- Table integrity (unique keys, non-null values).
- Business logic validation (regression checks).
- Metadata consistency across the research platform.
"""

    run_prod_tests = DbtTestLocalOperator(
        task_id="run_prod_tests",
        project_dir=DBT_PROJECT_PATH,
        profile_config=profile_config,
        execution_config=execution_config,
        select=["tag:prod_test"],
    )
