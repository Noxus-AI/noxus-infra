resource "google_compute_network" "vpc_network" {
  name                    = "${var.goog_cm_deployment_name}-noxus-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "vpc_subnetwork" {
  name          = "${var.goog_cm_deployment_name}-noxus-vpc-subnet"
  ip_cidr_range = "10.0.0.0/16"
  region        = var.region
  network       = google_compute_network.vpc_network.id
}

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

