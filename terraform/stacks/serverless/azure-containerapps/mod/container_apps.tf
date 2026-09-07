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
