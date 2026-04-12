# Antigravity Project Makefile
.DEFAULT_GOAL := help

# Variables
DBT := $(shell which dbtf 2>/dev/null || ( [ -f .venv/bin/dbt ] && echo .venv/bin/dbt ) || which dbt 2>/dev/null || echo dbt)
DBT_PROJECT_DIR = antigravity_project
TEST_DIR = tests
DAG_ID = antigravity_pipeline
PYTHON := $(shell ([ -f .venv/bin/python ] && echo .venv/bin/python) || which python3 2>/dev/null || echo python)

# Load environment variables from .env file if it exists
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Default Environment Variables for local/CI portability (only set if not already in env)
GCP_PROJECT_ID ?= local_antigravity
GCP_SCHEMA ?= main
GCP_REGION ?= europe-west2
DBT_TARGET ?= dev
DBT_PROFILES_DIR ?= $(shell pwd)/$(DBT_PROJECT_DIR)
DBT_PROFILES_YML ?= $(shell pwd)/$(DBT_PROJECT_DIR)/profiles.yml

# ── Terraform Targets ──────────────────────────────────────────

# Composer-related resources
COMPOSER_TARGETS = \
	-target=google_composer_environment.antigravity_env \
	-target=google_service_account.composer_sa \
	-target=google_project_iam_member.composer_worker \
	-target=google_project_iam_member.bq_data_editor \
	-target=google_project_iam_member.bq_job_user \
	-target=google_project_service.composer_api

# Streaming-related resources (Pub/Sub, BQ, Workflows, Scheduler)
STREAM_TARGETS = \
	-target=google_pubsub_schema.telemetry \
	-target=google_pubsub_topic.telemetry \
	-target=google_pubsub_subscription.telemetry_bq \
	-target=google_bigquery_dataset.streaming \
	-target=google_bigquery_table.raw_telemetry_stream \
	-target=google_bigquery_table.stg_telemetry_stream \
	-target=google_workflows_workflow.cq_manager \
	-target=google_cloud_scheduler_job.cq_proactive_restart \
	-target=google_cloud_scheduler_job.cq_health_check \
	-target=null_resource.bootstrap_initial_cq \
	-target=google_project_service.workflows_api \
	-target=google_project_service.scheduler_api \
	-target=google_service_account.workflow_sa \
	-target=google_project_iam_member.workflow_bq_job_user \
	-target=google_project_iam_member.workflow_bq_data_editor \
	-target=google_project_iam_member.workflow_invoker \
	-target=google_project_iam_member.workflow_log_writer \
	-target=google_project_iam_member.workflow_bq_resource_user \
	-target=google_project_service.reservation_api \
	-target=google_bigquery_reservation.streaming_reservation \
	-target=google_bigquery_reservation_assignment.streaming_assignment

# API Ingestion Framework resources (RAW layer)
INGESTION_TARGETS = \
	-target=google_bigquery_dataset.raw \
	-target=google_bigquery_table.etl_watermarks \
	-target=google_bigquery_table.raw_telemetry_mapped \
	-target=google_storage_bucket.telemetry_stating

# ── General Operations ─────────────────────────────────────────

.PHONY: help install dbt-run dbt-test dbt-build dbt-docs-generate dbt-docs-serve dbt-mock airflow-trigger airflow-start airflow-stop airflow-setup test-e2e clean check-env

airflow-setup: ## Initialize Airflow connections
	@echo "Configuring Airflow connections..."
	@airflow connections add 'google_cloud_default' \
		--conn-type 'google_cloud_platform' \
		--conn-extra '{"project": "$(GCP_PROJECT_ID)", "key_path": ""}' || true
	@airflow connections add 'telemetry_api_auth' \
		--conn-type 'generic' \
		--conn-host 'http://localhost:8000' \
		--login 'demo_client' \
		--password 'demo_secret' || true

airflow-start: airflow-setup ## Start local Airflow standalone in background
	@echo "Starting Airflow standalone..."
	@nohup airflow standalone > /home/vscode/airflow/standalone.log 2>&1 &
	@echo "Airflow started. Check /home/vscode/airflow/standalone.log for logs."

