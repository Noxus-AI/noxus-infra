output "account_name" {
  description = "Storage account name. With BUCKET_CLIENT=azure this is what SPOTFLOW_STORAGE_BUCKET is set to — the client derives the blob endpoint from it."
  value       = azurerm_storage_account.this.name
}

output "blob_endpoint" {
  description = "Blob service endpoint, for reference. Blob Storage exposes no S3-compatible API, so this is not an S3_ENDPOINT_URL — use BUCKET_CLIENT=azure instead."
  value       = azurerm_storage_account.this.primary_blob_endpoint
}

output "private_container" {
  description = "Private container name — set as env.SPOTFLOW_STORAGE_BUCKET."
  value       = azurerm_storage_container.private.name
}

output "public_container" {
  description = "Public container name — set as env.SPOTFLOW_PUBLIC_STORAGE_BUCKET."
  value       = azurerm_storage_container.public.name
}

output "access_key" {
  description = "Primary access key. Set as the chart's secrets.AZURE_STORAGE_ACCOUNT_KEY."
  value       = azurerm_storage_account.this.primary_access_key
  sensitive   = true
}

output "account_id" {
  description = "Resource ID of the account, for role assignments."
  value       = azurerm_storage_account.this.id
}
