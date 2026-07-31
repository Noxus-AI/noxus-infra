provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}

# Auth tokens are minted at apply time rather than baked into state. The exec
# block shells out to the AWS CLI, so the machine running terraform needs it on
# PATH and credentials for the same account.
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
