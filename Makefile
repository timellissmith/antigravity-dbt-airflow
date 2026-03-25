# Antigravity Project Makefile

# Variables
DBT = dbtf
DBT_PROJECT_DIR = antigravity_project
TEST_DIR = tests
DAG_ID = antigravity_pipeline

# Default Environment Variables for local/CI portability
export GCP_PROJECT_ID = local_antigravity
export GCP_SCHEMA = main
export DBT_TARGET = dev
export DBT_PROFILES_DIR = $(shell pwd)/$(DBT_PROJECT_DIR)
export DBT_PROFILES_YML = $(shell pwd)/$(DBT_PROJECT_DIR)/profiles.yml

.PHONY: help install dbt-run dbt-test dbt-build airflow-trigger test-e2e clean

help: ## Display this help screen
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

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

airflow-trigger: ## Trigger the main Airflow pipeline DAG
	airflow dags trigger $(DAG_ID)

test-e2e: ## Run full pytest end-to-end test suite
	CI=true pytest $(TEST_DIR)

clean: ## Clean up temporary files and dbt artifacts
	rm -rf $(DBT_PROJECT_DIR)/target/
	rm -rf $(DBT_PROJECT_DIR)/dbt_packages/
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
