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
