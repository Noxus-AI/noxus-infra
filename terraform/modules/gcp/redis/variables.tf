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
  description = "VPC network ID the instance is peered into."
  type        = string
}

variable "private_service_access_connection" {
  description = "Service networking connection ID from the network module."
  type        = string
}

variable "redis_version" {
  description = "Memorystore Redis version."
  type        = string
  default     = "REDIS_7_2"
}

variable "memory_size_gb" {
  description = "Instance memory in GiB."
  type        = number
  default     = 5
}

variable "high_availability" {
  description = "STANDARD_HA (replicated, cross-zone failover) rather than BASIC (single node, data loss on failure)."
  type        = bool
  default     = true
}

variable "auth_enabled" {
  description = "Require an AUTH string. When true, pass the auth_string output as the chart's secrets.REDIS_PASSWORD."
  type        = bool
  default     = true
}

variable "transit_encryption" {
  description = "Enable in-transit TLS. Requires env.REDIS_SSL=\"true\" in the chart and a client that trusts the Google CA."
  type        = bool
  default     = false
}

variable "maxmemory_policy" {
  description = "Eviction policy."
  type        = string
  default     = "allkeys-lru"
}

variable "redis_configs" {
  description = "Additional Redis config overrides, merged over maxmemory-policy."
  type        = map(string)
  default     = {}
}

variable "maintenance_day" {
  description = "Maintenance day, e.g. TUESDAY."
  type        = string
  default     = "TUESDAY"
}

variable "maintenance_hour" {
  description = "Maintenance start hour, UTC."
  type        = number
  default     = 4
}

variable "labels" {
  description = "Labels applied to the instance."
  type        = map(string)
  default     = {}
}
