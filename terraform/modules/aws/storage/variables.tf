variable "name" {
  description = "Name prefix, e.g. \"noxus-prod\"."
  type        = string
}

variable "bucket_suffix" {
  description = "Suffix appended to bucket names for global uniqueness. Empty generates a random one — pin it if you manage naming yourself."
  type        = string
  default     = ""
}

variable "public_read" {
  description = "Allow anonymous s3:GetObject on the public assets bucket. Leave false unless you serve that bucket directly from a CDN; the app can presign instead."
  type        = bool
  default     = false
}

variable "versioning_enabled" {
  description = "Enable versioning on the private bucket. Recommended — it is the cheapest recovery path from an accidental bulk delete."
  type        = bool
  default     = true
}

variable "noncurrent_version_expiration_days" {
  description = "Expire noncurrent object versions after this many days. 0 keeps them forever."
  type        = number
  default     = 90
}

variable "cors_allowed_origins" {
  description = "Origins allowed to read from the buckets in a browser. Set to the frontend URL when the UI fetches artifacts directly."
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "KMS key for private bucket encryption. null uses SSE-S3."
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete non-empty buckets. Leave false in production."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
