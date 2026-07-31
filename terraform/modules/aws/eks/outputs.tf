output "cluster_name" {
  description = "Cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 CA bundle for the API endpoint."
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_security_group_id" {
  description = "Security group EKS created for the control plane."
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Node security group. Pass this to the postgres and redis modules as an allowed source."
  value       = module.eks.node_security_group_id
}

output "oidc_provider" {
  description = "OIDC issuer hostname and path, without the scheme. Used in IRSA trust policy conditions."
  value       = module.eks.oidc_provider
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN. Used as the federated principal in IRSA trust policies."
  value       = module.eks.oidc_provider_arn
}
