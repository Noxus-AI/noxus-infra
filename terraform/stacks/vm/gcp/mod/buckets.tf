
resource "random_id" "bucket" {
  byte_length = 8
}

resource "google_storage_bucket" "noxus" {
  name          = "${var.goog_cm_deployment_name}-noxus-${random_id.bucket.hex}"
  location      = var.region
  force_destroy = true
}

resource "google_storage_bucket_iam_member" "noxus" {
  bucket = google_storage_bucket.noxus.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.logging.email}"
}
