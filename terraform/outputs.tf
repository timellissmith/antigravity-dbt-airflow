output "airflow_uri" {
  description = "The URI of the Apache Airflow Web UI"
  value       = google_composer_environment.antigravity_env.config[0].airflow_uri
}

output "gcs_bucket" {
  description = "The GCS bucket associated with the Composer environment"
  value       = google_composer_environment.antigravity_env.config[0].dag_gcs_prefix
}

output "service_account" {
  description = "The service account used by the Composer environment"
  value       = google_service_account.composer_sa.email
}
