variable "project_id" {
  description = "The GCP project ID where resources will be created."
  type        = string
}

variable "region" {
  description = "The GCP region for regional resources."
  type        = string
}

variable "zone" {
  description = "The GCP zone for zonal resources."
  type        = string
}

variable "domain" {
  description = "The domain name for SSL certificates and other configurations."
  type        = string
}

variable "machine_type" {
  description = "The machine type to use for the instance, e.g., n1-standard-1."
  type        = string
}

variable "source_image" {
  description = "The custom image to use for the instance boot disk."
  type        = string
}

variable "admin_email" {
  description = "Your admin email."
  type        = string
}

variable "whitelabel_logo" {
  description = "The URL or path to the whitelabel logo."
  type        = string
}

variable "goog_cm_deployment_name" {
  description = "The name of the deployment."
  type        = string
  default     = "vmtest"
}

variable "deployment_env" {
  description = "Deployment environment"
  type        = string
  default     = "prod"
}
variable "vm_version" {
  description = "The version of the deployment."
  type        = string
  default     = "latest"
}

variable "sql_instance_type" {
  description = "Cloud SQL instance type."
  type        = string
  default     = "db-custom-1-3840"
}

variable "auth0_domain" {
  description = "Auth0 tenant domain, e.g. tenant.eu.auth0.com."
  type        = string
}

variable "auth0_api_audience" {
  description = "Auth0 API audience identifier."
  type        = string
}

variable "auth0_client_id" {
  description = "Auth0 application client ID."
  type        = string
}

variable "auth0_client_secret" {
  description = "Auth0 application client secret."
  type        = string
  sensitive   = true
}

variable "auth0_mgmt_client_id" {
  description = "Auth0 Management API client ID. Only needed for programmatic user provisioning."
  type        = string
  default     = ""
}

variable "auth0_mgmt_client_secret" {
  description = "Auth0 Management API client secret."
  type        = string
  sensitive   = true
  default     = ""
}

variable "extra_config" {
  description = "Optional appliance settings passed through to instance metadata: license_server, redis_ssl, redis_password, serper_api_key, google_api_key, google_app_id, google_client_id, google_client_secret."
  type = object({
    license_server       = optional(string, "https://license.app.noxus.ai")
    redis_ssl            = optional(string, "")
    redis_password       = optional(string, "")
    serper_api_key       = optional(string, "")
    google_api_key       = optional(string, "")
    google_app_id        = optional(string, "")
    google_client_id     = optional(string, "")
    google_client_secret = optional(string, "")
  })
  default   = {}
  sensitive = true
}

module "deploy" {
  source                  = "./mod"
  project_id              = var.project_id
  region                  = var.region
  zone                    = var.zone
  domain                  = var.domain
  machine_type            = var.machine_type
  source_image            = var.source_image
  admin_email             = var.admin_email
  whitelabel_logo         = var.whitelabel_logo
  goog_cm_deployment_name = var.goog_cm_deployment_name
  vm_version              = var.vm_version
  deployment_env          = var.deployment_env
  sql_instance_type       = var.sql_instance_type

  auth0_domain             = var.auth0_domain
  auth0_api_audience       = var.auth0_api_audience
  auth0_client_id          = var.auth0_client_id
  auth0_client_secret      = var.auth0_client_secret
  auth0_mgmt_client_id     = var.auth0_mgmt_client_id
  auth0_mgmt_client_secret = var.auth0_mgmt_client_secret

  license_server       = var.extra_config.license_server
  redis_ssl            = var.extra_config.redis_ssl
  redis_password       = var.extra_config.redis_password
  serper_api_key       = var.extra_config.serper_api_key
  google_api_key       = var.extra_config.google_api_key
  google_app_id        = var.extra_config.google_app_id
  google_client_id     = var.extra_config.google_client_id
  google_client_secret = var.extra_config.google_client_secret
}

output "load_balancer_ip" {
  value       = module.deploy.load_balancer_ip
  description = "The public IP address of the load balancer"
}
