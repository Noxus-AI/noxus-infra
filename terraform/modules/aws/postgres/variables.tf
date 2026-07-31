variable "name" {
  description = "Name prefix, e.g. \"noxus-prod\"."
  type        = string
}

variable "vpc_id" {
  description = "VPC to place the security group in."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the DB subnet group. Must span at least two AZs."
  type        = list(string)
}

variable "allowed_cidrs" {
  description = "CIDR blocks allowed to reach port 5432. Normally just the VPC CIDR."
  type        = list(string)
  default     = []
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to reach port 5432, e.g. the EKS node security group."
  type        = list(string)
  default     = []
}

variable "engine_version" {
  description = "PostgreSQL major or major.minor version. Must be 15.2 or newer — pgvector is not available below that and the platform migrations require it."
  type        = string
  default     = "16.4"
}

variable "instance_class" {
  description = "RDS instance class. See docs/sizing.md for guidance."
  type        = string
  default     = "db.m6g.large"
}

variable "allocated_storage" {
  description = "Initial storage in GiB."
  type        = number
  default     = 100
}

variable "max_allocated_storage" {
  description = "Storage autoscaling ceiling in GiB. Set equal to allocated_storage to disable."
  type        = number
  default     = 2000
}

variable "multi_az" {
  description = "Run a synchronous standby in a second AZ. Roughly doubles cost; required for any production SLA."
  type        = bool
  default     = true
}

variable "initial_database" {
  description = "Database created with the instance. The platform's other databases (vectors, license, procrastinate, spot_userdata) are created by scripts/bootstrap-postgres.sh."
  type        = string
  default     = "spot"
}

variable "username" {
  description = "Master username."
  type        = string
  default     = "noxus"
}

variable "snapshot_identifier" {
  description = "Snapshot ARN or identifier to restore from. null for a fresh instance."
  type        = string
  default     = null
}

variable "backup_retention_days" {
  description = "Automated backup retention in days."
  type        = number
  default     = 14
}

variable "backup_window" {
  description = "Daily backup window in UTC."
  type        = string
  default     = "02:00-03:00"
}

variable "maintenance_window" {
  description = "Weekly maintenance window in UTC."
  type        = string
  default     = "Mon:03:30-Mon:04:30"
}

variable "deletion_protection" {
  description = "Block terraform destroy and take a final snapshot. Leave true for production."
  type        = bool
  default     = true
}

variable "performance_insights_enabled" {
  description = "Enable RDS Performance Insights."
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ARN for storage encryption. null uses the AWS-managed RDS key."
  type        = string
  default     = null
}

variable "parameters" {
  description = "Extra DB parameter group settings, applied with pending-reboot."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
