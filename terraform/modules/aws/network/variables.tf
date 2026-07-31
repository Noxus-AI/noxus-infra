variable "name" {
  description = "Name prefix for all resources, e.g. \"noxus-prod\"."
  type        = string
}

variable "region" {
  description = "AWS region. Used to build the S3 endpoint service name."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Must be at least a /20 to fit the subnet split."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to span. 3 for production, 2 is the practical minimum for EKS."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count must be between 2 and 4."
  }
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway for all AZs instead of one per AZ. Cheaper, but a single-AZ failure domain — leave false in production."
  type        = bool
  default     = false
}

variable "cluster_name" {
  description = "EKS cluster name to tag subnets for. Leave empty when the VPC is not backing a cluster."
  type        = string
  default     = ""
}

variable "enable_s3_endpoint" {
  description = "Create an S3 gateway VPC endpoint so artifact traffic bypasses the NAT gateway."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
