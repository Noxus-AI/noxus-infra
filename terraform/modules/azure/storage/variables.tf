variable "name" {
  description = "Name prefix. Non-alphanumeric characters are stripped to form the storage account name."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the account."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "account_suffix" {
  description = "Suffix for global uniqueness. Empty generates a random one."
  type        = string
  default     = ""
}

variable "replication_type" {
  description = "LRS, ZRS, GRS, or GZRS. ZRS or better for production."
  type        = string
  default     = "ZRS"
}

variable "private_container_name" {
  description = "Container for run artifacts and uploads. With BUCKET_CLIENT=azure the platform writes into a fixed \"noxus\" container, so set this to that name to keep the container Terraform-managed."
  type        = string
  default     = "artifacts"
}

variable "public_container_name" {
  description = "Container for whitelabel and integration assets. Only the S3-shaped clients address it separately; the native Azure client keeps everything in the private container."
  type        = string
  default     = "artifacts-public"
}

variable "public_read" {
  description = "Allow anonymous blob reads on the public container. Leave false unless you serve it directly."
  type        = bool
  default     = false
}

variable "versioning_enabled" {
  description = "Enable blob versioning."
  type        = bool
  default     = true
}

variable "soft_delete_retention_days" {
  description = "Blob soft-delete retention. 0 disables it."
  type        = number
  default     = 30
}

variable "cors_allowed_origins" {
  description = "Origins allowed to read blobs in a browser."
  type        = list(string)
  default     = []
}

variable "allowed_subnet_ids" {
  description = "Subnets allowed to reach the account. Non-empty switches the default network action to Deny — include the AKS node subnet or pods lose storage access."
  type        = list(string)
  default     = []
}

variable "allowed_ip_rules" {
  description = "Public IPs allowed when network rules are active."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to the account."
  type        = map(string)
  default     = {}
}
