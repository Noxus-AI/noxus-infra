resource "google_storage_bucket" "platform" {
  name                        = "${local.prefix}-files-${random_id.suffix.hex}"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = !var.deletion_protection

  depends_on = [google_project_service.enabled]
}

# Persistent sandbox state is synced here. A bucket of its own keeps code
# running in a sandbox away from platform files.
resource "google_storage_bucket" "sandbox" {
  count = var.deploy_sandbox ? 1 : 0

  name                        = "${local.prefix}-sandbox-${random_id.suffix.hex}"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = !var.deletion_protection

  depends_on = [google_project_service.enabled]
}
