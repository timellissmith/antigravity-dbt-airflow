# ==============================================================
# Ingestion Framework: BQ Landing + Control Tables + Storage
# ==============================================================

# ── BigQuery Dataset (raw) ──────────────────────────────────
resource "google_bigquery_dataset" "raw" {
  dataset_id  = "raw"
  project     = var.project_id
  location    = var.region
  description = "Landing zone for raw telemetry API data ingestions."

  labels = {
    managed_by = "terraform"
    layer      = "raw"
  }
}

# ── Control Table: etl_watermarks ───────────────────────────
# Tracks the last processed cursor for each incremental API stream.
resource "google_bigquery_table" "etl_watermarks" {
  dataset_id          = google_bigquery_dataset.raw.dataset_id
  table_id            = "etl_watermarks"
  project             = var.project_id
  deletion_protection = false
  description         = "Control table for tracking API state/cursors."

  schema = jsonencode([
    { name = "stream_name",    type = "STRING",    mode = "REQUIRED", description = "Name of the API stream (e.g., fraud)" },
    { name = "current_cursor", type = "STRING",    mode = "NULLABLE", description = "Last cursor returned by the API" },
    { name = "updated_at",     type = "TIMESTAMP", mode = "REQUIRED", description = "Last time this stream was updated" }
  ])

  depends_on = [google_bigquery_dataset.raw]
}

# ── Raw Landing Tables (Dynamic Example) ────────────────────
# In a real environment, we'd loop over a list of streams.
# For the mock/demo, we'll create the three requested ones.

variable "telemetry_streams" {
  type    = list(string)
  default = ["fraud", "audit", "access"]
}

resource "google_bigquery_table" "raw_telemetry_mapped" {
  for_each            = toset(var.telemetry_streams)
  dataset_id          = google_bigquery_dataset.raw.dataset_id
  table_id            = "telemetry_${each.key}"
  project             = var.project_id
  deletion_protection = false
  description         = "Raw landing table for ${each.key} telemetry API."

  # Ingestion-time partitioning
  time_partitioning {
    type = "DAY"
  }

  # Generic schema for JSON ingestion
  # Using a flexible schema where fields can be autodetected or staged in a JSON column.
  # For this framework, we'll use a JSON column as requested in some variants of the pattern,
  # or let the Load job autodetect.
  schema = jsonencode([
    { name = "_airflow_ingested_at", type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "_stream_source",       type = "STRING",    mode = "NULLABLE" },
    { name = "event_id",              type = "STRING",    mode = "NULLABLE" },
    { name = "stream_type",           type = "STRING",    mode = "NULLABLE" },
    { name = "data",                 type = "JSON",      mode = "NULLABLE" },
    { name = "timestamp",             type = "FLOAT",     mode = "NULLABLE" }
  ])

  depends_on = [google_bigquery_dataset.raw]
}

# ── Cloud Storage Bucket ────────────────────────────────────
resource "google_storage_bucket" "telemetry_stating" {
  name          = "antigravity-telemetry-${var.project_id}"
  project       = var.project_id
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "Delete"
    }
  }
}
