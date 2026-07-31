# Architecture

What the platform is made of, and what each piece needs from the infrastructure
underneath it.

## Components

```
                    ┌──────────────┐
   browser ───────► │   frontend   │  Next.js, SSR
                    └──────┬───────┘
                           │ server-side calls
                    ┌──────▼───────┐
   API clients ───► │   backend    │  FastAPI. Also serves /mcp in-process.
   MCP clients ───► └──┬────────┬──┘
                       │        │
              enqueue  │        │  read/write
                       │        │
                ┌──────▼──┐  ┌──▼──────────────────────────┐
                │ Postgres│  │ Redis · Object storage       │
                └──────▲──┘  └──▲──────────────────────────┘
                       │        │
                  poll │        │
                ┌──────┴────────┴──┐        ┌─────────────┐
                │     workers      │───────►│   sandbox   │  isolated code
                │  (pools)         │        └─────────────┘  execution
                └──────────────────┘
                       ▲
                       │ trigger events
                ┌──────┴───────┐
   Slack ──────►│    relay     │  webhook receivers
   Teams ──────►└──────────────┘
   email ──────►
```

### backend

FastAPI. Serves the REST API, WebSocket streams for live run output, and the
in-process MCP server mounted at `/mcp`. Runs Alembic migrations at startup when
`RUN_MIGRATIONS=1`, and bootstraps the first admin user when `RUN_BOOTSTRAP=1`.

It is not a thin API layer — it holds the model registry, auth caches, and
integration credential handling in memory, which is why it wants several GiB per
replica rather than a few hundred MiB.

### frontend

Next.js in SSR mode. Calls the backend server-side, so it needs network reach to
`BACKEND_URL` and Auth0. The session cookie is signed with `AUTH0_SECRET` —
rotating it logs everyone out.

### workers

Where all real work happens: workflow runs, agent conversations, knowledge-base
ingestion, scheduled jobs. Workers poll a Postgres-backed job queue
(Procrastinate) rather than a broker, which is why database connection pressure
scales with worker replica count.

Each worker pool subscribes to a subset of the queue via `WORKER_SUBSCRIBE`:

| Value | Consumes |
|-------|----------|
| `all` | everything, including KB ingestion and maintenance jobs |
| `all_but_kb` | everything except KB ingestion |
| `flow` | workflow runs |
| `chat` | agent and conversation runs |
| `kb` | knowledge-base ingestion only |

**The default single pool uses `all_but_kb`.** If you ingest documents you need
either a second pool set to `kb` or a pool set to `all`, or ingestion jobs queue
forever with nothing consuming them.

Splitting pools is about isolation of failure and latency, not throughput: KB
ingestion is memory-hungry and bursty, and a pool shared with chat makes agent
response times spike whenever a large document lands.

### relay

Off by default. Receives inbound webhooks from Slack, Teams, and email providers
and converts them into trigger events. Only needed if you deploy agents to those
channels. It is a StatefulSet because some channel integrations need stable
identity across restarts.

### sandbox

Off by default. Isolated execution for the Run Code node and — since the
standalone plugin-server was removed — for **all plugin execution**. The backend
and worker only receive `SANDBOX_MANAGER_URL` when the sandbox is enabled, so a
deployment with plugins but no sandbox silently fails to load them.

Two jail modes:

- `syd` — full syscall and network jail. Needs `SYS_PTRACE`, which some managed
  clusters (GKE Autopilot, restrictive PodSecurity) refuse.
- `minimal` — chroot plus `SYS_ADMIN`, with egress restricted by the bundled
  NetworkPolicy. Weaker; only appropriate for trusted code.

## Data stores

### PostgreSQL

Five logical databases on one server:

| Database | Holds |
|----------|-------|
| `spot` | Application schema — users, workflows, agents, runs |
| `vectors` | Knowledge-base embeddings |
| `procrastinate` | The job queue workers poll |
| `license` | License server state |
| `spot_userdata` | Noxus Tables, when `TABLES_ENABLED` is on |

Requires the `vector`, `uuid-ossp`, and `pg_trgm` extensions. Migrations create
them, so the server must permit it — on Azure Flexible Server that means adding
them to the `azure.extensions` allowlist first, or the backend fails on first
boot with a permission error rather than a clear one.

`scripts/bootstrap-postgres.sh` creates the databases and extensions; run it once
after the first apply.

**Connection pressure is the most common scaling surprise.** Every backend and
worker pod opens its own pool (`POSTGRES_POOL_SIZE`, default 64) plus a separate
vector pool and a Procrastinate pool. Ten worker replicas can mean well over a
thousand connections before any user traffic. Run PgBouncer.

### Redis

Cache, distributed locks, and live-stream coordination. It is not a durable
store — losing it costs a cold cache and any in-flight stream, not data. Use
`allkeys-lru` eviction so it degrades rather than erroring on write under
pressure.

### Object storage

Two buckets:

- **private** — run artifacts, uploaded files, KB source documents. The bulk of
  storage growth.
- **public** — whitelabel and integration assets. Can stay private and be served
  through presigned URLs; only make it publicly readable if you front it with a
  CDN.

The platform speaks S3 or GCS. Azure Blob is used through its S3-compatible
endpoint, with the account name and access key standing in for the S3 key pair.

## Request and job flow

**A synchronous API call** hits the backend, reads and writes Postgres and Redis,
and returns. Nothing queues.

**A workflow or agent run** is enqueued as a Procrastinate job in Postgres. The
backend returns immediately. A worker in a subscribed pool picks it up, executes
nodes, writes state and logs to tiered storage (memory → Redis → object storage),
and streams progress back through Redis to any connected WebSocket.

This is why worker autoscaling on queue depth (KEDA) beats CPU-based HPA: the
backlog is directly observable in the database, whereas CPU only rises after
work has already been sitting.

**A trigger** arrives at the relay as a webhook, or is discovered by a polling
trigger running on a worker. Either way it becomes a queued run.

## What the infrastructure must provide

| Requirement | Why |
|-------------|-----|
| Three hostnames on one domain | Frontend, API, and relay are distinct origins; the backend builds absolute URLs from them |
| TLS termination | Auth0 refuses non-HTTPS callbacks |
| Long-lived connections through the proxy | Agent streaming holds SSE and WebSocket connections for minutes; 60s proxy timeouts truncate responses |
| Stable egress IPs | Third-party services you integrate with often need to allowlist the platform |
| Pod-level cloud credentials | The platform reads and writes object storage and may call Bedrock or Vertex AI |
| Generous DB connection ceiling | See connection pressure above |

## Where the pieces live in this repo

| Component | Kubernetes | Serverless | VM |
|-----------|-----------|------------|-----|
| backend, frontend, worker, relay, sandbox | `charts/noxus-platform` | `terraform/stacks/serverless/` | docker-compose in the appliance image |
| Postgres | `modules/<cloud>/postgres` | same | in-container, on the VM's disk |
| Redis | `modules/<cloud>/redis` | same | in-container |
| Object storage | `modules/<cloud>/storage` | same | MinIO in-container, or a real bucket |
