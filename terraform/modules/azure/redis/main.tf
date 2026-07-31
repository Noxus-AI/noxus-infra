resource "azurerm_redis_cache" "this" {
  name                = "${var.name}-redis"
  resource_group_name = var.resource_group_name
  location            = var.location

  sku_name = var.sku_name
  family   = var.sku_name == "Premium" ? "P" : "C"
  capacity = var.capacity

  # Azure Cache for Redis serves TLS on 6380 and refuses plaintext unless you
  # explicitly re-enable 6379. The chart must therefore be told REDIS_PORT=6380
  # and REDIS_SSL=true — see the port and tls outputs.
  non_ssl_port_enabled = var.enable_non_ssl_port
  minimum_tls_version  = "1.2"

  redis_version = var.redis_version

  # Only the Premium SKU can be injected into a VNet. Standard and Basic are
  # reachable over the public endpoint, which is why public access is left on
  # for them and firewall rules do the gating instead.
  subnet_id = var.sku_name == "Premium" ? var.subnet_id : null

  public_network_access_enabled = var.sku_name != "Premium"

  zones = var.sku_name == "Premium" ? var.zones : null

  redis_configuration {
    maxmemory_policy = var.maxmemory_policy
  }

  patch_schedule {
    day_of_week    = var.maintenance_day
    start_hour_utc = var.maintenance_hour
  }

  tags = var.tags
}

resource "azurerm_redis_firewall_rule" "allowed" {
  for_each = var.sku_name == "Premium" ? {} : var.allowed_ip_ranges

  name                = replace(each.key, "-", "_")
  redis_cache_name    = azurerm_redis_cache.this.name
  resource_group_name = var.resource_group_name
  start_ip            = each.value.start_ip
  end_ip              = each.value.end_ip
}
