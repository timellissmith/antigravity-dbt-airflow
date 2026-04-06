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
4.  **Generic API Layer (Dynamic)**: High-performance, memory-safe framework for parallel API ingestion.
    - `raw.telemetry_*`: Dynamically created landing tables for diverse external streams (Fraud, Audit, Access).
    - `etl_watermarks`: Control table tracking incremental cursors/states for all mapped streams.

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
| `make stream-mock-api` | Starts the local FastAPI mock server for telemetry simulation. |

---

## Generic API Ingestion Framework

This framework utilizes **Airflow Dynamic Task Mapping** to ingest data from multiple external API endpoints concurrently.

### Key Features
- **Memory-Safe Extraction**: Streams API responses directly to local NDJSON chunks, maintaining a flat ~4MB memory profile.
- **Dynamic Scaling**: Uses `.expand_kwargs()` to automatically spin up parallel tasks based on configurations stored in BigQuery.
- **Lazy Sanitization**: Employs **Polars** for high-speed, lazy data enrichment (injecting ingest timestamps) before GCS upload.
- **Automated Auth**: A custom `TelemetryAuthHook` manages Bearer tokens and handles automatic 401 refreshes.
- **Silver Layer (Unnesting)**: An incremental dbt model (`stg_api_telemetry`) automatically unnests complex JSON payloads from the raw tables, providing a structured schema for analysis.

### Local Mocking & Testing
For development, a standalone **FastAPI** mock server (`streaming/mock_api.py`) simulates the vendor's behavior, including deterministic cursor-based pagination.
- **Start the Mock API**: `make stream-mock-api` (Port 8000)
- **DAG**: `telemetry_ingestion_parallel`

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

## Environment Configuration (.env)

This project uses `python-dotenv` to manage environment variables. A template is provided in `.env.v3`.

### Setup
1.  Copy the template: `cp .env.v3 .env`
2.  Edit `.env` to set your `GCP_PROJECT_ID` (default: `modelling-demo`).
3.  Variables in `.env` are automatically loaded by:
    -   The `Makefile` (top-level commands).
    -   The Airflow DAGs (`antigravity_pipeline.py`).
    -   The Dagger CI pipeline (`dagger_pipeline.py`).

Run `make check-env` to verify your current settings.

## Infrastructure as Code (Terraform)

The Cloud Composer 3 environment is managed via Terraform in the `terraform/` directory.

### Configuration
- **Composer Version**: Composer 3
- **Airflow Version**: Airflow 3
- **Region**: `europe-west2`
- **Environment Size**: `ENVIRONMENT_SIZE_MEDIUM`

### Management Commands
Use the following `make` targets to manage infrastructure:
- `make tf-init`: Initialize Terraform providers.
- `make tf-plan`: View proposed infrastructure changes.
- `make tf-apply`: Deploy or update the environment (auto-approved).
- `make tf-destroy`: Tear down the environment (auto-approved).
- `make deploy`: Deploy code to Composer and run validation/regression tests.

> [!NOTE]
> `make deploy` requires the `COMPOSER_BUCKET` environment variable to be set (or automatically retrieved from Terraform).

## CI/CD and Regression Testing

The deployment pipeline (`ci/deploy_pipeline.py`) includes multiple validation layers:
1.  **DAG Integrity**: Runs `pytest tests/test_dags.py` to catch syntax or Airflow import errors.
2.  **Shadow Build**: Executes `dbtf build --target prod` to verify transformation logic against real BigQuery data.
3.  **Data Regression**: Runs `pytest tests/regression_tests.py` to ensure:
    -   Key tables are not empty.
    -   Fact tables have no null keys.
    -   Calculated metrics (like vessel age) are logically sound.

## CI/CD Pipeline (Dagger)

The CI/CD pipeline (`ci/dagger_pipeline.py`) has been upgraded to support **dbt-fusion**.

### Key Improvements
- **Fusion Engine**: Uses `dbtf` for high-performance builds and unit testing.
- **Environment Parity**: Automatically loads `.env` variables using `override=True` to ensure local Dagger runs match project settings.
- **Dependency Handling**: The CI container now includes `jq` and correctly configured shell aliases for the Fusion CLI.

---

## Key Fixes & Design Decisions

- **Materialization**: `fct_levitation_events` uses `table` materialization for optimized performance.
- **Fusion Compatibility**: Simplified date-math logic in `dim_vessels` and `dim_researchers` to ensure compatibility with the `dbt-fusion` 2.0 parser.
- **Makefile Usability**: Running `make` without arguments now displays a formatted help screen with all available targets.
- **Devcontainer Fix**: Resolved an installation hang by removing redundant features and refining the `Dockerfile` permission model.
- **Agentic Governance**: The project uses specialized AI agents (defined in `AGENTS.md`) for automated testing, secret scanning, and Makefile maintenance.
