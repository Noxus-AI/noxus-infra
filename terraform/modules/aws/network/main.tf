data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # /16 split into /20s: first az_count for private, next az_count for public.
  private_subnets = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i + var.az_count)]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = "${var.name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_nat_gateway = true
  # One NAT gateway is a single-AZ failure domain and a bandwidth chokepoint. Only
  # acceptable for non-production, where the ~$100/mo/AZ saving matters more.
  single_nat_gateway = var.single_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  # The AWS Load Balancer Controller discovers subnets by these tags. Without them
  # an `internet-facing` Ingress fails to provision with "no matching subnets".
  public_subnet_tags = merge(
    { "kubernetes.io/role/elb" = "1" },
    var.cluster_name != "" ? { "kubernetes.io/cluster/${var.cluster_name}" = "shared" } : {}
  )
  private_subnet_tags = merge(
    { "kubernetes.io/role/internal-elb" = "1" },
    var.cluster_name != "" ? { "kubernetes.io/cluster/${var.cluster_name}" = "shared" } : {}
  )

  tags = var.tags
}

# S3 gateway endpoint keeps artifact traffic off the NAT gateway. Object storage is
# the highest-volume egress path in this platform (KB ingestion, run artifacts), so
# this is usually the single largest NAT cost saving available.
resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_endpoint ? 1 : 0

  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = merge(var.tags, { Name = "${var.name}-s3-endpoint" })
}
