output "address" {
  description = "Instance hostname."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Instance port."
  value       = aws_db_instance.this.port
}

output "username" {
  description = "Master username."
  value       = aws_db_instance.this.username
}

output "password" {
  description = "Generated master password."
  value       = random_password.root.result
  sensitive   = true
}

output "security_group_id" {
  description = "Security group guarding the instance. Attach further ingress rules to this."
  value       = aws_security_group.this.id
}

output "platform_url" {
  description = "Value for the chart's POSTGRESQL_URL — user:password@host:port, with no scheme. The platform prepends the driver itself."
  value       = "${aws_db_instance.this.username}:${random_password.root.result}@${aws_db_instance.this.address}:${aws_db_instance.this.port}"
  sensitive   = true
}

output "keda_url" {
  description = "Value for worker.keda.postgresConnectionString — a full postgresql:// URL, which is a different shape from platform_url."
  value       = "postgresql://${aws_db_instance.this.username}:${random_password.root.result}@${aws_db_instance.this.address}:${aws_db_instance.this.port}/${var.initial_database}"
  sensitive   = true
}
