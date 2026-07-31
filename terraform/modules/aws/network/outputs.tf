output "vpc_id" {
  description = "ID of the created VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "Private subnet IDs — cluster nodes, RDS, and ElastiCache live here."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnet IDs — load balancers only."
  value       = module.vpc.public_subnets
}

output "availability_zones" {
  description = "Availability zones the VPC spans."
  value       = local.azs
}

output "nat_public_ips" {
  description = "Public IPs of the NAT gateways. Allowlist these on any third-party service the platform calls out to."
  value       = module.vpc.nat_public_ips
}
