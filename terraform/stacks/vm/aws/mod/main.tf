provider "aws" {
  region = var.region

  default_tags {
    tags = var.default_tags
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}
