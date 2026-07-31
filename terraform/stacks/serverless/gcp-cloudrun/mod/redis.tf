resource "google_redis_instance" "redis_instance" {
  name               = "${var.goog_cm_deployment_name}-noxus-redis-service"
  memory_size_gb     = 18
  region             = var.region
  tier               = "BASIC"
  authorized_network = google_compute_network.vpc_network.id
  project            = var.project_id
}
