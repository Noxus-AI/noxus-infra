variable "project_name" {
  description = "Short project identifier."
  type        = string
  default     = "noxus"
}

variable "environment" {
  description = "Environment name. \"prod\" turns on regional clusters, HA Postgres and Redis, and deletion protection."
  type        = string
  default     = "prod"
}

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region."
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "Zone, used only for non-prod zonal clusters."
  type        = string
  default     = "europe-west1-b"
}

variable "domain" {
  description = "Apex domain the platform is served from."
  type        = string
}

variable "dns_managed_zone" {
  description = "Cloud DNS managed zone name for the domain. Empty skips record creation — but the managed certificate will not issue until the three hostnames resolve to the ingress IP, so create them yourself in that case."
  type        = string
  default     = ""
}

variable "admin_email" {
  description = "Email of the first admin user."
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

variable "subnet_cidr" {
  description = "Node subnet range."
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary range for pods. Cannot be resized later."
  type        = string
  default     = "10.20.0.0/16"
}

variable "services_cidr" {
  description = "Secondary range for services."
  type        = string
  default     = "10.30.0.0/20"
}

variable "private_service_access_cidr" {
  description = "Range reserved for Cloud SQL and Memorystore peering."
  type        = string
  default     = "10.40.0.0/16"
}

variable "master_cidr" {
  description = "/28 for the private control plane."
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "CIDRs allowed to reach the Kubernetes API. Terraform needs to reach it to install the Helm release, so include your operator or CI egress range."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

# --- Cluster --------------------------------------------------------------

variable "enable_autopilot" {
  description = "Use Autopilot. Autopilot forbids the SYS_PTRACE the sandbox's syd jail needs — set sandbox jail to \"minimal\" through extra_values if you enable this."
  type        = bool
  default     = false
}

variable "release_channel" {
  description = "GKE release channel."
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

# --- Data stores ----------------------------------------------------------

variable "postgres_version" {
  description = "Cloud SQL PostgreSQL version. POSTGRES_15 or newer, for pgvector."
  type        = string
  default     = "POSTGRES_16"
}

variable "postgres_tier" {
  description = "Cloud SQL machine tier."
  type        = string
  default     = "db-custom-4-16384"
}

variable "postgres_disk_size_gb" {
  description = "Cloud SQL initial disk size."
  type        = number
  default     = 100
}

variable "redis_memory_gb" {
  description = "Memorystore instance size."
  type        = number
  default     = 5
}

variable "bucket_location" {
  description = "GCS bucket location — a region or a multi-region like \"EU\"."
  type        = string
  default     = "EU"
}

# --- Platform -------------------------------------------------------------

variable "release_name" {
  description = "Helm release name. Also the ServiceAccount name Workload Identity binds to."
  type        = string
  default     = "noxus"
}

variable "namespace" {
  description = "Namespace to install into."
  type        = string
  default     = "noxus"
}

variable "pgbouncer_enabled" {
  description = "Deploy PgBouncer in front of Cloud SQL."
  type        = bool
  default     = true
}

variable "sandbox_enabled" {
  description = "Deploy the agent sandbox. Required for plugins."
  type        = bool
  default     = true
}

variable "grant_vertex_ai" {
  description = "Grant the platform identity roles/aiplatform.user, for Vertex AI models and embeddings."
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

variable "labels" {
  description = "Extra labels merged into the standard set."
  type        = map(string)
  default     = {}
}
