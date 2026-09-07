# ==========================================================================
# Auto-generated flattened Terraform configuration — DO NOT EDIT.
# Source: terraform/stacks/serverless/azure-containerapps/mod/*.tf
# Regenerate with: python terraform/stacks/serverless/azure-containerapps/generate_tf.py
# ==========================================================================

# -------------------------- PROVIDER --------------------------
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

# -------------------------- VERSIONS (versions.tf) --------------------------
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

# -------------------------- MAIN (main.tf) --------------------------
data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "main" {
  count    = var.create_resource_group ? 1 : 0
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

data "azurerm_resource_group" "existing" {
  count = var.create_resource_group ? 0 : 1
  name  = var.resource_group_name
}

locals {
  resource_group_name = var.create_resource_group ? azurerm_resource_group.main[0].name : data.azurerm_resource_group.existing[0].name
  location            = var.create_resource_group ? azurerm_resource_group.main[0].location : data.azurerm_resource_group.existing[0].location
}

# -------------------------- VARIABLES (variables.tf) --------------------------
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

# -------------------------- NETWORK (network.tf) --------------------------
resource "azurerm_virtual_network" "main" {
  name                = "${var.deployment_name}-vnet"
  location            = local.location
  resource_group_name = local.resource_group_name
  address_space       = ["10.0.0.0/16"]
  tags                = var.tags
}

# Workload profile environments require a dedicated subnet of at least /27;
# /21 leaves room for the environment to scale out its infrastructure nodes.
resource "azurerm_subnet" "container_apps" {
  name                 = "${var.deployment_name}-container-apps-subnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.0.0/21"]

  delegation {
    name = "container-apps-delegation"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "postgres" {
  count                = var.deploy_postgres ? 1 : 0
  name                 = "${var.deployment_name}-postgres-subnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.8.0/24"]

  delegation {
    name = "postgres-delegation"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "redis" {
  name                 = "${var.deployment_name}-redis-subnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.9.0/24"]
}

resource "azurerm_private_dns_zone" "postgres" {
  count               = var.deploy_postgres ? 1 : 0
  name                = "${var.deployment_name}.postgres.database.azure.com"
  resource_group_name = local.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  count                 = var.deploy_postgres ? 1 : 0
  name                  = "${var.deployment_name}-postgres-dns-link"
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres[0].name
  virtual_network_id    = azurerm_virtual_network.main.id
  tags                  = var.tags
}

# -------------------------- IDENTITY (identity.tf) --------------------------
resource "azurerm_user_assigned_identity" "main" {
  count               = var.use_managed_identity ? 1 : 0
  name                = "${var.deployment_name}-identity"
  location            = local.location
  resource_group_name = local.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  count                = var.use_managed_identity ? 1 : 0
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.main[0].principal_id
}

resource "azurerm_role_assignment" "keyvault_secrets_user" {
  count                = var.use_managed_identity ? 1 : 0
  scope                = azurerm_key_vault.main[0].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.main[0].principal_id
}

resource "azurerm_role_assignment" "storage_blob_contributor" {
  count                = var.use_managed_identity ? 1 : 0
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.main[0].principal_id
}

locals {
  # one() yields null when the identity is disabled, avoiding an index into a
  # zero-instance resource.
  identity_id = one(azurerm_user_assigned_identity.main[*].id)
}

# -------------------------- ACR (acr.tf) --------------------------
resource "azurerm_container_registry" "acr" {
  name                = replace("${var.deployment_name}acr", "-", "")
  location            = local.location
  resource_group_name = local.resource_group_name
  sku                 = "Standard"
  # Admin credentials are only needed when the container apps authenticate to
  # ACR with a username/password instead of the managed identity.
  admin_enabled = !var.use_managed_identity
  tags          = var.tags
}

locals {
  acr_images = {
    backend  = "noxusai/noxus-backend:${var.vm_version}"
    frontend = "noxusai/noxus-frontend:${var.vm_version}"
    worker   = "noxusai/noxus-worker:${var.vm_version}"
    relay    = "noxusai/noxus-relays:${var.vm_version}"
  }
}

# Container Apps cannot pull from Docker Hub with a rate limit low enough to
# survive a scale-out, so every image is mirrored into ACR first. Replacing this
# resource (which a vm_version change does) re-runs the import.
resource "terraform_data" "acr_import" {
  for_each = local.acr_images

  input = each.value

  provisioner "local-exec" {
    environment = {
      DOCKER_HUB_USERNAME = var.docker_hub_username
      DOCKER_HUB_TOKEN    = var.docker_hub_token
    }
    command = <<-EOT
      set -euo pipefail
      echo "Importing ${each.value} into ${azurerm_container_registry.acr.name}..."
      az acr import \
        --name ${azurerm_container_registry.acr.name} \
        --source docker.io/${each.value} \
        --image ${each.value} \
        --username "$DOCKER_HUB_USERNAME" \
        --password "$DOCKER_HUB_TOKEN" \
        --only-show-errors \
        --force
      echo "Imported ${each.value}"
    EOT
  }
}

# -------------------------- POSTGRES (postgres.tf) --------------------------
resource "random_password" "postgres_root_password" {
  length = 32
  # POSTGRESQL_URL is parsed as user:password@host:port, so keep the password
  # free of characters that would need escaping there.
  special = false
  upper   = true
  lower   = true
  numeric = true
}

resource "azurerm_postgresql_flexible_server" "main" {
  count               = var.deploy_postgres ? 1 : 0
  name                = "${var.deployment_name}-postgres"
  location            = local.location
  resource_group_name = local.resource_group_name

  # Matches the pgvector/pgvector:pg15 image the platform is developed against.
  version                       = "15"
  administrator_login           = "postgres"
  administrator_password        = random_password.postgres_root_password.result
  delegated_subnet_id           = azurerm_subnet.postgres[0].id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres[0].id
  public_network_access_enabled = false

  sku_name              = var.postgres_sku_name
  storage_mb            = var.postgres_storage_mb
  auto_grow_enabled     = true
  backup_retention_days = var.postgres_backup_retention_days

  zone = "1"

  lifecycle {
    ignore_changes = [zone]
  }

  tags = var.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres[0]]
}

resource "azurerm_postgresql_flexible_server_configuration" "max_connections" {
  count     = var.deploy_postgres ? 1 : 0
  name      = "max_connections"
  server_id = azurerm_postgresql_flexible_server.main[0].id
  value     = tostring(var.postgres_max_connections)
}

# Knowledge bases store embeddings in pgvector, and Flexible Server refuses
# CREATE EXTENSION for anything outside this allowlist.
resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  count     = var.deploy_postgres ? 1 : 0
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.main[0].id
  value     = "vector,uuid-ossp,pg_trgm"
}

