output "backend_dns" {
  value       = azurerm_container_app.backend.ingress[0].fqdn
  description = "FQDN of the backend container app (map api.<domain> here)"
}

output "frontend_dns" {
  value       = azurerm_container_app.frontend.ingress[0].fqdn
  description = "FQDN of the frontend container app (map <domain> here)"
}

output "relay_dns" {
  value       = azurerm_container_app.relay.ingress[0].fqdn
  description = "FQDN of the relay container app (map relay.<domain> here)"
}

output "acr_login_server" {
  value       = azurerm_container_registry.acr.login_server
  description = "The ACR login server URL"
}

output "resource_group_name" {
  value       = local.resource_group_name
  description = "The name of the resource group holding the deployment"
}

output "storage_account_name" {
  value       = azurerm_storage_account.main.name
  description = "Storage account backing SPOTFLOW_STORAGE_BUCKET"
}

output "postgres_fqdn" {
  value       = var.deploy_postgres ? azurerm_postgresql_flexible_server.main[0].fqdn : null
  description = "FQDN of the managed PostgreSQL Flexible Server, if one was deployed"
}

output "postgres_admin_password" {
  value       = var.deploy_postgres ? random_password.postgres_root_password.result : null
  description = "Generated password for the PostgreSQL admin user"
  sensitive   = true
}
