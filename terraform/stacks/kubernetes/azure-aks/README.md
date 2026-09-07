# Noxus on AKS

Provisions a VNet, an AKS cluster, PostgreSQL Flexible Server, Azure Cache for
Redis, a Storage account, a Container Registry holding mirrored platform images,
ingress-nginx with a static IP, cert-manager, and installs
`charts/noxus-platform`.

## Prerequisites

- An Azure subscription and a resource group (the stack can create it).
- An Azure DNS zone for your domain (optional; you can create records yourself).
- An Auth0 tenant with an application for `https://<domain>`.
- `az` authenticated; `tofu` ≥ 1.5; `helm` ≥ 3. The image mirror runs
  `az acr import` through a local provisioner, so the same `az` session needs
  rights on the new registry.
- Docker Hub credentials with pull access to the platform images
  (`docker_hub_username` / `docker_hub_token`), unless the repository is public.

## Deploy

```sh
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars

tofu init \
  -backend-config="resource_group_name=tfstate-rg" \
  -backend-config="storage_account_name=mytfstate" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=noxus/prod/azure-aks.tfstate"

tofu apply
```

## After the first apply

**Apply the ClusterIssuer.** cert-manager is installed by the stack but the
issuer is not — a Terraform-managed CRD instance would need the CRD to exist at
plan time, before cert-manager has been installed by the same apply.

```sh
eval "$(tofu output -raw kubeconfig_command)"
sed 's/ADMIN_EMAIL/you@example.com/' cluster-issuer.yaml | kubectl apply -f -
```

Until it exists, the Ingress requests a certificate from an issuer that is not
there and TLS stays broken.

**Create the databases and extensions.** Terraform creates the databases; the
extensions need a connection:

```sh
PGPASSWORD=$(tofu output -raw postgres_password) \
  ../../../../scripts/bootstrap-postgres.sh \
    --host "$(tofu output -raw postgres_fqdn)" --user noxus
```

The server is VNet-injected, so run this from inside the VNet — a jumpbox or a
`kubectl run` pod.

## Azure-specific behaviour

**PostgreSQL extensions need an allowlist.** Flexible Server refuses
`CREATE EXTENSION` for anything not in the `azure.extensions` server parameter.
`modules/azure/postgres` sets `VECTOR`, `UUID-OSSP`, `PG_TRGM`,
`PG_STAT_STATEMENTS`, and `POSTGRES_FDW`. Removing any of the first three makes
the backend fail on first boot with a permission error rather than a clear one.

**Redis enforces TLS on 6380.** The stack wires `REDIS_PORT` and `REDIS_SSL`
from module outputs. A hand-written values file must set both, or connections
fail.

**Blob Storage has no S3-compatible API**, so this uses the platform's native
Azure client: `BUCKET_CLIENT=azure` with `AZURE_STORAGE_ACCOUNT_KEY`. That client
treats `SPOTFLOW_STORAGE_BUCKET` as the storage *account* name — it builds
`https://<account>.blob.core.windows.net` itself — and writes everything into a
fixed `noxus` container, so the stack names the private container `noxus` to keep
it Terraform-managed. The public container is created but unused on this path;
public assets are served through presigned URLs from the private one.

**Images are mirrored into ACR.** Pulling from Docker Hub does not survive a
scale-out: the anonymous rate limit is per source IP and every node shares the
NAT gateway's. The stack creates a registry, imports the five platform images
into it under the same repository path, and grants the kubelet identity
`AcrPull` — which is what lets pods pull with no `imagePullSecret`. A platform
version bump re-runs the import. Point `image_registry` at a registry you
already run to skip all of it; add `image_pull_secrets` if that one needs
credentials.

**The federated identity credential is created but not yet in use.** Its
subject is an exact string — `system:serviceaccount:<namespace>:<release_name>`
— and two things currently stop pods exchanging a token with it: the chart's
ServiceAccount is named `<release>-noxus-platform`, not `<release>`, and the
chart does not label pods `azure.workload.identity/use: "true"`, which the
Azure webhook requires before it injects the token. Until both are fixed,
storage authenticates with the account key and this credential is inert.

**Postgres needs a delegated subnet all to itself.** Nothing else can go in it.
The network module also creates and links the private DNS zone; without that
link the server's FQDN does not resolve from inside the VNet.

**`network_policy = "cilium"`** so the sandbox NetworkPolicy is actually
enforced. Without a policy engine the policy object exists and does nothing.

## Notable choices

**ingress-nginx rather than the managed addon**, with `proxy-read-timeout` and
`proxy-send-timeout` raised to 3600 — agent streaming holds connections for
minutes and the 60-second default truncates responses. Set
`install_ingress_nginx = false` if you already run a controller, and replicate
those timeouts on it.

**A static public IP**, with `Network Contributor` granted to the kubelet
identity so the load balancer can attach to it. Egress goes out a separate NAT
gateway with its own stable IP (`nat_public_ip`).

**`sku_tier = "Standard"` when `environment = "prod"`**, which buys the control
plane SLA. `Free` otherwise.

## Destroying

```sh
tofu destroy
```

`prevent_deletion_if_contains_resources` is on, so a resource group holding
anything Terraform does not track will refuse to delete. The Postgres databases
carry `prevent_destroy` — remove that lifecycle block deliberately if you really
mean it.
