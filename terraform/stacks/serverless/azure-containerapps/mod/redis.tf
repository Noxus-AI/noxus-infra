resource "azurerm_redis_cache" "main" {
  name                          = "${var.deployment_name}-redis"
  location                      = local.location
  resource_group_name           = local.resource_group_name
  capacity                      = var.redis_capacity
  family                        = "P"
  sku_name                      = "Premium"
  non_ssl_port_enabled          = false
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false

  subnet_id = azurerm_subnet.redis.id

  redis_configuration {
    maxmemory_policy = "allkeys-lru"
  }

  tags = var.tags
}
