# Security

## Trust boundaries

| Boundary | Enforced by |
|----------|-------------|
| Internet → platform | TLS at the ingress; Auth0 or OIDC for user sessions; API keys for programmatic access |
| Tenant → tenant | Application-level authorisation. **Not** infrastructure isolation — all tenants share one database and one cluster |
| Workspace → workspace | Application-level, and the trust boundary for Noxus Tables SQL |
| User code → platform | The sandbox. This is the only place untrusted code runs |
| Platform → cloud APIs | Pod identity (IRSA / Workload Identity), scoped to specific buckets and services |

The tenant boundary being application-level is the most important thing to
understand. If you need infrastructure-level separation between tenants, run
separate deployments — the worker pool machinery isolates *load*, not *data*.

## Secrets

### What holds what

| Kind | Where it lives |
|------|----------------|
| Database and Redis credentials | Kubernetes Secret, created by the chart from `secrets:` values |
| Auth0 credentials | Same Secret |
| Object storage credentials | Same Secret — or absent entirely when pod identity is used |
| Model provider and integration API keys | The platform database, when `SECRETS_SOURCE=db` |

`SECRETS_SOURCE=db` is the recommended setting. Model and integration keys are
then entered through the admin UI after deployment and never appear in a values
file or in Terraform state.

### Terraform state contains secrets

Generated database passwords, Redis auth tokens, and everything passed in the
`auth0` variable are stored in plaintext in state. Consequences:

- Use a remote backend with encryption at rest and access control. The stacks
  leave the backend unconfigured precisely so you supply your own.
- Anyone who can read state can read the database password.
- `tofu output -json` prints secrets; do not pipe it into CI logs.

### Never commit

`*.tfvars` is gitignored; only `*.tfvars.example` is tracked. Keep it that way.

No credential in this repository has a default value. Auth0 client IDs and
secrets, registry tokens, and database passwords are all required inputs, so a
missing one fails at plan time rather than silently deploying a shared
placeholder. If you fork this repo, keep that property — a credential with a
default is a credential that ends up in someone's git history.

CI scans the working tree for common credential shapes and for tracked `.tfvars`
files; see [`.github/workflows/validate.yml`](../.github/workflows/validate.yml).

## Pod identity

Prefer it over static keys everywhere it is available.

| Cloud | Mechanism | Wired by |
|-------|-----------|----------|
| AWS | IRSA — an IAM role assumed via the cluster's OIDC provider | `modules/aws/eks-addons` → `helm_service_account_annotation` |
| GCP | Workload Identity — a Google SA bound to the Kubernetes SA | `modules/gcp/storage` → `helm_service_account_annotation` |
| Azure | Workload Identity — a federated user-assigned identity. **Not yet usable for the platform pods:** the chart does not label pods `azure.workload.identity/use: "true"`, which the webhook requires, so `azure-aks` uses the storage account key instead | `modules/azure/aks` → `helm_service_account_annotation` |

Each returns an annotation map the `noxus-release` module puts on the chart's
ServiceAccount. With it, `S3_ACCESS_KEY_ID` and `S3_SECRET_ACCESS_KEY` stay
empty and no long-lived credential exists.

Two scoping notes:

- The IRSA trust policy matches `system:serviceaccount:<ns>:*` — **every**
  ServiceAccount in the listed namespaces can assume the role. Keep
  `platform_namespaces` to namespaces you control entirely.
- The Azure federated credential subject is an exact string naming one namespace
  and one ServiceAccount. Change the release name or namespace and the token
  exchange fails with a generic authorization error.

## Sandbox isolation

The sandbox runs user-authored code: Run Code nodes and all plugin execution.

| Mode | Isolation | Requires |
|------|-----------|----------|
| `syd` | Syscall filtering plus network jail | `SYS_PTRACE` |
| `minimal` | chroot, egress limited by NetworkPolicy | `SYS_ADMIN` |

`syd` is the default and the one to use. `minimal` exists for clusters that
refuse `SYS_PTRACE` — notably GKE Autopilot — and is meaningfully weaker: it
constrains the filesystem and the network but not syscalls. Only run trusted
code under it.

The bundled NetworkPolicy restricts sandbox egress, which requires a cluster
with a policy engine. On AKS the stack sets `network_policy = "cilium"`; on EKS
and GKE the default CNIs enforce policy already.

**Turning the sandbox off does not disable plugins safely — it disables them
entirely.** `SANDBOX_MANAGER_URL` is only injected when the sandbox is deployed,
and without it plugin nodes and triggers fail to load rather than falling back
to a less isolated path.

`LOCAL_SANDBOX_BACKEND` controls the worker-local fallback. `subprocess` runs
user code in the worker's own process tree with much weaker isolation; `none` is
the safer choice when a remote sandbox is present.

## Network posture

The stacks default to:

- Private nodes; no public IPs on compute.
- Databases and caches with no public endpoint, reachable only from the cluster's
  security group or an injected subnet.
- Object storage with public access blocked. The "public" assets bucket is
  private by default and served through presigned URLs; `public_read` is opt-in.
- Egress through a NAT gateway with a stable IP.

The Kubernetes API endpoint is public by default, restricted by CIDR. That is a
deliberate compromise — Terraform installs the Helm release over that API, so a
private endpoint requires running applies from inside the network. Narrow
`cluster_endpoint_public_access_cidrs` (AWS) or `master_authorized_networks`
(GCP) to your operator and CI ranges.

## Encryption

- **At rest** — on by default for RDS, Cloud SQL, Azure Flexible Server, all
  object storage, and ElastiCache. Customer-managed keys via `kms_key_id`
  (AWS), `kms_key_name` (GCP).
- **In transit** — TLS at the ingress always. Database connections use the
  provider default (Cloud SQL is `ENCRYPTED_ONLY`; RDS and Azure accept TLS).
  Redis in-transit encryption is off by default on AWS and GCP because it adds
  latency to a cache; Azure enforces it.

## Logging sensitivity

`LOG_LEVEL=DEBUG` writes prompt and tool-call content to logs — user input and
retrieved knowledge-base content. A DEBUG log stream carries roughly the same
sensitivity as the database. Do not enable it in production or forward it to a
general-purpose aggregator.

## Air-gapped deployments

Set `USE_NCS=false` and `BILLING_ENABLED=false`, or the platform makes outbound
calls that hang rather than fail fast. `ON_PREM=true` disables features that
assume Noxus-hosted services. You will also need a local container registry
mirror and, depending on your models, a self-hosted inference endpoint.

## Reporting

Security issues in the platform or in this repository: security@noxus.ai.
