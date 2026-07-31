resource "google_service_account" "logging" {
  account_id   = "instance-logging-sa"
  display_name = "Instance Logging Service Account"
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

locals {
  postgres_url = var.deploy_postgres ? "postgres:${random_password.postgres_root_password.result}@${google_sql_database_instance.postgresql_instance[0].private_ip_address}:5432" : var.postgresql_url
}

resource "google_compute_instance_template" "default" {
  name_prefix  = "${var.goog_cm_deployment_name}-noxus-template"
  machine_type = var.machine_type

  tags = ["http-server"]

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.vpc_subnetwork.id

  }

  disk {
    auto_delete  = true
    boot         = true
    source_image = var.source_image
  }

  service_account {
    email = google_service_account.logging.email
    scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/devstorage.read_write",
    ]
  }

  # These keys must cover every attribute the appliance's boot script reads. A key
  # the script reads but Terraform does not set is written to env.vm as an empty
  # value — and because the appliance's env bootstrap only fills in keys that are
  # *absent*, an empty key never picks up its default. Leaving BACKEND_URL out is
  # how the backend ends up with no URL at all rather than the intended fallback.
  metadata = {
    ADMIN_EMAIL              = var.admin_email
    AUTH0_DOMAIN             = var.auth0_domain
    AUTH0_BASE_URL           = "https://${var.domain}"
    AUTH0_ISSUER_BASE_URL    = "https://${var.auth0_domain}"
    AUTH0_API_AUDIENCE       = var.auth0_api_audience
    AUTH0_CLIENT_ID          = var.auth0_client_id
    AUTH0_CLIENT_SECRET      = var.auth0_client_secret
    AUTH0_MGMT_CLIENT_ID     = var.auth0_mgmt_client_id
    AUTH0_MGMT_CLIENT_SECRET = var.auth0_mgmt_client_secret
    AUTH0_SECRET             = random_password.auth0_secret.result

    BACKEND_URL    = "https://${var.domain}"
    FRONTEND_URL   = "https://${var.domain}"
    RELAY_URL      = "https://${var.domain}"
    DEPLOYMENT_ENV = var.deployment_env
    LICENSE_SERVER = var.license_server

    POSTGRESQL_URL = local.postgres_url
    # Inert: start.sh derives VECTOR_POSTGRESQL_URL from POSTGRESQL_URL. Kept so
    # the metadata reads as a complete picture of the appliance's database config.
    VECTOR_POSTGRESQL_URL = local.postgres_url

    REDIS_URL      = "redis"
    REDIS_SSL      = var.redis_ssl
    REDIS_PASSWORD = var.redis_password

    SPOTFLOW_STORAGE_BUCKET        = google_storage_bucket.noxus.name
    SPOTFLOW_PUBLIC_STORAGE_BUCKET = google_storage_bucket.noxus.name

    WHITELABEL_LOGO = var.whitelabel_logo

    SERPER_API_KEY       = var.serper_api_key
    GOOGLE_API_KEY       = var.google_api_key
    GOOGLE_APP_ID        = var.google_app_id
    GOOGLE_CLIENT_ID     = var.google_client_id
    GOOGLE_CLIENT_SECRET = var.google_client_secret

    VERSION = var.vm_version
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_health_check" "http_health" {
  name = "${var.goog_cm_deployment_name}-instance-health-check"

  http_health_check {
    request_path = "/api/health"
    port         = 3000
  }
}

resource "google_compute_instance_group_manager" "default" {
  name               = "${var.goog_cm_deployment_name}-noxus-igm"
  base_instance_name = "noxus"
  zone               = var.zone
  target_size        = 1

  auto_healing_policies {
    health_check      = google_compute_health_check.http_health.id
    initial_delay_sec = 3600
  }

  version {
    instance_template = google_compute_instance_template.default.self_link_unique
  }

  named_port {
    name = "http"
    port = 3000
  }

  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 1
    max_unavailable_fixed = 0
  }

  wait_for_instances = true

  lifecycle {
    create_before_destroy = true
  }
}