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

| Service | Shape | Notes |
|---------|-------|-------|
| backend | Request-scaled | Serves the API and the MCP endpoint at `/mcp` |
| frontend | Request-scaled | |
| worker | Always-on | Polls the job queue |
| beat | Always-on, single instance | Scheduled jobs. **Must not scale past 1** — duplicate schedulers double-enqueue |
| relay | Request-scaled | Only when integration channels are used |

## Common configuration

Both stacks configure the platform with the same environment variables as every
other deployment mode — see [docs/configuration.md](../../../docs/configuration.md).
The shapes that catch people out are the same too: `POSTGRESQL_URL` takes no
scheme, `REDIS_URL` is a bare hostname.
