locals {
  chart_path = var.chart_path != "" ? var.chart_path : "${path.module}/../../../../charts/noxus-platform"

  postgres_url = "${var.database.username}:${var.database.password}@${var.database.host}:${var.database.port}"

  keda_connection_string = coalesce(
    var.database.keda_url,
    "postgresql://${var.database.username}:${var.database.password}@${var.database.host}:${var.database.port}/${var.database.name}"
  )

  # The chart derives api.<domain> and relay.<domain> itself, but the backend also
  # builds absolute URLs from these env vars — OAuth callbacks, webhook
  # registrations, file links. They must agree with the ingress hostnames or
  # those flows dead-end at a host that resolves to nothing.
  urls = {
    FRONTEND_URL = "https://${var.domain}"
    BACKEND_URL  = "https://api.${var.domain}"
    RELAY_URL    = "https://relay.${var.domain}"
  }

  # Azure Blob has no S3-compatible endpoint, so BUCKET_CLIENT=azure takes a
  # different credential shape entirely: the account key, and the account name
  # standing in for the bucket. Emitting the S3 pair alongside it would leave a
  # stale endpoint URL pointing somewhere that does not speak S3.
  storage_env = merge(
    {
      BUCKET_CLIENT                  = var.storage.client
      SPOTFLOW_STORAGE_BUCKET        = var.storage.private_bucket
      SPOTFLOW_PUBLIC_STORAGE_BUCKET = var.storage.public_bucket
    },
    var.storage.client == "azure" ? {} : {
      S3_ENDPOINT_URL = var.storage.endpoint_url
      AWS_REGION      = var.storage.region
    },
  )

  storage_secrets = var.storage.client == "azure" ? {
    AZURE_STORAGE_ACCOUNT_KEY = var.storage.azure_account_key
    } : {
    S3_ACCESS_KEY_ID     = var.storage.access_key_id
    S3_SECRET_ACCESS_KEY = var.storage.secret_access_key
  }

  base_env = merge(
    {
      ADMIN_EMAIL     = var.admin_email
      DEPLOYMENT_ENV  = var.deployment_env
      DEPLOYMENT_NAME = var.deployment_name
      IS_PROD         = var.deployment_env == "prod" ? "true" : "false"
      ON_PREM         = var.on_prem ? "true" : "false"
      LOG_LEVEL       = var.log_level

      REDIS_PORT = tostring(var.redis.port)
      REDIS_SSL  = var.redis.tls ? "true" : ""
    },
    local.storage_env,
    local.urls,
    var.extra_env,
  )

  base_secrets = merge(
    {
      POSTGRESQL_URL        = local.postgres_url
      VECTOR_POSTGRESQL_URL = local.postgres_url

      REDIS_URL      = var.redis.host
      REDIS_PASSWORD = var.redis.password

      AUTH0_DOMAIN             = var.auth0.domain
      AUTH0_ISSUER_BASE_URL    = "https://${var.auth0.domain}"
      AUTH0_BASE_URL           = local.urls.FRONTEND_URL
      AUTH0_API_AUDIENCE       = var.auth0.api_audience
      AUTH0_CLIENT_ID          = var.auth0.client_id
      AUTH0_CLIENT_SECRET      = var.auth0.client_secret
      AUTH0_SECRET             = coalesce(var.auth0.session_secret, random_password.auth0_session.result)
      AUTH0_MGMT_CLIENT_ID     = var.auth0.mgmt_client_id
      AUTH0_MGMT_CLIENT_SECRET = var.auth0.mgmt_client_secret
    },
    local.storage_secrets,
    var.extra_secrets,
  )

  computed_values = {
    appVersion = var.app_version

    global = {
      imageRegistry    = var.image_registry
      imagePullSecrets = [for name in var.image_pull_secrets : { name = name }]
    }

    serviceAccount = {
      create      = true
      annotations = var.service_account_annotations
    }

    env     = local.base_env
    secrets = local.base_secrets

    ingress = {
      enabled     = var.ingress.enabled
      className   = var.ingress.class_name
      domain      = var.domain
      annotations = var.ingress.annotations
      tls         = var.ingress.tls
    }

    pgbouncer = {
      enabled = var.pgbouncer_enabled
      postgresqlUrlSecret = {
        name = var.pgbouncer_enabled ? kubernetes_secret_v1.pgbouncer_upstream[0].metadata[0].name : ""
      }
    }

    worker = {
      keda = {
        existingPostgresSecret = var.keda_enabled ? kubernetes_secret_v1.keda_postgres[0].metadata[0].name : ""
      }
    }

    keda = {
      # KEDA is installed as a subchart only when this release owns it. Clusters
      # that already run a KEDA operator must not get a second one — two
      # operators reconciling the same ScaledObjects fight over replica counts.
      enabled = var.keda_enabled && var.install_keda
    }

    sandbox = {
      enabled = var.sandbox_enabled
    }
  }
}

resource "random_password" "auth0_session" {
  length  = 48
  special = false
}

resource "kubernetes_namespace_v1" "this" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name   = var.namespace
    labels = var.namespace_labels
  }
}

# PgBouncer needs the real upstream URL, because the app-env Secret the chart
# generates points at PgBouncer instead.
resource "kubernetes_secret_v1" "pgbouncer_upstream" {
  count = var.pgbouncer_enabled ? 1 : 0

  metadata {
    name      = "${var.release_name}-upstream-postgres"
    namespace = var.namespace
  }

  data = {
    POSTGRESQL_URL = local.postgres_url
  }

  depends_on = [kubernetes_namespace_v1.this]
}

# KEDA's Postgres scaler wants a full postgresql:// URL, a different shape from
# the app's scheme-less POSTGRESQL_URL.
resource "kubernetes_secret_v1" "keda_postgres" {
  count = var.keda_enabled ? 1 : 0

  metadata {
    name      = "${var.release_name}-keda-postgres"
    namespace = var.namespace
  }

  data = {
    connectionString = local.keda_connection_string
  }

  depends_on = [kubernetes_namespace_v1.this]
}

resource "helm_release" "noxus" {
  name      = var.release_name
  chart     = local.chart_path
  namespace = var.namespace

  dependency_update = true
  timeout           = var.helm_timeout
  atomic            = var.helm_atomic
  wait              = var.helm_wait

  values = concat(
    [yamlencode(local.computed_values)],
    var.extra_values,
  )

  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_secret_v1.pgbouncer_upstream,
    kubernetes_secret_v1.keda_postgres,
  ]
}
