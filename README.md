# Antigravity Data Pipeline

This repository contains the data engineering pipeline for the Antigravity research project. It uses **Airflow**, **Cosmos**, and **dbt** to transform raw telemetry and researcher data into curated gold-layer tables in **BigQuery**.

## Architecture Overview

The project follows a **Medallion Architecture**:

1.  **Bronze (Raw)**: Raw data ingested from external sources (simulated with dbt seeds).
    - `raw_telemetry`: Raw force readings and vessel metadata.
    - `raw_researchers`: Static researcher information.
2.  **Silver (Staging)**: Cleaned and standardized data.
    - `stg_telemetry`: Standardizes gravity readings to G-force.
    - `stg_researchers`: Standardizes names and contact information.
3.  **Gold (Curated)**: Business-ready fact and dimension tables.
    - `dim_researchers`: Enriched researcher dimensions with tenure and full names.
    - `fct_levitation_events`: Attributed levitation events with researcher mapping.

## Getting Started (Devcontainer)

This repo is optimized for development using Visual Studio Code Dev Containers.

### Prerequisites
- Docker Desktop or equivalent.
- VS Code with "Dev Containers" extension installed.
- (Optional) Google Cloud SDK for BigQuery access.

### Setup Instructions
1.  Open the repository in VS Code.
2.  When prompted, click **"Reopen in Container"**.
3.  The container will automatically:
    - Install all Python dependencies.
    - Initialize a local Airflow environment.
    - Install necessary dbt packages (e.g., `dbt-expectations`).
4.  Access the **Airflow UI** at [http://localhost:8080](http://localhost:8080).

## Data Deployment (dbt)

The dbt project is located in the `antigravity_project/` directory.

### Deploying Seeds
To load the raw research data into your BigQuery environment, run:
```bash
cd antigravity_project
dbt seed --target dev
```

## Testing Strategy

This project implements testing at multiple levels:

### 1. dbt Unit Tests
Used to validate transformation logic in models without requiring a database connection.
- Defined in `models/silver/schema.yml`.
- Run using: `dbt test --select test_type:unit`

### 2. dbt Data Tests
Generic and singular tests to ensure data quality (unique, not_null, and `dbt_expectations`).
- Run using: `dbt test --exclude test_type:unit`

### 3. Airflow DAG Tests (pytest)
A `pytest` suite in `tests/test_dags.py` validates:
- DAG loading and integrity (DagBag).
- Task structure and dependencies.
- Local execution of DAG runs using `dag.test()`.

Run the full suite:
```bash
pytest tests/test_dags.py
```

## CI/CD Pipeline (Dagger)

This project includes a containerized CI/CD pipeline built with **Dagger**. It allows you to run all tests and builds in an isolated, reproducible environment.

### Pipeline Overview
The pipeline (`ci/dagger_pipeline.py`) performs the following steps:
1.  **Environment Setup**: Spins up a container with all dependencies installed.
2.  **dbt Unit Tests**: Validates transformation logic and specific expectations.
3.  **dbt Seed & Build**: Loads sample data and builds models.
4.  **Airflow Validation**: Runs the `pytest` suite to ensure DAGs are correctly structured and executable.

### Environment Setup
The Dagger pipeline requires a **Docker Engine**. We've added the `docker-in-docker` feature to the devcontainer configuration. 

If you are running inside the devcontainer and encounter a "Failed to start Dagger engine session" error, you must **rebuild the container**:
1.  Open the Command Palette (`Ctrl+Shift+P`).
2.  Type and select: **Dev Containers: Rebuild Container**.

### How to Run
Once the environment is ready, run the pipeline with:
```bash
python ci/dagger_pipeline.py
```

> [!NOTE]
> Since Dagger requires a Docker daemon, this pipeline will only run in environments that support Docker-in-Docker or have access to the host's Docker socket.

## Key Fixes & Design Decisions

- **Join Logic**: `fct_levitation_events` uses a `QUALIFY` clause to avoid event duplication when multiple researchers share a 'Levitation' specialization.
- **Connection Method**: Production targets use `method: oauth` for seamless integration with Cloud Composer worker service accounts.
- **Test Tagging**: Critical production tests are tagged with `prod_test` for isolation in the audit DAG.
- **Devcontainer Fix (Hang)**: Resolved a build hang by removing the redundant `git` feature (pre-installed in the base image) and removing the `USER vscode` instruction from the `Dockerfile`, ensuring devcontainer features install with proper root permissions.
- **Dagger Support**: Includes the `docker-in-docker` feature to support local Dagger engine sessions for CI/CD pipeline validation.
