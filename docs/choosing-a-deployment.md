# Choosing a deployment

Three shapes, in decreasing order of operational cost and increasing order of
constraint. Pick the least complex one that meets your requirements.

## Single VM

`terraform/stacks/vm/{aws,gcp,azure}`, plus the Azure Marketplace offer in
`marketplace/azure-vm/`.

Everything — backend, frontend, worker, Postgres, Redis, MinIO, nginx — runs as
docker-compose on one machine, from a prebuilt appliance image.

**Choose it when** you are running a trial or POC, deploying into an air-gapped
or heavily restricted network, or serving a single small tenant where an hour of
downtime is acceptable.

**Do not choose it when** you need any availability guarantee. There is one of
everything; a host failure is an outage, and upgrades restart the whole stack.
Database backups are the VM's disk snapshots, not a managed backup service.

Scaling ceiling is roughly what one large instance can do — in practice a handful
of concurrent workflow runs and a modest knowledge base.

## Serverless containers

`terraform/stacks/serverless/gcp-cloudrun` and
`terraform/stacks/serverless/azure-containerapps`.

Each platform service becomes a managed container service, backed by managed
Postgres and Redis.

**Choose it when** you want production-grade managed data stores without running
Kubernetes, your load is bursty with a low baseline, and your team would rather
not own a cluster.

**Do not choose it when** knowledge-base ingestion is central to your use case.
Ingestion jobs are long-running and memory-heavy; serverless container platforms
impose request and instance lifetime limits that ingestion can exceed. Workers
run as always-on instances here specifically to work around that, which erodes
much of the cost argument.

Also weaker on: fine-grained worker pool isolation (you get services, not pools
with distinct queue subscriptions) and pod-level network policy.

## Kubernetes

`terraform/stacks/kubernetes/{aws-eks,gcp-gke,azure-aks}`, installing
`charts/noxus-platform`.

**Choose it when** you need any of:

- **Worker pool isolation** — separating KB ingestion from chat so a large
  document upload does not spike agent latency, or giving a noisy tenant
  dedicated capacity via `workerSubscribeWorkspaces`.
- **Queue-depth autoscaling** — KEDA scaling workers on actual backlog rather
  than on CPU, which only rises after work has already been waiting.
- **Geo-replication** — `backend.regions` and `frontend.regions` spread
  deployments across zones behind one Service.
- **Strong sandbox isolation** — the `syd` jail plus NetworkPolicy egress
  control.
- **Scale** — tens to hundreds of worker replicas.

**Do not choose it when** the deployment is small. A cluster, its control plane,
NAT gateways, and a Multi-AZ database cost real money before a single workflow
runs, and someone has to own cluster upgrades.

### Which cloud

The three stacks are feature-equivalent. Differences worth knowing:

| | EKS | GKE | AKS |
|---|---|---|---|
| Node management | Auto Mode by default — AWS runs the nodes | Managed node pools, or Autopilot | Managed node pools |
| Ingress | ALB via AWS Load Balancer Controller | GKE Ingress with a Google-managed cert | ingress-nginx + cert-manager, installed by the stack |
| Pod identity | IRSA | Workload Identity | Workload Identity (federated user-assigned identity) |
| Sandbox `syd` jail | Works | Works on Standard; **Autopilot refuses `SYS_PTRACE`** | Works |
| Postgres extensions | Available by default | Available by default | Must be added to the `azure.extensions` allowlist |
| Redis TLS | Optional, off by default | Optional, off by default | **Enforced**, on port 6380 |

The Azure quirks are handled by the stack — the `azure.extensions` allowlist is
set by `modules/azure/postgres`, and the Redis port and TLS flag are wired from
module outputs — but they are the things that break if you assemble your own.

## Mixed and staged approaches

A common path: start on a VM for evaluation, move to Kubernetes for production.
There is no in-place migration; you export data from the VM's Postgres and
restore it into the managed instance. Plan for it rather than discovering it.

Running staging on serverless and production on Kubernetes is workable but means
two configuration surfaces to keep in step. Prefer the same shape in both, sized
down — `environment = "staging"` in the Kubernetes stacks already drops
Multi-AZ, deletion protection, and cache replication.
