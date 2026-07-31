output "frontend_url" {
  description = "Public URL of the web app."
  value       = module.noxus.frontend_url
}

output "backend_url" {
  description = "Public URL of the API."
  value       = module.noxus.backend_url
}

output "ingress_ip" {
  description = "Static public IP of the ingress controller, or empty when ingress-nginx was not installed."
  value       = var.install_ingress_nginx ? azurerm_public_ip.ingress[0].ip_address : ""
}

output "required_dns_records" {
  description = "A records to create if dns_zone_name was not set."
  value = var.install_ingress_nginx ? {
    for h in local.hostnames : h => azurerm_public_ip.ingress[0].ip_address
  } : {}
}

output "cluster_name" {
  description = "AKS cluster name."
  value       = module.aks.cluster_name
}

output "kubeconfig_command" {
  description = "Command to point kubectl at the cluster."
  value       = "az aks get-credentials --resource-group ${local.resource_group_name} --name ${module.aks.cluster_name}"
}

output "postgres_fqdn" {
  description = "Private FQDN of the Postgres server."
  value       = module.postgres.fqdn
}

output "postgres_password" {
  description = "Generated Postgres administrator password."
  value       = module.postgres.password
  sensitive   = true
}

output "storage_account_name" {
  description = "Blob storage account name."
  value       = module.storage.account_name
}

output "nat_public_ip" {
  description = "Stable egress IP. Allowlist this on third-party services."
  value       = module.network.nat_public_ip
}
