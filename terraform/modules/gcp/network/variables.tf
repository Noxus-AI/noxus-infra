variable "name" {
  description = "Name prefix, e.g. \"noxus-prod\"."
  type        = string
}

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Region for the subnet and NAT."
  type        = string
}

variable "subnet_cidr" {
  description = "Primary node subnet range."
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary range for GKE pods. Cannot be resized after the cluster exists — size for growth."
  type        = string
  default     = "10.20.0.0/16"
}

variable "services_cidr" {
  description = "Secondary range for GKE services."
  type        = string
  default     = "10.30.0.0/20"
}

variable "private_service_access_cidr" {
  description = "Range reserved for Private Service Access. Cloud SQL and Memorystore are allocated from it, so it must not overlap the other ranges."
  type        = string
  default     = "10.40.0.0/16"
}

variable "nat_ip_addresses" {
  description = "Static IP self-links for Cloud NAT. Empty auto-allocates, which means the egress IP can change — pin them if a third party allowlists you."
  type        = list(string)
  default     = []
}
