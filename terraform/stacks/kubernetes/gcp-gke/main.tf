locals {
  name = "${var.project_name}-${var.environment}"

  labels = merge(
    {
      project     = var.project_name
      environment = var.environment
      managed-by  = "terraform"
    },
    var.labels,
  )

  hostnames = [var.domain, "api.${var.domain}", "relay.${var.domain}"]

  # The chart creates its ServiceAccount named after the release; Workload
  # Identity has to bind that exact name, which is why it is derived here rather
  # than guessed inside the storage module.
  workload_identity_member = "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${var.release_name}]"
}

module "network" {
  source = "../../../modules/gcp/network"

  name       = local.name
  project_id = var.project_id
  region     = var.region

  subnet_cidr                 = var.subnet_cidr
  pods_cidr                   = var.pods_cidr
  services_cidr               = var.services_cidr
  private_service_access_cidr = var.private_service_access_cidr
}

module "gke" {
  source = "../../../modules/gcp/gke"

  cluster_name = "${local.name}-gke"
  project_id   = var.project_id
  region       = var.region
  zone         = var.zone
  regional     = var.environment == "prod"

  enable_autopilot = var.enable_autopilot

  network_id = module.network.network_id
  subnet_id  = module.network.subnet_id

  pods_range_name     = module.network.pods_range_name
  services_range_name = module.network.services_range_name

  master_cidr                = var.master_cidr
  master_authorized_networks = var.master_authorized_networks
  release_channel            = var.release_channel
  node_pools                 = var.node_pools

  deletion_protection = var.environment == "prod"
  labels              = local.labels
}

module "postgres" {
  source = "../../../modules/gcp/postgres"

  name       = local.name
  project_id = var.project_id
  region     = var.region

  network_id                        = module.network.network_id
  private_service_access_connection = module.network.private_service_access_connection

  database_version    = var.postgres_version
  tier                = var.postgres_tier
  disk_size_gb        = var.postgres_disk_size_gb
  high_availability   = var.environment == "prod"
  deletion_protection = var.environment == "prod"

  labels = local.labels
}

module "redis" {
  source = "../../../modules/gcp/redis"

  name       = local.name
  project_id = var.project_id
  region     = var.region

  network_id                        = module.network.network_id
  private_service_access_connection = module.network.private_service_access_connection

  memory_size_gb    = var.redis_memory_gb
  high_availability = var.environment == "prod"

  labels = local.labels
}

module "storage" {
  source = "../../../modules/gcp/storage"

  name       = local.name
  project_id = var.project_id
  location   = var.bucket_location

  cors_allowed_origins     = ["https://${var.domain}"]
  workload_identity_member = local.workload_identity_member
  grant_vertex_ai          = var.grant_vertex_ai
  force_destroy            = var.environment != "prod"

  labels = local.labels
}

# --------------------------------------------------------------------------
# Ingress front door.
#
# GKE Ingress terminates TLS on a Google-managed certificate. Creating the
# certificate in Terraform and referencing it as a pre-shared cert keeps the
# whole chain in state — the alternative, a ManagedCertificate CRD, would need
# cluster API access at plan time.
# --------------------------------------------------------------------------

resource "google_compute_global_address" "ingress" {
  name    = "${local.name}-ingress-ip"
  project = var.project_id
}

resource "google_compute_managed_ssl_certificate" "ingress" {
  name    = "${local.name}-cert"
  project = var.project_id

  managed {
    domains = local.hostnames
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Google will not issue the managed certificate until these records resolve to
# the load balancer address, so DNS has to exist first.
resource "google_dns_record_set" "hostnames" {
  for_each = var.dns_managed_zone != "" ? toset(local.hostnames) : toset([])

  name         = "${each.value}."
  project      = var.project_id
  managed_zone = var.dns_managed_zone
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.ingress.address]
}

module "noxus" {
  source = "../../../modules/platform/noxus-release"

  release_name = var.release_name
  namespace    = var.namespace

  app_version    = var.app_version
  domain         = var.domain
  admin_email    = var.admin_email
  deployment_env = var.environment

  service_account_annotations = module.storage.helm_service_account_annotation

  database = {
    host     = module.postgres.private_ip
    port     = module.postgres.port
    name     = "spot"
    username = module.postgres.username
    password = module.postgres.password
  }

  redis = {
    host     = module.redis.host
    port     = module.redis.port
    password = module.redis.auth_string
  }

  storage = {
    client         = "gcloud"
    private_bucket = module.storage.private_bucket
    public_bucket  = module.storage.public_bucket
  }

  auth0 = var.auth0

  ingress = {
    enabled    = true
    class_name = "gce"
    annotations = {
      "kubernetes.io/ingress.class"                 = "gce"
      "kubernetes.io/ingress.global-static-ip-name" = google_compute_global_address.ingress.name
      "ingress.gcp.kubernetes.io/pre-shared-cert"   = google_compute_managed_ssl_certificate.ingress.name
      "kubernetes.io/ingress.allow-http"            = "false"
    }
  }

  extra_env = merge(
    {
      VERTEX_PROJECT_ID = var.project_id
      FIRESTORE_PROJECT = var.project_id
    },
    var.extra_env,
  )

  pgbouncer_enabled = var.pgbouncer_enabled
  sandbox_enabled   = var.sandbox_enabled

  extra_secrets = var.extra_secrets
  extra_values  = var.extra_values
}
