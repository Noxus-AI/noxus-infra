# Observability assets

## `grafana/`

Eight Grafana dashboards for the Noxus platform, as JSON.

Each exposes a `datasource` template variable rather than a hard-coded datasource
UID, so they import unmodified into any Prometheus-backed Grafana — self-hosted,
Amazon Managed Grafana, or Google Cloud Monitoring.

| File | UID | Covers |
|------|-----|--------|
| `platform-overview.json` | `noxus-overview` | Dense golden-signal wall: run success, time-to-start, latency across every subsystem, spend, cache hit, error rates. Start here. |
| `execution-engine-workers.json` | `noxus-engine-workers` | Queue depth, time-to-start, parallelism, worker count, run and node lifecycle, respawns, event-loop lag, stalled-job recovery. |
| `agents-and-latency.json` | `noxus-agents-latency` | Agent TTFT split into provider time vs platform overhead, build-stage timings, LLM latency by model. |
| `llm-and-cost.json` | `noxus-llm-cost` | Calls, errors, latency by model, tokens, spend per hour, cache hit ratio, fallbacks and retries. |
| `knowledge-bases.json` | `noxus-knowledge-bases` | Retrieval latency and result counts, ingestion throughput, embedding volume by model and provider. |
| `liquid-storage.json` | `noxus-liquid-storage` | Tiered run-state storage: read source mix, hit ratios by layer, hydration and archive latency. |
| `relays-and-triggers.json` | `noxus-relays-triggers` | Event register-to-dispatch throughput and latency, failures by channel, polling cadence, signature-verify failures. |
| `event-loop-health.json` | `noxus-eventloop-health` | Loop-lag percentiles and blocked-time attribution by culprit frame. |

## Importing

**Manually:** Grafana → Dashboards → New → Import → upload the JSON → pick your
Prometheus datasource.

**Declaratively**, with the Grafana sidecar that ships in kube-prometheus-stack:

```sh
kubectl create configmap noxus-dashboards \
  --from-file=grafana/ \
  -n monitoring \
  --dry-run=client -o yaml \
  | kubectl label -f- --local -o yaml grafana_dashboard=1 \
  | kubectl apply -f-
```

## Prerequisites

The dashboards read metrics the platform exposes on `:8080/metrics`. The Helm
chart already sets the scrape annotations, so any Prometheus that honours
`prometheus.io/scrape` picks them up. See
[`../docs/observability.md`](../docs/observability.md) for per-cloud collection
setup and the four signals worth alerting on.

Panels covering a subsystem you have not enabled — relays, knowledge bases —
read "No data" rather than erroring.