# The platform builds asyncpg URLs with no ssl argument, and asyncpg does not
# negotiate TLS on its own, so Flexible Server's default require_secure_transport
# would reject every async connection. Safe here because the server has no public
# endpoint and is only reachable from the delegated VNet subnet.
resource "azurerm_postgresql_flexible_server_configuration" "require_secure_transport" {
  count     = var.deploy_postgres ? 1 : 0
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.main[0].id
  value     = "OFF"
}

# The backend entrypoint creates spot, vectors and procrastinate on first boot;
# this just makes the primary database exist before anything connects.
resource "azurerm_postgresql_flexible_server_database" "spot" {
  count     = var.deploy_postgres ? 1 : 0
  name      = "spot"
  server_id = azurerm_postgresql_flexible_server.main[0].id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

locals {
  postgres_url = var.deploy_postgres ? "postgres:${random_password.postgres_root_password.result}@${azurerm_postgresql_flexible_server.main[0].fqdn}:5432" : var.postgresql_url
}

# -------------------------- REDIS (redis.tf) --------------------------
resource "azurerm_redis_cache" "main" {
  name                          = "${var.deployment_name}-redis"
  location                      = local.location
  resource_group_name           = local.resource_group_name
  capacity                      = var.redis_capacity
  family                        = "P"
  sku_name                      = "Premium"
  non_ssl_port_enabled          = false
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false

  subnet_id = azurerm_subnet.redis.id

  redis_configuration {
    maxmemory_policy = "allkeys-lru"
  }

  tags = var.tags
}

# -------------------------- STORAGE (storage.tf) --------------------------
resource "random_id" "storage" {
  byte_length = 4
}

locals {
  # Storage account names are 3-24 lowercase alphanumerics with no hyphens.
  storage_account_name = "${substr(replace(lower(var.deployment_name), "-", ""), 0, 14)}sa${random_id.storage.hex}"
}

resource "azurerm_storage_account" "main" {
  name                            = local.storage_account_name
  location                        = local.location
  resource_group_name             = local.resource_group_name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  tags                            = var.tags
}

# AzureBlobStorageClient hardcodes the container name and derives the account
# host from SPOTFLOW_STORAGE_BUCKET, so this name is not free-form.
resource "azurerm_storage_container" "noxus" {
  name                  = "noxus"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

# -------------------------- SECRETS (secrets.tf) --------------------------
resource "random_password" "auth0_secret" {
  length  = 32
  special = false
  upper   = false
  lower   = true
  numeric = true
}

locals {
  # The only secrets that may legitimately be unset. Both come from variables,
  # which keeps the key set of secret_env known at plan time — deriving it from
  # a value that is only known after apply (a Redis key, a generated password)
  # would make secret_env unusable as a for_each argument.
  optional_secret_env = {
    AUTH0_CLIENT_SECRET      = var.auth0_client_secret
    AUTH0_MGMT_CLIENT_SECRET = var.auth0_mgmt_client_secret
  }

  unset_secret_env = [
    for name, value in local.optional_secret_env : name
    if nonsensitive(sensitive(value)) == ""
  ]

  # Env var name -> Key Vault / container app secret name. Names only: Terraform
  # refuses sensitive values in for_each, so the values are looked up out of
  # secret_values at the point of use.
  secret_env = {
    for name in [
      "POSTGRESQL_URL",
      "VECTOR_POSTGRESQL_URL",
      "REDIS_PASSWORD",
      "AZURE_STORAGE_ACCOUNT_KEY",
      "AUTH0_SECRET",
      "AUTH0_CLIENT_SECRET",
      "AUTH0_MGMT_CLIENT_SECRET",
    ] : name => lower(replace(name, "_", "-"))
    if !contains(local.unset_secret_env, name)
  }

  secret_values = {
    POSTGRESQL_URL            = local.postgres_url
    VECTOR_POSTGRESQL_URL     = local.postgres_url
    REDIS_PASSWORD            = azurerm_redis_cache.main.primary_access_key
    AZURE_STORAGE_ACCOUNT_KEY = azurerm_storage_account.main.primary_access_key
    AUTH0_SECRET              = random_password.auth0_secret.result
    AUTH0_CLIENT_SECRET       = var.auth0_client_secret
    AUTH0_MGMT_CLIENT_SECRET  = var.auth0_mgmt_client_secret
  }

  registry_config = var.use_managed_identity ? {
    identity             = local.identity_id
    username             = null
    password_secret_name = null
    } : {
    identity             = null
    username             = azurerm_container_registry.acr.admin_username
    password_secret_name = "acr-password"
  }
}

# POSTGRESQL_URL is required; an empty one would leave every service unable to
# reach a database.
check "postgres_connection_configured" {
  assert {
    condition     = var.deploy_postgres || var.postgresql_url != ""
    error_message = "Set postgresql_url when deploy_postgres is false."
  }
}

# -------------------------- KEYVAULT (keyvault.tf) --------------------------
locals {
  # Key Vault names are capped at 24 characters and cannot contain consecutive
  # or trailing hyphens.
  key_vault_name = "${trimsuffix(substr(var.deployment_name, 0, 20), "-")}-kv"
}

resource "azurerm_key_vault" "main" {
  count                      = var.use_managed_identity ? 1 : 0
  name                       = local.key_vault_name
  location                   = local.location
  resource_group_name        = local.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = false
  soft_delete_retention_days = 7
  tags                       = var.tags
}

resource "azurerm_role_assignment" "keyvault_admin" {
  count                = var.use_managed_identity ? 1 : 0
  scope                = azurerm_key_vault.main[0].id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_secret" "app" {
  for_each = var.use_managed_identity ? local.secret_env : {}

  name         = each.value
  value        = local.secret_values[each.key]
  key_vault_id = azurerm_key_vault.main[0].id

  depends_on = [azurerm_role_assignment.keyvault_admin]
}

locals {
  key_vault_secret_ids = { for k, v in azurerm_key_vault_secret.app : k => v.id }
}

# -------------------------- CONTAINER APPS (container_apps.tf) --------------------------
# ---------------------- Log Analytics + Environment ----------------------

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.deployment_name}-logs"
  location            = local.location
  resource_group_name = local.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_container_app_environment" "main" {
  name                       = "${var.deployment_name}-env"
  location                   = local.location
  resource_group_name        = local.resource_group_name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  infrastructure_subnet_id = azurerm_subnet.container_apps.id

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  workload_profile {
    name                  = "dedicated-d4"
    workload_profile_type = "D4"
    minimum_count         = 0
    maximum_count         = 3
  }

  tags = var.tags
}

