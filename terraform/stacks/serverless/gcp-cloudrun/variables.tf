# ---------------------------------------------------------------- required ---

variable "project_id" {
  description = "GCP project to deploy into."
  type        = string
}

variable "region" {
  description = "Region for every regional resource (Cloud Run, Cloud SQL, Memorystore, buckets, Artifact Registry)."
  type        = string
}

variable "admin_email" {
  description = "Owner of the first tenant, created on first boot. The only person who can log in until they invite others."
  type        = string
}

variable "noxus_version" {
  description = "Platform release, e.g. \"1.9.2\". Tag of every noxusai/noxus-* image."
  type        = string
}

variable "auth0_client_id" {
  description = "Client ID of the Auth0 application this deployment logs in through. Noxus provides it."
  type        = string
}

variable "auth0_client_secret" {
  description = "Client secret of that Auth0 application."
  type        = string
  sensitive   = true
}

# ----------------------------------------------------------------- ingress ---

variable "domain" {
  description = "Hostname users reach, e.g. \"noxus.example.com\". Set: an external HTTPS load balancer with a Google-managed certificate serves it. Empty: no load balancer, and the frontend answers on its own run.app URL."
  type        = string
  default     = ""
}

variable "dns_managed_zone" {
  description = "Cloud DNS managed zone, in this project, that holds `domain`. Set it and the A record is created for you; leave it empty and create the record yourself from the `required_dns_records` output. The certificate does not issue until the record resolves."
  type        = string
  default     = ""
}

# ------------------------------------------------------------------ naming ---

variable "name_prefix" {
  description = "Prefix for every resource name. Change it to run two deployments in one project."
  type        = string
  default     = "noxus"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.name_prefix))
    error_message = "name_prefix must be 2 to 16 characters: lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "deployment_env" {
  description = "DEPLOYMENT_ENV. Leave at \"prod\" unless Noxus asks otherwise."
  type        = string
  default     = "prod"
}

