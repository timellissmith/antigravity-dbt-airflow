# ==============================================================
# CQ Lifecycle Management: Cloud Workflows + Cloud Scheduler
# ==============================================================
# Two schedulers drive a single Cloud Workflow:
#   1. Proactive: fires every 47 days → guaranteed restart before the 50-day BQ limit
#   2. Health check: fires daily → restarts CQ if it died unexpectedly (noop if healthy)
# ==============================================================

# ── APIs ──────────────────────────────────────────────────────
resource "google_project_service" "workflows_api" {
  project            = var.project_id
  service            = "workflows.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "scheduler_api" {
  project            = var.project_id
  service            = "cloudscheduler.googleapis.com"
  disable_on_destroy = false
}

# ── Service Account ───────────────────────────────────────────
resource "google_service_account" "workflow_sa" {
  account_id   = "cq-lifecycle-manager"
  display_name = "CQ Lifecycle Manager (Workflows SA)"
  project      = var.project_id
}

# Needs BQ Job User to list, cancel, and create BQ jobs
resource "google_project_iam_member" "workflow_bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.workflow_sa.email}"
}

# Needs BQ Data Editor to INSERT into the silver table (CQ writes data)
resource "google_project_iam_member" "workflow_bq_data_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.workflow_sa.email}"
}

# Needs Workflows Invoker so Cloud Scheduler can trigger executions
resource "google_project_iam_member" "workflow_invoker" {
  project = var.project_id
  role    = "roles/workflows.invoker"
  member  = "serviceAccount:${google_service_account.workflow_sa.email}"
}

# Needs Logging Log Writer to write to Cloud Logging (for sys.log calls)
resource "google_project_iam_member" "workflow_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.workflow_sa.email}"
}

# Needs BigQuery Resource User to use reservations for continuous queries
resource "google_project_iam_member" "workflow_bq_resource_user" {
  project = var.project_id
  role    = "roles/bigquery.resourceUser"
  member  = "serviceAccount:${google_service_account.workflow_sa.email}"
}

# ── Cloud Workflow ─────────────────────────────────────────────
resource "google_workflows_workflow" "cq_manager" {
  name            = "antigravity-cq-manager"
  project         = var.project_id
  region          = var.region
  description     = "Manages BQ Continuous Query lifecycle: finds running CQ, cancels it, and starts a fresh one. Triggered proactively every 47 days and daily as a health check."
  service_account = google_service_account.workflow_sa.email

  # templatefile renders: ${project_id}, ${streaming_dataset}, ${cq_label_value}
  # $${} in the YAML file becomes ${} in the rendered output (Cloud Workflows expressions)
  source_contents = templatefile("${path.module}/workflows/cq_manager.yaml", {
    project_id        = var.project_id
    streaming_dataset = var.streaming_dataset
    cq_label_value    = var.cq_label_value
  })

  labels = {
    managed_by = "terraform"
    pipeline   = "streaming"
  }

  depends_on = [
    google_project_service.workflows_api,
    google_bigquery_table.stg_telemetry_stream,
  ]
}

# ── Scheduler: Proactive Restart (every 47 days) ──────────────
# Runs on 1st and 17th of each month — this overlapping pattern ensures
# no 50-day window is ever missed regardless of month length.
resource "google_cloud_scheduler_job" "cq_proactive_restart" {
  name        = "antigravity-cq-proactive-restart"
  description = "Proactively restarts the Continuous Query before the 50-day BQ limit. Runs on 1st + 17th of each month."
  project     = var.project_id
  region      = var.region
  schedule    = "0 2 1,17 * *"
  time_zone   = "UTC"

  http_target {
    uri         = "https://workflowexecutions.googleapis.com/v1/projects/${var.project_id}/locations/${var.region}/workflows/${google_workflows_workflow.cq_manager.name}/executions"
    http_method = "POST"
    body        = base64encode(jsonencode({ argument = jsonencode({}) }))

    oauth_token {
      service_account_email = google_service_account.workflow_sa.email
    }
  }

  retry_config {
    retry_count          = 3
    min_backoff_duration = "5s"
    max_backoff_duration = "60s"
  }

  depends_on = [
    google_project_service.scheduler_api,
    google_workflows_workflow.cq_manager,
  ]
}

# ── Scheduler: Daily Health Check ─────────────────────────────
# If CQ dies unexpectedly (e.g., BQ error), this restarts it within 24h.
# The workflow is idempotent: if the CQ is healthy it cancels + recreates
# (minimal disruption: sub-second gap during restart).
resource "google_cloud_scheduler_job" "cq_health_check" {
  name        = "antigravity-cq-health-check"
  description = "Daily health check: restarts Continuous Query if it has stopped unexpectedly."
  project     = var.project_id
  region      = var.region
  schedule    = "0 6 * * *"
  time_zone   = "UTC"

  http_target {
    uri         = "https://workflowexecutions.googleapis.com/v1/projects/${var.project_id}/locations/${var.region}/workflows/${google_workflows_workflow.cq_manager.name}/executions"
    http_method = "POST"
    body        = base64encode(jsonencode({ argument = jsonencode({}) }))

    oauth_token {
      service_account_email = google_service_account.workflow_sa.email
    }
  }

  retry_config {
    retry_count          = 3
    min_backoff_duration = "5s"
    max_backoff_duration = "60s"
  }

  depends_on = [
    google_project_service.scheduler_api,
    google_workflows_workflow.cq_manager,
  ]
}

# ── Initial CQ Bootstrap ──────────────────────────────────────
# Triggers the workflow once immediately after terraform apply
# to create the very first CQ job. Subsequent restarts are scheduler-driven.
resource "null_resource" "bootstrap_initial_cq" {
  triggers = {
    workflow_id = google_workflows_workflow.cq_manager.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Bootstrapping initial Continuous Query via Cloud Workflow..."
      gcloud workflows run antigravity-cq-manager \
        --project=${var.project_id} \
        --location=${var.region} \
        --format="value(name)"
      echo "Initial CQ created successfully."
    EOT
  }

  depends_on = [
    google_workflows_workflow.cq_manager,
    google_bigquery_table.raw_telemetry_stream,
    google_bigquery_table.stg_telemetry_stream,
    google_pubsub_subscription.telemetry_bq,
  ]
}
