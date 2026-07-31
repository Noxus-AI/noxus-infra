variable "name" {
  description = "Name prefix, e.g. \"noxus-prod\"."
  type        = string
}

variable "vpc_id" {
  description = "VPC to place the security group in."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the cache subnet group."
  type        = list(string)
}

variable "allowed_cidrs" {
  description = "CIDR blocks allowed to reach port 6379."
  type        = list(string)
  default     = []
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to reach port 6379, e.g. the EKS node security group."
  type        = list(string)
  default     = []
}

variable "engine_version" {
  description = "Redis engine version."
  type        = string
  default     = "7.1"
}

variable "node_type" {
  description = "ElastiCache node type. See docs/sizing.md."
  type        = string
  default     = "cache.m7g.large"
}

variable "replica_count" {
  description = "Read replicas in addition to the primary. 1 or more enables automatic failover and Multi-AZ."
  type        = number
  default     = 1
}

variable "maxmemory_policy" {
  description = "Eviction policy. Keep allkeys-lru unless you have measured a reason not to."
  type        = string
  default     = "allkeys-lru"
}

variable "transit_encryption_enabled" {
  description = "Enable in-transit TLS and generate an auth token. Requires setting env.REDIS_SSL=\"true\" and secrets.REDIS_PASSWORD in the chart."
  type        = bool
  default     = false
}

variable "snapshot_retention_days" {
  description = "Daily snapshot retention. 0 disables snapshots — acceptable, since Redis holds no durable state the platform cannot rebuild."
  type        = number
  default     = 1
}

variable "maintenance_window" {
  description = "Weekly maintenance window in UTC."
  type        = string
  default     = "tue:04:00-tue:05:00"
}

variable "apply_immediately" {
  description = "Apply changes without waiting for the maintenance window. Causes a failover on some changes."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
