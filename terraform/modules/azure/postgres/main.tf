resource "random_password" "root" {
  length  = 32
  special = false
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                = "${var.name}-postgres"
  resource_group_name = var.resource_group_name
  location            = var.location

  # pgvector requires PostgreSQL 15 or newer on Flexible Server.
  version = var.postgres_version

  administrator_login    = var.username
  administrator_password = random_password.root.result

  sku_name     = var.sku_name
  storage_mb   = var.storage_mb
  storage_tier = var.storage_tier

  # VNet-injected: no public endpoint, resolvable only through the private DNS zone.
  delegated_subnet_id           = var.subnet_id
  private_dns_zone_id           = var.private_dns_zone_id
  public_network_access_enabled = false

  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup

  zone = var.availability_zone

  dynamic "high_availability" {
    for_each = var.high_availability ? [1] : []
    content {
      mode                      = "ZoneRedundant"
      standby_availability_zone = var.standby_availability_zone
    }
  }

  maintenance_window {
    day_of_week  = var.maintenance_day
    start_hour   = var.maintenance_hour
    start_minute = 0
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      administrator_password,
      # Azure picks a zone when none is given; letting a later plan move the
      # server between zones would force a rebuild.
      zone,
    ]
  }
}

# Flexible Server refuses CREATE EXTENSION for anything not on this allowlist.
# The platform migrations create vector, uuid-ossp, and pg_trgm — omit any of them
# and the backend fails on first startup with a permission error, not a clear one.
resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = join(",", var.allowed_extensions)
}

resource "azurerm_postgresql_flexible_server_configuration" "max_connections" {
  name      = "max_connections"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = tostring(var.max_connections)
}

resource "azurerm_postgresql_flexible_server_configuration" "extra" {
  for_each = var.server_configurations

  name      = each.key
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = each.value
}

resource "azurerm_postgresql_flexible_server_database" "databases" {
  for_each = toset(var.databases)

  name      = each.value
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = "UTF8"
  collation = "en_US.utf8"

  lifecycle {
    prevent_destroy = true
  }
}
