output "pods_role_arn" {
  description = "IAM role the platform pods assume."
  value       = aws_iam_role.pods.arn
}

output "helm_service_account_annotation" {
  description = "Set this as serviceAccount.annotations in the noxus-platform values so pods pick up the IRSA role."
  value       = { "eks.amazonaws.com/role-arn" = aws_iam_role.pods.arn }
}

output "load_balancer_controller_role_arn" {
  description = "IAM role for the AWS Load Balancer Controller, or empty when disabled."
  value       = var.enable_load_balancer_controller ? aws_iam_role.lb_controller[0].arn : ""
}

output "external_dns_role_arn" {
  description = "IAM role for external-dns, or empty when disabled."
  value       = var.enable_external_dns ? aws_iam_role.external_dns[0].arn : ""
}
