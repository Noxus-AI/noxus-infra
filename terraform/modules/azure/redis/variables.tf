variable "name" {
  description = "Name prefix, e.g. \"noxus-prod\"."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the cache."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "sku_name" {
  description = "Basic, Standard, or Premium. Only Premium supports VNet injection, zone redundancy, and persistence — use it for production."
  type        = string
  default     = "Premium"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku_name)
    error_message = "sku_name must be Basic, Standard, or Premium."
  }
}

variable "capacity" {
  description = "SKU capacity index. For Premium, 1 = 6 GB, 2 = 13 GB, 3 = 26 GB."
  type        = number
  default     = 1
}

variable "redis_version" {
  description = "Redis major version."
  type        = string
  default     = "6"
}

variable "subnet_id" {
  description = "Subnet to inject the cache into. Premium SKU only; ignored otherwise."
  type        = string
  default     = null
}

variable "zones" {
  description = "Availability zones. Premium SKU only."
  type        = list(string)
  default     = ["1", "2"]
}

variable "enable_non_ssl_port" {
  description = "Also expose plaintext 6379. Leave false — the platform can speak TLS via env.REDIS_SSL."
  type        = bool
  default     = false
}

variable "maxmemory_policy" {
  description = "Eviction policy."
  type        = string
  default     = "allkeys-lru"
}

variable "allowed_ip_ranges" {
  description = "Firewall rules for non-Premium SKUs, which have no VNet injection. Keyed by rule name."
  type = map(object({
    start_ip = string
    end_ip   = string
  }))
  default = {}
}

variable "maintenance_day" {
  description = "Patch day, e.g. Tuesday."
  type        = string
  default     = "Tuesday"
}

variable "maintenance_hour" {
  description = "Patch start hour, UTC."
  type        = number
  default     = 4
}

variable "tags" {
  description = "Tags applied to the cache."
  type        = map(string)
  default     = {}
}
