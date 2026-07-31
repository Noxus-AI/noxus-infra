module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  cluster_endpoint_public_access       = var.endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.endpoint_public_access_cidrs
  cluster_endpoint_private_access      = true

  # The identity that ran `terraform apply` is not automatically a cluster admin.
  # Grant access explicitly through admin_principal_arns so the cluster stays
  # reachable regardless of which CI role happened to create it.
  enable_cluster_creator_admin_permissions = var.grant_creator_admin

  authentication_mode = "API_AND_CONFIG_MAP"

  access_entries = {
    for idx, arn in var.admin_principal_arns : "admin-${idx}" => {
      principal_arn = arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  kms_key_administrators = var.kms_key_administrators

  # EKS Auto Mode: AWS manages the node pools, including scale-to-zero and
  # bin-packing. Set auto_mode_enabled=false to run your own managed node groups
  # instead — needed when you require specific instance types (e.g. GPU) or a
  # node-level agent that Auto Mode's locked-down AMI will not run.
  cluster_compute_config = var.auto_mode_enabled ? {
    enabled    = true
    node_pools = var.auto_mode_node_pools
    } : {
    enabled    = false
    node_pools = []
  }

  eks_managed_node_groups = var.auto_mode_enabled ? {} : var.managed_node_groups

  cluster_enabled_log_types = var.enabled_log_types

  cluster_addons = var.auto_mode_enabled ? {} : {
    coredns                = { most_recent = true }
    kube-proxy             = { most_recent = true }
    vpc-cni                = { most_recent = true }
    eks-pod-identity-agent = { most_recent = true }
    aws-ebs-csi-driver     = { most_recent = true }
  }

  tags = var.tags
}

# Allow the cluster's node security group to reach the data stores. Passing this
# group into the postgres/redis modules is what makes pods able to connect.
resource "aws_vpc_security_group_egress_rule" "nodes_to_vpc" {
  count = var.vpc_cidr != "" ? 1 : 0

  security_group_id = module.eks.node_security_group_id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "-1"
  description       = "Node egress to in-VPC data stores"
}
