resource "google_service_account" "logging" {
  account_id   = "cloudrun-logging-sa"
  display_name = "Cloud Run Logging Service Account"
}

resource "google_project_iam_member" "logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.logging.email}"
}

resource "google_project_iam_member" "gemini" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.logging.email}"
}

resource "random_password" "auth0_secret" {
  length  = 32
  special = false
  upper   = false
  lower   = true
  numeric = true
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

variable "docker_hub_token" {
  type        = string
  sensitive   = true
  description = "Docker Hub token for authentication"
}

locals {
  postgres_url = var.deploy_postgres ? "postgres:${random_password.postgres_root_password.result}@${google_sql_database_instance.postgresql_instance[0].private_ip_address}:5432" : var.postgresql_url
  env_vars = {
    "ADMIN_EMAIL"                    = var.admin_email
    "AUTH0_DOMAIN"                   = var.auth0_domain
    "AUTH0_BASE_URL"                 = "https://${var.domain}"
    "AUTH0_ISSUER_BASE_URL"          = "https://${var.auth0_domain}"
    "AUTH0_API_AUDIENCE"             = var.auth0_api_audience
    "AUTH0_CLIENT_ID"                = var.auth0_client_id
    "AUTH0_CLIENT_SECRET"            = var.auth0_client_secret
    "AUTH0_SECRET"                   = random_password.auth0_secret.result
    "BACKEND_URL"                    = "https://api.${var.domain}"
    "BILLING_ENABLED"                = "false"
    "BUCKET_CLIENT"                  = "gcloud"
    "DEPLOYMENT_ENV"                 = var.deployment_env
    "FIRESTORE_PROJECT"              = var.project_id
    "FRONTEND_URL"                   = "https://${var.domain}"
    "IS_PROD"                        = "true"
    "NOLLM_CONFIG_PATH"              = "/code/configs"
    "ON_PREM"                        = "true"
    "REDIS_URL"                      = google_redis_instance.redis_instance.host
    "RELAY_URL"                      = "https://relay.${var.domain}"
    "RUN_MIGRATIONS"                 = "1"
    "RUN_BOOTSTRAP"                  = "1"
    "SECRETS_SOURCE"                 = "db"
    "SPOTFLOW_STORAGE_BUCKET"        = google_storage_bucket.noxus.name
    "SPOTFLOW_PUBLIC_STORAGE_BUCKET" = google_storage_bucket.noxus.name
    "VERSION"                        = var.vm_version
    "VERTEX_PROJECT_ID"              = var.project_id
  }
  secret_env_vars = {
    "POSTGRESQL_URL" = {
      secret_name    = google_secret_manager_secret.postgres_url.name
      secret_version = "latest"
    }
    "VECTOR_POSTGRESQL_URL" = {
      secret_name    = google_secret_manager_secret.postgres_url.name
      secret_version = "latest"
    }
  }
  all_env_vars = merge(
    # Transform plain_vars into the target structure
    {
      for key, value in local.env_vars : key => {
        value = value
      }
    },

    # Transform secret_vars into the target structure
    {
      for key, secret in local.secret_env_vars : key => {
        value_source = {
          secret_key_ref = {
            secret  = secret.secret_name
            version = secret.secret_version
          }
        }
      }
    }
  )
}

resource "google_secret_manager_secret" "docker_hub_auth" {
  secret_id = "docker-hub-auth"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "docker_hub_auth" {
  secret      = google_secret_manager_secret.docker_hub_auth.id
  secret_data = var.docker_hub_token
}

resource "google_secret_manager_secret_iam_member" "docker_hub_auth_access" {
  secret_id = google_secret_manager_secret.docker_hub_auth.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.logging.email}"
}

resource "google_secret_manager_secret" "postgres_url" {
  secret_id = "postgres-url"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "postgres_url" {
  secret      = google_secret_manager_secret.postgres_url.id
  secret_data = local.postgres_url
}

data "google_project" "project_number" {}

resource "google_secret_manager_secret_iam_member" "artifact_registry_access" {
  secret_id = google_secret_manager_secret.docker_hub_auth.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:service-${data.google_project.project_number.number}@gcp-sa-artifactregistry.iam.gserviceaccount.com"
}

resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = "noxus-images"
  format        = "DOCKER"
  description   = "Docker repository for Noxus images"
  mode          = "REMOTE_REPOSITORY"
  remote_repository_config {
    disable_upstream_validation = true

    docker_repository {
      public_repository = "DOCKER_HUB"
    }
    upstream_credentials {
      username_password_credentials {
        username                = "davidnoxus"
        password_secret_version = google_secret_manager_secret_version.docker_hub_auth.name
      }
    }
  }
  depends_on = [google_secret_manager_secret_iam_member.artifact_registry_access]
}
resource "google_artifact_registry_repository_iam_member" "cloudrun_puller" {
  location   = google_artifact_registry_repository.docker_repo.location
  repository = google_artifact_registry_repository.docker_repo.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.logging.email}"
}

