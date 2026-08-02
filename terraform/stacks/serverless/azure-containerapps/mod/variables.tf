variable "location" {
  description = "The Azure region for all resources. Ignored when create_resource_group is false (the existing group's location is used)."
  type        = string
  default     = "westeurope"
}

variable "resource_group_name" {
  description = "Resource group to create (create_resource_group = true) or to deploy into (false)."
  type        = string
  default     = "noxus-rg"
}

variable "create_resource_group" {
  description = "Create the resource group. Set false to deploy into a group managed outside this config."
  type        = bool
  default     = true
}

variable "use_managed_identity" {
  description = <<-EOT
    Authenticate to ACR and read secrets from Key Vault with a user-assigned
    managed identity. Requires permission to create role assignments. Set false
    to fall back to ACR admin credentials and inline container app secrets.
  EOT
  type        = bool
  default     = true
}

variable "deployment_name" {
  description = "A prefix used for naming Azure resources. Lowercase alphanumerics and hyphens only."
  type        = string
  default     = "noxus"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,20}[a-z0-9]$", var.deployment_name))
    error_message = "deployment_name must be 2-22 lowercase alphanumerics or hyphens and cannot start or end with a hyphen (Key Vault and storage account names are derived from it)."
  }
}

variable "domain" {
  description = <<-EOT
    Custom domain used to build BACKEND_URL / FRONTEND_URL / RELAY_URL. Leave
    empty to use the Container App Environment's default domain, which works
    without any DNS setup. Binding the domain itself is done outside this config.
  EOT
  type        = string
  default     = ""
}

variable "admin_email" {
  description = "Admin email. Also gates the first-boot bootstrap in the backend entrypoint."
  type        = string
}

variable "auth0_domain" {
  description = "Your Auth0 domain."
  type        = string
  default     = "noxus-oncloud.eu.auth0.com"
}

variable "auth0_api_audience" {
  description = "The Auth0 API audience identifier."
  type        = string
  default     = "https://oncloud.noxus.ai"
}

variable "auth0_client_id" {
  description = "The Auth0 application client ID. No default — supply your own tenant's application."
  type        = string
}

variable "auth0_client_secret" {
  description = "The Auth0 application client secret. No default — supply your own tenant's application."
  type        = string
  sensitive   = true
}

variable "auth0_mgmt_client_id" {
  description = "Client ID of the Auth0 machine-to-machine application used for the Management API."
  type        = string
  default     = ""
}

variable "auth0_mgmt_client_secret" {
  description = "Client secret of the Auth0 machine-to-machine application used for the Management API."
  type        = string
  sensitive   = true
  default     = ""
}

variable "deployment_env" {
  description = "The deployment environment."
  type        = string
  default     = "prod"
}

variable "whitelabel_logo" {
  description = "The URL or path to the whitelabel logo."
  type        = string
  default     = ""
}

variable "postgresql_url" {
  description = "External PostgreSQL connection string in user:password@host:port form (no scheme, no database). Used when deploy_postgres is false."
  type        = string
  sensitive   = true
  default     = ""
}

variable "deploy_postgres" {
  description = "Whether to deploy a managed PostgreSQL Flexible Server."
  type        = bool
  default     = true
}

variable "postgres_sku_name" {
  description = "SKU of the PostgreSQL Flexible Server."
  type        = string
  default     = "GP_Standard_D2s_v3"
}

variable "postgres_storage_mb" {
  description = "Storage allocated to the PostgreSQL Flexible Server, in MB."
  type        = number
  default     = 131072
}

variable "postgres_max_connections" {
  description = "max_connections on the PostgreSQL Flexible Server. The allowed ceiling scales with the SKU; 500 fits GP_Standard_D2s_v3."
  type        = number
  default     = 500
}

variable "postgres_backup_retention_days" {
  description = "Point-in-time restore window for the PostgreSQL Flexible Server, in days."
  type        = number
  default     = 14
}

variable "redis_capacity" {
  description = "Azure Cache for Redis capacity within the Premium family (1 = P1/6GB, 2 = P2/13GB, ...)."
  type        = number
  default     = 1
}

variable "vm_version" {
  description = "The image tag for the noxusai/noxus-* container images."
  type        = string
}

variable "docker_hub_username" {
  description = "Docker Hub username used to import images into ACR."
  type        = string
  default     = "noxusai"
}

variable "docker_hub_token" {
  type        = string
  sensitive   = true
  description = "Docker Hub token used to import images into ACR."
}

variable "backend_count" {
  type    = number
  default = 1
}

variable "frontend_count" {
  type    = number
  default = 1
}

variable "worker_count" {
  type    = number
  default = 1
}

variable "relay_count" {
  type    = number
  default = 1
}

variable "vertex_project_id" {
  description = "GCP Vertex AI project ID, for tenants using Vertex-hosted models."
  type        = string
  default     = ""
}

variable "firestore_project" {
  description = "GCP Firestore project ID, for tenants using Firestore-backed features."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to every resource created by this module."
  type        = map(string)
  default     = {}
}
