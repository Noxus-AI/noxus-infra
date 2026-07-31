# noxus-platform Helm chart

Deploys the Noxus platform onto any conformant Kubernetes cluster — EKS, GKE, AKS,
or self-managed. The chart deploys the application only; **Postgres, Redis, and
object storage are expected to already exist** and are passed in as connection
strings. The Terraform stacks in `terraform/stacks/kubernetes/` provision those
dependencies and install this chart for you.

## Components

| Component | Kind | Default | Purpose |
|-----------|------|---------|---------|
| `backend` | Deployment | on | FastAPI API server. Also serves the MCP server at `/mcp` (in-process, no separate pod). |
| `frontend` | Deployment | on | Next.js web app. |
| `worker` | Deployment per pool | on | Executes workflows and agent runs. Pools are independently scaled and subscribed. |
| `relay` | StatefulSet | **off** | Webhook receivers for Slack / Teams / email. Only needed if you use those channels. |
| `sandbox` | Deployment | **off** | Isolated code execution (`agentsandbox`). **Required for plugins.** |
| `pgbouncer` | Deployment | **off** | Connection pooler in front of Postgres. Strongly recommended at scale. |
| `keda` | subchart | on | Queue-depth autoscaling for worker pools. Set `keda.enabled=false` if already installed cluster-wide. |

## Quick start

```sh
helm dependency update charts/noxus-platform

helm upgrade --install noxus charts/noxus-platform \
  --namespace noxus --create-namespace \
  --values my-values.yaml
```

Minimum viable `my-values.yaml`:

```yaml
appVersion: "0.8.1"

env:
  ADMIN_EMAIL: admin@example.com
  BACKEND_URL: https://api.example.com
  FRONTEND_URL: https://example.com
  BUCKET_CLIENT: s3
  SPOTFLOW_STORAGE_BUCKET: noxus-artifacts
  SPOTFLOW_PUBLIC_STORAGE_BUCKET: noxus-artifacts-public

secrets:
  POSTGRESQL_URL: "user:password@postgres.internal:5432"
  VECTOR_POSTGRESQL_URL: "user:password@postgres.internal:5432"
  REDIS_URL: "redis.internal"
  AUTH0_DOMAIN: tenant.eu.auth0.com
  AUTH0_ISSUER_BASE_URL: https://tenant.eu.auth0.com
  AUTH0_BASE_URL: https://example.com
  AUTH0_API_AUDIENCE: https://api.example.com
  AUTH0_CLIENT_ID: "..."
  AUTH0_CLIENT_SECRET: "..."
  AUTH0_SECRET: "..."           # 32+ random chars, used to sign session cookies

ingress:
  enabled: true
  className: alb
  domain: example.com
```

Cloud-specific starting points: [`values-aws.example.yaml`](values-aws.example.yaml),
[`values-gcp.example.yaml`](values-gcp.example.yaml), [`values-azure.example.yaml`](values-azure.example.yaml).

## The `env` / `secrets` split

Two flat maps become two Kubernetes objects:

- `env:` → ConfigMap-like plain values, rendered into the app env Secret.
- `secrets:` → the same Secret, kept separate in values so you can source them from
  a different file, SOPS, or `--set`.

Everything in both maps is injected into backend, frontend, worker, and relay pods.
`extraEnv` merges on top of `env` (and wins). `frontendExtraEnv` adds frontend-only
vars. `relayExcludeKeys` strips keys from the relay's copy.

Never commit real values under `secrets:`. Use a separate un-tracked values file,
`--set`, or an external secret operator that writes the Secret this chart references.

The full env-var reference lives in [`../../docs/configuration.md`](../../docs/configuration.md).

## DNS and ingress

`ingress.domain` drives three hostnames, derived automatically:

| Host | Routes to |
|------|-----------|
| `<domain>` | frontend (`/`), backend (`/mcp`) |
| `api.<domain>` | backend |
| `relay.<domain>` | relay (only when `relay.enabled=true`) |

These must match `env.FRONTEND_URL`, `env.BACKEND_URL`, and `env.RELAY_URL` — the
backend builds absolute URLs (OAuth callbacks, webhook registrations, file links)
from those vars, so a mismatch produces redirects that dead-end.

