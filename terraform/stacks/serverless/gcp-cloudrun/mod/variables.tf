variable "project_id" {
  description = "The GCP project ID where resources will be created."
  type        = string
}

variable "region" {
  description = "The GCP region for regional resources."
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "The GCP zone for zonal resources."
  type        = string
  default     = "europe-west1-b"
}

variable "domain" {
  description = "The domain name for SSL certificates and other configurations."
  type        = string
  default     = "test.example.com"
}

variable "admin_email" {
  description = "Your admin email."
  type        = string
  default     = "example@example.com"
}

variable "auth0_domain" {
  description = "Your Auth0 domain."
  type        = string
  default     = "noxus-oncloud.eu.auth0.com"
}

variable "auth0_api_audience" {
  description = "The Auth0 API audience identifier."
  type        = string
  default     = "https://oncloud.noxus.ai"
}

variable "auth0_client_id" {
  description = "The Auth0 client ID. No default — supply your own tenant's application."
  type        = string
}

variable "auth0_client_secret" {
  description = "The Auth0 client secret. No default — supply your own tenant's application."
  type        = string
  sensitive   = true
}

variable "auth0_mgmt_client_id" {
  description = "The Auth0 client ID."
  type        = string
  default     = ""
}

variable "auth0_mgmt_client_secret" {
  description = "The Auth0 client secret."
  type        = string
  sensitive   = true
  default     = ""
}

variable "deployment_env" {
  description = "The deployment environment."
  type        = string
  default     = "prod"
}

variable "whitelabel_logo" {
  description = "The URL or path to the whitelabel logo."
  type        = string
  default     = ""
}

variable "postgresql_url" {
  description = "The URL or path to the postgresql server."
  type        = string
  default     = "postgres:password@postgres:5432"
}

variable "deploy_postgres" {
  description = "The URL or path to the postgresql server."
  type        = bool
  default     = true
}

variable "goog_cm_deployment_name" {
  description = "The name of the deployment."
  type        = string
  default     = "noxus"
}

variable "vm_version" {
  description = "The version of the deployment."
  type        = string
}
