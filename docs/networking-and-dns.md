# Networking and DNS

## Three hostnames

The platform serves three origins derived from one apex domain:

| Hostname | Serves | Required |
|----------|--------|----------|
| `<domain>` | Frontend, plus the MCP server at `/mcp` | Always |
| `api.<domain>` | Backend API | Always |
| `relay.<domain>` | Webhook receivers | Only when relays are enabled |

The Helm chart derives all three from `ingress.domain`. They must agree with
`FRONTEND_URL`, `BACKEND_URL`, and `RELAY_URL`, because the backend builds
absolute URLs from those variables — OAuth callbacks, webhook registrations,
shared file links. A mismatch does not fail loudly; it produces redirects to a
host that does not resolve, usually discovered when someone tries to connect an
integration.

The `terraform/modules/platform/noxus-release` module derives the env vars from
the same `domain` input as the ingress, so the two cannot drift.

## TLS

Auth0 refuses non-HTTPS callback URLs, so TLS is not optional.

| Stack | Mechanism |
|-------|-----------|
| `aws-eks` | ACM certificate for `<domain>` + `*.<domain>`, DNS-validated via Route53, attached to the ALB |
| `gcp-gke` | Google-managed certificate covering all three hostnames, referenced as a pre-shared cert |
| `azure-aks` | cert-manager with a Let's Encrypt HTTP-01 issuer, through ingress-nginx |
| `gcp-cloudrun` | Google-managed certificate for the single `<domain>` on an external Application Load Balancer; the frontend proxies the API and relay paths |
| `azure-containerapps` | Managed certificates on the Container Apps custom domains |
| VM | Self-signed by default; `marketplace/azure-vm/cert.sh` swaps in a real one |

### The GCP ordering trap

A Google-managed certificate will not issue until the hostnames already resolve
to the load balancer IP. The stack creates the static IP first and, if
`dns_managed_zone` is set, the A records too — so it converges on its own. If
you manage DNS elsewhere, `tofu apply` completes but the certificate sits in
`PROVISIONING` until you create the records manually. The stack's
`required_dns_records` output tells you exactly what to add.

## Long-lived connections

Agent streaming holds SSE and WebSocket connections open for minutes. Default
proxy read timeouts are 60 seconds, which truncates responses partway through —
the symptom is agents that "stop mid-sentence" on long answers.

Each stack raises it:

- **ALB** — `idle_timeout.timeout_seconds=600` via
  `alb.ingress.kubernetes.io/load-balancer-attributes`.
- **ingress-nginx** — `proxy-read-timeout` and `proxy-send-timeout` at 3600, set
  both on the controller and as per-Ingress annotations.
- **GKE Ingress** — the default backend timeout is 30 seconds; raise it with a
  `BackendConfig` if you see truncation.

If you put a CDN or WAF in front, check its timeout too. Cloudflare's free tier
caps at 100 seconds regardless of origin settings.

## Egress

Third-party services you integrate with will often need to allowlist the
platform, so egress needs a stable, known set of IPs.

| Stack | Source |
|-------|--------|
| `aws-eks` | NAT gateway IPs — `nat_public_ips` output |
| `gcp-gke` | Cloud NAT. Auto-allocated by default; set `nat_ip_addresses` in the network module to pin them |
| `azure-aks` | NAT gateway on the node subnet — `nat_public_ip` output. Without it, egress comes from the load balancer's outbound pool, whose addresses rotate |

The AWS network module also creates an S3 gateway endpoint by default, keeping
artifact traffic off the NAT gateway. Object storage is the highest-volume
egress path in the platform, so this is usually the largest single NAT saving
available.

## Private clusters

All three cluster modules run private nodes. The control plane endpoint is a
separate decision:

**Terraform installs the Helm release over the Kubernetes API.** If the endpoint
is private, `tofu apply` must run from inside the network — a bastion, a
self-hosted runner in the VPC, or over a VPN. This is the most common reason a
first apply hangs.

| Stack | Variable |
|-------|----------|
| `aws-eks` | `cluster_endpoint_public_access`, `cluster_endpoint_public_access_cidrs` |
| `gcp-gke` | `master_authorized_networks` — **empty allows nothing**, locking out kubectl entirely |
| `azure-aks` | Public by default; Entra RBAC gates access |

Leaving the endpoint public but restricting it by CIDR is the usual compromise.

## Network address planning

Ranges must not overlap, and some cannot be changed later.

### AWS

One `/16` VPC, split into `/20`s: three private subnets, three public. Nodes,
RDS, and ElastiCache all live in the private subnets; only load balancers are
public.

### GCP

Four ranges, all in `modules/gcp/network`:

| Range | Default | Resizable later |
|-------|---------|-----------------|
| Node subnet | `10.10.0.0/20` | Yes |
| Pods (secondary) | `10.20.0.0/16` | **No** |
| Services (secondary) | `10.30.0.0/20` | **No** |
| Private Service Access | `10.40.0.0/16` | No |

The pod range is the one that bites. GKE allocates a `/24` per node by default,
so a `/16` caps you at roughly 250 nodes — and you cannot grow it without
rebuilding the cluster.

Cloud SQL and Memorystore are allocated out of the Private Service Access block,
which is why it must not overlap anything else.

### Azure

| Subnet | Default | Notes |
|--------|---------|-------|
| Nodes | `10.0.0.0/20` | With Azure CNI Overlay (the default here) pods do not consume VNet addresses |
| Postgres | `10.0.16.0/24` | **Delegated** — nothing else may be placed in it |
| Private endpoints | `10.0.17.0/24` | Premium Redis, storage endpoints |
| Service CIDR | `172.16.0.0/16` | Kubernetes services; must not overlap the VNet |

Postgres Flexible Server in VNet-injected mode also needs a private DNS zone
linked to the VNet, or its FQDN resolves to nothing from inside. The network
module creates and links it.

## Ingress controller prerequisites

The chart emits an Ingress; something has to act on it.

- **EKS** — the AWS Load Balancer Controller. `modules/aws/eks-addons` installs
  it and its IRSA role. Without it the Ingress object exists and nothing
  happens.
- **GKE** — the GCE ingress controller is built in.
- **AKS** — nothing is built in. The stack installs ingress-nginx by default;
  set `install_ingress_nginx = false` if you already run one.

The AWS subnet tags (`kubernetes.io/role/elb`) matter here: without them the
controller reports "no matching subnets" and provisions nothing. The network
module sets them when `cluster_name` is passed.
