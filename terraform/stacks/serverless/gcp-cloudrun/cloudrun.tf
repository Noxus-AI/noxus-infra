locals {
  platform_env = merge(
    {
      DEPLOYMENT_ENV  = var.deployment_env
      ON_PREM         = "true"
      IS_PROD         = "true"
      BILLING_ENABLED = "false"
      # Model and integration API keys are entered in the admin UI and kept in
      # the database. The default, "file", expects a vault file the images do
      # not contain.
      SECRETS_SOURCE = "db"
      ADMIN_EMAIL    = var.admin_email

      FRONTEND_URL = local.public_url
      # The address the browser follows, OAuth callbacks included.
      BACKEND_URL = local.backend_public_url
      # Base of every webhook URL handed to Slack, Teams, Telegram and the rest.
      RELAY_URL = local.relay_public_url
      # BACKEND_URL goes through the frontend's authenticated proxy, which
      # rejects the API keys MCP clients send, so agents reach the Noxus MCP
      # server on the backend directly.
      MCP_SERVER_URL = "${local.internal_url.backend}/mcp/"

      AUTH0_DOMAIN          = var.auth0_domain
      AUTH0_ISSUER_BASE_URL = "https://${var.auth0_domain}"
      AUTH0_API_AUDIENCE    = var.auth0_api_audience
      AUTH0_CLIENT_ID       = var.auth0_client_id
      AUTH0_MGMT_CLIENT_ID  = var.auth0_mgmt_client_id
      AUTH0_BASE_URL        = local.public_url
      APP_BASE_URL          = local.public_url

      # Host only: the platform adds the scheme and port.
      REDIS_URL = google_redis_instance.main.host

      BUCKET_CLIENT                  = "gcloud"
      SPOTFLOW_STORAGE_BUCKET        = google_storage_bucket.platform.name
      SPOTFLOW_PUBLIC_STORAGE_BUCKET = google_storage_bucket.platform.name

      VERTEX_PROJECT_ID = var.project_id
    },
    var.deploy_sandbox ? {
      SANDBOX_MANAGER_URL = local.internal_url.sandbox
      USE_REMOTE_SANDBOX  = "true"
      } : {
      PLATFORM_HEALTH_SANDBOX_ENABLED = "false"
    },
    var.whitelabel_logo != "" ? { WHITELABEL_LOGO = var.whitelabel_logo } : {},
    var.extra_env,
  )

  backend_env = merge(local.platform_env, {
    RUN_MIGRATIONS = "1"
    RUN_BOOTSTRAP  = "1"
    # The in-process MCP tools call back into this same backend with local API
    # keys, which only the loopback address accepts.
    NOXUS_BACKEND_URL = "http://localhost:8080"
  })

  # The frontend's server side proxies to the backend and the relay, so it gets
  # their direct addresses. It still needs the rest of the plain configuration:
  # it serves ON_PREM, FRONTEND_URL and whether plugins exist
  # (SANDBOX_MANAGER_URL) to the browser.
  frontend_env = merge(local.platform_env, {
    BACKEND_URL = local.internal_url.backend
    RELAY_URL   = local.internal_url.relay
  })

  # The sandbox runs untrusted code, so it gets only what it needs: its bucket
  # for persistent sandbox state and its own settings.
  sandbox_env = var.deploy_sandbox ? {
    DEPLOYMENT_ENV                 = var.deployment_env
    SECRETS_SOURCE                 = "env"
    SANDBOX_PROVIDER               = var.sandbox_provider
    BUCKET_CLIENT                  = "gcloud"
    SPOTFLOW_STORAGE_BUCKET        = google_storage_bucket.sandbox[0].name
    SPOTFLOW_PUBLIC_STORAGE_BUCKET = google_storage_bucket.sandbox[0].name
    # Instances are ephemeral: without FS sync every persistent sandbox (agent
    # workspaces, installed plugins) is lost on restart.
    SANDBOX_FS_ENABLED       = "true"
    SANDBOX_FS_PREFIX        = "sandboxes"
    SANDBOX_FS_SYNC_INTERVAL = "300"
    # The manager hands callers WebSocket URLs (plugin workers, MCP bridges)
    # built from this. The default is localhost.
    EXTERNAL_BASE_URL = local.internal_url.sandbox
  } : {}
}

# Every service has invoker IAM disabled instead of granting run.invoker to
# allUsers: ingress settings are the network boundary, the platform does its
# own authentication, and many organisations forbid allUsers bindings.