`ingress.className` and `ingress.annotations` are cloud-specific:

- **EKS** — `alb`, with `alb.ingress.kubernetes.io/certificate-arn` set to your ACM cert.
  Requires the AWS Load Balancer Controller.
- **GKE** — `gce`, with `networking.gke.io/managed-certificates` or a pre-shared cert.
- **AKS** — `nginx` or `webapprouting.kubernetes.azure.com`, with cert-manager for TLS.

## Worker pools

Each entry under `worker.pools` becomes its own Deployment, Service, HPA/ScaledObject,
and PDB. A pool's `workerSubscribe` decides what it picks up:

| Value | Consumes |
|-------|----------|
| `all` | everything, including knowledge-base ingestion and maintenance jobs |
| `all_but_kb` | everything except KB ingestion (the default pool) |
| `flow` | workflow runs |
| `chat` | agent/conversation runs |
| `kb` | knowledge-base ingestion only |

The default single `default` pool (`all_but_kb`) is fine for small deployments, but
note it excludes KB work — if you ingest documents you need either a `kb` pool or a
pool set to `all`. Splitting matters because KB ingestion is memory-hungry and bursty;
letting it share a pool with chat makes agent latency spike during ingestion.

`workerSubscribeWorkspaces` / `workerUnsubscribeWorkspaces` pin pools to specific
workspaces — used to give a noisy tenant dedicated capacity without starving others.

### Autoscaling

`autoscaling.type: hpa` uses CPU/memory. `autoscaling.type: keda` scales on queue
depth via a Postgres query (`worker.keda.query`), which tracks actual backlog rather
than a lagging CPU signal — prefer it for workers. KEDA needs
`worker.keda.postgresConnectionString` (full `postgresql://` URL, unlike the app's
`POSTGRESQL_URL` which omits the scheme) or `existingPostgresSecret`.

## Sandbox and plugins

`sandbox.enabled=false` by default. Turn it on if you need:

- the **Run Code** node with real isolation, or
- **plugins** — these now execute inside the sandbox; the standalone plugin-server is
  gone. `SANDBOX_MANAGER_URL` is only injected when `sandbox.enabled=true`, so a
  deployment upgrading from `pluginServer.enabled=true` must flip this on or its
  plugin nodes and triggers silently fail to load.

`sandbox.jail: syd` gives full syscall + network jailing but needs `SYS_PTRACE`.
Clusters that forbid it can use `jail: minimal` (chroot + `SYS_ADMIN`, egress
restricted by the bundled NetworkPolicy) — weaker isolation, so only use it for
trusted workloads.

## PgBouncer

Off by default; enable it once you have more than a couple of worker replicas.
Each backend and worker pod opens its own pool (`POSTGRES_POOL_SIZE`, default 64),
so connection count grows with replicas and hits RDS/Cloud SQL limits quickly.

- `pgbouncer.enabled=true` — chart deploys one, and rewrites `POSTGRESQL_URL` /
  `VECTOR_POSTGRESQL_URL` in the app Secret to point at it.
- `pgbouncer.managed_externally=true` + `hostname_override` — same rewrite, pointing
  at a pooler you run yourself.

Either mode needs `pgbouncer.postgresqlUrlSecret.name` — an existing Secret holding
the real upstream `POSTGRESQL_URL`, since the app-env copy now points at the pooler.

## Geo-replication

`backend.regions` and `frontend.regions` create extra Deployments carrying the same
`app:` label, so the single Service load-balances across all of them. Each region
overrides only what it needs (`nodeSelector`, `replicaCount`, `resources`,
`autoscaling`); unset fields inherit the parent block.

## Upgrading

`env.RUN_MIGRATIONS="1"` makes the backend run Alembic migrations on startup. With
multiple backend replicas the migration is guarded, but the safest sequence for a
major upgrade is still: scale workers to 0, upgrade, let the backend migrate, scale
workers back. See [`../../docs/upgrades.md`](../../docs/upgrades.md).

## Values reference

Run `helm show values charts/noxus-platform` for the annotated defaults — the
`values.yaml` comments are the authoritative per-key documentation.
