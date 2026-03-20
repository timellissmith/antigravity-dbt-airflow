import os
import pytest
from airflow.models import DagBag


@pytest.fixture(scope="session")
def dagbag():
    dag_path = os.path.join(os.path.dirname(__file__), "../dags")
    return DagBag(dag_folder=dag_path, include_examples=False)


def test_dag_loading(dagbag):
    """Verify that DAGs load without import errors."""
    assert len(dagbag.import_errors) == 0, f"DAG import errors: {dagbag.import_errors}"
    assert "antigravity_pipeline" in dagbag.dags
    assert "antigravity_data_quality_audit" in dagbag.dags


def test_antigravity_pipeline_structure(dagbag):
    """Verify the task structure of the antigravity_pipeline DAG."""
    dag = dagbag.get_dag("antigravity_pipeline")

    # In Cosmos, tasks are generated from dbt models
    # We expect tasks for stg_telemetry, stg_researchers, dim_researchers, fct_levitation_events
    # Cosmos task IDs usually look like 'antigravity_project.stg_telemetry.run'

    task_ids = dag.task_ids
    print(f"Tasks in antigravity_pipeline: {task_ids}")

    # Check for core silver and gold models
    # Depending on Cosmos version and config, the task ID might vary
    # We'll use a search approach
    expected_models = [
        "stg_telemetry",
        "stg_researchers",
        "dim_researchers",
        "fct_levitation_events",
    ]

    for model in expected_models:
        assert any(
            model in task_id for task_id in task_ids
        ), f"Model {model} not found in DAG tasks"


def test_quality_audit_structure(dagbag):
    """Verify the task structure of the quality_audit_dag."""
    dag = dagbag.get_dag("antigravity_data_quality_audit")

    task_ids = dag.task_ids
    print(f"\nTasks in quality_audit_dag: {task_ids}")

    # The audit DAG runs tests via DbtTestLocalOperator
    assert (
        "run_prod_tests" in task_ids
    ), f"Expected task run_prod_tests not found. Tasks: {task_ids}"


@pytest.mark.skipif(
    os.getenv("CI") == "true",
    reason="dag.test() fails with serialization error in isolated CI",
)
def test_pipeline_dag_execution(dagbag):
    """Execute the pipeline DAG to ensure tasks pass and yield expected results."""
    dag = dagbag.get_dag("antigravity_pipeline")
    print(f"\nTesting DAG execution for: {dag.dag_id}")
    # dag.test() executes the tasks locally
    info = dag.test()
    # The return value from dag.test() can be a DagRun object. We can check its state
    assert info.state == "success", f"Pipeline DAG failed: {info.state}"


@pytest.mark.skipif(
    os.getenv("CI") == "true",
    reason="dag.test() fails with serialization error in isolated CI",
)
def test_quality_audit_dag_execution(dagbag):
    """Execute the quality audit DAG to ensure tasks pass and yield expected results."""
    dag = dagbag.get_dag("antigravity_data_quality_audit")
    print(f"\nTesting DAG execution for: {dag.dag_id}")
    info = dag.test()
    assert info.state == "success", f"Quality Audit DAG failed: {info.state}"
