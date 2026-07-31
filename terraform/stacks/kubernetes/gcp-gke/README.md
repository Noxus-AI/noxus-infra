# Noxus on GKE

Provisions a VPC with Private Service Access, a GKE cluster, Cloud SQL
PostgreSQL, Memorystore Redis, GCS buckets, a global static IP with a
Google-managed certificate, and installs `charts/noxus-platform`.

## Prerequisites

- A GCP project with these APIs enabled: `container`, `compute`, `sqladmin`,
  `redis`, `servicenetworking`, `storage`, and `dns` if you let it manage records.
- A Cloud DNS managed zone for your domain (optional but strongly recommended —
  see the certificate note below).
- An Auth0 tenant with an application for `https://<domain>`.
- `gcloud` authenticated; `tofu` ≥ 1.5; `helm` ≥ 3.

## Deploy

```sh
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars

tofu init \
  -backend-config="bucket=my-tfstate" \
  -backend-config="prefix=noxus/prod/gcp-gke"

tofu apply
```

## After the first apply

Cloud SQL databases are created by Terraform, but extensions are not:

```sh
gcloud sql connect noxus-prod-postgres --user=noxus   # or via a bastion
# then run the SQL from scripts/bootstrap-postgres.sh
```

```sh
eval "$(tofu output -raw kubeconfig_command)"
kubectl get pods -n noxus
```

## The certificate ordering trap

A Google-managed certificate will not issue until all three hostnames already
resolve to the load balancer IP. With `dns_managed_zone` set, the stack creates
the A records and this resolves on its own — allow 15–30 minutes.

Without it, `tofu apply` completes but the certificate sits in `PROVISIONING`
indefinitely and HTTPS never works. Create the records manually:

```sh
tofu output required_dns_records
```

## Notable choices

**Cloud SQL and Memorystore are reached over Private Service Access**, peered
into the VPC. Both modules depend on the service networking connection, so
Terraform orders them correctly — but that peering range
(`private_service_access_cidr`) must not overlap anything else.

**The pod secondary range cannot be resized.** `pods_cidr` defaults to a `/16`,
which caps the cluster at roughly 250 nodes given GKE's default `/24`-per-node
allocation. Growing past it means rebuilding the cluster. Size it now.

**Workload Identity binds `<namespace>/<release_name>` exactly.** Change either
and the binding breaks — the stack derives the member string from both variables
so they stay consistent.

**Autopilot is off by default, and enabling it has a real consequence:**
Autopilot refuses `SYS_PTRACE`, which the sandbox's `syd` jail requires. On
Autopilot you must set the sandbox jail to `minimal` through `extra_values`,
which is weaker isolation. Prefer Standard node pools if you run untrusted code.

**Regional clusters when `environment = "prod"`**, zonal otherwise. Zonal
clusters have a single-zone control plane and no SLA.

**Vertex AI access is granted by default** (`grant_vertex_ai`), so Vertex models
and embeddings work through pod identity with no API key.

## Destroying

```sh
tofu apply -var environment=staging   # drops deletion protection
tofu destroy
```
