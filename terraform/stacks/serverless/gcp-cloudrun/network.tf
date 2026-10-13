# Every service sends all of its traffic through this VPC (Direct VPC egress,
# ALL_TRAFFIC). Two reasons: a service only counts as "internal" to another
# service's internal-only ingress when its own egress goes through the VPC, and
# it gives the deployment one egress path, through Cloud NAT, with a fixed IP.

resource "google_compute_network" "main" {
  count = local.create_network ? 1 : 0

  name                    = "${local.prefix}-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.enabled]
}

resource "google_compute_subnetwork" "main" {
  count = local.create_network ? 1 : 0

  name          = "${local.prefix}-subnet"
  region        = var.region
  network       = google_compute_network.main[0].id
  ip_cidr_range = var.subnet_cidr

  # Google APIs (Vertex AI, Cloud Storage) and the services' own run.app URLs
  # are reached over Google's network, not through NAT.
  private_ip_google_access = true
}

# Private Service Access: Cloud SQL and Memorystore get private IPs from this
# range and are reachable only from inside the VPC.
resource "google_compute_global_address" "private_service_access" {
  count = local.create_network ? 1 : 0

  name          = "${local.prefix}-private-service-access"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = cidrhost(var.private_service_access_cidr, 0)
  prefix_length = tonumber(split("/", var.private_service_access_cidr)[1])
  network       = google_compute_network.main[0].id
}

resource "google_service_networking_connection" "private_service_access" {
  count = local.create_network ? 1 : 0

  network                 = google_compute_network.main[0].id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_access[0].name]

  # Deleting the peering fails while Cloud SQL still holds addresses in it,
  # which would otherwise block `tofu destroy`.
  deletion_policy = "ABANDON"
}

resource "google_compute_router" "main" {
  count = local.create_network ? 1 : 0

  name    = "${local.prefix}-router"
  region  = var.region
  network = google_compute_network.main[0].id
}

resource "google_compute_address" "egress" {
  count = local.create_network ? 1 : 0

  name   = "${local.prefix}-egress"
  region = var.region
}

resource "google_compute_router_nat" "main" {
  count = local.create_network ? 1 : 0

  name   = "${local.prefix}-nat"
  router = google_compute_router.main[0].name
  region = var.region

  nat_ip_allocate_option = "MANUAL_ONLY"
  nat_ips                = [google_compute_address.egress[0].self_link]

  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.main[0].id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  enable_dynamic_port_allocation      = true
  enable_endpoint_independent_mapping = false
  min_ports_per_vm                    = 128
  max_ports_per_vm                    = 8192

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# The gvisor provider shares the sandbox service's network with the code it
# runs, so keep that code away from Cloud SQL, Memorystore and anything else on
# private ranges. The metadata server is not routed through the VPC and stays
# reachable, which is why the sandbox runs as its own service account with
# access to nothing but its own bucket.
resource "google_compute_firewall" "sandbox_deny_private" {
  count = local.create_network && var.deploy_sandbox ? 1 : 0

  name        = "${local.prefix}-sandbox-deny-private"
  network     = google_compute_network.main[0].id
  direction   = "EGRESS"
  priority    = 900
  target_tags = [local.sandbox_network_tag]

  destination_ranges = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "100.64.0.0/10"]

  deny {
    protocol = "all"
  }
}
