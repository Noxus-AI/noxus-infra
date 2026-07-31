output "frontend_url" {
  description = "Public URL of the web app."
  value       = module.noxus.frontend_url
}

output "backend_url" {
  description = "Public URL of the API."
  value       = module.noxus.backend_url
}

output "ingress_ip" {
  description = "Global static IP fronting the platform. Point the three hostnames here if dns_managed_zone was not set."
  value       = google_compute_global_address.ingress.address
}

output "required_dns_records" {
  description = "A records the managed certificate needs before it will issue."
  value       = { for h in local.hostnames : h => google_compute_global_address.ingress.address }
}

output "cluster_name" {
  description = "GKE cluster name."
  value       = module.gke.cluster_name
}

output "kubeconfig_command" {
  description = "Command to point kubectl at the cluster."
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --location ${module.gke.location} --project ${var.project_id}"
}

output "postgres_private_ip" {
  description = "Cloud SQL private IP."
  value       = module.postgres.private_ip
}

output "postgres_password" {
  description = "Generated Cloud SQL password."
  value       = module.postgres.password
  sensitive   = true
}

output "redis_host" {
  description = "Memorystore host."
  value       = module.redis.host
}

output "private_bucket" {
  description = "Artifact bucket name."
  value       = module.storage.private_bucket
}
