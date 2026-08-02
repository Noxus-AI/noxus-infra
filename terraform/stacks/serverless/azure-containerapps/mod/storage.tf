resource "random_id" "storage" {
  byte_length = 4
}

locals {
  # Storage account names are 3-24 lowercase alphanumerics with no hyphens.
  storage_account_name = "${substr(replace(lower(var.deployment_name), "-", ""), 0, 14)}sa${random_id.storage.hex}"
}

resource "azurerm_storage_account" "main" {
  name                            = local.storage_account_name
  location                        = local.location
  resource_group_name             = local.resource_group_name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  tags                            = var.tags
}

# AzureBlobStorageClient hardcodes the container name and derives the account
# host from SPOTFLOW_STORAGE_BUCKET, so this name is not free-form.
resource "azurerm_storage_container" "noxus" {
  name                  = "noxus"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}
