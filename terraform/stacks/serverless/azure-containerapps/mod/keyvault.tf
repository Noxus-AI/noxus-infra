locals {
  # Key Vault names are capped at 24 characters and cannot contain consecutive
  # or trailing hyphens.
  key_vault_name = "${trimsuffix(substr(var.deployment_name, 0, 20), "-")}-kv"
}

resource "azurerm_key_vault" "main" {
  count                      = var.use_managed_identity ? 1 : 0
  name                       = local.key_vault_name
  location                   = local.location
  resource_group_name        = local.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = false
  soft_delete_retention_days = 7
  tags                       = var.tags
}

resource "azurerm_role_assignment" "keyvault_admin" {
  count                = var.use_managed_identity ? 1 : 0
  scope                = azurerm_key_vault.main[0].id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_secret" "app" {
  for_each = var.use_managed_identity ? local.secret_env : {}

  name         = each.value
  value        = local.secret_values[each.key]
  key_vault_id = azurerm_key_vault.main[0].id

  depends_on = [azurerm_role_assignment.keyvault_admin]
}

locals {
  key_vault_secret_ids = { for k, v in azurerm_key_vault_secret.app : k => v.id }
}
