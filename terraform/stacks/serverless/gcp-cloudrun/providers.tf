provider "google" {
  project        = var.project_id
  region         = var.region
  default_labels = local.labels
}

# Only used to materialise the Artifact Registry service agent before granting it
# access to the Docker Hub token.
provider "google-beta" {
  project        = var.project_id
  region         = var.region
  default_labels = local.labels
}
