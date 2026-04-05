variable "project_id" {
  description = "The GCP project ID"
  type        = string
  default     = "modelling-demo"
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "europe-west2"
}

variable "environment_name" {
  description = "The name of the Composer environment"
  type        = string
  default     = "antigravity-composer"
}

variable "streaming_dataset" {
  description = "BigQuery dataset ID for streaming pipeline (bronze + silver streaming tables)"
  type        = string
  default     = "streaming"
}

variable "pubsub_topic_name" {
  description = "Pub/Sub topic name for telemetry ingestion"
  type        = string
  default     = "antigravity-telemetry"
}

variable "cq_label_value" {
  description = "Label value applied to Continuous Query jobs so the Cloud Workflow can identify them"
  type        = string
  default     = "antigravity-cq-manager"
}
