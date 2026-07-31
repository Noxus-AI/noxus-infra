locals {
  name = "${var.project_name}-${var.environment}"

  tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "noxus-infra"
    },
    var.tags,
  )
}

module "network" {
  source = "../../../modules/aws/network"

  name               = local.name
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  single_nat_gateway = var.environment != "prod"
  cluster_name       = "${local.name}-eks"
  tags               = local.tags
}

module "dns" {
  source = "../../../modules/aws/dns"

  domain    = var.domain
  zone_id   = var.route53_zone_id
  zone_name = var.route53_zone_name
  tags      = local.tags
}

module "eks" {
  source = "../../../modules/aws/eks"

  cluster_name       = "${local.name}-eks"
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.network.vpc_id
  vpc_cidr   = module.network.vpc_cidr
  subnet_ids = module.network.private_subnet_ids

  endpoint_public_access       = var.cluster_endpoint_public_access
  endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  admin_principal_arns         = var.cluster_admin_principal_arns
  grant_creator_admin          = var.grant_creator_admin

  auto_mode_enabled   = var.eks_auto_mode
  managed_node_groups = var.eks_managed_node_groups

  tags = local.tags
}

module "postgres" {
  source = "../../../modules/aws/postgres"

  name       = local.name
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids

  # Reaching the DB is gated on the node security group rather than the VPC CIDR,
  # so anything else placed in the VPC does not get database access for free.
  allowed_security_group_ids = [module.eks.node_security_group_id]

  engine_version        = var.postgres_engine_version
  instance_class        = var.postgres_instance_class
  allocated_storage     = var.postgres_allocated_storage
  multi_az              = var.environment == "prod"
  deletion_protection   = var.environment == "prod"
  backup_retention_days = var.postgres_backup_retention_days

  tags = local.tags
}

module "redis" {
  source = "../../../modules/aws/redis"

  name       = local.name
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids

  allowed_security_group_ids = [module.eks.node_security_group_id]

  node_type     = var.redis_node_type
  replica_count = var.environment == "prod" ? 1 : 0

  tags = local.tags
}

module "storage" {
  source = "../../../modules/aws/storage"

  name                 = local.name
  cors_allowed_origins = ["https://${var.domain}"]
  force_destroy        = var.environment != "prod"
  tags                 = local.tags
}

module "addons" {
  source = "../../../modules/aws/eks-addons"

  name         = local.name
  region       = var.region
  cluster_name = module.eks.cluster_name
  vpc_id       = module.network.vpc_id

  oidc_provider     = module.eks.oidc_provider
  oidc_provider_arn = module.eks.oidc_provider_arn

  platform_namespaces = [var.namespace]
  bucket_arns         = module.storage.bucket_arns

  enable_bedrock   = var.enable_bedrock
  route53_zone_ids = [module.dns.zone_id]

  tags = local.tags
}

module "noxus" {
  source = "../../../modules/platform/noxus-release"

  release_name = var.release_name
  namespace    = var.namespace

  app_version    = var.app_version
  domain         = var.domain
  admin_email    = var.admin_email
  deployment_env = var.environment

  service_account_annotations = module.addons.helm_service_account_annotation

  database = {
    host     = module.postgres.address
    port     = module.postgres.port
    name     = "spot"
    username = module.postgres.username
    password = module.postgres.password
  }

  redis = {
    host = module.redis.primary_endpoint
    port = module.redis.port
  }

  storage = {
    client         = "s3"
    private_bucket = module.storage.private_bucket
    public_bucket  = module.storage.public_bucket
    region         = var.region
    # No static keys: pods authenticate through the IRSA role bound above.
  }

  auth0 = var.auth0

  ingress = {
    enabled    = true
    class_name = "alb"
    annotations = {
      "kubernetes.io/ingress.class"                        = "alb"
      "alb.ingress.kubernetes.io/scheme"                   = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"              = "ip"
      "alb.ingress.kubernetes.io/listen-ports"             = "[{\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/ssl-policy"               = "ELBSecurityPolicy-TLS13-1-2-2021-06"
      "alb.ingress.kubernetes.io/certificate-arn"          = module.dns.certificate_arn
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "idle_timeout.timeout_seconds=600"
    }
  }

  pgbouncer_enabled = var.pgbouncer_enabled
  sandbox_enabled   = var.sandbox_enabled

  extra_env     = var.extra_env
  extra_secrets = var.extra_secrets
  extra_values  = var.extra_values

  depends_on = [module.addons]
}
