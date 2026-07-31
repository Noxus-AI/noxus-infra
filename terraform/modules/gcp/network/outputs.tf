output "network_id" {
  description = "VPC network ID."
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "VPC network name."
  value       = google_compute_network.this.name
}

output "subnet_id" {
  description = "Node subnet ID."
  value       = google_compute_subnetwork.this.id
}

output "subnet_name" {
  description = "Node subnet name."
  value       = google_compute_subnetwork.this.name
}

output "subnet_cidr" {
  description = "Primary subnet range."
  value       = google_compute_subnetwork.this.ip_cidr_range
}

output "pods_range_name" {
  description = "Secondary range name for GKE pods."
  value       = "pods"
}

output "services_range_name" {
  description = "Secondary range name for GKE services."
  value       = "services"
}

output "private_service_access_connection" {
  description = "Service networking connection. Depend on this from Cloud SQL and Memorystore so peering exists before they are created."
  value       = google_service_networking_connection.this.id
}
