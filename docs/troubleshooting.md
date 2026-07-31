# Troubleshooting

Symptoms, and what usually causes them.

## Deployment does not converge

### `tofu apply` hangs creating the Helm release

Terraform installs the chart over the Kubernetes API. If it cannot reach it, the
apply sits until timeout.

- **GKE**: `master_authorized_networks` empty or missing your egress IP. Empty
  allows *nothing*.
- **EKS**: `cluster_endpoint_public_access = false` with the apply running
  outside the VPC.
- **AKS**: `disable_local_accounts = true` without a working Entra RBAC binding.

Confirm with `kubectl get nodes` from the same machine before re-running.

### `Secret "..." is required in namespace "..." when pgbouncer.enabled=true`

The chart reads the upstream `POSTGRESQL_URL` from a live Secret using `lookup`,
which means the pgbouncer templates cannot render without a cluster.

- With Terraform: the `noxus-release` module creates that Secret; this error
  means the Secret was deleted or the namespace changed.
- With plain `helm template`: expected. Offline rendering cannot resolve it —
  test pgbouncer against a real cluster.

### Ingress created, no load balancer appears

- **EKS**: the AWS Load Balancer Controller is not installed, or the public
  subnets lack the `kubernetes.io/role/elb` tag. The controller logs "no
  matching subnets" for the tag case. `modules/aws/network` sets the tags when
  `cluster_name` is passed.
- **AKS**: no ingress controller. Nothing is built in — `install_ingress_nginx`
  must be true, or you must run your own.

### GCP certificate stuck in `PROVISIONING`

Google-managed certificates do not issue until the hostnames already resolve to
the load balancer IP. If `dns_managed_zone` was not set, create the records
yourself — `tofu output required_dns_records` lists them exactly.

## Platform will not start

### Backend crash-loops on first boot

Check the logs for the failing stage:

- **`CREATE EXTENSION vector` permission denied** — Azure Flexible Server without
  `vector` on the `azure.extensions` allowlist, or a PostgreSQL major below 15.
- **`database "spot" does not exist`** — `scripts/bootstrap-postgres.sh` has not
  been run. RDS creates only the initial database.
- **Connection refused to the database host** — security group or firewall. On
  AWS confirm the node security group is in the Postgres module's
  `allowed_security_group_ids`.
- **`could not translate host name "postgresql://..."`** — `POSTGRESQL_URL`
  includes a scheme. It must be `user:pass@host:port` with none.

### Login redirects to a page that does not resolve

`AUTH0_BASE_URL`, `FRONTEND_URL`, and the ingress hostname disagree, or the Auth0
application's allowed callback URLs do not include `https://<domain>/api/auth/callback`.

The Terraform stacks derive all three from one `domain` input so they cannot
drift; hand-written values files can.

### Everyone is logged out after a deploy

`AUTH0_SECRET` changed. If you did not set it explicitly, the `noxus-release`
module generates one — it is stable in state, but recreating the module
regenerates it. Pin it via `auth0.session_secret` if that matters.

## Runtime problems

### Agent responses stop mid-sentence

Proxy read timeout. Streaming holds the connection for minutes; defaults are 60
seconds.

- ALB: `alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=600`
- ingress-nginx: `proxy-read-timeout` / `proxy-send-timeout` on both the
  controller and the Ingress annotations
- GKE: raise the backend timeout with a `BackendConfig`
- Any CDN or WAF in front — Cloudflare's free tier caps at 100s regardless of
  origin settings

The stacks set the first two. A CDN added later is the usual culprit for this
reappearing.

### Jobs queue and nothing runs

Check what the pools subscribe to. The chart's default pool is `all_but_kb`, so
a single-pool deployment has **no consumer for knowledge-base ingestion** — those
jobs queue forever.

```sh
kubectl get deploy -n noxus -l app=worker \
  -o custom-columns=NAME:.metadata.name,SUBSCRIBE:'.spec.template.spec.containers[0].env[?(@.name=="WORKER_SUBSCRIBE")].value'
```

Fix by adding a `kb` pool or setting the single pool to `all`.

Other causes: workers cannot reach Postgres (the queue lives there), or
`WORKER_SUBSCRIBE_WORKSPACES` is set and excludes the workspace in question.

### `FATAL: sorry, too many clients already`

Connection exhaustion. Every backend and worker pod opens its own pools:

```
(backend_replicas + worker_replicas) × (POSTGRES_POOL_SIZE
                                      + VECTOR_POSTGRES_POOL_SIZE
                                      + PROCRASTINATE_POOL_SIZE)
```

Enable PgBouncer. Raising `max_connections` alone trades one limit for memory
pressure on the database.

### Workers restart with no error in the logs

OOM kill. Nothing is logged because the process is killed, not terminated.

```sh
kubectl get pod -n noxus <pod> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
```

`OOMKilled` means raise the pool's memory. KB ingestion pools are the usual
victims — a large document plus embedding batches is not a small allocation.

### Plugins do not appear

`sandbox.enabled=false`. Plugins execute inside the sandbox now, and
`SANDBOX_MANAGER_URL` is only injected when it is deployed. Nothing errors; the
plugins are simply absent. See [upgrades.md](upgrades.md#known-breaking-change-plugins-moved-into-the-sandbox).

### Sandbox pods will not schedule

`syd` jail needs `SYS_PTRACE`. GKE Autopilot refuses it outright; a restrictive
PodSecurity admission policy will too. Set `sandbox.jail: minimal` — weaker
isolation, so only for trusted code — or move to Standard node pools.

### Run Code works but cannot reach the network

Expected. The sandbox NetworkPolicy restricts egress by design. If your workflows
need outbound calls from Run Code, widen the policy deliberately rather than
disabling the sandbox.

### Files upload but cannot be read back

Object storage credentials. With pod identity, check the ServiceAccount carries
the annotation:

```sh
kubectl get sa -n noxus noxus -o yaml
```

- **AWS**: the IRSA trust policy lists your namespace in `platform_namespaces`.
- **GCP**: `workload_identity_member` must name `<namespace>/<release_name>`
  exactly.
- **Azure**: the federated credential subject must be
  `system:serviceaccount:<namespace>:<release_name>` exactly — a renamed release
  breaks it.

### Redis connection failures on Azure

Azure Cache enforces TLS on 6380. Set `REDIS_PORT=6380` and `REDIS_SSL=true`.
The `azure-aks` stack wires these from module outputs; a hand-written values
file must set them.

## Performance

### Everything is slow, no obvious bottleneck

Check event-loop lag on the `event-loop-health` dashboard. Sustained lag means
something is blocking the async loop and degrades every request in that process
at once. The dashboard attributes blocked time to the responsible code frame.

### Agent time-to-first-token is high

`agents-and-latency` splits TTFT into provider time and platform overhead. High
provider time is the model or the region; high platform overhead points at
registry builds, auth lookups, or database contention.

### Knowledge-base search is slow

The `vectors` database is doing index scans over a large table. Check database
CPU during queries, and whether the `kb` pool is ingesting at the same time —
ingestion and retrieval contend for the same instance.

## Getting more detail

```sh
kubectl logs -n noxus -l app=backend --tail=200
kubectl logs -n noxus -l app=worker --tail=200
kubectl describe pod -n noxus <pod>          # events explain scheduling failures
kubectl get events -n noxus --sort-by=.lastTimestamp
```

`LOG_LEVEL=DEBUG` gives far more, **including prompt and tool-call content**.
Turn it on deliberately, on one pod if you can, and turn it off afterwards — see
[security.md](security.md#logging-sensitivity).
