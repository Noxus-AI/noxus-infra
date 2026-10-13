resource "google_redis_instance" "main" {
  name               = "${local.prefix}-redis"
  tier               = "BASIC"
  memory_size_gb     = var.redis_memory_size_gb
  region             = var.region
  redis_version      = "REDIS_7_2"
  authorized_network = local.network_id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  depends_on = [
    google_project_service.enabled,
    google_service_networking_connection.private_service_access,
  ]
}
