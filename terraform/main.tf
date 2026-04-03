resource "google_project_service" "composer_api" {
  project            = var.project_id
  service            = "composer.googleapis.com"
  disable_on_destroy = false
}

resource "google_service_account" "composer_sa" {
  account_id   = "composer-worker-sa"
  display_name = "Composer Worker Service Account"
}

resource "google_project_iam_member" "composer_worker" {
  project = var.project_id
  role    = "roles/composer.worker"
  member  = "serviceAccount:${google_service_account.composer_sa.email}"
}

resource "google_project_iam_member" "bq_data_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.composer_sa.email}"
}

resource "google_project_iam_member" "bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.composer_sa.email}"
}

resource "google_composer_environment" "antigravity_env" {
  name   = var.environment_name
  region = var.region

  config {
    software_config {
      image_version = "composer-3-airflow-3"
      pypi_packages = {
        "astronomer-cosmos" = "~=1.13.1"
        "dbt-bigquery"      = "~=1.11.0"
        "python-dotenv"     = "~=1.0.1"
      }
      env_variables = {
        "GCP_PROJECT_ID" = var.project_id
        "GCP_SCHEMA"     = "main"
      }
    }

    environment_size = "ENVIRONMENT_SIZE_MEDIUM"

    node_config {
      service_account = google_service_account.composer_sa.email
    }
  }

  depends_on = [
    google_project_service.composer_api,
    google_project_iam_member.composer_worker
  ]
}
