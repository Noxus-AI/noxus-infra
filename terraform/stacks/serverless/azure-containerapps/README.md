# Noxus on Azure Container Apps

**Not yet implemented.** This directory is the intended home for the Container
Apps stack; the Terraform is being supplied separately.

## What it needs to provide

To match the Cloud Run stack and the shared expectations documented in
[docs/configuration.md](../../../../docs/configuration.md):

| Piece | Notes |
|-------|-------|
| Container Apps Environment | VNet-integrated, so it can reach Postgres and Redis privately |
| `backend` app | Ingress enabled, external. Serves the API and `/mcp` |
| `frontend` app | Ingress enabled, external |
| `worker` app | **No ingress; fixed replicas, min ≥ 1.** Runs long jobs that outlive request scaling |
| `beat` app | **Exactly one replica.** Duplicate schedulers double-enqueue |
| `relay` app | Ingress enabled, external. Only when integration channels are used |
| PostgreSQL Flexible Server | Reuse `terraform/modules/azure/postgres` — it already sets the `azure.extensions` allowlist that pgvector needs |
| Azure Cache for Redis | Reuse `terraform/modules/azure/redis` — it emits the port and TLS flag Azure requires |
| Storage account | Reuse `terraform/modules/azure/storage` |

## Constraints to respect

- **Redis is TLS-only on 6380.** Set `REDIS_PORT=6380` and `REDIS_SSL=true`, or
  every connection fails.
- **Postgres extensions need the allowlist.** `VECTOR`, `UUID-OSSP`, and
  `PG_TRGM` must be in `azure.extensions` before the backend's first migration.
- **Ingress timeouts.** Agent streaming holds connections for minutes; the
  default request timeout truncates responses.
- **`POSTGRESQL_URL` takes no scheme** and **`REDIS_URL` is a bare hostname.**
- **Blob Storage** is consumed through its S3-compatible endpoint:
  `BUCKET_CLIENT=s3`, `S3_ENDPOINT_URL` pointing at the account, account name and
  key as the S3 credential pair.

## Then

Wire it into [`.github/workflows/validate.yml`](../../../../.github/workflows/validate.yml)
— the loop over `terraform/stacks/*/*/` picks it up automatically once it
contains `.tf` files — and add a row to the table in
[docs/choosing-a-deployment.md](../../../../docs/choosing-a-deployment.md).
