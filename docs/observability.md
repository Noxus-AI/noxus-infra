# Observability

## Metrics

Every platform pod exposes Prometheus metrics on `:8080/metrics`. The chart sets
the scrape annotations already:

```yaml
prometheus.io/scrape: "true"
prometheus.io/port: "8080"
prometheus.io/path: "/metrics"
```

`PROMETHEUS_MULTIPROC_DIR` (default `/tmp`) must be set, or a multi-process
backend reports only one worker's view.

### Collecting them

| Stack | Options |
|-------|---------|
| EKS | Amazon Managed Prometheus. Pass `prometheus_workspace_arn` to `modules/aws/eks-addons` to grant pods remote-write, and set `PROM_REMOTE_WRITE_URL` |
| GKE | Google Managed Prometheus, enabled by default in `modules/gcp/gke` — it honours the annotations above with no extra config |
| AKS | Azure Monitor managed Prometheus via `monitor_metrics`, enabled in `modules/azure/aks` |
| Anywhere | Self-hosted kube-prometheus-stack |

For push-based collection set `PROM_REMOTE_WRITE_URL` plus
`PROM_REMOTE_WRITE_USERNAME` and `PROM_REMOTE_WRITE_PASSWORD`.

## Dashboards

Eight Grafana dashboards ship in [`observability/grafana/`](../observability/grafana).
They use a `datasource` template variable rather than a hard-coded UID, so they
import into any Prometheus-backed workspace.

```sh
# Grafana → Dashboards → New → Import → upload the JSON, pick your Prometheus
# datasource. Or provision them declaratively:
kubectl create configmap noxus-dashboards \
  --from-file=observability/grafana/ -n monitoring
```

| Dashboard | Answers |
|-----------|---------|
| `platform-overview` | "Is anything wrong?" — 24 golden-signal tiles across every subsystem |
| `execution-engine-workers` | Queue depth, time-to-start, worker count, run and node lifecycle, stalled-job recovery |
| `agents-and-latency` | Agent TTFT split into provider time vs platform overhead, build-stage timings |
| `llm-and-cost` | Calls, errors, tokens, spend per hour, cache hit ratio, fallbacks |
| `knowledge-bases` | Retrieval latency, ingestion throughput, embedding volume by model |
| `liquid-storage` | Tiered run-state storage: hit ratios by layer, hydration and archive latency |
| `relays-and-triggers` | Event register-to-dispatch latency, failures by channel, polling cadence |
| `event-loop-health` | Loop lag percentiles and blocked-time attribution by culprit frame |

Start with `platform-overview` on a wall display and
`execution-engine-workers` when investigating slowness.

## The four signals worth alerting on

Most of the dashboards are for diagnosis. These four are worth paging on:

**Queue depth that does not drain.** A backlog rising steadily through business
hours means workers are undersized or a pool has no subscriber. The specific
failure to watch for: KB ingestion jobs queued with no pool subscribed to `kb`,
which never resolves on its own.

**Time-to-start climbing.** The gap between enqueue and a worker picking the job
up. Rising time-to-start with flat queue depth means workers are alive but busy;
rising with growing depth means not enough of them.

**Database connection count approaching the ceiling.** The failure mode is
abrupt — everything works until the limit, then every new pod fails to connect.
Alert at 80% of `max_connections`.

**Event-loop lag.** Sustained lag means something is blocking the async loop, and
it degrades everything in that process at once. The `event-loop-health`
dashboard attributes blocked time to the code frame responsible.

## Logs

`LOG_LEVEL` controls verbosity for backend and worker.

**`DEBUG` logs prompt and tool-call content.** That includes whatever users put
into agents and whatever the agents retrieve. Treat a DEBUG-level log stream as
carrying the same sensitivity as the platform's database, and do not leave it on
in production or ship it to a general-purpose log aggregator.

`INFO` includes the time-to-first-token breakdown, which is usually enough to
diagnose latency without turning on content logging.

Per-library overrides: `SPOT_AGENTS_LOGGING_LEVEL`, `STDPROMPT_LOGGING_LEVEL`.

### Collection

- **EKS** — Fluent Bit or the CloudWatch agent; `modules/aws/eks-addons` grants
  pods `logs:PutLogEvents`.
- **GKE** — Cloud Logging, on by default via `logging_config`.
- **AKS** — Log Analytics; set `log_analytics_workspace_id` on the stack.

## Tracing

OpenTelemetry, off unless configured:

| Variable | Default |
|----------|---------|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://localhost:4318` |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `grpc` |
| `OTEL_TRACES_EXPORTER` | `otlp` |

LLM-specific observability through Langfuse (`LANGFUSE_PUBLIC_KEY`,
`LANGFUSE_SECRET_KEY`, `LANGFUSE_HOST`, `LANGFUSE_PROJECT`) or Phoenix
(`PHOENIX_COLLECTOR_ENDPOINT`, `PHOENIX_API_KEY`). `ENABLE_LLM_OBSERVABILITY`
gates the instrumentation.

Errors go to Sentry via `SENTRY_URL`.

## Health endpoints

| Path | Used by | Meaning |
|------|---------|---------|
| `/status/health` | Liveness and readiness on backend, worker, relay | Process is up and can reach its dependencies |
| `/status/test-task` | Deeper worker liveness | The worker can actually execute a job — catches a worker that is running but not consuming |
| `/health` | Sandbox | Sandbox manager is up |

The chart uses `tcpSocket` for frontend probes because Next.js has no cheap
health route worth polling.

`/status/test-task` is the more useful worker signal: a worker whose queue
subscription is broken still answers `/status/health` happily.
