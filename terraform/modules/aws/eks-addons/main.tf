data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # IRSA trust policies key off the OIDC issuer without its scheme.
  oidc_condition_prefix = var.oidc_provider
}

# --------------------------------------------------------------------------
# Platform pod role — what the backend, worker, and sandbox pods are allowed to
# do. Bound to the chart's ServiceAccount via the eks.amazonaws.com/role-arn
# annotation (see helm_service_account_annotation output).
# --------------------------------------------------------------------------

data "aws_iam_policy_document" "pods_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_condition_prefix}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "${local.oidc_condition_prefix}:sub"
      values   = [for ns in var.platform_namespaces : "system:serviceaccount:${ns}:*"]
    }
  }
}

resource "aws_iam_role" "pods" {
  name               = "${var.name}-pods"
  assume_role_policy = data.aws_iam_policy_document.pods_trust.json
  tags               = var.tags
}

data "aws_iam_policy_document" "pods" {
  statement {
    sid    = "ArtifactStorage"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:GetBucketLocation",
    ]
    resources = concat(var.bucket_arns, [for arn in var.bucket_arns : "${arn}/*"])
  }

  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["arn:aws:logs:${var.region}:${local.account_id}:*"]
  }

  dynamic "statement" {
    for_each = var.enable_bedrock ? [1] : []
    content {
      sid    = "Bedrock"
      effect = "Allow"
      actions = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
        "bedrock:Converse",
        "bedrock:ConverseStream",
        "bedrock:GetFoundationModel",
        "bedrock:ListFoundationModels",
      ]
      resources = var.bedrock_model_arns
    }
  }

  dynamic "statement" {
    for_each = var.prometheus_workspace_arn != "" ? [1] : []
    content {
      sid       = "PrometheusRemoteWrite"
      effect    = "Allow"
      actions   = ["aps:RemoteWrite", "aps:GetSeries", "aps:GetLabels", "aps:GetMetricMetadata"]
      resources = [var.prometheus_workspace_arn]
    }
  }
}

resource "aws_iam_role_policy" "pods" {
  name   = "${var.name}-pods"
  role   = aws_iam_role.pods.id
  policy = data.aws_iam_policy_document.pods.json
}

# --------------------------------------------------------------------------
# AWS Load Balancer Controller — turns the chart's Ingress into an ALB.
# Without it, `ingress.className: alb` produces an Ingress nothing acts on.
# --------------------------------------------------------------------------

data "aws_iam_policy_document" "lb_controller_trust" {
  count = var.enable_load_balancer_controller ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_condition_prefix}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_condition_prefix}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "lb_controller" {
  count = var.enable_load_balancer_controller ? 1 : 0

  name               = "${var.name}-aws-lb-controller"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_trust[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy" "lb_controller" {
  count = var.enable_load_balancer_controller ? 1 : 0

  name = "${var.name}-aws-lb-controller"
  role = aws_iam_role.lb_controller[0].id
  # Upstream-maintained policy document, vendored so the module has no network
  # dependency at plan time. Refresh with scripts/update-lb-controller-policy.sh.
  policy = file("${path.module}/policies/aws-load-balancer-controller.json")
}

resource "helm_release" "lb_controller" {
  count = var.enable_load_balancer_controller && var.install_helm_releases ? 1 : 0

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.load_balancer_controller_chart_version
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.lb_controller[0].arn
  }
  set {
    name  = "region"
    value = var.region
  }
  set {
    name  = "vpcId"
    value = var.vpc_id
  }
}

# --------------------------------------------------------------------------
# external-dns — creates the Route53 records for the three platform hostnames
# from the annotation the chart's Ingress carries.
# --------------------------------------------------------------------------

data "aws_iam_policy_document" "external_dns_trust" {
  count = var.enable_external_dns ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_condition_prefix}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_condition_prefix}:sub"
      values   = ["system:serviceaccount:kube-system:external-dns"]
    }
  }
}

resource "aws_iam_role" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  name               = "${var.name}-external-dns"
  assume_role_policy = data.aws_iam_policy_document.external_dns_trust[0].json
  tags               = var.tags
}

data "aws_iam_policy_document" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["route53:ChangeResourceRecordSets"]
    # Scoped to the specific zones this deployment owns, not every zone in the
    # account — external-dns will happily rewrite records it can reach.
    resources = [for id in var.route53_zone_ids : "arn:aws:route53:::hostedzone/${id}"]
  }

  statement {
    effect = "Allow"
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  name   = "${var.name}-external-dns"
  role   = aws_iam_role.external_dns[0].id
  policy = data.aws_iam_policy_document.external_dns[0].json
}

resource "helm_release" "external_dns" {
  count = var.enable_external_dns && var.install_helm_releases ? 1 : 0

  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns"
  chart      = "external-dns"
  version    = var.external_dns_chart_version
  namespace  = "kube-system"

  set {
    name  = "provider.name"
    value = "aws"
  }
  set {
    name  = "serviceAccount.name"
    value = "external-dns"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.external_dns[0].arn
  }
  set {
    name  = "txtOwnerId"
    value = var.cluster_name
  }
  # upsert-only: a deleted Ingress leaves its DNS record behind rather than
  # blackholing the hostname during a bad rollout.
  set {
    name  = "policy"
    value = "upsert-only"
  }
}
