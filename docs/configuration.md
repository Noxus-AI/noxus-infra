# Configuration reference

Every deployment mode configures the platform the same way: environment
variables. The Helm chart splits them into `env` (plain) and `secrets`
(sensitive), but both land in the same pod environment.

Names below are exact. Defaults are the platform's own defaults, which are not
always the same as the chart's.

## Required everywhere

Nothing starts without these.

| Variable | Example | Notes |
|----------|---------|-------|
| `DEPLOYMENT_ENV` | `prod` | `local`, `staging`, or `prod`. Affects logging and feature gating. |
| `FRONTEND_URL` | `https://noxus.example.com` | Must match the hostname users reach. |
| `BACKEND_URL` | `https://api.noxus.example.com` | Absolute URLs the API hands out are built from this. |
| `POSTGRESQL_URL` | `user:pass@host:5432` | **No scheme.** The platform prepends the driver. |
| `VECTOR_POSTGRESQL_URL` | `user:pass@host:5432` | Same server is fine; a different database is used. |
| `REDIS_URL` | `redis.internal` | **Hostname only** — no scheme, no port. |
| `SPOTFLOW_STORAGE_BUCKET` | `noxus-artifacts` | Private bucket. |
| `SPOTFLOW_PUBLIC_STORAGE_BUCKET` | `noxus-artifacts-public` | Assets bucket. |
| `ADMIN_EMAIL` | `admin@example.com` | First user created during bootstrap. |

The `POSTGRESQL_URL` and `REDIS_URL` shapes trip people up. They are not URLs in
the usual sense — the platform assembles the full DSN itself, and passing
`postgresql://...` or `redis://...` produces a connection error that names a host
containing the scheme.

## URLs and routing

| Variable | Default | Purpose |
|----------|---------|---------|
| `RELAY_URL` | `http://spotflow-relays:8080` | Public relay hostname when relays are enabled. |
| `NOXUS_BACKEND_URL` | `""` | Loopback URL the MCP tools use to reach this backend. Set to `http://localhost:8080`; a public URL routes out and the local API key is rejected. |
| `MCP_SERVER_URL` | `""` | Public MCP URL. Leave empty unless `BACKEND_URL` goes through a path-stripping or auth-wrapping proxy — otherwise the catalog derives it as `BACKEND_URL + /mcp/`. |
| `INBOX_DOMAIN` | `inbox.noxus.ai` | Domain for case-management email intake. |

## Authentication

| Variable | Notes |
|----------|-------|
| `AUTH0_DOMAIN` | Tenant domain, e.g. `tenant.eu.auth0.com`. |
| `AUTH0_ISSUER_BASE_URL` | `https://<AUTH0_DOMAIN>`. |
| `AUTH0_BASE_URL` | Must equal `FRONTEND_URL`. |
| `AUTH0_API_AUDIENCE` | API identifier configured in Auth0. |
| `AUTH0_CLIENT_ID` / `AUTH0_CLIENT_SECRET` | The application credentials. |
| `AUTH0_SECRET` | Signs the session cookie. 32+ random characters. **Changing it logs every user out.** |
| `AUTH0_MGMT_CLIENT_ID` / `AUTH0_MGMT_CLIENT_SECRET` | Only needed for programmatic user provisioning. |

OIDC is available as an alternative: `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`,
`OIDC_ISSUER`, `OIDC_SCOPES` (default `openid profile email`),
`OIDC_CONNECTION_NAME`, `OIDC_DISPLAY_NAME`.

## Database tuning

