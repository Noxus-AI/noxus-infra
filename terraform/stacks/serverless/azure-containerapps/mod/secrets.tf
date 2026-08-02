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
