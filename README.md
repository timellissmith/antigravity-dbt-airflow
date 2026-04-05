# Antigravity Data Pipeline

[![CI](https://github.com/timellissmith/antigravity-dbt-airflow/actions/workflows/ci.yml/badge.svg)](https://github.com/timellissmith/antigravity-dbt-airflow/actions/workflows/ci.yml)

This repository contains the data engineering pipeline for the Antigravity research project. It uses **Airflow**, **Cosmos**, and **dbt-fusion** to transform raw telemetry and researcher data into curated gold-layer tables in **BigQuery**.

## Architecture Overview

The project follows a **Medallion Architecture**:

1.  **Bronze (Raw/Streaming)**: Raw data ingested from both static and streaming sources.
    - `raw_telemetry`: Seeded raw force readings, vessel IDs, and location IDs.
    - `stg_telemetry_stream`: Real-time telemetry ingested from Pub/Sub via BigQuery Continuous Queries.
    - `raw_researchers`: Static researcher information including assigned vessels.
    - `raw_vessels`: Metadata for antigravity vessels.
    - `raw_locations`: Information about research facilities and regions.
2.  **Silver (Staging)**: Cleaned and standardized data.
    - `stg_telemetry`: Standardizes gravity readings to G-force (from static bronze).
    - `stg_telemetry_stream`: Real-time telemetry processed by BigQuery Continuous Queries.
    - `stg_researchers`: Standardizes names and contact information.
    - `stg_vessels`: Standardizes vessel commissioning dates.
    - `stg_locations`: Standardizes facility types and regions.
3.  **Gold (Curated)**: Business-ready fact and dimension tables.
    - `dim_researchers`: Enriched researcher dimensions with tenure and full names.
    - `dim_vessels`: Vessel attributes and calculated age.
    - `dim_locations`: Research facility details.
    - `fct_levitation_events`: Enriched fact table mapping events to vessels, locations, and lead researchers.

---

## Streaming Telemetry Pipeline

This project includes a real-time ingestion layer for vessel telemetry.

### Data Flow
1.  **Load Generation**: `streaming/generator.py` simulates real-time vessel telemetry.
2.  **Ingestion**: Events are published to a **Google Cloud Pub/Sub** topic (`antigravity-telemetry`).
3.  **Continuous Query**: A **BigQuery Continuous Query** job listens for new messages via the `APPENDS` function.
4.  **Materialization**: The data is streamed directly into the `stg_telemetry_stream` table in BigQuery.

### Management Infrastructure
- **BigQuery Reservations**: To support Continuous Queries, we use an **Enterprise Edition** reservation with a **1-slot baseline** and **autoscaling to 100 slots**. This ensures high performance while maintaining a low baseline cost.
- **CQ Lifecycle Manager**: A **Cloud Workflow** (`antigravity-cq-manager`) automatically manages the continuous query jobs (cancels duplicates, ensures continuity).

### Management Commands
| Target | Description |
| :--- | :--- |
| `make stream-infra-apply` | Deploys Pub/Sub, BQ Reservations, and Cloud Workflow infra. |
| `make stream-generate` | Starts the Python load generator (publishes to Pub/Sub). |
| `make stream-cq-status` | Checks if the continuous query job is currently running. |
| `make stream-cq-restart` | Manually triggers the CQ lifecycle workflow. |
| `make stream-cq-stop` | Identifies and cancels all running continuous query jobs. |

---

## Data Modelling

The Antigravity data model is designed to support research analysis into levitation phenomena across different environments and assets.

- **Researchers**: The primary human actors in the system. Each event is attributed to a researcher based on their assigned vessel at the time of the event.
- **Vessels**: The physical assets (probes, shuttles, drones) performing the measurements. Vessel metadata (type, age) allows for asset-performance correlation.
- **Locations**: The physical or celestial environments (Moon, Mars, LEO) where experiments take place. This enables environmental impact analysis on antigravity stability.
- **Levitation Events**: The core transactional data. An event is classified as a "True Levitation" when the recorded gravity falls below 0.1G.

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

## Data Deployment (dbt-fusion)

The dbt project is located in the `antigravity_project/` directory.

### Deploying Seeds
To load the raw research data into your BigQuery environment, run:
```bash
cd antigravity_project
dbtf seed --target dev
```

## Testing Strategy

This project implements testing at multiple levels:

### 1. dbt-fusion Unit Tests
Used to validate transformation logic in models without requiring a database connection.
- Defined in `models/silver/schema.yml`.
- Run using: `dbtf test --select test_type:unit`

### 2. dbt-fusion Data Tests
Generic and singular tests to ensure data quality (unique, not_null, and `dbt_expectations`).
- Run using: `dbtf test --exclude test_type:unit`

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