# ---------------------- Shared locals ----------------------

locals {
  acr_server     = azurerm_container_registry.acr.login_server
  default_domain = azurerm_container_app_environment.main.default_domain

  # The environment's default hostnames serve traffic immediately. A custom
  # domain has to be bound and DNS-validated outside this config, so only build
  # URLs from it once one is supplied.
  frontend_url = var.domain != "" ? "https://${var.domain}" : "https://frontend.${local.default_domain}"
  backend_url  = var.domain != "" ? "https://api.${var.domain}" : "https://backend.${local.default_domain}"
  relay_url    = var.domain != "" ? "https://relay.${var.domain}" : "https://relay.${local.default_domain}"

  env_vars = {
    "ADMIN_EMAIL"                     = var.admin_email
    "APP_BASE_URL"                    = local.frontend_url
    "AUTH0_API_AUDIENCE"              = var.auth0_api_audience
    "AUTH0_BASE_URL"                  = local.frontend_url
    "AUTH0_CLIENT_ID"                 = var.auth0_client_id
    "AUTH0_DOMAIN"                    = var.auth0_domain
    "AUTH0_ISSUER_BASE_URL"           = "https://${var.auth0_domain}"
    "AUTH0_MGMT_CLIENT_ID"            = var.auth0_mgmt_client_id
    "BACKEND_URL"                     = local.backend_url
    "BILLING_ENABLED"                 = "false"
    "BUCKET_CLIENT"                   = "azure"
    "DEPLOYMENT_ENV"                  = var.deployment_env
    "FIRESTORE_PROJECT"               = var.firestore_project
    "FRONTEND_URL"                    = local.frontend_url
    "IS_PROD"                         = "true"
    "NOLLM_CONFIG_PATH"               = "/code/configs"
    "ON_PREM"                         = "true"
    "PLATFORM_HEALTH_RELAY_ENABLED"   = "true"
    "PLATFORM_HEALTH_SANDBOX_ENABLED" = "false"
    "REDIS_PORT"                      = tostring(azurerm_redis_cache.main.ssl_port)
    "REDIS_SSL"                       = "true"
    "REDIS_URL"                       = azurerm_redis_cache.main.hostname
    "RELAY_URL"                       = local.relay_url
    "SECRETS_SOURCE"                  = "db"
    "SPOTFLOW_PUBLIC_STORAGE_BUCKET"  = azurerm_storage_account.main.name
    "SPOTFLOW_STORAGE_BUCKET"         = azurerm_storage_account.main.name
    "VERSION"                         = var.vm_version
    "VERTEX_PROJECT_ID"               = var.vertex_project_id
    "WHITELABEL_LOGO"                 = var.whitelabel_logo
  }

  # Only the backend entrypoint runs migrations and the first-boot bootstrap.
  backend_env_vars = merge(local.env_vars, {
    "RUN_MIGRATIONS" = "1"
    "RUN_BOOTSTRAP"  = "1"
  })

}

