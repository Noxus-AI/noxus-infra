variable "project_name" {
  description = "Short project identifier, e.g. \"noxus\". Combined with environment to prefix every resource."
  type        = string
  default     = "noxus"
}

variable "environment" {
  description = "Environment name. \"prod\" turns on Multi-AZ Postgres, Redis replication, and deletion protection."
  type        = string
  default     = "prod"
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-west-1"
}

variable "domain" {
  description = "Apex domain the platform is served from. The chart derives api.<domain> and relay.<domain> from it."
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for the domain. Empty looks it up by route53_zone_name."
  type        = string
  default     = ""
}

variable "route53_zone_name" {
  description = "Hosted zone name, used when route53_zone_id is empty."
  type        = string
  default     = ""
}

variable "admin_email" {
  description = "Email of the first admin user, created during bootstrap."
  type        = string
}

variable "app_version" {
  description = "Platform version, selecting the container image tags."
  type        = string
}

variable "auth0" {
  description = "Auth0 tenant configuration."
  type = object({
    domain             = string
    api_audience       = string
    client_id          = string
    client_secret      = string
    session_secret     = optional(string)
    mgmt_client_id     = optional(string, "")
    mgmt_client_secret = optional(string, "")
  })
  sensitive = true
}

# --- Networking -----------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Availability zones to span."
  type        = number
  default     = 3
}

# --- Cluster --------------------------------------------------------------

variable "kubernetes_version" {
  description = "EKS control plane version."
  type        = string
  default     = "1.31"
}

variable "eks_auto_mode" {
  description = "Use EKS Auto Mode. Set false to manage node groups yourself via eks_managed_node_groups."
  type        = bool
  default     = true
}

variable "eks_managed_node_groups" {
  description = "Managed node group definitions, used when eks_auto_mode is false."
  type        = any
  default = {
    general = {
      instance_types = ["m6a.xlarge"]
      min_size       = 2
      max_size       = 10
      desired_size   = 3
    }
  }
}

variable "cluster_endpoint_public_access" {
  description = "Expose the Kubernetes API publicly. Terraform needs to reach it to install the Helm release, so disabling this requires running from inside the VPC."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. Narrow this from the default."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_admin_principal_arns" {
  description = "IAM roles or users granted cluster-admin, e.g. your SSO permission-set role and CI deploy role."
  type        = list(string)
  default     = []
}

variable "grant_creator_admin" {
  description = "Also grant cluster-admin to whoever runs apply. Useful for a first bootstrap only."
  type        = bool
  default     = true
}

# --- Data stores ----------------------------------------------------------

variable "postgres_engine_version" {
  description = "RDS PostgreSQL version. 15.2 or newer, for pgvector."
  type        = string
  default     = "16.4"
}

variable "postgres_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.m6g.large"
}

variable "postgres_allocated_storage" {
  description = "Initial RDS storage in GiB."
  type        = number
  default     = 100
}

variable "postgres_backup_retention_days" {
  description = "RDS automated backup retention."
  type        = number
  default     = 14
}

variable "redis_node_type" {
  description = "ElastiCache node type."
  type        = string
  default     = "cache.m7g.large"
}

# --- Platform -------------------------------------------------------------

variable "release_name" {
  description = "Helm release name."
  type        = string
  default     = "noxus"
}

variable "namespace" {
  description = "Namespace to install the platform into."
  type        = string
  default     = "noxus"
}

variable "pgbouncer_enabled" {
  description = "Deploy PgBouncer in front of RDS."
  type        = bool
  default     = true
}

variable "sandbox_enabled" {
  description = "Deploy the agent sandbox. Required for plugins."
  type        = bool
  default     = true
}

variable "enable_bedrock" {
  description = "Grant the platform pods Bedrock invoke permissions."
  type        = bool
  default     = false
}

variable "extra_env" {
  description = "Additional non-sensitive env vars for the platform."
  type        = map(string)
  default     = {}
}

variable "extra_secrets" {
  description = "Additional secret env vars for the platform."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "extra_values" {
  description = "Raw Helm values documents layered over the computed set — worker pools, resource sizing, geo regions."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Extra tags merged into the standard set."
  type        = map(string)
  default     = {}
}
