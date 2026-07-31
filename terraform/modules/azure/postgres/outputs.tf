output "fqdn" {
  description = "Private FQDN of the server. Only resolvable from inside the linked VNet."
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "port" {
  description = "PostgreSQL port."
  value       = 5432
}

output "username" {
  description = "Administrator login."
  value       = azurerm_postgresql_flexible_server.this.administrator_login
}

output "password" {
  description = "Generated administrator password."
  value       = random_password.root.result
  sensitive   = true
}

output "platform_url" {
  description = "Value for the chart's POSTGRESQL_URL — user:password@host:port, no scheme."
  value       = "${azurerm_postgresql_flexible_server.this.administrator_login}:${random_password.root.result}@${azurerm_postgresql_flexible_server.this.fqdn}:5432"
  sensitive   = true
}

output "server_id" {
  description = "Resource ID of the server."
  value       = azurerm_postgresql_flexible_server.this.id
}
