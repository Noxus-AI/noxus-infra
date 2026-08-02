resource "azurerm_virtual_network" "main" {
  name                = "${var.deployment_name}-vnet"
  location            = local.location
  resource_group_name = local.resource_group_name
  address_space       = ["10.0.0.0/16"]
  tags                = var.tags
}

# Workload profile environments require a dedicated subnet of at least /27;
# /21 leaves room for the environment to scale out its infrastructure nodes.
resource "azurerm_subnet" "container_apps" {
  name                 = "${var.deployment_name}-container-apps-subnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.0.0/21"]

  delegation {
    name = "container-apps-delegation"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "postgres" {
  count                = var.deploy_postgres ? 1 : 0
  name                 = "${var.deployment_name}-postgres-subnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.8.0/24"]

  delegation {
    name = "postgres-delegation"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "redis" {
  name                 = "${var.deployment_name}-redis-subnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.9.0/24"]
}

resource "azurerm_private_dns_zone" "postgres" {
  count               = var.deploy_postgres ? 1 : 0
  name                = "${var.deployment_name}.postgres.database.azure.com"
  resource_group_name = local.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  count                 = var.deploy_postgres ? 1 : 0
  name                  = "${var.deployment_name}-postgres-dns-link"
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres[0].name
  virtual_network_id    = azurerm_virtual_network.main.id
  tags                  = var.tags
}
