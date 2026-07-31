terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.google_project_id
}

# Create a service account for Gemini API access
resource "google_service_account" "gemini" {
  account_id   = "${local.name_prefix}-gemini"
  display_name = "Service Account for Gemini API access"
  description  = "Used for accessing Google's Gemini API"
}

# Create a service account key
resource "google_service_account_key" "gemini" {
  service_account_id = google_service_account.gemini.name
}

# Grant Vertex AI User role to the service account
resource "google_project_iam_member" "gemini_vertexai" {
  project = var.google_project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.gemini.email}"
}
