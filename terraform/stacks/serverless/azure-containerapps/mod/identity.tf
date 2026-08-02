resource "azurerm_user_assigned_identity" "main" {
  count               = var.use_managed_identity ? 1 : 0
  name                = "${var.deployment_name}-identity"
  location            = local.location
  resource_group_name = local.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  count                = var.use_managed_identity ? 1 : 0
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.main[0].principal_id
}

resource "azurerm_role_assignment" "keyvault_secrets_user" {
  count                = var.use_managed_identity ? 1 : 0
  scope                = azurerm_key_vault.main[0].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.main[0].principal_id
}

resource "azurerm_role_assignment" "storage_blob_contributor" {
  count                = var.use_managed_identity ? 1 : 0
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.main[0].principal_id
}

locals {
  # one() yields null when the identity is disabled, avoiding an index into a
  # zero-instance resource.
  identity_id = one(azurerm_user_assigned_identity.main[*].id)
}
