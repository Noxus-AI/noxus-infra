variable "project_name" {
  description = "The name of the project"
}
variable "environment" {
  description = "The environment (dev, staging, prod)"
}
variable "region" {
  description = "The AWS region"
  default     = "eu-west-1"
}
variable "ami_id" {
  description = "The AMI ID to use for the instance"
}

variable "domain" {
  description = "The domain to use"
}

variable "dns_zone" {
  description = "The dns zone to use"
}

variable "vm_config" {
  description = "VM configuration to be passed to user_data"
  type        = map(string)
  default     = {}
}

variable "google_project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "snapshot_identifier" {
  description = "The snapshot ID to restore from. If provided, the database will be restored from this snapshot."
  type        = string
  default     = null
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

provider "aws" {
  region = var.region

  default_tags {
    tags = { "managed-by" = "terraform" }
  }
}

# GitHub Actions IAM User
resource "aws_iam_user" "github_actions" {
  name = "${local.name_prefix}-github-actions"
  path = "/service-accounts/"
}

resource "aws_iam_access_key" "github_actions" {
  user = aws_iam_user.github_actions.name
}

resource "aws_iam_user_policy_attachment" "github_actions_admin" {
  user       = aws_iam_user.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "github_actions_access_key" {
  value     = aws_iam_access_key.github_actions.id
  sensitive = false
}

output "github_actions_secret_key" {
  value     = aws_iam_access_key.github_actions.secret
  sensitive = true
}

module "deploy" {
  source            = "./mod"
  project_name      = var.project_name
  environment       = var.environment
  region            = var.region
  ami_id            = var.ami_id
  domain            = var.domain
  dns_zone          = var.dns_zone
  vm_config         = var.vm_config
  google_project_id = var.google_project_id
}
