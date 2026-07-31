# Supply the state storage account at init time:
#
#   tofu init \
#     -backend-config="resource_group_name=tfstate-rg" \
#     -backend-config="storage_account_name=mytfstate" \
#     -backend-config="container_name=tfstate" \
#     -backend-config="key=noxus/prod/azure-aks.tfstate"
terraform {
  backend "azurerm" {}
}
