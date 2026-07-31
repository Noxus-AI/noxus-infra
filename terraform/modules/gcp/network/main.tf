resource "google_compute_network" "this" {
  name                    = "${var.name}-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "this" {
  name          = "${var.name}-subnet"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.this.id
  ip_cidr_range = var.subnet_cidr

  private_ip_google_access = true

  # GKE places pods and services in these secondary ranges. They must exist before
  # the cluster is created and cannot be resized afterwards, so size them for the
  # cluster you expect to grow into: a /16 pod range caps you at ~250 nodes with
  # the default /24-per-node allocation.
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Private nodes have no external IP, so egress to model providers and integrations
# has to route through Cloud NAT.
resource "google_compute_router" "this" {
  name    = "${var.name}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  name    = "${var.name}-nat"
  project = var.project_id
  region  = var.region
  router  = google_compute_router.this.name

  nat_ip_allocate_option             = length(var.nat_ip_addresses) > 0 ? "MANUAL_ONLY" : "AUTO_ONLY"
  nat_ips                            = var.nat_ip_addresses
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Private Service Access range. Cloud SQL and Memorystore are peered into the VPC
# out of this block, which is why it must not overlap the subnet ranges above.
resource "google_compute_global_address" "private_service_access" {
  name          = "${var.name}-psa"
  project       = var.project_id
  network       = google_compute_network.this.id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = split("/", var.private_service_access_cidr)[0]
  prefix_length = tonumber(split("/", var.private_service_access_cidr)[1])
}

resource "google_service_networking_connection" "this" {
  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_access.name]
}
