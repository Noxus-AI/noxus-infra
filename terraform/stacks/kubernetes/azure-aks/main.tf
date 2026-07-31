locals {
  name = "${var.project_name}-${var.environment}"

  tags = merge(
    {
      project     = var.project_name
      environment = var.environment
      managed-by  = "terraform"
    },
    var.tags,
  )

  hostnames = [var.domain, "api.${var.domain}", "relay.${var.domain}"]
}

resource "azurerm_resource_group" "this" {
  count = var.create_resource_group ? 1 : 0

  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

data "azurerm_resource_group" "this" {
  count = var.create_resource_group ? 0 : 1

  name = var.resource_group_name
}

locals {
  resource_group_name = var.create_resource_group ? azurerm_resource_group.this[0].name : data.azurerm_resource_group.this[0].name
}

module "network" {
  source = "../../../modules/azure/network"

  name                = local.name
  resource_group_name = local.resource_group_name
  location            = var.location

  vnet_cidr              = var.vnet_cidr
  nodes_cidr             = var.nodes_cidr
  postgres_cidr          = var.postgres_cidr
  private_endpoints_cidr = var.private_endpoints_cidr

  tags = local.tags
}

module "storage" {
  source = "../../../modules/azure/storage"

  name                = replace(local.name, "-", "")
  resource_group_name = local.resource_group_name
  location            = var.location

  replication_type     = var.environment == "prod" ? "ZRS" : "LRS"
  cors_allowed_origins = ["https://${var.domain}"]

  tags = local.tags
}

module "aks" {
  source = "../../../modules/azure/aks"

  cluster_name        = "${local.name}-aks"
  resource_group_name = local.resource_group_name
  location            = var.location

  subnet_id          = module.network.nodes_subnet_id
  kubernetes_version = var.kubernetes_version
  sku_tier           = var.environment == "prod" ? "Standard" : "Free"

  system_pool = var.system_pool
  node_pools  = var.node_pools

  admin_group_object_ids     = var.admin_group_object_ids
  log_analytics_workspace_id = var.log_analytics_workspace_id

  # The federated credential subject is an exact string; it has to name the same
  # namespace and ServiceAccount the chart will create, or the token exchange
  # fails at runtime with a generic authorization error.
  platform_namespace       = var.namespace
  platform_service_account = var.release_name
  storage_account_id       = module.storage.account_id

  tags = local.tags
}

module "postgres" {
  source = "../../../modules/azure/postgres"

  name                = local.name
  resource_group_name = local.resource_group_name
  location            = var.location

  subnet_id           = module.network.postgres_subnet_id
  private_dns_zone_id = module.network.postgres_private_dns_zone_id

  postgres_version  = var.postgres_version
  sku_name          = var.postgres_sku
  storage_mb        = var.postgres_storage_mb
  storage_tier      = var.postgres_storage_tier
  high_availability = var.environment == "prod"

  tags = local.tags
}

module "redis" {
  source = "../../../modules/azure/redis"

  name                = local.name
  resource_group_name = local.resource_group_name
  location            = var.location

  sku_name  = var.redis_sku
  capacity  = var.redis_capacity
  subnet_id = var.redis_sku == "Premium" ? module.network.private_endpoints_subnet_id : null

  tags = local.tags
}

# --------------------------------------------------------------------------
# Ingress. AKS has no built-in L7 ingress the chart can target, so this installs
# ingress-nginx (bound to a static public IP) and cert-manager. The ClusterIssuer
# is applied out of band — see cluster-issuer.yaml and this stack's README —
# because a Terraform-managed CRD instance would need cluster API access at plan
# time, before the CRD exists.
# --------------------------------------------------------------------------

resource "azurerm_public_ip" "ingress" {
  count = var.install_ingress_nginx ? 1 : 0

  name                = "${local.name}-ingress-ip"
  resource_group_name = local.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

# The kubelet identity, not the cluster identity, is what attaches the load
# balancer to this IP.
resource "azurerm_role_assignment" "ingress_ip" {
  count = var.install_ingress_nginx ? 1 : 0

  scope                = azurerm_public_ip.ingress[0].id
  role_definition_name = "Network Contributor"
  principal_id         = module.aks.kubelet_identity_object_id
}

resource "helm_release" "ingress_nginx" {
  count = var.install_ingress_nginx ? 1 : 0

  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_nginx_chart_version
  namespace        = "ingress-nginx"
  create_namespace = true

  set {
    name  = "controller.service.loadBalancerIP"
    value = azurerm_public_ip.ingress[0].ip_address
  }
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = local.resource_group_name
  }
  # Agent streaming holds long-lived SSE and WebSocket connections; the nginx
  # default read timeout of 60s cuts them mid-response.
  set {
    name  = "controller.config.proxy-read-timeout"
    value = "3600"
  }
  set {
    name  = "controller.config.proxy-send-timeout"
    value = "3600"
  }

  depends_on = [azurerm_role_assignment.ingress_ip]
}

resource "helm_release" "cert_manager" {
  count = var.install_cert_manager ? 1 : 0

  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_chart_version
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "crds.enabled"
    value = "true"
  }
}

resource "azurerm_dns_a_record" "hostnames" {
  for_each = var.dns_zone_name != "" && var.install_ingress_nginx ? toset(local.hostnames) : toset([])

  name                = each.value == var.domain ? "@" : trimsuffix(each.value, ".${var.domain}")
  zone_name           = var.dns_zone_name
  resource_group_name = var.dns_resource_group_name != "" ? var.dns_resource_group_name : local.resource_group_name
  ttl                 = 300
  records             = [azurerm_public_ip.ingress[0].ip_address]
  tags                = local.tags
}

module "noxus" {
  source = "../../../modules/platform/noxus-release"

  release_name = var.release_name
  namespace    = var.namespace

  app_version    = var.app_version
  domain         = var.domain
  admin_email    = var.admin_email
  deployment_env = var.environment

  service_account_annotations = module.aks.helm_service_account_annotation

  database = {
    host     = module.postgres.fqdn
    port     = module.postgres.port
    name     = "spot"
    username = module.postgres.username
    password = module.postgres.password
  }

  redis = {
    host     = module.redis.host
    port     = module.redis.port
    password = module.redis.primary_access_key
    tls      = module.redis.tls
  }

  # Blob Storage is reached through its S3-compatible endpoint, so the account
  # name and access key stand in for the S3 credential pair.
  storage = {
    client            = "s3"
    private_bucket    = module.storage.private_container
    public_bucket     = module.storage.public_container
    endpoint_url      = module.storage.blob_endpoint
    access_key_id     = module.storage.account_name
    secret_access_key = module.storage.access_key
  }

  auth0 = var.auth0

  ingress = {
    enabled    = true
    class_name = "nginx"
    annotations = merge(
      {
        "nginx.ingress.kubernetes.io/proxy-read-timeout" = "3600"
        "nginx.ingress.kubernetes.io/proxy-send-timeout" = "3600"
        "nginx.ingress.kubernetes.io/proxy-body-size"    = "100m"
      },
      var.install_cert_manager ? { "cert-manager.io/cluster-issuer" = var.cluster_issuer_name } : {},
    )
    tls = var.install_cert_manager ? [{
      secretName = "${var.release_name}-tls"
      hosts      = local.hostnames
    }] : []
  }

  pgbouncer_enabled = var.pgbouncer_enabled
  sandbox_enabled   = var.sandbox_enabled

  extra_env     = var.extra_env
  extra_secrets = var.extra_secrets
  extra_values  = var.extra_values

  depends_on = [
    helm_release.ingress_nginx,
    helm_release.cert_manager,
  ]
}
