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
  default     = "cloudrun"
}

variable "deployment_env" {
  description = "Deployment environment"
  type        = string
  default     = "prod"
}

variable "vm_version" {
  description = "The version of the deployment."
  type        = string
  default     = "ec09562-20250321T143742"
}

variable "docker_hub_token" {
  type        = string
  sensitive   = true
  description = "Docker Hub token for authentication"
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

module "deploy" {
  source                  = "./mod"
  project_id              = var.project_id
  region                  = var.region
  zone                    = var.zone
  domain                  = var.domain
  admin_email             = var.admin_email
  whitelabel_logo         = var.whitelabel_logo
  goog_cm_deployment_name = var.goog_cm_deployment_name
  vm_version              = var.vm_version
  deployment_env          = var.deployment_env
  docker_hub_token        = var.docker_hub_token

  auth0_domain        = var.auth0_domain
  auth0_api_audience  = var.auth0_api_audience
  auth0_client_id     = var.auth0_client_id
  auth0_client_secret = var.auth0_client_secret
}

output "backend_dns" {
  value       = module.deploy.backend_dns
  description = "The public dns to add for the backend"
}

output "frontend_dns" {
  value       = module.deploy.frontend_dns
  description = "The public dns to add for the frontend"
}

output "relay_dns" {
  value       = module.deploy.relay_dns
  description = "The public dns to add for the relay"
}
