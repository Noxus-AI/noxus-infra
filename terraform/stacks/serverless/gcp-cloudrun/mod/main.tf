provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

resource "google_project_service" "cloudresourcemanager_api" {
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
  project            = var.project_id
}

resource "google_project_service" "service_networking" {
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
  project            = var.project_id
  depends_on         = [google_project_service.cloudresourcemanager_api]
}

resource "google_project_service" "aiplatform_api" {
  service            = "aiplatform.googleapis.com"
  disable_on_destroy = false
  project            = var.project_id
  depends_on         = [google_project_service.service_networking]
}

resource "google_project_service" "vpcaccess_api" {
  service            = "vpcaccess.googleapis.com"
  disable_on_destroy = false
  project            = var.project_id
  depends_on         = [google_project_service.aiplatform_api]
}

resource "google_project_service" "secretmanager_api" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
  project            = var.project_id
  depends_on         = [google_project_service.vpcaccess_api]
}

resource "google_project_service" "gcr_api" {
  service            = "containerregistry.googleapis.com"
  disable_on_destroy = false
  project            = var.project_id
  depends_on         = [google_project_service.secretmanager_api]
}

resource "google_project_service" "redis_api" {
  service            = "redis.googleapis.com"
  disable_on_destroy = false
  project            = var.project_id
  depends_on         = [google_project_service.gcr_api]
}
