resource "random_password" "postgres_root_password" {
  length = 32
  # POSTGRESQL_URL is parsed as user:password@host:port, so keep the password
  # free of characters that would need escaping there.
  special = false
  upper   = true
  lower   = true
  numeric = true
}

resource "azurerm_postgresql_flexible_server" "main" {
  count               = var.deploy_postgres ? 1 : 0
  name                = "${var.deployment_name}-postgres"
  location            = local.location
  resource_group_name = local.resource_group_name

  # Matches the pgvector/pgvector:pg15 image the platform is developed against.
  version                       = "15"
  administrator_login           = "postgres"
  administrator_password        = random_password.postgres_root_password.result
  delegated_subnet_id           = azurerm_subnet.postgres[0].id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres[0].id
  public_network_access_enabled = false

  sku_name              = var.postgres_sku_name
  storage_mb            = var.postgres_storage_mb
  auto_grow_enabled     = true
  backup_retention_days = var.postgres_backup_retention_days

  zone = "1"

  lifecycle {
    ignore_changes = [zone]
  }

  tags = var.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres[0]]
}

resource "azurerm_postgresql_flexible_server_configuration" "max_connections" {
  count     = var.deploy_postgres ? 1 : 0
  name      = "max_connections"
  server_id = azurerm_postgresql_flexible_server.main[0].id
  value     = tostring(var.postgres_max_connections)
}

# Knowledge bases store embeddings in pgvector, and Flexible Server refuses
# CREATE EXTENSION for anything outside this allowlist.
resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  count     = var.deploy_postgres ? 1 : 0
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.main[0].id
  value     = "vector,uuid-ossp,pg_trgm"
}

# The platform builds asyncpg URLs with no ssl argument, and asyncpg does not
# negotiate TLS on its own, so Flexible Server's default require_secure_transport
# would reject every async connection. Safe here because the server has no public
# endpoint and is only reachable from the delegated VNet subnet.
resource "azurerm_postgresql_flexible_server_configuration" "require_secure_transport" {
  count     = var.deploy_postgres ? 1 : 0
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.main[0].id
  value     = "OFF"
}

# The backend entrypoint creates spot, vectors and procrastinate on first boot;
# this just makes the primary database exist before anything connects.
resource "azurerm_postgresql_flexible_server_database" "spot" {
  count     = var.deploy_postgres ? 1 : 0
  name      = "spot"
  server_id = azurerm_postgresql_flexible_server.main[0].id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

locals {
  postgres_url = var.deploy_postgres ? "postgres:${random_password.postgres_root_password.result}@${azurerm_postgresql_flexible_server.main[0].fqdn}:5432" : var.postgresql_url
}