| Variable | Platform default | Chart default | Notes |
|----------|------------------|---------------|-------|
| `DATABASE` | `spot` | `spot` | Application database name. |
| `USERDATA_DATABASE` | `spot_userdata` | — | Noxus Tables. |
| `POSTGRES_POOL_SIZE` | `64` | `64` | **Per pod.** Multiply by replica count when sizing the server. |
| `POSTGRES_MAX_OVERFLOW` | `10` | `0` | The chart pins 0 so pool size is a hard ceiling rather than a floor. |
| `VECTOR_POSTGRES_POOL_SIZE` | `64` | `128` | Separate pool for the embeddings database. |
| `VECTOR_POSTGRES_MAX_OVERFLOW` | `10` | `0` | |
| `PROCRASTINATE_POOL_SIZE` | `4` | `4` | Job-queue polling pool. |
| `PROCRASTINATE_POOL_MIN_SIZE` | `0` | `0` | |
| `ASYNC_DB_CHECKOUT_LIMIT` | `0` | `0` | 0 = off. Caps concurrent async checkouts; raise only to relieve pressure from wide subflow fan-out, after auditing nesting depth. |
| `DIRECT_POSTGRESQL_URL` | `""` | — | Bypasses PgBouncer. Needed by operations that require a session-mode connection. |
| `PROCRASTINATE_POSTGRESQL_URL` | `""` | `""` | Optional override; blank reuses `POSTGRESQL_URL`. |
| `LICENSE_POSTGRESQL_URL` | `""` | `""` | |

### Sizing the connection ceiling

```
connections ≈ (backend_replicas + worker_replicas) × (POSTGRES_POOL_SIZE
                                                    + VECTOR_POSTGRES_POOL_SIZE
                                                    + PROCRASTINATE_POOL_SIZE)
```

With the chart defaults and 2 backend + 10 worker replicas that is roughly
`12 × 196 ≈ 2352` — well past what a `db.m6g.large` will accept. This is the
single most common cause of a deployment that works in staging and falls over
under load. Run PgBouncer, which collapses it to the pooler's own backend pool.

## Redis

| Variable | Default | Notes |
|----------|---------|-------|
| `REDIS_URL` | required | Hostname only. |
| `REDIS_PORT` | `6379` | Azure Cache serves TLS on `6380`. |
| `REDIS_SSL` | `""` | Any non-empty value enables TLS. |
| `REDIS_PASSWORD` | `""` | ElastiCache auth token, Memorystore AUTH string, or Azure access key. |
| `REDIS_USER` | `""` | For ACL-based auth. |
| `REDIS_SINGLE_DB_ONLY` | `""` | Set when the provider exposes only database 0. |
| `CELERY_BROKER_URL_OVERRIDE` | `""` | Full broker URL, overriding the derived one. |
| `CACHE_LOCATION` | `redis` | |

## Object storage

| Variable | Default | Notes |
|----------|---------|-------|
| `BUCKET_CLIENT` | `gcloud` | `s3`, `gcloud`, `minio`, or `azure`. |
| `S3_ENDPOINT_URL` | `""` | Set for MinIO. Leave empty for real S3, and unset entirely on Azure — Blob Storage has no S3-compatible endpoint. |
| `S3_ACCESS_KEY_ID` / `S3_SECRET_ACCESS_KEY` | `""` | Omit when pods use IRSA / Workload Identity. |
| `AWS_REGION` | `eu-west-1` | |
| `AZURE_STORAGE_ACCOUNT_KEY` | `null` | Credential for `BUCKET_CLIENT=azure`. On that path `SPOTFLOW_STORAGE_BUCKET` is the storage **account** name, not a container — the client builds `https://<account>.blob.core.windows.net` and writes into a fixed `noxus` container, so the private/public bucket split does not apply. |
| `ARCHIVE_MODE` | `sync` | `sync`, `async`, or `disabled`. Controls when run state is pushed to cold storage. |
| `ARCHIVE_BATCH_INTERVAL` | — | Batching window for `async` mode. |

## Workers

| Variable | Default | Notes |
|----------|---------|-------|
| `WORKER_SUBSCRIBE` | `all` | `all`, `all_but_kb`, `flow`, `chat`, `kb`. The chart's default pool uses `all_but_kb`. |
| `WORKER_SUBSCRIBE_WORKSPACES` | `""` | Comma-separated workspace IDs; empty means all. |
| `WORKER_UNSUBSCRIBE_WORKSPACES` | `""` | Workspaces to exclude, so a catch-all pool can leave specific tenants to dedicated pools. |
| `MAX_TASK_ATTEMPTS` | `3` | Retries before a job is marked failed. |

## Sandbox and plugins

