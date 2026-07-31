resource "random_string" "suffix" {
  count = var.account_suffix == "" ? 1 : 0

  length  = 6
  upper   = false
  special = false
}

locals {
  # Storage account names are globally unique, lowercase alphanumeric, 3-24 chars.
  suffix       = var.account_suffix != "" ? var.account_suffix : random_string.suffix[0].result
  account_name = substr(replace(lower("${var.name}${local.suffix}"), "/[^a-z0-9]/", ""), 0, 24)
}

resource "azurerm_storage_account" "this" {
  name                = local.account_name
  resource_group_name = var.resource_group_name
  location            = var.location

  account_tier             = "Standard"
  account_replication_type = var.replication_type
  account_kind             = "StorageV2"

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = var.public_read
  shared_access_key_enabled       = true

  blob_properties {
    versioning_enabled = var.versioning_enabled

    dynamic "delete_retention_policy" {
      for_each = var.soft_delete_retention_days > 0 ? [1] : []
      content {
        days = var.soft_delete_retention_days
      }
    }

    dynamic "cors_rule" {
      for_each = length(var.cors_allowed_origins) > 0 ? [1] : []
      content {
        allowed_origins    = var.cors_allowed_origins
        allowed_methods    = ["GET", "PUT", "POST", "HEAD"]
        allowed_headers    = ["*"]
        exposed_headers    = ["*"]
        max_age_in_seconds = 3000
      }
    }
  }

  dynamic "network_rules" {
    for_each = length(var.allowed_subnet_ids) > 0 ? [1] : []
    content {
      default_action             = "Deny"
      bypass                     = ["AzureServices"]
      virtual_network_subnet_ids = var.allowed_subnet_ids
      ip_rules                   = var.allowed_ip_rules
    }
  }

  tags = var.tags
}

resource "azurerm_storage_container" "private" {
  name                  = var.private_container_name
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "public" {
  name               = var.public_container_name
  storage_account_id = azurerm_storage_account.this.id
  # "blob" allows anonymous reads of individual objects but not container listing.
  container_access_type = var.public_read ? "blob" : "private"
}
