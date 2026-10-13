# Three identities, scoped to what each service touches.
#
#   platform  backend, worker, relay: Vertex AI, the platform bucket, its secrets
#   frontend  the two Auth0 secrets, nothing else
#   sandbox   its own bucket and the control-plane key, nothing else

resource "google_service_account" "platform" {
  account_id   = "${local.prefix}-platform"
  display_name = "Noxus backend, worker and relay"

  depends_on = [google_project_service.enabled]
}

resource "google_service_account" "frontend" {
  account_id   = "${local.prefix}-frontend"
  display_name = "Noxus frontend"

  depends_on = [google_project_service.enabled]
}

resource "google_service_account" "sandbox" {
  count = var.deploy_sandbox ? 1 : 0

  account_id   = "${local.prefix}-sandbox"
  display_name = "Noxus agent sandbox"

  depends_on = [google_project_service.enabled]
}

# Gemini and embedding models through Vertex AI, as this service account.
resource "google_project_iam_member" "platform_vertex" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = google_service_account.platform.member
}

resource "google_storage_bucket_iam_member" "platform" {
  bucket = google_storage_bucket.platform.name
  role   = "roles/storage.admin"
  member = google_service_account.platform.member
}

resource "google_storage_bucket_iam_member" "sandbox" {
  count = var.deploy_sandbox ? 1 : 0

  bucket = google_storage_bucket.sandbox[0].name
  role   = "roles/storage.admin"
  member = google_service_account.sandbox[0].member
}

locals {
  secret_readers = merge(
    { for name in distinct(values(local.platform_secret_env)) : "platform/${name}" => { secret = name, member = google_service_account.platform.member } },
    { for name in values(local.frontend_secret_env) : "frontend/${name}" => { secret = name, member = google_service_account.frontend.member } },
    var.deploy_sandbox ? { for name in values(local.sandbox_secret_env) : "sandbox/${name}" => { secret = name, member = google_service_account.sandbox[0].member } } : {},
  )
}

resource "google_secret_manager_secret_iam_member" "readers" {
  for_each = local.secret_readers

  secret_id = google_secret_manager_secret.platform[each.value.secret].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value.member
}
