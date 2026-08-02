# Serverless container deployments

Each platform service runs as a managed container service, backed by managed
Postgres and Redis. No Kubernetes.

| Stack | Platform |
|-------|----------|
| `gcp-cloudrun` | Google Cloud Run |
| `azure-containerapps` | Azure Container Apps |

## When this is the right shape

Production-grade managed data stores without owning a cluster, for load that is
bursty with a low baseline. See
[docs/choosing-a-deployment.md](../../../docs/choosing-a-deployment.md).

## The constraint to understand first

**Workers cannot be request-scaled.** Workflow runs and knowledge-base ingestion
are long-running and outlive request timeouts on both platforms. Workers
therefore run as always-on instances with a fixed replica count, which removes
most of the scale-to-zero cost argument for the largest component.

Two consequences:

- Cost is closer to always-on containers than to true serverless.
- Worker pool isolation is coarse. You get services, not pools with distinct
  queue subscriptions and independent autoscaling — so a large document upload
  can still affect agent latency in a way the Kubernetes stacks let you prevent.

If knowledge-base ingestion is central to your workload, use Kubernetes.

## Services deployed

| Service | Shape | `gcp-cloudrun` | `azure-containerapps` | Notes |
|---------|-------|:--:|:--:|-------|
| backend | Request-scaled | ✓ | ✓ | Serves the API and the MCP endpoint at `/mcp` |
| frontend | Request-scaled | ✓ | ✓ | |
| worker | Always-on | ✓ | ✓ | Polls the job queue |
| relay | Request-scaled | ✓ | ✓ | Only when integration channels are used |
| beat | Always-on, single instance | ✓ | — | Scheduled jobs. **Must not scale past 1** — duplicate schedulers double-enqueue |

<!-- The beat gap is real, not an oversight in this table: the Azure stack
     deploys four container apps and none of them overrides the worker
     entrypoint, so nothing runs the scheduler. -->

> **The Azure stack has no scheduler.** Cloud Run runs `beat` as a fifth service
> (the worker image with `beat_start.sh` as its command). Container Apps does
> not, so anything time-driven — polling triggers, scheduled workflow runs,
> periodic maintenance jobs — will not fire there. Event-driven and
> user-initiated work is unaffected.
>
> If you need scheduled work on Azure today, either add a fifth container app
> running the worker image with that command and `min_replicas = max_replicas = 1`,
> or use the [Kubernetes](../kubernetes/azure-aks) path, where the chart handles it.

Neither stack deploys the **Agent Sandbox**, which is required for plugins and
for isolated Run Code execution. See [docs/architecture.md](../../../docs/architecture.md).

## Common configuration

Both stacks configure the platform with the same environment variables as every
other deployment mode — see [docs/configuration.md](../../../docs/configuration.md).
The shapes that catch people out are the same too: `POSTGRESQL_URL` takes no
scheme, `REDIS_URL` is a bare hostname.
