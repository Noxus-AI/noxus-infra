output "host" {
  description = "Cache hostname. This is the value the chart's secrets.REDIS_URL expects."
  value       = azurerm_redis_cache.this.hostname
}

output "port" {
  description = "Port the platform should use — 6380 for TLS, which is the default here. Set this as env.REDIS_PORT."
  value       = var.enable_non_ssl_port ? azurerm_redis_cache.this.port : azurerm_redis_cache.this.ssl_port
}

output "tls" {
  description = "Whether the platform must connect over TLS. Set as env.REDIS_SSL."
  value       = !var.enable_non_ssl_port
}

output "primary_access_key" {
  description = "Primary access key. Set as the chart's secrets.REDIS_PASSWORD."
  value       = azurerm_redis_cache.this.primary_access_key
  sensitive   = true
}