| Variable | Default | Notes |
|----------|---------|-------|
| `SANDBOX_MANAGER_URL` | `""` | Injected only when the sandbox is deployed. **Empty disables plugins entirely.** |
| `USE_REMOTE_SANDBOX` | `true` | |
| `REMOTE_SANDBOX_BACKEND` | `""` | `syd` in normal use. |
| `SANDBOX_BACKEND` | `syd` | |
| `LOCAL_SANDBOX_BACKEND` | `deno` | Worker-local fallback: `deno`, `subprocess` (weaker isolation), or `none`. |
| `PLUGIN_CALL_TIMEOUT` | `240.0` | Seconds. |
| `PLUGIN_SDK_REQUIREMENT` | `noxus-sdk>=0.5.1` | |

## Observability

| Variable | Default | Notes |
|----------|---------|-------|
| `LOG_LEVEL` | `INFO` | **`DEBUG` logs prompt and tool-call content.** Treat that log stream as sensitive data. |
| `PROMETHEUS_MULTIPROC_DIR` | `/tmp` | Required for multi-worker metric aggregation. |
| `PROM_REMOTE_WRITE_URL` | `""` | Push metrics to a remote-write endpoint. |
| `PROM_REMOTE_WRITE_USERNAME` / `_PASSWORD` | `""` | |
| `ENABLE_LLM_OBSERVABILITY` | `true` | |
| `SENTRY_URL` | `""` | |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://localhost:4318` | |
| `OTEL_TRACES_EXPORTER` | `otlp` | |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `grpc` | |
| `LANGFUSE_PUBLIC_KEY` / `_SECRET_KEY` / `_HOST` / `_PROJECT` | `""` | |

## Licensing and platform services

| Variable | Default | Notes |
|----------|---------|-------|
| `ON_PREM` | `false` | Disables features that assume Noxus-hosted services. |
| `IS_PROD` | `false` | |
| `LICENSE_SERVER` | `https://license.app.noxus.ai` | |
| `NCS_SERVER` | `https://ncs.app.noxus.ai` | Noxus Control Service. |
| `USE_NCS` | `true` | |
| `NCS_CHECKIN_ENABLED` | `false` | Periodic check-in for managed upgrades. |
| `BILLING_ENABLED` | `true` | |
| `DEPLOYMENT_NAME` | `NOXUS` | Shown in logs and notifications. |

Air-gapped deployments must set `USE_NCS=false` and `BILLING_ENABLED=false`, or
the platform makes outbound calls that will hang.

## Secrets source

`SECRETS_SOURCE` decides where integration and model API keys come from:

| Value | Behaviour |
|-------|-----------|
| `db` | Stored in the database, managed through the admin UI. **Recommended.** |
| `env` | Read from the process environment. |
| `file` | Read from `SPOT_SECRETS_FILE` (default `.spot/api_keys`). |

With `db`, model provider keys are entered in the admin panel after deployment
rather than baked into your values file.

## Model providers

Set whichever you use — they are all optional and empty by default:
`OPENAI_API_KEY`, `MISTRAL_API_KEY`, `GROQ_API_KEY`, `DEEPSEEK_API_KEY`,
`PERPLEXITY_API_KEY`, `AZURE_AI_API_KEY` + `AZURE_AI_API_BASE`,
`AWS_BEDROCK_KEY`, `VERTEX_PROJECT_ID`.

Bedrock and Vertex are better reached through pod identity than static keys — see
the `enable_bedrock` and `grant_vertex_ai` variables in the AWS and GCP stacks.

Bedrock connection tuning: `BEDROCK_MAX_POOL_CONNECTIONS` (50),
`AWS_READ_TIMEOUT` (300), `AWS_CONNECT_TIMEOUT` (30).

## Startup behaviour

| Variable | Default in chart | Notes |
|----------|------------------|-------|
| `RUN_MIGRATIONS` | `1` | Backend runs Alembic on startup. |
| `RUN_BOOTSTRAP` | `1` | Creates the admin user and seed data on an empty database. |

Both are idempotent, so leaving them on is safe. See
[upgrades.md](upgrades.md) for the ordering that matters during a version bump.