# ---------------------------------------------------------------- backend ---

resource "google_cloud_run_v2_service" "backend" {
  name                 = local.services.backend
  location             = var.region
  ingress              = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  invoker_iam_disabled = true
  deletion_protection  = false

  template {
    service_account       = google_service_account.platform.email
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    # Agent responses stream over long-lived requests.
    timeout                          = "3600s"
    max_instance_request_concurrency = 250

    scaling {
      min_instance_count = var.backend.instances
      max_instance_count = var.backend.instances
    }

    vpc_access {
      egress = "ALL_TRAFFIC"
      network_interfaces {
        network    = local.network_id
        subnetwork = local.subnetwork_id
      }
    }

    containers {
      image = "${local.image_prefix}/noxus-backend:${var.noxus_version}"

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = var.backend.cpu
          memory = var.backend.memory
        }
        startup_cpu_boost = true
      }

      # Boot runs migrations before the API listens. The first boot applies
      # the whole schema, so allow it 15 minutes.
      startup_probe {
        initial_delay_seconds = 30
        period_seconds        = 30
        timeout_seconds       = 10
        failure_threshold     = 30
        http_get {
          path = "/status/health"
          port = 8080
        }
      }

      liveness_probe {
        period_seconds    = 30
        timeout_seconds   = 10
        failure_threshold = 10
        http_get {
          path = "/status/health"
          port = 8080
        }
      }

      dynamic "env" {
        for_each = local.backend_env
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.platform_secret_env
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.platform[env.value].secret_id
              version = "latest"
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [client, client_version]
  }

  depends_on = [
    google_project_service.enabled,
    google_secret_manager_secret_version.platform,
    google_secret_manager_secret_iam_member.readers,
    google_artifact_registry_repository.images,
    google_sql_user.noxus,
    google_project_iam_member.platform_vertex,
    google_storage_bucket_iam_member.platform,
  ]
}

# --------------------------------------------------------------- frontend ---

resource "google_cloud_run_v2_service" "frontend" {
  name                 = local.services.frontend
  location             = var.region
  ingress              = local.use_load_balancer ? "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" : "INGRESS_TRAFFIC_ALL"
  invoker_iam_disabled = true
  deletion_protection  = false

  template {
    service_account                  = google_service_account.frontend.email
    execution_environment            = "EXECUTION_ENVIRONMENT_GEN2"
    timeout                          = "3600s"
    max_instance_request_concurrency = 250

    scaling {
      min_instance_count = var.frontend.instances
      max_instance_count = var.frontend.instances
    }

    vpc_access {
      egress = "ALL_TRAFFIC"
      network_interfaces {
        network    = local.network_id
        subnetwork = local.subnetwork_id
      }
    }

    containers {
      image = "${local.image_prefix}/noxus-frontend:${var.noxus_version}"

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = var.frontend.cpu
          memory = var.frontend.memory
        }
        startup_cpu_boost = true
      }

      startup_probe {
        period_seconds    = 10
        timeout_seconds   = 5
        failure_threshold = 30
        tcp_socket {
          port = 8080
        }
      }

      dynamic "env" {
        for_each = local.frontend_env
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.frontend_secret_env
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.platform[env.value].secret_id
              version = "latest"
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [client, client_version]
  }

  depends_on = [google_cloud_run_v2_service.backend]
}

# ----------------------------------------------------------------- worker ---

resource "google_cloud_run_v2_service" "worker" {
  name                 = local.services.worker
  location             = var.region
  ingress              = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  invoker_iam_disabled = true
  deletion_protection  = false

  template {
    service_account       = google_service_account.platform.email
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

    scaling {
      min_instance_count = var.worker.instances
      max_instance_count = var.worker.instances
    }

    vpc_access {
      egress = "ALL_TRAFFIC"
      network_interfaces {
        network    = local.network_id
        subnetwork = local.subnetwork_id
      }
    }

    containers {
      image = "${local.image_prefix}/noxus-worker:${var.noxus_version}"

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = var.worker.cpu
          memory = var.worker.memory
        }
        # The worker pulls jobs from the queue between requests; a throttled
        # CPU would stall every run.
        cpu_idle          = false
        startup_cpu_boost = true
      }

      startup_probe {
        initial_delay_seconds = 30
        period_seconds        = 30
        timeout_seconds       = 10
        failure_threshold     = 20
        http_get {
          path = "/status/health"
          port = 8080
        }
      }

      liveness_probe {
        period_seconds    = 60
        timeout_seconds   = 30
        failure_threshold = 10
        http_get {
          path = "/status/health"
          port = 8080
        }
      }

      dynamic "env" {
        for_each = local.platform_env
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.platform_secret_env
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.platform[env.value].secret_id
              version = "latest"
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [client, client_version]
  }

  # The backend creates the databases and applies migrations on its first
  # boot; the worker fails to start against an empty schema.
  depends_on = [google_cloud_run_v2_service.backend]
}

