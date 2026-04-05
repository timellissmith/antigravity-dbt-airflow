# ==============================================================
# BigQuery Reservations for Continuous Queries
# ==============================================================

resource "google_project_service" "reservation_api" {
  project            = var.project_id
  service            = "bigqueryreservation.googleapis.com"
  disable_on_destroy = false
}

# ── BigQuery Reservation ──────────────────────────────────────
# Continuous queries require an Enterprise or Enterprise Plus edition reservation.
resource "google_bigquery_reservation" "streaming_reservation" {
  name     = "antigravity-continuous-reservation"
  project  = var.project_id
  location = var.region
  
  # Edition must be ENTERPRISE or ENTERPRISE_PLUS for Continuous Queries.
  edition  = "ENTERPRISE"
  
  # Use autoscaling to minimize costs when queries are idle.
  # Continuous queries will scale up to 100 slots as needed.
  # A baseline of at least 1 slot is required to start the job.
  slot_capacity = 1
  autoscale {
    max_slots = 100
  }

  depends_on = [google_project_service.reservation_api]
}

# ── Reservation Assignment ────────────────────────────────────
# Assigns the 'CONTINUOUS' job type for this project to the reservation.
resource "google_bigquery_reservation_assignment" "streaming_assignment" {
  assignee    = "projects/${var.project_id}"
  job_type    = "CONTINUOUS"
  reservation = google_bigquery_reservation.streaming_reservation.id
  project     = var.project_id
  location    = var.region
}
