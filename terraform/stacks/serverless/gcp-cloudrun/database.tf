resource "google_sql_database_instance" "main" {
  # Cloud SQL reserves a deleted instance's name for about a week; the suffix
  # lets a destroyed deployment be recreated straight away.
  name                = "${local.prefix}-postgres-${random_id.suffix.hex}"
  database_version    = "POSTGRES_15"
  region              = var.region
  deletion_protection = var.deletion_protection

  settings {
    tier              = var.database.tier
    edition           = "ENTERPRISE"
    availability_type = "ZONAL"
    disk_type         = "PD_SSD"
    disk_size         = var.database.disk_size_gb
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled    = false
      private_network = local.network_id
    }

    backup_configuration {
      enabled    = true
      start_time = "02:00"
    }

    maintenance_window {
      day  = 7
      hour = 3
    }

    # The backend and every worker process keep their own connection pools.
    database_flags {
      name  = "max_connections"
      value = tostring(var.database.max_connections)
    }
  }

  depends_on = [
    google_project_service.enabled,
    google_service_networking_connection.private_service_access,
  ]
}

# Built-in Cloud SQL users belong to cloudsqlsuperuser, which is what the
# platform needs on first boot: it creates its own databases (spot, vectors,
# procrastinate, spot_userdata) and the vector and postgres_fdw extensions.
# No special characters: a ":word" sequence in the password breaks the Tables
# foreign-data-wrapper setup.
resource "random_password" "database" {
  length  = 32
  special = false
}

resource "google_sql_user" "noxus" {
  name     = "noxus"
  instance = google_sql_database_instance.main.name
  password = random_password.database.result

  # The user owns every platform database, so Postgres refuses to drop it.
  deletion_policy = "ABANDON"
}

locals {
  # No scheme and no database name: the platform adds both.
  postgresql_url = "${google_sql_user.noxus.name}:${random_password.database.result}@${google_sql_database_instance.main.private_ip_address}:5432"
}
