output "primary_endpoint" {
  description = "Primary endpoint hostname. This is the value the chart's secrets.REDIS_URL expects — hostname only, no scheme or port."
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "reader_endpoint" {
  description = "Reader endpoint hostname. Unused by the platform today; exposed for external tooling."
  value       = aws_elasticache_replication_group.this.reader_endpoint_address
}

output "port" {
  description = "Redis port."
  value       = aws_elasticache_replication_group.this.port
}

output "auth_token" {
  description = "Generated auth token when transit encryption is on. Set as secrets.REDIS_PASSWORD."
  value       = var.transit_encryption_enabled ? random_password.auth_token[0].result : ""
  sensitive   = true
}

output "security_group_id" {
  description = "Security group guarding the cluster."
  value       = aws_security_group.this.id
}
