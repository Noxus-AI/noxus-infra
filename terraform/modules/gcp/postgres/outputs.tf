output "instance_name" {
  description = "Cloud SQL instance name."
  value       = google_sql_database_instance.this.name
}

output "connection_name" {
  description = "Instance connection name, for the Cloud SQL Auth Proxy and Cloud Run connectors."
  value       = google_sql_database_instance.this.connection_name
}

output "private_ip" {
  description = "Private IP address. This is the host the platform connects to from inside the VPC."
  value       = google_sql_database_instance.this.private_ip_address
}

output "port" {
  description = "PostgreSQL port."
  value       = 5432
}

output "username" {
  description = "Application database user."
  value       = google_sql_user.this.name
}

output "password" {
  description = "Generated password for the application user."
  value       = random_password.root.result
  sensitive   = true
}

output "platform_url" {
  description = "Value for the chart's POSTGRESQL_URL — user:password@host:port, no scheme."
  value       = "${google_sql_user.this.name}:${random_password.root.result}@${google_sql_database_instance.this.private_ip_address}:5432"
  sensitive   = true
}
