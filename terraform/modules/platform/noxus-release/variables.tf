variable "release_name" {
  description = "Helm release name."
  type        = string
  default     = "noxus"
}

variable "namespace" {
  description = "Namespace to install into."
  type        = string
  default     = "noxus"
}

variable "create_namespace" {
  description = "Create the namespace. Set false if it already exists or is managed elsewhere."
  type        = bool
  default     = true
}

variable "namespace_labels" {
  description = "Labels for the created namespace, e.g. pod-security enforcement levels."
  type        = map(string)
  default     = {}
}

variable "chart_path" {
  description = "Path to the noxus-platform chart. Empty resolves to charts/noxus-platform in this repository."
  type        = string
  default     = ""
}

variable "app_version" {
  description = "Platform version. Selects the image tags (spotflow-backend-<version> and friends)."
  type        = string
}

variable "domain" {
  description = "Apex domain, e.g. \"noxus.example.com\". Drives the ingress hostnames and the FRONTEND_URL / BACKEND_URL / RELAY_URL env vars together."
  type        = string
}

variable "admin_email" {
  description = "Email of the first admin user, created during bootstrap."
  type        = string
}

variable "deployment_env" {
  description = "Environment label: local, staging, or prod. Anything other than prod sets IS_PROD=false."
  type        = string
  default     = "prod"
}

variable "deployment_name" {
  description = "Display name used in logs and notifications."
  type        = string
  default     = "NOXUS"
}

variable "on_prem" {
  description = "Mark the deployment as on-premises, which disables features that assume Noxus-hosted services."
  type        = bool
  default     = false
}

variable "log_level" {
  description = "Backend and worker log level. DEBUG additionally logs prompt and tool-call content — treat that stream as sensitive."
  type        = string
  default     = "INFO"
}

variable "database" {
  description = "PostgreSQL connection details. keda_url overrides the derived postgresql:// URL when the scaler must reach the DB by a different route."
  type = object({
    host     = string
    port     = number
    name     = string
    username = string
    password = string
    keda_url = optional(string)
  })
  sensitive = true
}

variable "redis" {
  description = "Redis connection details. host is the bare hostname — the platform builds the URL itself."
  type = object({
    host     = string
    port     = optional(number, 6379)
    password = optional(string, "")
    tls      = optional(bool, false)
  })
  sensitive = true
}

variable "storage" {
  description = <<-EOT
    Object storage settings. client is "s3", "gcloud", "minio", or "azure".

    For "azure", private_bucket and public_bucket are the storage ACCOUNT name,
    not container names: the platform's Azure client derives the blob endpoint
    from SPOTFLOW_STORAGE_BUCKET and writes into a fixed "noxus" container.
    azure_account_key is the account shared key.

    For the S3-shaped clients, leave the key pair empty when pods authenticate
    through a workload identity instead.
  EOT
  type = object({
    client            = string
    private_bucket    = string
    public_bucket     = string
    region            = optional(string, "")
    endpoint_url      = optional(string, "")
    access_key_id     = optional(string, "")
    secret_access_key = optional(string, "")
    azure_account_key = optional(string, "")
  })
  sensitive = true

  validation {
    condition     = contains(["s3", "gcloud", "minio", "azure"], var.storage.client)
    error_message = "storage.client must be one of: s3, gcloud, minio, azure."
  }
}

variable "image_registry" {
  description = "Registry host prefixed to the platform image references, e.g. \"myacr.azurecr.io\". Empty pulls the repository as written, from Docker Hub."
  type        = string
  default     = ""
}

variable "image_pull_secrets" {
  description = "Names of existing imagePullSecrets in the namespace. Not needed when the cluster's node identity holds pull rights (AcrPull, an ECR policy)."
  type        = list(string)
  default     = []
}

variable "auth0" {
  description = "Auth0 tenant configuration. session_secret is generated when null. The mgmt_* pair is only needed for programmatic user provisioning."
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

variable "ingress" {
  description = "Ingress settings. class_name and annotations are cloud-specific — see the per-cloud stacks for working values."
  type = object({
    enabled     = optional(bool, true)
    class_name  = optional(string, "")
    annotations = optional(map(string), {})
    tls = optional(list(object({
      secretName = string
      hosts      = list(string)
    })), [])
  })
  default = {}
}

variable "service_account_annotations" {
  description = "Annotations on the chart's ServiceAccount. This is how IRSA, GKE Workload Identity, and Azure Workload Identity bind cloud credentials to pods."
  type        = map(string)
  default     = {}
}

variable "pgbouncer_enabled" {
  description = "Deploy PgBouncer and route the app at it. Recommended above a couple of worker replicas — each pod opens its own pool."
  type        = bool
  default     = true
}

variable "keda_enabled" {
  description = "Create the KEDA connection secret and wire worker pools to queue-depth scaling."
  type        = bool
  default     = true
}

variable "install_keda" {
  description = "Install the KEDA operator as a subchart. Set false when the cluster already runs one — two operators reconciling the same ScaledObjects conflict."
  type        = bool
  default     = true
}

variable "sandbox_enabled" {
  description = "Deploy the agent sandbox. Required for plugins and for isolated Run Code execution."
  type        = bool
  default     = true
}

variable "extra_env" {
  description = "Additional non-sensitive env vars, merged over the computed set."
  type        = map(string)
  default     = {}
}

variable "extra_secrets" {
  description = "Additional secret env vars, merged over the computed set."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "extra_values" {
  description = "Raw YAML value documents layered on top, in order. Use for anything this module does not model — worker pools, resources, geo regions."
  type        = list(string)
  default     = []
}

variable "helm_timeout" {
  description = "Seconds to wait for the release. Raise it when migrations on a large database run at startup."
  type        = number
  default     = 900
}

variable "helm_atomic" {
  description = "Roll back automatically on a failed upgrade."
  type        = bool
  default     = false
}

variable "helm_wait" {
  description = "Wait for all resources to become ready before returning."
  type        = bool
  default     = true
}
