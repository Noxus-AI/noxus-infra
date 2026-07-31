variable "name" {
  description = "Name prefix, e.g. \"noxus-prod\"."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the server."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "subnet_id" {
  description = "Delegated subnet ID from the network module."
  type        = string
}

variable "private_dns_zone_id" {
  description = "Private DNS zone ID from the network module."
  type        = string
}

variable "postgres_version" {
  description = "PostgreSQL major version. Must be 15 or newer for pgvector."
  type        = string
  default     = "16"
}

variable "sku_name" {
  description = "Flexible Server SKU, e.g. GP_Standard_D4ds_v5. See docs/sizing.md."
  type        = string
  default     = "GP_Standard_D4ds_v5"
}

variable "storage_mb" {
  description = "Storage in MB. Azure derives IOPS from this, so an undersized disk throttles the whole platform."
  type        = number
  default     = 262144
}

variable "storage_tier" {
  description = "Storage performance tier, e.g. P30. Must be valid for the chosen storage_mb."
  type        = string
  default     = "P30"
}

variable "username" {
  description = "Administrator login."
  type        = string
  default     = "noxus"
}

variable "databases" {
  description = "Databases to create. The platform needs all of these."
  type        = list(string)
  default     = ["spot", "vectors", "license", "procrastinate", "spot_userdata"]
}

variable "allowed_extensions" {
  description = "Extensions added to the azure.extensions allowlist. VECTOR, UUID-OSSP, and PG_TRGM are required by the platform migrations."
  type        = list(string)
  default     = ["VECTOR", "UUID-OSSP", "PG_TRGM", "PG_STAT_STATEMENTS", "POSTGRES_FDW"]
}

variable "max_connections" {
  description = "Server max_connections. Each backend and worker pod opens its own pool, so this climbs fast with replica count — run PgBouncer as well."
  type        = number
  default     = 1000
}

variable "server_configurations" {
  description = "Additional server parameters."
  type        = map(string)
  default     = {}
}

variable "high_availability" {
  description = "Zone-redundant HA with a synchronous standby. Roughly doubles cost; required for any production SLA."
  type        = bool
  default     = true
}

variable "availability_zone" {
  description = "Primary availability zone."
  type        = string
  default     = "1"
}

variable "standby_availability_zone" {
  description = "Standby zone, used when high_availability is true. Must differ from availability_zone."
  type        = string
  default     = "2"
}

variable "backup_retention_days" {
  description = "Backup retention in days, 7 to 35."
  type        = number
  default     = 14
}

variable "geo_redundant_backup" {
  description = "Replicate backups to the paired region."
  type        = bool
  default     = false
}

variable "maintenance_day" {
  description = "Maintenance day, 0 (Sunday) through 6."
  type        = number
  default     = 0
}

variable "maintenance_hour" {
  description = "Maintenance start hour, UTC."
  type        = number
  default     = 3
}

variable "tags" {
  description = "Tags applied to the server."
  type        = map(string)
  default     = {}
}
