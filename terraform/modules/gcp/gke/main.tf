resource "google_container_cluster" "this" {
  name     = var.cluster_name
  project  = var.project_id
  location = var.regional ? var.region : var.zone

  network    = var.network_id
  subnetwork = var.subnet_id

  # Terraform cannot create a cluster with no node pool, so the default pool is
  # created and immediately removed; real capacity comes from the pools below (or
  # from Autopilot, which manages nodes itself).
  remove_default_node_pool = var.enable_autopilot ? null : true
  initial_node_count       = var.enable_autopilot ? null : 1

  enable_autopilot = var.enable_autopilot ? true : null

  deletion_protection = var.deletion_protection

  min_master_version = var.kubernetes_version
  release_channel {
    channel = var.release_channel
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.private_endpoint
    master_ipv4_cidr_block  = var.enable_autopilot ? null : var.master_cidr
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  # Workload Identity is how pods get GCS and Vertex AI access without static keys.
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    gcs_fuse_csi_driver_config {
      enabled = true
    }
  }

  logging_config {
    enable_components = var.logging_components
  }

  monitoring_config {
    enable_components = var.monitoring_components
    managed_prometheus {
      enabled = var.managed_prometheus
    }
  }

  maintenance_policy {
    recurring_window {
      start_time = var.maintenance_start_time
      end_time   = var.maintenance_end_time
      recurrence = var.maintenance_recurrence
    }
  }

  resource_labels = var.labels

  lifecycle {
    ignore_changes = [
      # GKE rewrites this after Autopilot or channel upgrades; a plan should not
      # try to drag the cluster back to the pinned minimum every run.
      min_master_version,
    ]
  }
}

resource "google_service_account" "nodes" {
  count = var.enable_autopilot ? 0 : 1

  account_id   = "${var.cluster_name}-nodes"
  project      = var.project_id
  display_name = "GKE nodes for ${var.cluster_name}"
}

resource "google_project_iam_member" "nodes" {
  for_each = var.enable_autopilot ? toset([]) : toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.nodes[0].email}"
}

resource "google_container_node_pool" "pools" {
  for_each = var.enable_autopilot ? {} : var.node_pools

  name     = each.key
  project  = var.project_id
  cluster  = google_container_cluster.this.name
  location = google_container_cluster.this.location

  initial_node_count = each.value.initial_node_count

  autoscaling {
    min_node_count = each.value.min_node_count
    max_node_count = each.value.max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type = each.value.machine_type
    disk_size_gb = each.value.disk_size_gb
    disk_type    = each.value.disk_type
    spot         = each.value.spot

    service_account = google_service_account.nodes[0].email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = each.value.labels
    tags   = each.value.tags

    dynamic "taint" {
      for_each = each.value.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  lifecycle {
    ignore_changes = [initial_node_count]
  }
}
