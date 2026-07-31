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

variable "source_image" {
  description = <<-EOT
    Appliance image to boot. No default: the value that used to live here dated
    from March 2025 and silently deployed a stale platform, which is worse than
    failing to plan. List the current images with:

      gcloud compute images list --project spot-public --filter="name~spot-standalone" --sort-by=~creationTimestamp
  EOT
  type        = string
}

variable "machine_type" {
  description = "Machine type. The appliance runs the whole platform including Postgres, so n1-standard-2 is an evaluation size — use at least 8 vCPU / 32 GB for real use."
  type        = string
  default     = "n1-standard-2"
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

variable "sql_instance_type" {
  description = "Cloud SQL instance type."
  type        = string
}

variable "license_server" {
  description = "License server the appliance checks in with. Point at your own only for air-gapped installs."
  type        = string
  default     = "https://license.app.noxus.ai"
}

variable "redis_ssl" {
  description = "Non-empty enables TLS to Redis. The appliance runs Redis in-container over the compose network, so this is normally empty."
  type        = string
  default     = ""
}

variable "redis_password" {
  description = "Redis password. Empty for the in-container Redis."
  type        = string
  sensitive   = true
  default     = ""
}

variable "serper_api_key" {
  description = "Serper API key for web-search nodes. Optional."
  type        = string
  sensitive   = true
  default     = ""
}

variable "google_api_key" {
  description = "Google API key for the Drive/Sheets picker. Optional."
  type        = string
  sensitive   = true
  default     = ""
}

variable "google_app_id" {
  description = "Google OAuth application ID. Optional."
  type        = string
  default     = ""
}

variable "google_client_id" {
  description = "Google OAuth client ID. Optional."
  type        = string
  default     = ""
}

variable "google_client_secret" {
  description = "Google OAuth client secret. Optional."
  type        = string
  sensitive   = true
  default     = ""
}
