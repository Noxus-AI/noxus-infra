variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "redis_node_type" {
  description = "Redis node instance type"
  type        = string
  default     = "cache.t4g.micro"
}

variable "default_tags" {
  description = "Default tags for all resources"
  type        = map(string)
  default     = {}
}

variable "deploy_postgres" {
  description = "Whether to deploy PostgreSQL database"
  type        = bool
  default     = true
}

variable "postgres_instance_class" {
  description = "Instance class for PostgreSQL database"
  type        = string
  default     = "db.t3.medium"
}

variable "ami_id" {
  description = "AMI ID for the instances"
  type        = string
}

variable "instance_type" {
  description = "Instance type for the EC2 instances"
  type        = string
  default     = "t3.xlarge"
}

variable "vm_config" {
  description = "VM configuration to be passed to user_data"
  type        = map(string)
  default     = {}
}

variable "domain" {
  description = "The domain name for SSL certificates and other configurations."
  type        = string
  default     = "test.example.com"
}

variable "dns_zone" {
  description = "The domain name for SSL certificates and other configurations."
  type        = string
  default     = "example.com"
}

variable "snapshot_identifier" {
  description = "The snapshot ID to restore from. If provided, the database will be restored from this snapshot."
  type        = string
  default     = null
}

variable "google_project_id" {
  description = "The Google Cloud project ID for Gemini API access"
  type        = string
}
