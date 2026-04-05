# ==============================================================
# Streaming Pipeline: Pub/Sub + BigQuery Tables + Initial CQ
# ==============================================================

# ── APIs ──────────────────────────────────────────────────────
resource "google_project_service" "pubsub_api" {
  project            = var.project_id
  service            = "pubsub.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "bigquery_api" {
  project            = var.project_id
  service            = "bigquery.googleapis.com"
  disable_on_destroy = false
}

# ── Pub/Sub Schema (Avro, JSON encoding) ──────────────────────
resource "google_pubsub_schema" "telemetry" {
  name    = "antigravity-telemetry-schema"
  project = var.project_id
  type    = "AVRO"

  # Schema matches raw_telemetry_stream BQ table columns exactly.
  # JSON encoding allows the generator to publish plain JSON without Avro binary serialisation.
  definition = jsonencode({
    type = "record"
    name = "TelemetryEvent"
    fields = [
      { name = "id",                type = "long"   },
      { name = "vessel_id",         type = "string" },
      { name = "raw_force_reading", type = "double" },
      { name = "location_id",       type = "string" },
      { name = "event_time",        type = "string" }
    ]
  })

  depends_on = [google_project_service.pubsub_api]
}

# ── Pub/Sub Topic ─────────────────────────────────────────────
resource "google_pubsub_topic" "telemetry" {
  name    = var.pubsub_topic_name
  project = var.project_id

  schema_settings {
    schema   = google_pubsub_schema.telemetry.id
    encoding = "JSON"
  }

  message_retention_duration = "86600s" # 24h retention

  depends_on = [google_pubsub_schema.telemetry]
}

# Dead-letter topic for messages that fail BQ delivery after 5 attempts
resource "google_pubsub_topic" "telemetry_dlq" {
  name    = "${var.pubsub_topic_name}-dlq"
  project = var.project_id
}

# ── BigQuery Dataset (streaming) ──────────────────────────────
resource "google_bigquery_dataset" "streaming" {
  dataset_id  = var.streaming_dataset
  project     = var.project_id
  location    = var.region
  description = "Antigravity real-time telemetry streaming pipeline (bronze + silver layers)"

  labels = {
    managed_by = "terraform"
    pipeline   = "streaming"
  }
}

# ── Bronze Table: raw_telemetry_stream ────────────────────────
# Written to by the Pub/Sub BigQuery subscription directly.
resource "google_bigquery_table" "raw_telemetry_stream" {
  dataset_id          = google_bigquery_dataset.streaming.dataset_id
  table_id            = "raw_telemetry_stream"
  project             = var.project_id
  deletion_protection = false
  description         = "Bronze streaming landing table. Populated by Pub/Sub BQ native subscription."

  # Ingestion-time partitioning (event_time is a STRING so cannot be used as partition field)
  time_partitioning {
    type = "DAY"
  }

  labels = {
    layer      = "bronze"
    managed_by = "terraform"
  }

  schema = jsonencode([
    { name = "id",                type = "INTEGER", mode = "REQUIRED", description = "Unique event ID" },
    { name = "vessel_id",         type = "STRING",  mode = "REQUIRED", description = "Vessel identifier (FK → dim_vessels)" },
    { name = "raw_force_reading", type = "FLOAT",   mode = "REQUIRED", description = "Unscaled force reading (m/s²)" },
    { name = "location_id",       type = "STRING",  mode = "REQUIRED", description = "Location identifier (FK → dim_locations)" },
    { name = "event_time",        type = "STRING",  mode = "REQUIRED", description = "ISO 8601 UTC timestamp from the generator" }
  ])

  depends_on = [google_bigquery_dataset.streaming]
}

# ── Silver Table: stg_telemetry_stream ────────────────────────
# Written to by the BigQuery Continuous Query (managed by cq_lifecycle.tf).
resource "google_bigquery_table" "stg_telemetry_stream" {
  dataset_id          = google_bigquery_dataset.streaming.dataset_id
  table_id            = "stg_telemetry_stream"
  project             = var.project_id
  deletion_protection = false
  description         = "Silver streaming table. Populated by BigQuery Continuous Query from bronze."

  time_partitioning {
    type  = "DAY"
    field = "observed_at"
  }

  labels = {
    layer      = "silver"
    managed_by = "terraform"
  }

  schema = jsonencode([
    { name = "event_id",     type = "INTEGER",   mode = "REQUIRED", description = "Normalised event ID" },
    { name = "vessel_id",    type = "STRING",    mode = "REQUIRED", description = "Vessel identifier" },
    { name = "location_id",  type = "STRING",    mode = "REQUIRED", description = "Location identifier" },
    { name = "gravity_g",    type = "FLOAT",     mode = "REQUIRED", description = "Force reading in Standard Gravity (G)" },
    { name = "observed_at",  type = "TIMESTAMP", mode = "REQUIRED", description = "Parsed event timestamp" },
    { name = "processed_at", type = "TIMESTAMP", mode = "REQUIRED", description = "Timestamp when the CQ processed this row" }
  ])

  depends_on = [google_bigquery_dataset.streaming]
}

# ── Service Account: Pub/Sub → BigQuery ──────────────────────
resource "google_service_account" "pubsub_bq_sa" {
  account_id   = "pubsub-bq-writer"
  display_name = "Pub/Sub → BigQuery Writer"
  project      = var.project_id
}

resource "google_project_iam_member" "pubsub_bq_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.pubsub_bq_sa.email}"
}

resource "google_project_iam_member" "pubsub_bq_metadata" {
  project = var.project_id
  role    = "roles/bigquery.metadataViewer"
  member  = "serviceAccount:${google_service_account.pubsub_bq_sa.email}"
}

# Pub/Sub's own managed SA also needs BQ write access (required for BQ subscriptions)
resource "google_project_iam_member" "pubsub_sa_bq_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

data "google_project" "project" {
  project_id = var.project_id
}

# ── Pub/Sub BigQuery Subscription ────────────────────────────
# Writes Pub/Sub messages directly to BQ bronze table (no Dataflow required).
# use_topic_schema = true: maps Avro schema fields directly to BQ columns.
resource "google_pubsub_subscription" "telemetry_bq" {
  name    = "${var.pubsub_topic_name}-bq-sub"
  topic   = google_pubsub_topic.telemetry.name
  project = var.project_id

  bigquery_config {
    table               = "${var.project_id}.${var.streaming_dataset}.${google_bigquery_table.raw_telemetry_stream.table_id}"
    use_topic_schema    = true
    write_metadata      = false
    drop_unknown_fields = true
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.telemetry_dlq.id
    max_delivery_attempts = 5
  }

  depends_on = [
    google_bigquery_table.raw_telemetry_stream,
    google_project_iam_member.pubsub_sa_bq_editor,
  ]
}