# -------------------------- BACKEND --------------------------
resource "google_cloud_run_v2_service" "backend" {
  name     = "backend"
  location = var.region
  project  = var.project_id

  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    scaling {
      min_instance_count = var.backend_count
      max_instance_count = var.backend_count
    }
    service_account = google_service_account.logging.email

    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/noxus-images/davidnoxus/noxus:spotflow-backend-${var.vm_version}"

      ports {
        container_port = 8080
      }
      startup_probe {
        initial_delay_seconds = 41
        timeout_seconds       = 10
        period_seconds        = 37
        failure_threshold     = 20
        http_get {
          path = "/status/health"
          port = 8080
        }
      }
      liveness_probe {
        initial_delay_seconds = 41
        timeout_seconds       = 10
        period_seconds        = 37
        failure_threshold     = 20
        http_get {
          path = "/status/health"
          port = 8080
        }
      }

      resources {
        limits = {
          memory = "4Gi"
          cpu    = "4"
        }
      }

      dynamic "env" {
        for_each = local.all_env_vars

        content {
          name = env.key

          # Set 'value' only if it exists in our map, otherwise null
          value = lookup(env.value, "value", null)

          # --- Nested Dynamic Block for Secrets ---
          # This block is only created if 'value_source' exists in our map
          dynamic "value_source" {
            for_each = lookup(env.value, "value_source", null) != null ? [lookup(env.value, "value_source")] : []

            content {
              secret_key_ref {
                secret  = value_source.value.secret_key_ref.secret
                version = value_source.value.secret_key_ref.version
              }
            }
          }
        }
      }
    }
    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"

      network_interfaces {
        network    = google_compute_network.vpc_network.id
        subnetwork = google_compute_subnetwork.vpc_subnetwork.id
      }
    }
  }

  depends_on = [
    google_redis_instance.redis_instance,
    google_sql_database_instance.postgresql_instance[0],
    google_service_account.logging,
    google_secret_manager_secret_iam_member.docker_hub_auth_access,
    google_artifact_registry_repository.docker_repo
  ]
}

resource "google_cloud_run_service_iam_member" "public_access" {
  location = var.region
  project  = var.project_id
  service  = google_cloud_run_v2_service.backend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_domain_mapping" "backend_domain" {
  location = var.region
  name     = "api.${var.domain}"

  metadata {
    namespace = var.project_id
  }

  spec {
    route_name = google_cloud_run_v2_service.backend.name
  }
}


# -------------------------- FRONTEND --------------------------
resource "google_cloud_run_v2_service" "frontend" {
  name     = "frontend"
  location = var.region
  project  = var.project_id

  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    scaling {
      min_instance_count = var.frontend_count
      max_instance_count = var.frontend_count
    }
    service_account = google_service_account.logging.email

    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/noxus-images/davidnoxus/noxus:spotflow-frontend-${var.vm_version}"

      ports {
        container_port = 8080
      }
      startup_probe {
        initial_delay_seconds = 1
        timeout_seconds       = 240
        period_seconds        = 240
        failure_threshold     = 3
        tcp_socket {
          port = 8080
        }
      }

      resources {
        limits = {
          memory = "8Gi"
          cpu    = "4"
        }
      }

      dynamic "env" {
        for_each = local.all_env_vars

        content {
          name = env.key

          # Set 'value' only if it exists in our map, otherwise null
          value = lookup(env.value, "value", null)

          # --- Nested Dynamic Block for Secrets ---
          # This block is only created if 'value_source' exists in our map
          dynamic "value_source" {
            for_each = lookup(env.value, "value_source", null) != null ? [lookup(env.value, "value_source")] : []

            content {
              secret_key_ref {
                secret  = value_source.value.secret_key_ref.secret
                version = value_source.value.secret_key_ref.version
              }
            }
          }
        }
      }
    }
    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"

      network_interfaces {
        network    = google_compute_network.vpc_network.id
        subnetwork = google_compute_subnetwork.vpc_subnetwork.id
      }
    }
  }

  depends_on = [
    google_redis_instance.redis_instance,
    google_sql_database_instance.postgresql_instance[0],
    google_service_account.logging,
    google_secret_manager_secret_iam_member.docker_hub_auth_access,
    google_artifact_registry_repository.docker_repo
  ]
}

resource "google_cloud_run_service_iam_member" "public_access_frontend" {
  location = var.region
  project  = var.project_id
  service  = google_cloud_run_v2_service.frontend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_domain_mapping" "frontend_domain" {
  location = var.region
  name     = var.domain

  metadata {
    namespace = var.project_id
  }

  spec {
    route_name = google_cloud_run_v2_service.frontend.name
  }
}
# -------------------------- WORKER --------------------------