airflow-stop: ## Stop all local Airflow processes
	@echo "Stopping Airflow..."
	@pkill -f airflow || true
	@echo "Airflow stopped."

check-env: ## Verify environment variable resolution
	@echo "GCP_PROJECT_ID: $(GCP_PROJECT_ID)"
	@echo "GCP_SCHEMA: $(GCP_SCHEMA)"
	@echo "DBT_TARGET: $(DBT_TARGET)"

tf-init: ## Initialize Terraform
	terraform -chdir=terraform init

tf-plan: ## View Cloud Composer infrastructure changes
	terraform -chdir=terraform plan \
		-var="project_id=$(GCP_PROJECT_ID)" \
		$(COMPOSER_TARGETS)

tf-apply: ## Deploy Cloud Composer infrastructure
	terraform -chdir=terraform apply -auto-approve \
		-var="project_id=$(GCP_PROJECT_ID)" \
		$(COMPOSER_TARGETS)

tf-destroy: ## Destroy Cloud Composer infrastructure
	terraform -chdir=terraform destroy -auto-approve \
		-var="project_id=$(GCP_PROJECT_ID)" \
		$(COMPOSER_TARGETS)

deploy: ## Deploy to Cloud Composer using Dagger
	python ci/deploy_pipeline.py

help: ## Display this help screen
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

install: ## Install python dependencies
	pip install -r requirements.txt
	cd $(DBT_PROJECT_DIR) && $(DBT) deps

dbt-seed: ## Load dbt seeds
	$(DBT) seed --project-dir $(DBT_PROJECT_DIR)

dbt-run: ## Run all dbt models
	$(DBT) run --project-dir $(DBT_PROJECT_DIR)

dbt-test: ## Run dbt generic and unit tests
	$(DBT) test --project-dir $(DBT_PROJECT_DIR)

dbt-build: ## Execute dbt build (seeds, models, snapshots, and tests)
	$(DBT) seed --project-dir $(DBT_PROJECT_DIR)
	$(DBT) build --project-dir $(DBT_PROJECT_DIR)

dbt-docs-generate: ## Generate dbt documentation
	$(DBT) docs generate --project-dir $(DBT_PROJECT_DIR)

dbt-docs-serve: dbt-docs-generate ## Serve dbt documentation locally on port 8081
	$(DBT) docs serve --project-dir $(DBT_PROJECT_DIR) --port 8081

dbt-mock: ## Generate mock data programmatically via LLM
	@if [ -z "$(MODEL)" ]; then echo "Missing MODEL=... parameter"; exit 1; fi
	@if [ -z "$(GEMINI_API_KEY)" ]; then echo "Missing GEMINI_API_KEY in .env file"; exit 1; fi
	$(PYTHON) scripts/ai_tools/dbt_mock_generator.py --model $(MODEL)

dbt-optimize: ## Optimize dbt models for BigQuery via LLM
	@if [ -z "$(MODEL_PATH)" ]; then \
		echo "Missing MODEL_PATH=... parameter (relative to project root, e.g. models/gold/fct_levitation_events.sql)"; \
		exit 1; \
	fi
	@if [ -z "$(GEMINI_API_KEY)" ]; then echo "Missing GEMINI_API_KEY in .env file"; exit 1; fi
	$(PYTHON) scripts/ai_tools/bq_optimizer.py --model-path $(DBT_PROJECT_DIR)/$(MODEL_PATH)

airflow-trigger: ## Trigger the main Airflow pipeline DAG
	airflow dags trigger $(DAG_ID)

test-e2e: ## Run full pytest end-to-end test suite
	CI=true pytest $(TEST_DIR)

clean: ## Clean up temporary files and dbt artifacts
	rm -rf $(DBT_PROJECT_DIR)/target/
	rm -rf $(DBT_PROJECT_DIR)/dbt_packages/
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete

# ── Streaming Pipeline ─────────────────────────────────────────

