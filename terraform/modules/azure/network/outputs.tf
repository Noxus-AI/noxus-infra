output "vnet_id" {
  description = "Virtual network ID."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Virtual network name."
  value       = azurerm_virtual_network.this.name
}

output "nodes_subnet_id" {
  description = "Subnet ID for AKS nodes."
  value       = azurerm_subnet.nodes.id
}

output "postgres_subnet_id" {
  description = "Delegated subnet ID for PostgreSQL Flexible Server."
  value       = azurerm_subnet.postgres.id
}

output "private_endpoints_subnet_id" {
  description = "Subnet ID for private endpoints."
  value       = azurerm_subnet.private_endpoints.id
}

output "postgres_private_dns_zone_id" {
  description = "Private DNS zone ID for the Postgres private hostname."
  value       = azurerm_private_dns_zone.postgres.id
}

output "nat_public_ip" {
  description = "Stable egress IP, or empty when the NAT gateway is disabled. Allowlist this on third-party services."
  value       = var.enable_nat_gateway ? azurerm_public_ip.nat[0].ip_address : ""
}
