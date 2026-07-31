variable "project_name" {
  description = "Short project identifier."
  type        = string
  default     = "noxus"
}

variable "environment" {
  description = "Environment name. \"prod\" turns on HA Postgres, the AKS uptime SLA, and zone-redundant storage."
  type        = string
  default     = "prod"
}

variable "resource_group_name" {
  description = "Resource group to deploy into."
  type        = string
}

variable "create_resource_group" {
  description = "Create the resource group. Set false to deploy into one that already exists."
  type        = bool
  default     = true
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "westeurope"
}

variable "domain" {
  description = "Apex domain the platform is served from."
  type        = string
}

variable "dns_zone_name" {
  description = "Azure DNS zone for the domain. Empty skips record creation."
  type        = string
  default     = ""
}

variable "dns_resource_group_name" {
  description = "Resource group holding the DNS zone, when it differs from the deployment group."
  type        = string
  default     = ""
}

variable "admin_email" {
  description = "Email of the first admin user. Also used for Let's Encrypt registration in cluster-issuer.yaml."
  type        = string
}

variable "app_version" {
  description = "Platform version, selecting the container image tags."
  type        = string
}

variable "auth0" {
  description = "Auth0 tenant configuration."
  type = object({
    domain             = string
    api_audience       = string
    client_id          = string
    client_secret      = string
    session_secret     = optional(string)
    mgmt_client_id     = optional(string, "")
    mgmt_client_secret = optional(string, "")
  })
  sensitive = true
}

# --- Networking -----------------------------------------------------------

variable "vnet_cidr" {
  description = "Virtual network address space."
  type        = string
  default     = "10.0.0.0/16"
}

variable "nodes_cidr" {
  description = "Node subnet."
  type        = string
  default     = "10.0.0.0/20"
}

variable "postgres_cidr" {
  description = "Delegated subnet for PostgreSQL Flexible Server."
  type        = string
  default     = "10.0.16.0/24"
}

variable "private_endpoints_cidr" {
  description = "Subnet for private endpoints, including Premium Redis."
  type        = string
  default     = "10.0.17.0/24"
}

# --- Cluster --------------------------------------------------------------

variable "kubernetes_version" {
  description = "AKS version. null takes the region default."
  type        = string
  default     = null
}

variable "system_pool" {
  description = "Default node pool."
  type = object({
    vm_size              = optional(string, "Standard_D4ds_v5")
    node_count           = optional(number, 3)
    auto_scaling_enabled = optional(bool, true)
    min_count            = optional(number, 2)
    max_count            = optional(number, 5)
    max_pods             = optional(number, 60)
    os_disk_size_gb      = optional(number, 128)
  })
  default = {}
}

variable "node_pools" {
  description = "Additional user node pools, e.g. a memory-heavy pool for knowledge-base workers."
  type = map(object({
    vm_size              = optional(string, "Standard_D8ds_v5")
    node_count           = optional(number, 2)
    auto_scaling_enabled = optional(bool, true)
    min_count            = optional(number, 1)
    max_count            = optional(number, 10)
    max_pods             = optional(number, 60)
    os_disk_size_gb      = optional(number, 256)
    spot                 = optional(bool, false)
    labels               = optional(map(string), {})
    taints               = optional(list(string), [])
  }))
  default = {}
}

variable "admin_group_object_ids" {
  description = "Entra ID groups granted cluster-admin."
  type        = list(string)
  default     = []
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace for container logs. Empty disables the agent."
  type        = string
  default     = ""
}

# --- Data stores ----------------------------------------------------------

variable "postgres_version" {
  description = "PostgreSQL major version. 15 or newer, for pgvector."
  type        = string
  default     = "16"
}

variable "postgres_sku" {
  description = "Flexible Server SKU."
  type        = string
  default     = "GP_Standard_D4ds_v5"
}

variable "postgres_storage_mb" {
  description = "Storage in MB. IOPS scale with size, so an undersized disk throttles everything."
  type        = number
  default     = 262144
}

variable "postgres_storage_tier" {
  description = "Storage performance tier. Must be valid for postgres_storage_mb."
  type        = string
  default     = "P30"
}

variable "redis_sku" {
  description = "Redis SKU. Premium is required for VNet injection and zone redundancy."
  type        = string
  default     = "Premium"
}

variable "redis_capacity" {
  description = "Redis capacity index."
  type        = number
  default     = 1
}

# --- Ingress --------------------------------------------------------------

variable "install_ingress_nginx" {
  description = "Install ingress-nginx and give it a static public IP. Set false if the cluster already has an ingress controller."
  type        = bool
  default     = true
}

variable "ingress_nginx_chart_version" {
  description = "ingress-nginx chart version."
  type        = string
  default     = "4.12.0"
}

variable "install_cert_manager" {
  description = "Install cert-manager. You must still apply a ClusterIssuer — see cluster-issuer.yaml."
  type        = bool
  default     = true
}

variable "cert_manager_chart_version" {
  description = "cert-manager chart version."
  type        = string
  default     = "v1.16.2"
}

variable "cluster_issuer_name" {
  description = "ClusterIssuer the Ingress requests certificates from. Must match the issuer you apply from cluster-issuer.yaml."
  type        = string
  default     = "letsencrypt-prod"
}

# --- Platform -------------------------------------------------------------

variable "release_name" {
  description = "Helm release name. Also the ServiceAccount name the federated identity credential binds to."
  type        = string
  default     = "noxus"
}

variable "namespace" {
  description = "Namespace to install into."
  type        = string
  default     = "noxus"
}

variable "pgbouncer_enabled" {
  description = "Deploy PgBouncer in front of Postgres."
  type        = bool
  default     = true
}

variable "sandbox_enabled" {
  description = "Deploy the agent sandbox. Required for plugins."
  type        = bool
  default     = true
}

variable "extra_env" {
  description = "Additional non-sensitive env vars."
  type        = map(string)
  default     = {}
}

variable "extra_secrets" {
  description = "Additional secret env vars."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "extra_values" {
  description = "Raw Helm values documents layered over the computed set."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Extra tags merged into the standard set."
  type        = map(string)
  default     = {}
}