# ---------------------- BACKEND ----------------------

resource "azurerm_container_app" "backend" {
  name                         = "backend"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = local.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = var.tags

  dynamic "identity" {
    for_each = var.use_managed_identity ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = [local.identity_id]
    }
  }

  registry {
    server               = local.acr_server
    identity             = local.registry_config.identity
    username             = local.registry_config.username
    password_secret_name = local.registry_config.password_secret_name
  }

  dynamic "secret" {
    for_each = local.secret_env
    content {
      name                = secret.value
      value               = var.use_managed_identity ? null : local.secret_values[secret.key]
      key_vault_secret_id = lookup(local.key_vault_secret_ids, secret.key, null)
      identity            = local.identity_id
    }
  }

  dynamic "secret" {
    for_each = var.use_managed_identity ? [] : ["acr-password"]
    content {
      name  = secret.value
      value = azurerm_container_registry.acr.admin_password
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    transport        = "auto"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.backend_count
    max_replicas = var.backend_count

    container {
      # Consumption profiles only accept memory equal to 2Gi per core.
      name   = "backend"
      image  = "${local.acr_server}/${local.acr_images["backend"]}"
      cpu    = 2
      memory = "4Gi"

      dynamic "env" {
        for_each = local.backend_env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.secret_env
        content {
          name        = env.key
          secret_name = env.value
        }
      }

      startup_probe {
        port                    = 8080
        transport               = "TCP"
        initial_delay           = 10
        interval_seconds        = 10
        timeout                 = 5
        failure_count_threshold = 30
      }

      liveness_probe {
        path                    = "/status/health"
        port                    = 8080
        transport               = "HTTP"
        initial_delay           = 30
        interval_seconds        = 20
        timeout                 = 10
        failure_count_threshold = 5
      }

      readiness_probe {
        path                    = "/status/health"
        port                    = 8080
        transport               = "HTTP"
        initial_delay           = 10
        interval_seconds        = 10
        timeout                 = 5
        failure_count_threshold = 3
      }
    }
  }

  depends_on = [
    azurerm_redis_cache.main,
    azurerm_postgresql_flexible_server.main,
    azurerm_role_assignment.acr_pull,
    azurerm_role_assignment.keyvault_secrets_user,
    azurerm_key_vault_secret.app,
    terraform_data.acr_import,
  ]
}

