output "cluster_name" {
  description = "Cluster name."
  value       = google_container_cluster.this.name
}

output "endpoint" {
  description = "Kubernetes API endpoint."
  value       = google_container_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64 CA bundle for the API endpoint."
  value       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "location" {
  description = "Cluster location — a region when regional, otherwise a zone."
  value       = google_container_cluster.this.location
}

output "workload_identity_pool" {
  description = "Workload Identity pool. Used to build the serviceAccount:POOL[NAMESPACE/KSA] member string."
  value       = "${var.project_id}.svc.id.goog"
}

output "node_service_account_email" {
  description = "Service account the nodes run as, or empty under Autopilot."
  value       = var.enable_autopilot ? "" : google_service_account.nodes[0].email
}