# ------------------------------------------------------------------ relay ---

resource "google_cloud_run_v2_service" "relay" {
  name                 = local.services.relay
  location             = var.region
  ingress              = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  invoker_iam_disabled = true
  deletion_protection  = false

  template {
    service_account       = google_service_account.platform.email
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

    scaling {
      min_instance_count = var.relay.instances
      max_instance_count = var.relay.instances
    }

    vpc_access {
      egress = "ALL_TRAFFIC"
      network_interfaces {
        network    = local.network_id
        subnetwork = local.subnetwork_id
      }
    }

    containers {
      image = "${local.image_prefix}/noxus-relays:${var.noxus_version}"

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = var.relay.cpu
          memory = var.relay.memory
        }
        cpu_idle          = false
        startup_cpu_boost = true
      }

      startup_probe {
        initial_delay_seconds = 10
        period_seconds        = 15
        timeout_seconds       = 10
        failure_threshold     = 20
        http_get {
          path = "/status/health"
          port = 8080
        }
      }

      dynamic "env" {
        for_each = local.platform_env
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.platform_secret_env
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.platform[env.value].secret_id
              version = "latest"
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [client, client_version]
  }

  depends_on = [google_cloud_run_v2_service.backend]
}

# ---------------------------------------------------------------- sandbox ---

resource "google_cloud_run_v2_service" "sandbox" {
  count = var.deploy_sandbox ? 1 : 0

  name                 = local.services.sandbox
  location             = var.region
  ingress              = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  invoker_iam_disabled = true
  deletion_protection  = false

  template {
    service_account       = google_service_account.sandbox[0].email
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    # Plugin workers, MCP bridges and shells are WebSockets that live as long
    # as the session; the request timeout is what would cut them.
    timeout = "3600s"
    # Each open WebSocket holds a slot for its whole life.
    max_instance_request_concurrency = 250

    # One instance: the live sandboxes (processes, terminals, overlay mounts)
    # exist only in that instance's memory.
    scaling {
      min_instance_count = 1
      max_instance_count = 1
    }

    vpc_access {
      egress = "ALL_TRAFFIC"
      network_interfaces {
        network    = local.network_id
        subnetwork = local.subnetwork_id
        tags       = [local.sandbox_network_tag]
      }
    }

    volumes {
      name = "sandbox-data"
      empty_dir {
        medium     = "MEMORY"
        size_limit = var.sandbox.data_size
      }
    }

    containers {
      image = "${local.image_prefix}/noxus-agentsandbox:${var.noxus_version}"

      # The image's entrypoint binds 8000 and does not read $PORT.
      ports {
        container_port = 8000
      }

      resources {
        limits = {
          cpu    = var.sandbox.cpu
          memory = var.sandbox.memory
        }
        cpu_idle          = false
        startup_cpu_boost = true
      }

      volume_mounts {
        name       = "sandbox-data"
        mount_path = "/data/sandboxes"
      }

      startup_probe {
        initial_delay_seconds = 10
        period_seconds        = 10
        timeout_seconds       = 10
        failure_threshold     = 30
        http_get {
          path = "/health"
          port = 8000
        }
      }

      # Slack on purpose: a restart takes every running sandbox with it.
      liveness_probe {
        period_seconds    = 60
        timeout_seconds   = 30
        failure_threshold = 5
        http_get {
          path = "/health"
          port = 8000
        }
      }

      dynamic "env" {
        for_each = local.sandbox_env
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.sandbox_secret_env
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.platform[env.value].secret_id
              version = "latest"
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [client, client_version]
  }

  depends_on = [
    google_project_service.enabled,
    google_secret_manager_secret_version.platform,
    google_secret_manager_secret_iam_member.readers,
    google_artifact_registry_repository.images,
    google_storage_bucket_iam_member.sandbox,
  ]
}