# ---------------------- FRONTEND ----------------------

resource "azurerm_container_app" "frontend" {
  name                         = "frontend"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = local.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = var.tags

  dynamic "identity" {
    for_each = var.use_managed_identity ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = [local.identity_id]
    }
  }

  registry {
    server               = local.acr_server
    identity             = local.registry_config.identity
    username             = local.registry_config.username
    password_secret_name = local.registry_config.password_secret_name
  }

  dynamic "secret" {
    for_each = local.secret_env
    content {
      name                = secret.value
      value               = var.use_managed_identity ? null : local.secret_values[secret.key]
      key_vault_secret_id = lookup(local.key_vault_secret_ids, secret.key, null)
      identity            = local.identity_id
    }
  }

  dynamic "secret" {
    for_each = var.use_managed_identity ? [] : ["acr-password"]
    content {
      name  = secret.value
      value = azurerm_container_registry.acr.admin_password
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    transport        = "auto"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.frontend_count
    max_replicas = var.frontend_count

    container {
      name   = "frontend"
      image  = "${local.acr_server}/${local.acr_images["frontend"]}"
      cpu    = 2
      memory = "4Gi"

      dynamic "env" {
        for_each = local.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.secret_env
        content {
          name        = env.key
          secret_name = env.value
        }
      }

      startup_probe {
        port                    = 8080
        transport               = "TCP"
        initial_delay           = 10
        interval_seconds        = 10
        timeout                 = 5
        failure_count_threshold = 30
      }

      # Next.js serves no dedicated health route, so the platform probes the port.
      liveness_probe {
        port                    = 8080
        transport               = "TCP"
        initial_delay           = 30
        interval_seconds        = 20
        timeout                 = 10
        failure_count_threshold = 5
      }

      readiness_probe {
        port                    = 8080
        transport               = "TCP"
        initial_delay           = 10
        interval_seconds        = 10
        timeout                 = 5
        failure_count_threshold = 3
      }
    }
  }

  depends_on = [
    azurerm_redis_cache.main,
    azurerm_postgresql_flexible_server.main,
    azurerm_role_assignment.acr_pull,
    azurerm_role_assignment.keyvault_secrets_user,
    azurerm_key_vault_secret.app,
    terraform_data.acr_import,
  ]
}

# ---------------------- WORKER ----------------------

resource "azurerm_container_app" "worker" {
  name                         = "worker"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = local.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = "dedicated-d4"
  tags                         = var.tags

  dynamic "identity" {
    for_each = var.use_managed_identity ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = [local.identity_id]
    }
  }

  registry {
    server               = local.acr_server
    identity             = local.registry_config.identity
    username             = local.registry_config.username
    password_secret_name = local.registry_config.password_secret_name
  }

  dynamic "secret" {
    for_each = local.secret_env
    content {
      name                = secret.value
      value               = var.use_managed_identity ? null : local.secret_values[secret.key]
      key_vault_secret_id = lookup(local.key_vault_secret_ids, secret.key, null)
      identity            = local.identity_id
    }
  }

  dynamic "secret" {
    for_each = var.use_managed_identity ? [] : ["acr-password"]
    content {
      name  = secret.value
      value = azurerm_container_registry.acr.admin_password
    }
  }

  ingress {
    external_enabled = false
    target_port      = 8080
    transport        = "auto"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.worker_count
    max_replicas = var.worker_count

    container {
      # A D4 node is 4 vCPU / 16 GiB, part of which the Container Apps runtime
      # reserves, so a replica asking for the full node never gets scheduled.
      name   = "worker"
      image  = "${local.acr_server}/${local.acr_images["worker"]}"
      cpu    = 3.5
      memory = "14Gi"

      dynamic "env" {
        for_each = local.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.secret_env
        content {
          name        = env.key
          secret_name = env.value
        }
      }

      startup_probe {
        port                    = 8080
        transport               = "TCP"
        initial_delay           = 10
        interval_seconds        = 10
        timeout                 = 5
        failure_count_threshold = 30
      }

      liveness_probe {
        path                    = "/status/health"
        port                    = 8080
        transport               = "HTTP"
        initial_delay           = 30
        interval_seconds        = 20
        timeout                 = 10
        failure_count_threshold = 5
      }

      readiness_probe {
        path                    = "/status/health"
        port                    = 8080
        transport               = "HTTP"
        initial_delay           = 10
        interval_seconds        = 10
        timeout                 = 5
        failure_count_threshold = 3
      }
    }
  }

  depends_on = [azurerm_container_app.backend]
}

