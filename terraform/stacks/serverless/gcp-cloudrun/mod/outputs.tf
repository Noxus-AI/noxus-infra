output "backend_dns" {
  value       = jsonencode(google_cloud_run_domain_mapping.backend_domain.status)
  description = "The public dns to add for the backend"
}

output "frontend_dns" {
  value       = jsonencode(google_cloud_run_domain_mapping.frontend_domain.status)
  description = "The public dns to add for the frontend"
}

output "relay_dns" {
  value       = jsonencode(google_cloud_run_domain_mapping.relay_domain.status)
  description = "The public dns to add for the relay"
}
