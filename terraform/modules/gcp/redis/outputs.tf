output "host" {
  description = "Instance host. This is the value the chart's secrets.REDIS_URL expects — hostname only."
  value       = google_redis_instance.this.host
}

output "port" {
  description = "Instance port."
  value       = google_redis_instance.this.port
}

output "auth_string" {
  description = "AUTH string when auth_enabled is true. Set as the chart's secrets.REDIS_PASSWORD."
  value       = var.auth_enabled ? google_redis_instance.this.auth_string : ""
  sensitive   = true
}
