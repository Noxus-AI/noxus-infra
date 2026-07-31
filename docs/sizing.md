# Sizing

Starting points, not answers. Every number here is a guess about your workload
that you should replace with a measurement within a week of running.

## The three variables that actually matter

1. **Concurrent workflow and agent runs.** Drives worker count and memory.
2. **Knowledge-base volume and ingestion rate.** Drives worker memory, database
   storage, and vector query cost. This is the usual reason a deployment needs
   more than it expected.
3. **Database connection count.** Not a workload property — a consequence of
   replica count and pool settings. See [configuration.md](configuration.md#sizing-the-connection-ceiling).

Request rate to the API is rarely the constraint.

## Small — evaluation, single team, < 20 users

| | AWS | GCP | Azure |
|---|---|---|---|
| Postgres | `db.t4g.large` | `db-custom-2-8192` | `GP_Standard_D2ds_v5` |
| Redis | `cache.t4g.medium` | 2 GB Basic | Standard C1 |
| Nodes | 2 × `m6a.large` | 2 × `n2-standard-2` | 2 × `Standard_D2ds_v5` |

Chart values:

```yaml
backend:  { replicaCount: 1 }
frontend: { replicaCount: 1 }
worker:
  pools:
    default:
      enabled: true
      workerSubscribe: all      # single pool must cover KB work
      replicaCount: 1
      resources:
        requests: { cpu: "2", memory: "8Gi" }
pgbouncer: { enabled: false }
```

Note `workerSubscribe: all`, not the chart's `all_but_kb` default — with one
pool, `all_but_kb` leaves ingestion jobs with no consumer.

Set `environment = "staging"` in the Terraform stacks to drop Multi-AZ and
deletion protection.

## Medium — production, one organisation, hundreds of users

| | AWS | GCP | Azure |
|---|---|---|---|
| Postgres | `db.m6g.xlarge`, Multi-AZ | `db-custom-4-16384`, regional | `GP_Standard_D4ds_v5`, zone-redundant |
| Redis | `cache.m7g.large` + 1 replica | 5 GB Standard HA | Premium P1 |
| Nodes | 3–8 × `m6a.xlarge` | 3–8 × `n2-standard-4` | 3–8 × `Standard_D4ds_v5` |

```yaml
backend:
  replicaCount: 2
  autoscaling: { enabled: true, minReplicas: 2, maxReplicas: 8 }
  resources:
    requests: { cpu: "2", memory: "6Gi" }
frontend:
  replicaCount: 2
worker:
  pools:
    default:
      enabled: true
      workerSubscribe: all_but_kb
      resources:
        requests: { cpu: "2", memory: "12Gi" }
      autoscaling:
        enabled: true
        type: keda
        minReplicas: 2
        maxReplicas: 20
    kb:
      enabled: true
      workerSubscribe: kb
      replicaCount: 1
      resources:
        requests: { cpu: "4", memory: "16Gi" }
      autoscaling:
        enabled: true
        type: hpa
        minReplicas: 1
        maxReplicas: 5
pgbouncer: { enabled: true }
```

**Split the KB pool here.** This is the point where ingestion sharing a pool with
chat becomes visible as agent latency spikes.

**Turn PgBouncer on here.** At 20 worker replicas the naive connection count is
in the thousands.

## Large — multi-tenant, heavy knowledge bases

| | AWS | GCP | Azure |
|---|---|---|---|
| Postgres | `db.r6g.2xlarge`+, Multi-AZ, read replica for analytics | `db-custom-16-65536`, ENTERPRISE_PLUS | `MO_Standard_E8ds_v5` |
| Redis | `cache.r7g.xlarge`, replicated | 10 GB+ Standard HA | Premium P2+ |
| Nodes | Autoscaling 10–50 | Autoscaling 10–50 | Autoscaling 10–50 |

At this size the shape matters more than the numbers:

- **Dedicated pools per workload class** — `chat`, `flow`, `kb` at minimum.
- **Per-tenant pools** for anyone whose bursts hurt others, using
  `workerSubscribeWorkspaces` on a dedicated pool and
  `workerUnsubscribeWorkspaces` on the catch-all.
- **KEDA everywhere**, with `minReplicas: 0` on pools that are genuinely idle
  overnight and a `cronTrigger` to pre-warm before business hours.
- **Geo regions** (`backend.regions`, `frontend.regions`) pinned to zones with
  `topologySpreadConstraints`, so a zone failure degrades rather than halts.
- **Read replica** for anything analytical. The primary is busy serving the job
  queue.

## Memory notes

**Workers are memory-bound, not CPU-bound.** A worker holds run state, node
outputs, and — during ingestion — whole documents plus embedding batches. A
worker OOM-kills mid-run and the job retries, so undersized memory shows up as
mysteriously slow throughput and repeated work rather than as an obvious crash.

**Backend replicas want several GiB.** The model registry, auth cache, and
integration credential handling are all in-process.

**The sandbox needs headroom for the code it runs**, not for itself. Its 2 GiB
default request is for the manager; user code runs in jails that draw from the
same limit.

## Storage growth

Object storage is where the volume goes:

- Run artifacts accumulate with every execution. `ARCHIVE_MODE` controls when
  state moves from Redis to object storage; `disabled` keeps it hot and costs
  memory instead.
- KB source documents are stored in full, in addition to their embeddings.
- Set a lifecycle rule on noncurrent versions — the modules default to expiring
  them after 90 days.

Database storage grows mainly with the `vectors` database. Budget roughly
1–2 KB per chunk embedded, plus index overhead, and autoscale the disk — on
Azure in particular, IOPS scale with provisioned size, so an undersized disk
throttles the whole platform rather than merely filling up.

## When to move up a tier

| Symptom | Change |
|---------|--------|
| Queue depth stays above zero during business hours | More worker replicas, or raise `maxReplicas` |
| `FATAL: too many connections` in backend logs | PgBouncer, then a larger instance |
| Workers restarting without a clear error | More worker memory |
| KB ingestion starves chat responsiveness | Split the `kb` pool |
| Agent responses truncate after ~60 seconds | Not a sizing issue — proxy read timeout, see [troubleshooting.md](troubleshooting.md) |
| Database CPU pinned during ingestion | Larger instance, or throttle `kb` pool `maxReplicas` |
