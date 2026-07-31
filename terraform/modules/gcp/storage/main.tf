resource "random_id" "suffix" {
  count = var.bucket_suffix == "" ? 1 : 0

  byte_length = 4
}

locals {
  # GCS bucket names are globally unique.
  suffix = var.bucket_suffix != "" ? var.bucket_suffix : random_id.suffix[0].hex

  private_bucket_name = "${var.name}-artifacts-${local.suffix}"
  public_bucket_name  = "${var.name}-artifacts-public-${local.suffix}"
}

resource "google_storage_bucket" "private" {
  name     = local.private_bucket_name
  project  = var.project_id
  location = var.location

  force_destroy               = var.force_destroy
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = var.versioning_enabled
  }

  dynamic "lifecycle_rule" {
    for_each = var.noncurrent_version_expiration_days > 0 ? [1] : []
    content {
      condition {
        days_since_noncurrent_time = var.noncurrent_version_expiration_days
        with_state                 = "ARCHIVED"
      }
      action {
        type = "Delete"
      }
    }
  }

  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }

  dynamic "cors" {
    for_each = length(var.cors_allowed_origins) > 0 ? [1] : []
    content {
      origin          = var.cors_allowed_origins
      method          = ["GET", "PUT", "POST", "HEAD"]
      response_header = ["*"]
      max_age_seconds = 3000
    }
  }

  dynamic "encryption" {
    for_each = var.kms_key_name != null ? [1] : []
    content {
      default_kms_key_name = var.kms_key_name
    }
  }

  labels = var.labels
}

# Whitelabel and integration assets. Kept private by default — the app can presign
# instead. public_read opens anonymous reads on every object in the bucket, which
# is only appropriate when you front it with a CDN and treat its contents as public.
resource "google_storage_bucket" "public" {
  name     = local.public_bucket_name
  project  = var.project_id
  location = var.location

  force_destroy               = var.force_destroy
  uniform_bucket_level_access = true
  public_access_prevention    = var.public_read ? "inherited" : "enforced"

  dynamic "cors" {
    for_each = length(var.cors_allowed_origins) > 0 ? [1] : []
    content {
      origin          = var.cors_allowed_origins
      method          = ["GET", "HEAD"]
      response_header = ["*"]
      max_age_seconds = 3000
    }
  }

  labels = var.labels
}

resource "google_storage_bucket_iam_member" "public_read" {
  count = var.public_read ? 1 : 0

  bucket = google_storage_bucket.public.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# Bind the platform's Kubernetes ServiceAccount to a Google service account that
# can read and write both buckets. This is what makes BUCKET_CLIENT=gcloud work
# without static keys in the values file.
resource "google_service_account" "platform" {
  count = var.create_service_account ? 1 : 0

  account_id   = "${var.name}-platform"
  project      = var.project_id
  display_name = "Noxus platform pods (${var.name})"
}

resource "google_storage_bucket_iam_member" "platform_private" {
  count = var.create_service_account ? 1 : 0

  bucket = google_storage_bucket.private.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.platform[0].email}"
}

resource "google_storage_bucket_iam_member" "platform_public" {
  count = var.create_service_account ? 1 : 0

  bucket = google_storage_bucket.public.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.platform[0].email}"
}

resource "google_service_account_iam_member" "workload_identity" {
  count = var.create_service_account && var.workload_identity_member != "" ? 1 : 0

  service_account_id = google_service_account.platform[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = var.workload_identity_member
}

# Vertex AI as an LLM provider runs under the same identity.
resource "google_project_iam_member" "vertex_ai" {
  count = var.create_service_account && var.grant_vertex_ai ? 1 : 0

  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.platform[0].email}"
}
