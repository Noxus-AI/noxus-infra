resource "google_redis_instance" "this" {
  name    = "${var.name}-redis"
  project = var.project_id
  region  = var.region

  tier           = var.high_availability ? "STANDARD_HA" : "BASIC"
  memory_size_gb = var.memory_size_gb
  redis_version  = var.redis_version

  authorized_network      = var.network_id
  connect_mode            = "PRIVATE_SERVICE_ACCESS"
  auth_enabled            = var.auth_enabled
  transit_encryption_mode = var.transit_encryption ? "SERVER_AUTHENTICATION" : "DISABLED"

  # The platform uses Redis as a cache plus queue-coordination store. Evicting
  # under pressure keeps it serving; the alternative is OOM on write, which
  # surfaces as failed runs rather than degraded caching.
  redis_configs = merge(
    { maxmemory-policy = var.maxmemory_policy },
    var.redis_configs,
  )

  maintenance_policy {
    weekly_maintenance_window {
      day = var.maintenance_day
      start_time {
        hours   = var.maintenance_hour
        minutes = 0
      }
    }
  }

  labels = var.labels

  depends_on = [var.private_service_access_connection]
}
