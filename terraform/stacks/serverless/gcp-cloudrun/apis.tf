resource "google_project_service" "enabled" {
  for_each = toset(concat(
    [
      "aiplatform.googleapis.com",
      "artifactregistry.googleapis.com",
      "cloudresourcemanager.googleapis.com",
      "compute.googleapis.com",
      "iam.googleapis.com",
      "redis.googleapis.com",
      "run.googleapis.com",
      "secretmanager.googleapis.com",
      "servicenetworking.googleapis.com",
      "sqladmin.googleapis.com",
    ],
    var.dns_managed_zone != "" ? ["dns.googleapis.com"] : [],
  ))

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