variable "labels" {
  description = "Labels added to every resource that supports them."
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------- auth0 ---

variable "auth0_domain" {
  description = "Auth0 tenant domain. The default is the Noxus tenant."
  type        = string
  default     = "noxus-oncloud.eu.auth0.com"
}

variable "auth0_api_audience" {
  description = "Auth0 API audience. The default matches the Noxus tenant."
  type        = string
  default     = "https://oncloud.noxus.ai"
}

variable "auth0_mgmt_client_id" {
  description = "Optional Auth0 machine-to-machine application for the Management API. Its access is tenant-wide, so leave it empty on a tenant shared with other organisations. Without it, the login page lists the connections configured in the platform's authentication settings, and the admin list of Auth0 users and verification-email resends are unavailable."
  type        = string
  default     = ""
}

variable "auth0_mgmt_client_secret" {
  description = "Secret of the machine-to-machine application. Required when auth0_mgmt_client_id is set."
  type        = string
  sensitive   = true
  default     = ""
}

variable "credential_encryption_key" {
  description = "Fernet key that encrypts integration credentials at rest. Leave empty to generate one. Once data exists it can only change through a key rotation, so keep the generated value with the state."
  type        = string
  sensitive   = true
  default     = ""
}

# ------------------------------------------------------------------ images ---

variable "docker_hub_token" {
  description = "Docker Hub access token for the private noxusai images, provided by Noxus. Used by the Artifact Registry remote repository that this stack creates. Not needed when image_registry is set."
  type        = string
  sensitive   = true
  default     = ""
}

variable "docker_hub_username" {
  description = "Docker Hub account the token belongs to."
  type        = string
  default     = "noxusai"
}

variable "image_registry" {
  description = "Registry path that already mirrors the noxusai images, e.g. \"europe-west2-docker.pkg.dev/my-project/mirror/noxusai\". Images are pulled as <image_registry>/noxus-backend:<noxus_version>. Empty: this stack creates an Artifact Registry remote repository in front of Docker Hub."
  type        = string
  default     = ""
}

# ----------------------------------------------------------------- network ---

variable "network" {
  description = "Existing VPC network id (projects/<p>/global/networks/<n>) to deploy into instead of creating one. It must already have Private Service Access and Cloud NAT (or another internet egress path)."
  type        = string
  default     = ""
}

variable "subnetwork" {
  description = "Existing subnetwork id in `region`, required with `network`. Needs Private Google Access enabled."
  type        = string
  default     = ""
}

variable "subnet_cidr" {
  description = "Range of the subnet this stack creates. Cloud Run instances take their addresses from it."
  type        = string
  default     = "10.10.0.0/20"
}

variable "private_service_access_cidr" {
  description = "Range reserved for Cloud SQL and Memorystore private IPs. Must not overlap anything the VPC is peered with."
  type        = string
  default     = "10.40.0.0/16"
}

# ------------------------------------------------------------------- data ---

variable "database" {
  description = "Cloud SQL for PostgreSQL sizing."
  type = object({
    tier            = optional(string, "db-custom-2-8192")
    disk_size_gb    = optional(number, 50)
    max_connections = optional(number, 1000)
  })
  default = {}
}

variable "redis_memory_size_gb" {
  description = "Memorystore for Redis capacity."
  type        = number
  default     = 1
}

variable "deletion_protection" {
  description = "Protects the database from deletion and refuses to delete non-empty buckets. Set to false before `tofu destroy`."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------- services ---

variable "backend" {
  description = "Backend sizing. Keep instances at 1: it runs migrations on boot, and two booting together race."
  type = object({
    cpu       = optional(string, "2")
    memory    = optional(string, "4Gi")
    instances = optional(number, 1)
  })
  default = {}
}

variable "frontend" {
  description = "Frontend sizing."
  type = object({
    cpu       = optional(string, "1")
    memory    = optional(string, "2Gi")
    instances = optional(number, 1)
  })
  default = {}
}

variable "worker" {
  description = "Worker sizing. Each instance forks about ten processes, so memory scales with them rather than with load."
  type = object({
    cpu       = optional(string, "4")
    memory    = optional(string, "8Gi")
    instances = optional(number, 1)
  })
  default = {}
}

variable "relay" {
  description = "Relay sizing. The relay receives webhooks and channel events (Slack, Teams, WhatsApp, Telegram, generic webhooks)."
  type = object({
    cpu       = optional(string, "1")
    memory    = optional(string, "2Gi")
    instances = optional(number, 1)
  })
  default = {}
}

variable "deploy_sandbox" {
  description = "Deploy the agent sandbox, where Run Code, plugins and browser automation execute. Without it Run Code runs inside the worker, and plugins and browser features are unavailable."
  type        = bool
  default     = true
}

variable "sandbox" {
  description = "Sandbox sizing. Its filesystem is in memory on Cloud Run, so `data_size` (the sandboxes' writable space) comes out of `memory`. Keep one instance: it holds live sandboxes in memory."
  type = object({
    cpu       = optional(string, "4")
    memory    = optional(string, "8Gi")
    data_size = optional(string, "4Gi")
  })
  default = {}
}

variable "sandbox_provider" {
  description = "Isolation runtime inside the sandbox. \"gvisor\" is the one that has run on Cloud Run in production; \"syd\" adds its own network jail but needs capabilities Cloud Run has not been verified to grant."
  type        = string
  default     = "gvisor"

  validation {
    condition     = contains(["gvisor", "syd"], var.sandbox_provider)
    error_message = "sandbox_provider must be gvisor or syd. auto can silently fall back to a runtime with no isolation."
  }
}

# ------------------------------------------------------------------- misc ---

variable "whitelabel_logo" {
  description = "URL of a logo shown in place of the Noxus one."
  type        = string
  default     = ""
}

variable "extra_env" {
  description = "Additional environment variables for the backend, worker, relay and frontend. Values here override the stack's own. Not for secrets: they are readable by anyone who can view the services."
  type        = map(string)
  default     = {}
}
