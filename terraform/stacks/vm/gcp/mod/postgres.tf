resource "random_password" "postgres_root_password" {
  length  = 32
  special = false
  upper   = true
  lower   = true
  numeric = true
}

resource "google_sql_database_instance" "postgresql_instance" {
  count            = var.deploy_postgres ? 1 : 0
  name             = "${var.goog_cm_deployment_name}-noxus-postgres-service"
  database_version = "POSTGRES_15"
  region           = var.region
  project          = var.project_id

  settings {
    tier              = var.sql_instance_type
    activation_policy = "ALWAYS"
    availability_type = "ZONAL"
    disk_type         = "PD_SSD"
    disk_size         = 100


    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc_network.id
    }

    maintenance_window {
      day  = 1
      hour = 22
    }

    database_flags {
      name  = "max_connections"
      value = "5001"
    }
  }

  root_password       = random_password.postgres_root_password.result
  deletion_protection = false

  lifecycle {
    ignore_changes = [settings[0].maintenance_window]
  }

  depends_on = [google_service_networking_connection.private_vpc_connection[0]]
}

resource "google_sql_database" "noxus_database" {
  count    = var.deploy_postgres ? 1 : 0
  name     = "spot"
  instance = google_sql_database_instance.postgresql_instance[0].name
  project  = var.project_id
}
