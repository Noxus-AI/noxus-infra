variable "name" {
  description = "Name prefix for IAM roles, e.g. \"noxus-prod\"."
  type        = string
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name. Also used as external-dns's TXT owner ID."
  type        = string
}

variable "vpc_id" {
  description = "VPC the cluster runs in. Required by the load balancer controller."
  type        = string
}

variable "oidc_provider" {
  description = "Cluster OIDC issuer without the scheme, from the eks module's oidc_provider output."
  type        = string
}

variable "oidc_provider_arn" {
  description = "Cluster IAM OIDC provider ARN, from the eks module's oidc_provider_arn output."
  type        = string
}

variable "platform_namespaces" {
  description = "Namespaces whose service accounts may assume the platform pod role. Keep this tight — every SA in a listed namespace gets the role."
  type        = list(string)
  default     = ["noxus"]
}

variable "bucket_arns" {
  description = "S3 bucket ARNs the platform pods may read and write."
  type        = list(string)
  default     = []
}

variable "enable_bedrock" {
  description = "Grant pods Bedrock invoke permissions, for using Bedrock as an LLM provider."
  type        = bool
  default     = false
}

variable "bedrock_model_arns" {
  description = "Bedrock model ARNs pods may invoke. Defaults to any model, which is broad — narrow it to the models you actually enable."
  type        = list(string)
  default     = ["*"]
}

variable "prometheus_workspace_arn" {
  description = "Amazon Managed Prometheus workspace ARN to grant remote-write on. Empty skips the grant."
  type        = string
  default     = ""
}

variable "enable_load_balancer_controller" {
  description = "Create the IRSA role for the AWS Load Balancer Controller. Required for ingress.className=alb."
  type        = bool
  default     = true
}

variable "enable_external_dns" {
  description = "Create the IRSA role for external-dns, which publishes the platform hostnames to Route53."
  type        = bool
  default     = true
}

variable "route53_zone_ids" {
  description = "Hosted zone IDs external-dns may modify. Required when enable_external_dns is true."
  type        = list(string)
  default     = []
}

variable "install_helm_releases" {
  description = "Also install the controller and external-dns Helm charts. Set false if you manage cluster addons separately — the IAM roles are still created."
  type        = bool
  default     = true
}

variable "load_balancer_controller_chart_version" {
  description = "aws-load-balancer-controller chart version. Keep the vendored IAM policy in step (scripts/update-lb-controller-policy.sh)."
  type        = string
  default     = "1.13.0"
}

variable "external_dns_chart_version" {
  description = "external-dns chart version."
  type        = string
  default     = "1.15.0"
}

variable "tags" {
  description = "Tags applied to IAM resources."
  type        = map(string)
  default     = {}
}
