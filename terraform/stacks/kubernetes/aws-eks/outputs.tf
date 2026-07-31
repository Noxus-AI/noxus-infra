output "frontend_url" {
  description = "Public URL of the web app."
  value       = module.noxus.frontend_url
}

output "backend_url" {
  description = "Public URL of the API."
  value       = module.noxus.backend_url
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "kubeconfig_command" {
  description = "Command to point kubectl at the cluster."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "postgres_address" {
  description = "RDS endpoint hostname."
  value       = module.postgres.address
}

output "postgres_password" {
  description = "Generated RDS master password."
  value       = module.postgres.password
  sensitive   = true
}

output "postgres_bootstrap_command" {
  description = "Run this once after the first apply to create the platform's remaining databases. The RDS instance is private, so run it from a pod or bastion inside the VPC."
  value       = "scripts/bootstrap-postgres.sh --host ${module.postgres.address} --user ${module.postgres.username}"
}

output "redis_endpoint" {
  description = "ElastiCache primary endpoint."
  value       = module.redis.primary_endpoint
}

output "private_bucket" {
  description = "Artifact bucket name."
  value       = module.storage.private_bucket
}

output "certificate_arn" {
  description = "ACM certificate fronting the ALB."
  value       = module.dns.certificate_arn
}

output "nat_public_ips" {
  description = "Egress IPs. Allowlist these on third-party services the platform calls."
  value       = module.network.nat_public_ips
}
