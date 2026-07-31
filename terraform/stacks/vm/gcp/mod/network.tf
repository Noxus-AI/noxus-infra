# create vpc network
resource "google_compute_network" "vpc_network" {
  name                    = "${var.goog_cm_deployment_name}-noxus-vpc"
  auto_create_subnetworks = false
}

# create vpc subnet
resource "google_compute_subnetwork" "vpc_subnetwork" {
  name                     = "noxus-vpc-subnet"
  ip_cidr_range            = "10.0.0.0/16"
  region                   = var.region
  network                  = google_compute_network.vpc_network.id
  private_ip_google_access = true
}

# vpc peering for Cloud SQL PSA
resource "google_compute_global_address" "default" {
  count         = var.deploy_postgres ? 1 : 0
  name          = "${var.goog_cm_deployment_name}-noxus-service-networking"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc_network.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  count                   = var.deploy_postgres ? 1 : 0
  network                 = google_compute_network.vpc_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.default[0].name]
  depends_on              = [google_project_service.service_networking]
  provider                = google-beta
}

# cloud router
resource "google_compute_router" "router" {
  name    = "${var.goog_cm_deployment_name}-noxus-router"
  network = google_compute_network.vpc_network.id
  region  = var.region
}

# cloud nat
resource "google_compute_router_nat" "nat" {
  name                               = "${var.goog_cm_deployment_name}-noxus-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# fw rule to allow internal
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  source_ranges = ["10.0.0.0/16"]
}

# fw rule for iap tcp forwarding
# https://cloud.google.com/iap/docs/using-tcp-forwarding#create-firewall-rule
resource "google_compute_firewall" "allow_iap" {
  name    = "allow-iap"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # allow iap source ranges
  source_ranges = [
    "35.235.240.0/20"
  ]
}

# fw rule for health checks
# https://cloud.google.com/load-balancing/docs/health-check-concepts#ip-ranges
resource "google_compute_firewall" "allow_3000" {
  name    = "allow-3000"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }

  source_ranges = [
    google_compute_global_address.spot.address,
    "35.191.0.0/16",
    "130.211.0.0/22",
  ]

  target_tags = ["http-server"]

  depends_on = [google_compute_global_address.spot]
}

# XLB ssl certificate
resource "google_compute_managed_ssl_certificate" "spot" {
  name = "${var.goog_cm_deployment_name}-noxus-ssl-cert"
  managed {
    domains = [var.domain]
  }
}

# XLB external IP address
resource "google_compute_global_address" "spot" {
  name = "${var.goog_cm_deployment_name}-noxus-address"
}

# XLB backend service (MIG)
resource "google_compute_backend_service" "https_default" {
  name      = "${var.goog_cm_deployment_name}-noxus-backend-service"
  protocol  = "HTTP"
  port_name = "http"
  backend {
    group = google_compute_instance_group_manager.default.instance_group
  }

  health_checks         = [google_compute_http_health_check.spot.id]
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# Health Checks
resource "google_compute_http_health_check" "spot" {
  name                = "${var.goog_cm_deployment_name}-noxus-health-check"
  request_path        = "/api/health"
  port                = 3000
  check_interval_sec  = 5
  timeout_sec         = 5
  unhealthy_threshold = 2
  healthy_threshold   = 2
}

# HTTPS url map
resource "google_compute_url_map" "spot" {
  name            = "${var.goog_cm_deployment_name}-noxus-url-map"
  default_service = google_compute_backend_service.https_default.id

  host_rule {
    hosts        = [var.domain]
    path_matcher = "default-path-matcher"
  }

  path_matcher {
    name            = "default-path-matcher"
    default_service = google_compute_backend_service.https_default.id
  }
}

# HTTPS target proxy
resource "google_compute_target_https_proxy" "spot" {
  name             = "${var.goog_cm_deployment_name}-noxus-https-proxy"
  url_map          = google_compute_url_map.spot.id
  ssl_certificates = [google_compute_managed_ssl_certificate.spot.id]
}

# HTTPS forwarding rule
resource "google_compute_global_forwarding_rule" "spot" {
  name                  = "${var.goog_cm_deployment_name}-noxus-https-forwarding-rule"
  target                = google_compute_target_https_proxy.spot.id
  port_range            = "443"
  ip_address            = google_compute_global_address.spot.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# HTTP url map (redirect http to https) 
resource "google_compute_url_map" "http" {
  name = "${var.goog_cm_deployment_name}-noxus-url-map-redirect"
  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

# HTTP target proxy
resource "google_compute_target_http_proxy" "http" {
  name    = "${var.goog_cm_deployment_name}-noxus-http-proxy"
  url_map = google_compute_url_map.http.id
}

# HTTP forwarding rule
resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.goog_cm_deployment_name}-noxus-http-forwarding-rule"
  target                = google_compute_target_http_proxy.http.id
  port_range            = "80"
  ip_address            = google_compute_global_address.spot.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
