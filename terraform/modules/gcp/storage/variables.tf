variable "name" {
  description = "Name prefix, e.g. \"noxus-prod\"."
  type        = string
}

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "location" {
  description = "Bucket location — a region like \"europe-west1\" or a multi-region like \"EU\"."
  type        = string
}

variable "bucket_suffix" {
  description = "Suffix appended to bucket names for global uniqueness. Empty generates a random one."
  type        = string
  default     = ""
}

variable "public_read" {
  description = "Allow anonymous reads on the public assets bucket. Leave false unless you serve it directly from a CDN."
  type        = bool
  default     = false
}

variable "versioning_enabled" {
  description = "Enable object versioning on the private bucket."
  type        = bool
  default     = true
}

variable "noncurrent_version_expiration_days" {
  description = "Delete archived object versions after this many days. 0 keeps them forever."
  type        = number
  default     = 90
}

variable "cors_allowed_origins" {
  description = "Origins allowed to read from the buckets in a browser."
  type        = list(string)
  default     = []
}

variable "kms_key_name" {
  description = "CMEK key for the private bucket. null uses Google-managed keys."
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete non-empty buckets."
  type        = bool
  default     = false
}

variable "create_service_account" {
  description = "Create a Google service account for the platform pods and grant it bucket access."
  type        = bool
  default     = true
}

variable "workload_identity_member" {
  description = "Kubernetes SA to bind, as serviceAccount:PROJECT.svc.id.goog[NAMESPACE/KSA_NAME]. Empty skips the binding — set it once you know the namespace and release name."
  type        = string
  default     = ""
}

variable "grant_vertex_ai" {
  description = "Also grant roles/aiplatform.user, for using Vertex AI as an LLM or embedding provider."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels applied to the buckets."
  type        = map(string)
  default     = {}
}