# ---------------------- RELAY ----------------------

resource "azurerm_container_app" "relay" {
  name                         = "relay"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = local.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = var.tags

  dynamic "identity" {
    for_each = var.use_managed_identity ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = [local.identity_id]
    }
  }

  registry {
    server               = local.acr_server
    identity             = local.registry_config.identity
    username             = local.registry_config.username
    password_secret_name = local.registry_config.password_secret_name
  }

  dynamic "secret" {
    for_each = local.secret_env
    content {
      name                = secret.value
      value               = var.use_managed_identity ? null : local.secret_values[secret.key]
      key_vault_secret_id = lookup(local.key_vault_secret_ids, secret.key, null)
      identity            = local.identity_id
    }
  }

  dynamic "secret" {
    for_each = var.use_managed_identity ? [] : ["acr-password"]
    content {
      name  = secret.value
      value = azurerm_container_registry.acr.admin_password
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    transport        = "auto"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.relay_count
    max_replicas = var.relay_count

    container {
      name   = "relay"
      image  = "${local.acr_server}/${local.acr_images["relay"]}"
      cpu    = 2
      memory = "4Gi"

      dynamic "env" {
        for_each = local.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.secret_env
        content {
          name        = env.key
          secret_name = env.value
        }
      }

      startup_probe {
        port                    = 8080
        transport               = "TCP"
        initial_delay           = 10
        interval_seconds        = 10
        timeout                 = 5
        failure_count_threshold = 30
      }

      liveness_probe {
        path                    = "/status/health"
        port                    = 8080
        transport               = "HTTP"
        initial_delay           = 30
        interval_seconds        = 20
        timeout                 = 10
        failure_count_threshold = 5
      }

      readiness_probe {
        path                    = "/status/health"
        port                    = 8080
        transport               = "HTTP"
        initial_delay           = 10
        interval_seconds        = 10
        timeout                 = 5
        failure_count_threshold = 3
      }
    }
  }

  depends_on = [azurerm_container_app.backend]
}

# -------------------------- OUTPUTS (outputs.tf) --------------------------
output "backend_dns" {
  value       = azurerm_container_app.backend.ingress[0].fqdn
  description = "FQDN of the backend container app (map api.<domain> here)"
}

output "frontend_dns" {
  value       = azurerm_container_app.frontend.ingress[0].fqdn
  description = "FQDN of the frontend container app (map <domain> here)"
}

output "relay_dns" {
  value       = azurerm_container_app.relay.ingress[0].fqdn
  description = "FQDN of the relay container app (map relay.<domain> here)"
}

output "acr_login_server" {
  value       = azurerm_container_registry.acr.login_server
  description = "The ACR login server URL"
}

output "resource_group_name" {
  value       = local.resource_group_name
  description = "The name of the resource group holding the deployment"
}

output "storage_account_name" {
  value       = azurerm_storage_account.main.name
  description = "Storage account backing SPOTFLOW_STORAGE_BUCKET"
}

output "postgres_fqdn" {
  value       = var.deploy_postgres ? azurerm_postgresql_flexible_server.main[0].fqdn : null
  description = "FQDN of the managed PostgreSQL Flexible Server, if one was deployed"
}

output "postgres_admin_password" {
  value       = var.deploy_postgres ? random_password.postgres_root_password.result : null
  description = "Generated password for the PostgreSQL admin user"
  sensitive   = true
}

