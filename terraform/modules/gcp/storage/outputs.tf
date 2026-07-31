output "private_bucket" {
  description = "Private bucket name — set as env.SPOTFLOW_STORAGE_BUCKET."
  value       = google_storage_bucket.private.name
}

output "public_bucket" {
  description = "Public assets bucket name — set as env.SPOTFLOW_PUBLIC_STORAGE_BUCKET."
  value       = google_storage_bucket.public.name
}

output "service_account_email" {
  description = "Google service account the platform pods impersonate, or empty when not created."
  value       = var.create_service_account ? google_service_account.platform[0].email : ""
}

output "helm_service_account_annotation" {
  description = "Set as serviceAccount.annotations in the noxus-platform values so Workload Identity binds the GSA to the pods."
  value = var.create_service_account ? {
    "iam.gke.io/gcp-service-account" = google_service_account.platform[0].email
  } : {}
}
