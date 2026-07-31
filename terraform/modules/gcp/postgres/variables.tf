variable "name" {
  description = "Name prefix, e.g. \"noxus-prod\"."
  type        = string
}

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Region for the instance."
  type        = string
}

variable "network_id" {
  description = "VPC network ID to attach the private IP to."
  type        = string
}

variable "private_service_access_connection" {
  description = "Service networking connection ID from the network module. Creating the instance before peering exists fails."
  type        = string
}

variable "database_version" {
  description = "Cloud SQL PostgreSQL version. Must be POSTGRES_15 or newer for pgvector."
  type        = string
  default     = "POSTGRES_16"
}

variable "tier" {
  description = "Machine tier. See docs/sizing.md."
  type        = string
  default     = "db-custom-4-16384"
}

variable "edition" {
  description = "ENTERPRISE or ENTERPRISE_PLUS. ENTERPRISE_PLUS adds a data cache and faster maintenance, at roughly double the price."
  type        = string
  default     = "ENTERPRISE"
}

variable "disk_size_gb" {
  description = "Initial disk size. Autoresize is always on."
  type        = number
  default     = 100
}

variable "high_availability" {
  description = "Regional (synchronous cross-zone) rather than zonal. Required for any production SLA."
  type        = bool
  default     = true
}

variable "username" {
  description = "Application database user."
  type        = string
  default     = "noxus"
}

variable "databases" {
  description = "Databases to create. The platform needs all of these: spot (app), vectors (embeddings), license, procrastinate (job queue), spot_userdata (Tables)."
  type        = list(string)
  default     = ["spot", "vectors", "license", "procrastinate", "spot_userdata"]
}

variable "database_flags" {
  description = "Cloud SQL database flags. max_connections defaults low relative to what the platform's per-pod pools open."
  type        = map(string)
  default = {
    max_connections = "1000"
  }
}

variable "backup_start_time" {
  description = "Daily backup start time, UTC, HH:MM."
  type        = string
  default     = "02:00"
}

variable "point_in_time_recovery" {
  description = "Enable PITR via write-ahead log archiving."
  type        = bool
  default     = true
}

variable "transaction_log_retention_days" {
  description = "Days of WAL retained for PITR."
  type        = number
  default     = 7
}

variable "retained_backups" {
  description = "Number of automated backups to keep."
  type        = number
  default     = 14
}

variable "maintenance_day" {
  description = "Maintenance day, 1 (Monday) through 7."
  type        = number
  default     = 1
}

variable "maintenance_hour" {
  description = "Maintenance hour, UTC."
  type        = number
  default     = 3
}

variable "deletion_protection" {
  description = "Block deletion of the instance. Leave true in production."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels applied to the instance."
  type        = map(string)
  default     = {}
}
