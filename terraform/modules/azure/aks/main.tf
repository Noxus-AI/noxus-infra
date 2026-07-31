resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = var.cluster_name

  kubernetes_version        = var.kubernetes_version
  sku_tier                  = var.sku_tier
  automatic_upgrade_channel = var.upgrade_channel

  # Workload Identity is how pods reach Blob Storage without static keys. OIDC
  # issuance is a prerequisite and cannot be turned on later without a rebuild in
  # some configurations, so it is always enabled here.
  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  local_account_disabled            = var.disable_local_accounts
  role_based_access_control_enabled = true

  dynamic "azure_active_directory_role_based_access_control" {
    for_each = length(var.admin_group_object_ids) > 0 ? [1] : []
    content {
      admin_group_object_ids = var.admin_group_object_ids
      azure_rbac_enabled     = var.azure_rbac_enabled
    }
  }

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_pool.vm_size
    node_count                   = var.system_pool.auto_scaling_enabled ? null : var.system_pool.node_count
    auto_scaling_enabled         = var.system_pool.auto_scaling_enabled
    min_count                    = var.system_pool.auto_scaling_enabled ? var.system_pool.min_count : null
    max_count                    = var.system_pool.auto_scaling_enabled ? var.system_pool.max_count : null
    max_pods                     = var.system_pool.max_pods
    os_disk_size_gb              = var.system_pool.os_disk_size_gb
    vnet_subnet_id               = var.subnet_id
    zones                        = var.availability_zones
    only_critical_addons_enabled = var.dedicated_system_pool

    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = var.network_plugin_mode
    network_policy      = var.network_policy
    load_balancer_sku   = "standard"
    # Egress goes out the NAT gateway attached to the node subnet, giving a
    # stable allowlistable IP rather than a rotating outbound pool.
    outbound_type  = var.enable_nat_gateway ? "userAssignedNATGateway" : "loadBalancer"
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip
  }

  dynamic "oms_agent" {
    for_each = var.log_analytics_workspace_id != "" ? [1] : []
    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }

  monitor_metrics {
    annotations_allowed = null
    labels_allowed      = null
  }

  dynamic "web_app_routing" {
    for_each = var.enable_web_app_routing ? [1] : []
    content {
      dns_zone_ids = var.dns_zone_ids
    }
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      # The autoscaler owns this after creation.
      default_node_pool[0].node_count,
      kubernetes_version,
    ]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "pools" {
  for_each = var.node_pools

  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id

  vm_size              = each.value.vm_size
  node_count           = each.value.auto_scaling_enabled ? null : each.value.node_count
  auto_scaling_enabled = each.value.auto_scaling_enabled
  min_count            = each.value.auto_scaling_enabled ? each.value.min_count : null
  max_count            = each.value.auto_scaling_enabled ? each.value.max_count : null
  max_pods             = each.value.max_pods
  os_disk_size_gb      = each.value.os_disk_size_gb
  vnet_subnet_id       = var.subnet_id
  zones                = var.availability_zones
  priority             = each.value.spot ? "Spot" : "Regular"
  eviction_policy      = each.value.spot ? "Delete" : null
  spot_max_price       = each.value.spot ? -1 : null

  node_labels = each.value.labels
  node_taints = each.value.taints

  upgrade_settings {
    max_surge = "33%"
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [node_count]
  }
}

# User-assigned identity federated to the platform's Kubernetes ServiceAccount.
# This is the Azure equivalent of IRSA — the chart annotates its SA with the
# client ID and pods exchange the projected token for Azure credentials.
resource "azurerm_user_assigned_identity" "platform" {
  count = var.create_workload_identity ? 1 : 0

  name                = "${var.cluster_name}-platform"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "platform" {
  count = var.create_workload_identity ? 1 : 0

  name                = "${var.cluster_name}-platform"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.platform[0].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.this.oidc_issuer_url
  subject             = "system:serviceaccount:${var.platform_namespace}:${var.platform_service_account}"
}

resource "azurerm_role_assignment" "platform_storage" {
  count = var.create_workload_identity && var.storage_account_id != "" ? 1 : 0

  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.platform[0].principal_id
}
