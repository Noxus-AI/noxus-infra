output "url" {
  description = "Where users open the platform."
  value       = local.public_url
}

output "ingress_ip" {
  description = "Load balancer address. Null without a domain."
  value       = local.use_load_balancer ? google_compute_global_address.ingress[0].address : null
}

output "required_dns_records" {
  description = "A record to create when dns_managed_zone is not set. The certificate stays in PROVISIONING until it resolves."
  value       = local.use_load_balancer && var.dns_managed_zone == "" ? { (var.domain) = google_compute_global_address.ingress[0].address } : {}
}

output "auth0_application_settings" {
  description = "Values the Auth0 application must allow. Send them to Noxus if Noxus manages the application."
  value = {
    allowed_callback_urls = ["${local.public_url}/auth/callback"]
    allowed_logout_urls   = [local.public_url]
    allowed_web_origins   = [local.public_url]
  }
}

output "webhook_base_url" {
  description = "Public base of every webhook and channel endpoint (Slack, Teams, WhatsApp, Telegram, generic webhooks)."
  value       = local.relay_public_url
}

output "egress_ip" {
  description = "Address all outbound traffic leaves from, for allowlists on the receiving side. Null when deploying into an existing network."
  value       = local.create_network ? google_compute_address.egress[0].address : null
}

output "service_urls" {
  description = "Internal addresses of each service. Reachable only from inside the VPC."
  value = {
    for key, url in local.internal_url : key => url
    if key != "sandbox" || var.deploy_sandbox
  }
}

output "service_accounts" {
  description = "Runtime identities."
  value = merge(
    {
      platform = google_service_account.platform.email
      frontend = google_service_account.frontend.email
    },
    var.deploy_sandbox ? { sandbox = google_service_account.sandbox[0].email } : {},
  )
}

output "cloud_run_service_agent" {
  description = "Identity Cloud Run pulls images with. Grant it roles/artifactregistry.reader on the repository when image_registry is in another project."
  value       = "service-${data.google_project.this.number}@serverless-robot-prod.iam.gserviceaccount.com"
}

output "image_prefix" {
  description = "Registry path images are pulled from."
  value       = local.image_prefix
}

output "database_instance" {
  description = "Cloud SQL instance name."
  value       = google_sql_database_instance.main.name
}
