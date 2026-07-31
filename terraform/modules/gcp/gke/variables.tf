variable "cluster_name" {
  description = "GKE cluster name."
  type        = string
}

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Region, used when regional=true."
  type        = string
}

variable "zone" {
  description = "Zone, used when regional=false. A zonal cluster has a single-zone control plane and no SLA."
  type        = string
  default     = ""
}

variable "regional" {
  description = "Create a regional cluster with a replicated control plane. Required for any production SLA."
  type        = bool
  default     = true
}

variable "enable_autopilot" {
  description = "Use Autopilot instead of managed node pools. Autopilot removes node operations but forbids privileged pods — the sandbox's syd jail needs SYS_PTRACE and will not schedule, so set sandbox.jail=minimal if you enable this."
  type        = bool
  default     = false
}

variable "network_id" {
  description = "VPC network ID."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID with the pods and services secondary ranges."
  type        = string
}

variable "pods_range_name" {
  description = "Secondary range name for pods."
  type        = string
  default     = "pods"
}

variable "services_range_name" {
  description = "Secondary range name for services."
  type        = string
  default     = "services"
}

variable "master_cidr" {
  description = "/28 for the private control plane. Must not overlap any other range in the VPC."
  type        = string
  default     = "172.16.0.0/28"
}

variable "private_endpoint" {
  description = "Make the Kubernetes API reachable only from inside the VPC. Requires a bastion or VPN for kubectl and for terraform to apply the Helm release."
  type        = bool
  default     = false
}

variable "master_authorized_networks" {
  description = "CIDRs allowed to reach the Kubernetes API. Empty allows none, which locks out kubectl entirely — set at least your operator range or CI egress."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "kubernetes_version" {
  description = "Minimum control plane version. Leave empty to take whatever the release channel offers."
  type        = string
  default     = ""
}

variable "release_channel" {
  description = "GKE release channel: RAPID, REGULAR, or STABLE."
  type        = string
  default     = "REGULAR"
}

variable "node_pools" {
  description = "Node pool definitions, ignored under Autopilot."
  type = map(object({
    machine_type       = optional(string, "n2-standard-4")
    initial_node_count = optional(number, 1)
    min_node_count     = optional(number, 1)
    max_node_count     = optional(number, 10)
    disk_size_gb       = optional(number, 100)
    disk_type          = optional(string, "pd-balanced")
    spot               = optional(bool, false)
    labels             = optional(map(string), {})
    tags               = optional(list(string), [])
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  default = {
    general = {
      machine_type   = "n2-standard-4"
      min_node_count = 2
      max_node_count = 10
    }
  }
}

variable "logging_components" {
  description = "Cloud Logging components to enable."
  type        = list(string)
  default     = ["SYSTEM_COMPONENTS", "WORKLOADS"]
}

variable "monitoring_components" {
  description = "Cloud Monitoring components to enable."
  type        = list(string)
  default     = ["SYSTEM_COMPONENTS"]
}

variable "managed_prometheus" {
  description = "Enable Google Managed Prometheus, which scrapes the prometheus.io pod annotations the chart already sets."
  type        = bool
  default     = true
}

variable "maintenance_start_time" {
  description = "Maintenance window start, RFC3339."
  type        = string
  default     = "2024-01-01T03:00:00Z"
}

variable "maintenance_end_time" {
  description = "Maintenance window end, RFC3339."
  type        = string
  default     = "2024-01-01T07:00:00Z"
}

variable "maintenance_recurrence" {
  description = "Maintenance recurrence, RRULE format."
  type        = string
  default     = "FREQ=WEEKLY;BYDAY=SA,SU"
}

variable "deletion_protection" {
  description = "Block terraform destroy of the cluster."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Resource labels."
  type        = map(string)
  default     = {}
}
