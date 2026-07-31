variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes control plane version."
  type        = string
  default     = "1.31"
}

variable "vpc_id" {
  description = "VPC to create the cluster in."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR, used to open node egress to in-VPC data stores. Empty skips the rule."
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Private subnet IDs for cluster nodes and ENIs."
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Expose the Kubernetes API publicly. Keep true only if your CI or operators sit outside the VPC, and pair it with endpoint_public_access_cidrs."
  type        = bool
  default     = true
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. The default is open to the internet — narrow it."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "admin_principal_arns" {
  description = "IAM role or user ARNs granted cluster-admin. Typically an SSO permission-set role ARN and your CI deploy role."
  type        = list(string)
  default     = []
}

variable "grant_creator_admin" {
  description = "Also grant cluster-admin to whichever identity ran apply. Convenient for a first bootstrap, fragile afterwards — prefer admin_principal_arns."
  type        = bool
  default     = false
}

variable "kms_key_administrators" {
  description = "IAM ARNs allowed to administer the cluster's secrets-encryption KMS key. Empty falls back to the module default (the account root and the caller)."
  type        = list(string)
  default     = []
}

variable "auto_mode_enabled" {
  description = "Use EKS Auto Mode instead of self-managed node groups. Auto Mode removes node lifecycle work but restricts node customization."
  type        = bool
  default     = true
}

variable "auto_mode_node_pools" {
  description = "Auto Mode built-in node pools to enable."
  type        = list(string)
  default     = ["general-purpose", "system"]
}

variable "managed_node_groups" {
  description = "EKS managed node group definitions, used when auto_mode_enabled=false. Passed through to the upstream module verbatim."
  type        = any
  default = {
    general = {
      instance_types = ["m6a.xlarge"]
      min_size       = 2
      max_size       = 10
      desired_size   = 3
      capacity_type  = "ON_DEMAND"
    }
  }
}

variable "enabled_log_types" {
  description = "Control-plane log types shipped to CloudWatch."
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
