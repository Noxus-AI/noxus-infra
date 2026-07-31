output "account_name" {
  description = "Storage account name. Also the S3-compatible access key ID."
  value       = azurerm_storage_account.this.name
}

output "blob_endpoint" {
  description = "Blob service endpoint. Set as env.S3_ENDPOINT_URL, since the platform reaches Blob Storage through its S3-compatible path."
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
  description = "Primary access key. Set as the chart's secrets.S3_SECRET_ACCESS_KEY, with account_name as S3_ACCESS_KEY_ID."
  value       = azurerm_storage_account.this.primary_access_key
  sensitive   = true
}

output "account_id" {
  description = "Resource ID of the account, for role assignments."
  value       = azurerm_storage_account.this.id
}
