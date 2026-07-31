variable "cluster_name" {
  description = "AKS cluster name. Also used as the DNS prefix."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the cluster."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "subnet_id" {
  description = "Node subnet ID from the network module."
  type        = string
}

variable "kubernetes_version" {
  description = "Control plane version. Leave empty to take the region default."
  type        = string
  default     = null
}

variable "sku_tier" {
  description = "Free, Standard, or Premium. Standard buys the control-plane SLA and is the minimum for production."
  type        = string
  default     = "Standard"
}

variable "upgrade_channel" {
  description = "Automatic upgrade channel: patch, stable, rapid, node-image, or none."
  type        = string
  default     = "patch"
}

variable "availability_zones" {
  description = "Zones to spread nodes across."
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "system_pool" {
  description = "Default (system) node pool."
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

variable "dedicated_system_pool" {
  description = "Taint the system pool so only critical addons schedule on it. Requires at least one entry in node_pools, or the platform has nowhere to run."
  type        = bool
  default     = false
}

variable "node_pools" {
  description = "Additional user node pools."
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

variable "network_plugin_mode" {
  description = "Set to \"overlay\" for Azure CNI Overlay, which stops pods consuming VNet addresses. null uses classic Azure CNI."
  type        = string
  default     = "overlay"
}

variable "network_policy" {
  description = "Network policy engine: azure, calico, or cilium. Required for the sandbox NetworkPolicy to be enforced."
  type        = string
  default     = "cilium"
}

variable "service_cidr" {
  description = "CIDR for Kubernetes services. Must not overlap the VNet."
  type        = string
  default     = "172.16.0.0/16"
}

variable "dns_service_ip" {
  description = "Cluster DNS service IP. Must be inside service_cidr."
  type        = string
  default     = "172.16.0.10"
}

variable "enable_nat_gateway" {
  description = "Set true when the node subnet has a NAT gateway attached, so egress uses it instead of the load balancer pool."
  type        = bool
  default     = true
}

variable "admin_group_object_ids" {
  description = "Entra ID group object IDs granted cluster-admin. Empty disables Entra integration and falls back to local admin certificates."
  type        = list(string)
  default     = []
}

variable "azure_rbac_enabled" {
  description = "Use Azure RBAC for Kubernetes authorization instead of in-cluster RoleBindings."
  type        = bool
  default     = true
}

variable "disable_local_accounts" {
  description = "Disable the local admin kubeconfig. Safer, but requires Entra integration to be working before you can reach the cluster at all."
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace to ship container logs to. Empty disables the OMS agent."
  type        = string
  default     = ""
}

variable "enable_web_app_routing" {
  description = "Enable the managed ingress addon. An alternative to installing ingress-nginx and cert-manager yourself."
  type        = bool
  default     = false
}

variable "dns_zone_ids" {
  description = "DNS zone IDs the web app routing addon may manage."
  type        = list(string)
  default     = []
}

variable "create_workload_identity" {
  description = "Create a user-assigned identity federated to the platform's ServiceAccount."
  type        = bool
  default     = true
}

variable "platform_namespace" {
  description = "Namespace the platform is installed into. Must match the federated credential subject or the token exchange fails."
  type        = string
  default     = "noxus"
}

variable "platform_service_account" {
  description = "ServiceAccount name the chart creates. Defaults to the chart fullname, which is the release name."
  type        = string
  default     = "noxus"
}

variable "storage_account_id" {
  description = "Storage account to grant the platform identity Blob Data Contributor on. Empty skips the assignment."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
