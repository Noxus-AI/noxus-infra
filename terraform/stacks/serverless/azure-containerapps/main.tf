terraform {
  required_version = ">= 1.5.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

variable "location" {
  description = "The Azure region for all resources."
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
  description = "Use a user-assigned managed identity for ACR pulls and Key Vault secrets. Set false to use ACR admin credentials and inline container app secrets instead."
  type        = bool
  default     = true
}

variable "deployment_name" {
  description = "A prefix used for naming Azure resources."
  type        = string
  default     = "noxus"
}

variable "domain" {
  description = "Custom domain for URL construction. Leave empty to use the Container App Environment's default domain."
  type        = string
  default     = ""
}

variable "admin_email" {
  description = "Your admin email."
  type        = string
}

variable "whitelabel_logo" {
  description = "The URL or path to the whitelabel logo."
  type        = string
  default     = ""
}

variable "deployment_env" {
  description = "Deployment environment."
  type        = string
  default     = "prod"
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

variable "deploy_postgres" {
  description = "Whether to deploy a managed PostgreSQL Flexible Server."
  type        = bool
  default     = true
}

variable "postgresql_url" {
  description = "External PostgreSQL connection string in user:password@host:port form. Used when deploy_postgres is false."
  type        = string
  sensitive   = true
  default     = ""
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
  description = "max_connections on the PostgreSQL Flexible Server."
  type        = number
  default     = 500
}

variable "redis_capacity" {
  description = "Azure Cache for Redis capacity within the Premium family (1 = P1/6GB)."
  type        = number
  default     = 1
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
  description = "Tags applied to every resource created by this deployment."
  type        = map(string)
  default     = {}
}

module "deploy" {
  source = "./mod"

  location                 = var.location
  resource_group_name      = var.resource_group_name
  create_resource_group    = var.create_resource_group
  use_managed_identity     = var.use_managed_identity
  deployment_name          = var.deployment_name
  domain                   = var.domain
  admin_email              = var.admin_email
  whitelabel_logo          = var.whitelabel_logo
  deployment_env           = var.deployment_env
  vm_version               = var.vm_version
  docker_hub_username      = var.docker_hub_username
  docker_hub_token         = var.docker_hub_token
  auth0_domain             = var.auth0_domain
  auth0_api_audience       = var.auth0_api_audience
  auth0_client_id          = var.auth0_client_id
  auth0_client_secret      = var.auth0_client_secret
  auth0_mgmt_client_id     = var.auth0_mgmt_client_id
  auth0_mgmt_client_secret = var.auth0_mgmt_client_secret
  deploy_postgres          = var.deploy_postgres
  postgresql_url           = var.postgresql_url
  postgres_sku_name        = var.postgres_sku_name
  postgres_storage_mb      = var.postgres_storage_mb
  postgres_max_connections = var.postgres_max_connections
  redis_capacity           = var.redis_capacity
  backend_count            = var.backend_count
  frontend_count           = var.frontend_count
  worker_count             = var.worker_count
  relay_count              = var.relay_count
  vertex_project_id        = var.vertex_project_id
  firestore_project        = var.firestore_project
  tags                     = var.tags
}

output "backend_dns" {
  value       = module.deploy.backend_dns
  description = "FQDN of the backend container app"
}

output "frontend_dns" {
  value       = module.deploy.frontend_dns
  description = "FQDN of the frontend container app"
}

output "relay_dns" {
  value       = module.deploy.relay_dns
  description = "FQDN of the relay container app"
}

output "acr_login_server" {
  value       = module.deploy.acr_login_server
  description = "The ACR login server URL"
}

output "resource_group_name" {
  value       = module.deploy.resource_group_name
  description = "The name of the resource group holding the deployment"
}

output "storage_account_name" {
  value       = module.deploy.storage_account_name
  description = "Storage account backing SPOTFLOW_STORAGE_BUCKET"
}

output "postgres_fqdn" {
  value       = module.deploy.postgres_fqdn
  description = "FQDN of the managed PostgreSQL Flexible Server, if one was deployed"
}

output "postgres_admin_password" {
  value       = module.deploy.postgres_admin_password
  description = "Generated password for the PostgreSQL admin user"
  sensitive   = true
}
