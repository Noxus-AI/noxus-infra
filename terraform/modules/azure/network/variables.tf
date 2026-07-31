variable "name" {
  description = "Name prefix, e.g. \"noxus-prod\". Also used as the private DNS zone label, so it must be DNS-safe."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to create the network in."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "vnet_cidr" {
  description = "Address space for the virtual network."
  type        = string
  default     = "10.0.0.0/16"
}

variable "nodes_cidr" {
  description = "Subnet for AKS nodes. With Azure CNI every pod takes an address from this range — size it for max_pods multiplied by max node count."
  type        = string
  default     = "10.0.0.0/20"
}

variable "postgres_cidr" {
  description = "Delegated subnet for PostgreSQL Flexible Server. Nothing else may be placed in it."
  type        = string
  default     = "10.0.16.0/24"
}

variable "private_endpoints_cidr" {
  description = "Subnet for private endpoints, e.g. Redis and Storage."
  type        = string
  default     = "10.0.17.0/24"
}

variable "enable_nat_gateway" {
  description = "Attach a NAT gateway to the node subnet so egress has a stable IP."
  type        = bool
  default     = true
}

variable "availability_zones" {
  description = "Zones for the NAT public IP."
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
