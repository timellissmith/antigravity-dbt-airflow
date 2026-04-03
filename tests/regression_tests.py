import os
import pytest
from google.cloud import bigquery

@pytest.fixture
def bq_client():
    return bigquery.Client()

def test_dim_researchers_counts(bq_client):
    """Verify dim_researchers has expected data volume."""
    project = os.getenv("GCP_PROJECT_ID", "modelling-demo")
    dataset = "main" # Assumed target dataset
    
    query = f"SELECT count(*) as cnt FROM `{project}.{dataset}.dim_researchers`"
    query_job = bq_client.query(query)
    results = list(query_job.result())
    
    count = results[0].cnt
    assert count > 0, "dim_researchers is empty!"
    # Basic regression check: ensure we have the static seed count or more
    assert count >= 3, f"Expected at least 3 researchers, found {count}"

def test_fct_levitation_events_integrity(bq_client):
    """Ensure no nulls in critical fact columns and reasonable totals."""
    project = os.getenv("GCP_PROJECT_ID", "modelling-demo")
    dataset = "main"
    
    query = f"""
        SELECT 
            count(*) as total_rows,
            countif(vessel_id IS NULL) as null_vessels,
            countif(location_id IS NULL) as null_locations
        FROM `{project}.{dataset}.fct_levitation_events`
    """
    query_job = bq_client.query(query)
    results = list(query_job.result())
    
    row = results[0]
    assert row.total_rows > 0, "fct_levitation_events is empty!"
    assert row.null_vessels == 0, "Found null vessel_ids in facts!"
    assert row.null_locations == 0, "Found null location_ids in facts!"

def test_regression_vessel_age(bq_client):
    """Business logic check: Verify vessel ages are positive."""
    project = os.getenv("GCP_PROJECT_ID", "modelling-demo")
    dataset = "main"
    
    query = f"SELECT count(*) as errors FROM `{project}.{dataset}.dim_vessels` WHERE age_days < 0"
    query_job = bq_client.query(query)
    results = list(query_job.result())
    
    assert results[0].errors == 0, "Found vessels with negative age!"
