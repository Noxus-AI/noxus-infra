# Every credential the services read is a Secret Manager secret mounted as an
# environment variable, so none of them appear in the Cloud Run configuration.

resource "random_password" "auth0_secret" {
  length  = 64
  special = false
}

# Grants admin on the backend to anyone presenting it as X-API-Key, and is the
# only credential on the sandbox control plane. The platform's built-in default
# is a published value, so it must always be set.
resource "random_password" "admin_api_key" {
  length  = 48
  special = false
}

resource "random_bytes" "credential_encryption_key" {
  length = 32
}

locals {
  # A Fernet key is 32 bytes in URL-safe base64.
  generated_fernet_key = replace(replace(random_bytes.credential_encryption_key.base64, "+", "-"), "/", "_")

  # Keyed by a non-sensitive name so the set can drive for_each.
  secret_names = concat(
    ["postgres-url", "auth0-client-secret", "auth0-secret", "admin-api-key", "credential-encryption-key"],
    var.auth0_mgmt_client_id != "" ? ["auth0-mgmt-client-secret"] : [],
  )

  secret_values = {
    "postgres-url"              = local.postgresql_url
    "auth0-client-secret"       = var.auth0_client_secret
    "auth0-secret"              = random_password.auth0_secret.result
    "admin-api-key"             = random_password.admin_api_key.result
    "credential-encryption-key" = var.credential_encryption_key != "" ? var.credential_encryption_key : local.generated_fernet_key
    "auth0-mgmt-client-secret"  = var.auth0_mgmt_client_secret
  }
}

resource "google_secret_manager_secret" "platform" {
  for_each = toset(local.secret_names)

  secret_id = "${local.prefix}-${each.key}"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  depends_on = [google_project_service.enabled]
}

resource "google_secret_manager_secret_version" "platform" {
  for_each = toset(local.secret_names)

  secret      = google_secret_manager_secret.platform[each.key].id
  secret_data = local.secret_values[each.key]
}

locals {
  # Environment variable => secret, per service. The frontend only needs the
  # Auth0 pair; the sandbox only needs the key the platform calls it with.
  platform_secret_env = merge(
    {
      POSTGRESQL_URL            = "postgres-url"
      VECTOR_POSTGRESQL_URL     = "postgres-url"
      AUTH0_CLIENT_SECRET       = "auth0-client-secret"
      AUTH0_SECRET              = "auth0-secret"
      ADMIN_API_KEY             = "admin-api-key"
      CREDENTIAL_ENCRYPTION_KEY = "credential-encryption-key"
    },
    var.auth0_mgmt_client_id != "" ? { AUTH0_MGMT_CLIENT_SECRET = "auth0-mgmt-client-secret" } : {},
  )

  frontend_secret_env = {
    AUTH0_CLIENT_SECRET = "auth0-client-secret"
    AUTH0_SECRET        = "auth0-secret"
  }

  sandbox_secret_env = {
    ADMIN_API_KEY = "admin-api-key"
  }
}