STREAM_PROJECT ?= $(GCP_PROJECT_ID)
STREAM_TOPIC   ?= antigravity-telemetry
STREAM_COUNT   ?= 10
STREAM_RATE    ?= 1.0
STREAMING_ENABLED ?= false

stream-infra-init: ## Init Terraform for streaming infrastructure
	terraform -chdir=terraform init

stream-infra-plan: ## Preview streaming infrastructure changes (Pub/Sub, BQ, Workflows, Scheduler)
	terraform -chdir=terraform plan \
		-var="project_id=$(STREAM_PROJECT)" \
		$(STREAM_TARGETS)

stream-infra-apply: ## Deploy streaming infrastructure and bootstrap the Continuous Query
	terraform -chdir=terraform apply -auto-approve \
		-var="project_id=$(STREAM_PROJECT)" \
		$(STREAM_TARGETS)

ingestion-infra-plan: ## Preview API ingestion infrastructure changes
	terraform -chdir=terraform plan \
		-var="project_id=$(STREAM_PROJECT)" \
		$(INGESTION_TARGETS)

ingestion-infra-apply: ## Deploy API ingestion infrastructure (Landing Dataset, Watermarks, GCS Bucket)
	terraform -chdir=terraform apply -auto-approve \
		-var="project_id=$(STREAM_PROJECT)" \
		$(INGESTION_TARGETS)

stream-infra-destroy: ## Destroy all streaming infrastructure (irreversible)
	@echo "WARNING: This will delete all streaming tables and data!"
	terraform -chdir=terraform destroy -auto-approve \
		-var="project_id=$(STREAM_PROJECT)" \
		$(STREAM_TARGETS)

stream-generate: ## Publish $(STREAM_COUNT) events at $(STREAM_RATE)/s (defaults: 10 events @ 1/s)
	python -m streaming.generator \
		--project $(STREAM_PROJECT) \
		--topic   $(STREAM_TOPIC) \
		--count   $(STREAM_COUNT) \
		--rate    $(STREAM_RATE)

stream-generate-load: ## Load test: publish 500 events at max throughput
	$(MAKE) stream-generate STREAM_COUNT=500 STREAM_RATE=0

stream-cq-restart: ## Manually trigger CQ lifecycle workflow (restart Continuous Query now)
	gcloud workflows run antigravity-cq-manager \
		--project=$(STREAM_PROJECT) \
		--location=$(GCP_REGION) \
		--format="value(name)"

stream-cq-status: ## Check status of the running Continuous Query job
	@bq query --use_legacy_sql=false --format=prettyjson \
		"SELECT start_time, job_id, state, continuous_query_info.output_watermark \
		 FROM \`$(STREAM_PROJECT).region-$(GCP_REGION).INFORMATION_SCHEMA.JOBS\` \
		 WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 day) \
		   AND continuous IS TRUE \
		   AND state = 'RUNNING' \
		 ORDER BY start_time DESC"

stream-cq-stop: ## Stop all running continuous queries for this pipeline
	@echo "Identifying and stopping running continuous queries..."
	@bq query --use_legacy_sql=false --format=csv --no_heading \
		"SELECT job_id \
		 FROM \`$(STREAM_PROJECT).region-$(GCP_REGION).INFORMATION_SCHEMA.JOBS\` \
		 WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 day) \
		   AND continuous IS TRUE \
		   AND state = 'RUNNING'" | \
	 xargs -I {} bq cancel --project_id=$(STREAM_PROJECT) {}

dbt-streaming: ## Run streaming-tagged dbt models (requires streaming infra to be deployed)
	STREAMING_ENABLED=true $(DBT) run --project-dir $(DBT_PROJECT_DIR) --select tag:streaming

dbt-streaming-test: ## Test streaming-tagged dbt models
	STREAMING_ENABLED=true $(DBT) test --project-dir $(DBT_PROJECT_DIR) --select tag:streaming

test-streaming: ## Run streaming unit tests (no GCP required)
	CI=false pytest tests/test_streaming.py -v -k "not Integration"

stream-mock-api: ## Start local FastAPI mock server for telemetry simulation
	@echo "Starting Telemetry Mock API..."
	python3 streaming/mock_api.py