resource "google_cloud_run_v2_service" "worker" {
  name     = "worker"
  location = var.region
  project  = var.project_id

  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    scaling {
      min_instance_count = var.worker_count
      max_instance_count = var.worker_count
    }
    service_account = google_service_account.logging.email

    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/noxus-images/davidnoxus/noxus:spotflow-worker-${var.vm_version}"

      ports {
        container_port = 8080
      }
      startup_probe {
        initial_delay_seconds = 43
        timeout_seconds       = 10
        period_seconds        = 37
        failure_threshold     = 20
        http_get {
          path = "/status/health"
          port = 8080
        }
      }
      liveness_probe {
        initial_delay_seconds = 30
        timeout_seconds       = 60
        period_seconds        = 600
        failure_threshold     = 3
        http_get {
          path = "/status/test-task"
          port = 8080
        }
      }

      resources {
        limits = {
          memory = "32Gi"
          cpu    = "8000m"
        }
      }

      dynamic "env" {
        for_each = local.all_env_vars

        content {
          name = env.key

          # Set 'value' only if it exists in our map, otherwise null
          value = lookup(env.value, "value", null)

          # --- Nested Dynamic Block for Secrets ---
          # This block is only created if 'value_source' exists in our map
          dynamic "value_source" {
            for_each = lookup(env.value, "value_source", null) != null ? [lookup(env.value, "value_source")] : []

            content {
              secret_key_ref {
                secret  = value_source.value.secret_key_ref.secret
                version = value_source.value.secret_key_ref.version
              }
            }
          }
        }
      }
    }
    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"

      network_interfaces {
        network    = google_compute_network.vpc_network.id
        subnetwork = google_compute_subnetwork.vpc_subnetwork.id
      }
    }
  }

  depends_on = [
    google_cloud_run_v2_service.backend
  ]
}

# -------------------------- BEAT --------------------------
resource "google_cloud_run_v2_service" "beat" {
  name     = "beat"
  location = var.region
  project  = var.project_id

  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    scaling {
      min_instance_count = 1
      max_instance_count = 1
    }
    service_account = google_service_account.logging.email

    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/noxus-images/davidnoxus/noxus:spotflow-worker-${var.vm_version}"
      args = [
        "bash",
        "./beat_start.sh"
      ]

      ports {
        container_port = 8080
      }
      startup_probe {
        initial_delay_seconds = 43
        timeout_seconds       = 10
        period_seconds        = 37
        failure_threshold     = 20
        http_get {
          path = "/status/health"
          port = 8080
        }
      }

      resources {
        limits = {
          memory = "2Gi"
          cpu    = "1000m"
        }
      }

      dynamic "env" {
        for_each = local.all_env_vars

        content {
          name = env.key

          # Set 'value' only if it exists in our map, otherwise null
          value = lookup(env.value, "value", null)

          # --- Nested Dynamic Block for Secrets ---
          # This block is only created if 'value_source' exists in our map
          dynamic "value_source" {
            for_each = lookup(env.value, "value_source", null) != null ? [lookup(env.value, "value_source")] : []

            content {
              secret_key_ref {
                secret  = value_source.value.secret_key_ref.secret
                version = value_source.value.secret_key_ref.version
              }
            }
          }
        }
      }
    }
    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"

      network_interfaces {
        network    = google_compute_network.vpc_network.id
        subnetwork = google_compute_subnetwork.vpc_subnetwork.id
      }
    }
  }

  depends_on = [
    google_cloud_run_v2_service.backend
  ]
}
# -------------------------- RELAY --------------------------
resource "google_cloud_run_v2_service" "relay" {
  name     = "relay"
  location = var.region
  project  = var.project_id

  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    scaling {
      min_instance_count = var.relay_count
      max_instance_count = var.relay_count
    }
    service_account = google_service_account.logging.email

    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/noxus-images/davidnoxus/noxus:spotflow-relays-${var.vm_version}"

      ports {
        container_port = 8080
      }
      startup_probe {
        initial_delay_seconds = 41
        timeout_seconds       = 10
        period_seconds        = 37
        failure_threshold     = 20
        http_get {
          path = "/status/health"
          port = 8080
        }
      }

      resources {
        limits = {
          memory = "4Gi"
          cpu    = "2"
        }
      }

      # This referenced a `local.env` that does not exist, so the relay service
      # never planned. It takes the same merged plain+secret env as every other
      # service.
      dynamic "env" {
        for_each = local.all_env_vars

        content {
          name  = env.key
          value = lookup(env.value, "value", null)

          dynamic "value_source" {
            for_each = lookup(env.value, "value_source", null) != null ? [lookup(env.value, "value_source")] : []

            content {
              secret_key_ref {
                secret  = value_source.value.secret_key_ref.secret
                version = value_source.value.secret_key_ref.version
              }
            }
          }
        }
      }
    }
    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"

      network_interfaces {
        network    = google_compute_network.vpc_network.id
        subnetwork = google_compute_subnetwork.vpc_subnetwork.id
      }
    }
  }

  depends_on = [
    google_redis_instance.redis_instance,
    google_sql_database_instance.postgresql_instance[0],
    google_service_account.logging,
    google_secret_manager_secret_iam_member.docker_hub_auth_access,
    google_artifact_registry_repository.docker_repo
  ]
}

resource "google_cloud_run_service_iam_member" "relay_public_access" {
  location = var.region
  project  = var.project_id
  service  = google_cloud_run_v2_service.relay.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_domain_mapping" "relay_domain" {
  location = var.region
  name     = "relay.${var.domain}"

  metadata {
    namespace = var.project_id
  }

  spec {
    route_name = google_cloud_run_v2_service.relay.name
  }
}
