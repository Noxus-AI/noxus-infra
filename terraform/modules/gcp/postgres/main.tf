resource "random_password" "root" {
  length  = 32
  special = false
}

resource "google_sql_database_instance" "this" {
  name    = "${var.name}-postgres"
  project = var.project_id
  region  = var.region

  # pgvector is available on Cloud SQL from PostgreSQL 15 on. The platform
  # migrations run CREATE EXTENSION vector, so an older major fails on first boot.
  database_version = var.database_version

  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    availability_type = var.high_availability ? "REGIONAL" : "ZONAL"
    disk_type         = "PD_SSD"
    disk_size         = var.disk_size_gb
    disk_autoresize   = true

    edition = var.edition

    ip_configuration {
      # No public IP: the instance is only reachable over the VPC peering created
      # by the network module.
      ipv4_enabled                                  = false
      private_network                               = var.network_id
      enable_private_path_for_google_cloud_services = true
      ssl_mode                                      = "ENCRYPTED_ONLY"
    }

    backup_configuration {
      enabled                        = true
      start_time                     = var.backup_start_time
      point_in_time_recovery_enabled = var.point_in_time_recovery
      transaction_log_retention_days = var.transaction_log_retention_days

      backup_retention_settings {
        retained_backups = var.retained_backups
        retention_unit   = "COUNT"
      }
    }

    maintenance_window {
      day          = var.maintenance_day
      hour         = var.maintenance_hour
      update_track = "stable"
    }

    insights_config {
      query_insights_enabled  = true
      record_application_tags = true
      record_client_address   = false
    }

    dynamic "database_flags" {
      for_each = var.database_flags
      content {
        name  = database_flags.key
        value = database_flags.value
      }
    }

    user_labels = var.labels
  }

  depends_on = [var.private_service_access_connection]
}

resource "google_sql_user" "this" {
  name     = var.username
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  password = random_password.root.result
}

# The platform expects these four databases. spot and vectors additionally need
# the vector extension, which Terraform cannot create — run
# scripts/bootstrap-postgres.sh once the instance is reachable.
resource "google_sql_database" "databases" {
  for_each = toset(var.databases)

  name     = each.value
  project  = var.project_id
  instance = google_sql_database_instance.this.name
}
