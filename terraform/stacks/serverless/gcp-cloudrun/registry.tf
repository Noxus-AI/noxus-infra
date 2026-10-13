# A remote repository is a pull-through cache: the first pull of a tag fetches
# it from Docker Hub with the Noxus-issued token and keeps a copy in this
# project. Cloud Run only ever pulls from here. The fetch happens on Google's
# side, so it needs no egress from the VPC.

resource "google_project_service_identity" "artifactregistry" {
  count    = local.create_registry ? 1 : 0
  provider = google-beta

  project = var.project_id
  service = "artifactregistry.googleapis.com"

  depends_on = [google_project_service.enabled]
}

resource "google_secret_manager_secret" "docker_hub_token" {
  count = local.create_registry ? 1 : 0

  secret_id = "${local.prefix}-docker-hub-token"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  depends_on = [google_project_service.enabled]
}

resource "google_secret_manager_secret_version" "docker_hub_token" {
  count = local.create_registry ? 1 : 0

  secret      = google_secret_manager_secret.docker_hub_token[0].id
  secret_data = var.docker_hub_token
}

resource "google_secret_manager_secret_iam_member" "docker_hub_token" {
  count = local.create_registry ? 1 : 0

  secret_id = google_secret_manager_secret.docker_hub_token[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_project_service_identity.artifactregistry[0].email}"
}

resource "google_artifact_registry_repository" "images" {
  count = local.create_registry ? 1 : 0

  location      = var.region
  repository_id = "${local.prefix}-images"
  description   = "Pull-through cache of the noxusai images on Docker Hub"
  format        = "DOCKER"
  mode          = "REMOTE_REPOSITORY"

  remote_repository_config {
    description                 = "Docker Hub"
    disable_upstream_validation = true

    docker_repository {
      public_repository = "DOCKER_HUB"
    }

    upstream_credentials {
      username_password_credentials {
        username = var.docker_hub_username
        # A new token is a new secret version, which replaces this repository
        # and empties its cache. Cloud Run re-pulls on the next deploy.
        password_secret_version = google_secret_manager_secret_version.docker_hub_token[0].name
      }
    }
  }

  lifecycle {
    precondition {
      condition     = nonsensitive(var.docker_hub_token != "")
      error_message = "docker_hub_token is required unless image_registry points at an existing mirror."
    }
  }

  depends_on = [google_secret_manager_secret_iam_member.docker_hub_token]
}
