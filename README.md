# Noxus Infrastructure

Infrastructure as Code for deploying the [Noxus](https://noxus.ai) platform — on
Kubernetes, on serverless containers, or as a single-VM appliance, across AWS,
GCP, and Azure.

```
charts/          Helm chart for the platform
terraform/
  modules/       Reusable building blocks, per cloud
  stacks/        Composed, deployable environments
marketplace/     Cloud marketplace listings (Azure VM offer)
observability/   Grafana dashboards
docs/            Architecture, configuration, sizing, operations
scripts/         Database bootstrap, IAM policy refresh
```

## Which deployment do I want?

| | **Kubernetes** | **Serverless containers** | **Single VM** |
|---|---|---|---|
| Where | `terraform/stacks/kubernetes/` | `terraform/stacks/serverless/` | `terraform/stacks/vm/` |
| Clouds | EKS, GKE, AKS | Cloud Run, Container Apps | GCE, EC2, Azure VM |
| Scales to | Hundreds of workers, multi-AZ | Moderate, per-service autoscaling | One box |
| Worker pools | Yes — dedicated pools per workload | Fixed services | All-in-one |
| Ops burden | Highest | Low | Lowest |
| Good for | Production at scale, strict isolation, geo-replication | Teams without Kubernetes experience; bursty low-baseline load | Trials, POCs, air-gapped single-tenant |
| Not good for | Small deployments — the fixed cost is real | Long-running knowledge-base ingestion, which outlives request timeouts | Anything needing availability guarantees |

See [docs/choosing-a-deployment.md](docs/choosing-a-deployment.md) for the longer
version, including the failure modes each mode has.

## Quick start

Every stack needs the same four things before you begin:

1. **A domain** you control DNS for. The Kubernetes stacks serve three
   hostnames: `<domain>`, `api.<domain>`, and `relay.<domain>`. The Cloud Run
   stack serves everything from `<domain>`, and can start on its `run.app`
   address before you have one.
2. **An Auth0 application** for that domain, provided by Noxus on its tenant
   or created on your own.
3. **Registry credentials** for the platform images, provided by Noxus.
4. **A platform version** to deploy, e.g. `1.9.2`.

Then, for a Kubernetes deployment on AWS:

```sh
cd terraform/stacks/kubernetes/aws-eks
cp terraform.tfvars.example terraform.tfvars   # fill it in
tofu init \
  -backend-config="bucket=my-tfstate" \
  -backend-config="key=noxus/prod.tfstate" \
  -backend-config="region=eu-west-1"
tofu apply
```

After the first apply, create the platform's remaining databases — Terraform can
create the instance but not the extensions inside it:

```sh
PGPASSWORD=$(tofu output -raw postgres_password) \
  ../../../../scripts/bootstrap-postgres.sh \
    --host "$(tofu output -raw postgres_address)" --user noxus
```

RDS is private, so run that from a bastion or a pod inside the VPC. The
equivalent commands for GCP and Azure are in each stack's README.

Every other stack has its own walkthrough in its directory's README. For Google
Cloud Run, follow
[terraform/stacks/serverless/gcp-cloudrun](terraform/stacks/serverless/gcp-cloudrun/README.md).
There, the backend creates its databases and extensions itself, so nothing
needs running after `apply`.

## Documentation

| Document | Covers |
|----------|--------|
| [choosing-a-deployment.md](docs/choosing-a-deployment.md) | Picking between Kubernetes, serverless, and VM |
| [architecture.md](docs/architecture.md) | Components, data stores, traffic and job flow |
| [configuration.md](docs/configuration.md) | Every environment variable the platform reads |
| [sizing.md](docs/sizing.md) | Instance and replica sizing at three scales |
| [networking-and-dns.md](docs/networking-and-dns.md) | Hostnames, TLS, egress, private clusters |
| [observability.md](docs/observability.md) | Metrics, the Grafana dashboards, log levels |
| [security.md](docs/security.md) | Trust boundaries, secrets, sandbox isolation |
| [upgrades.md](docs/upgrades.md) | Version bumps, migrations, rollback |
| [troubleshooting.md](docs/troubleshooting.md) | Symptoms and their usual causes |

## The Helm chart

`charts/noxus-platform` is the single application definition all three Kubernetes
stacks install. It deploys the platform only — Postgres, Redis, and object
storage are expected to already exist and are passed in as connection strings.

```sh
helm dependency update charts/noxus-platform
helm upgrade --install noxus charts/noxus-platform \
  --namespace noxus --create-namespace \
  --values my-values.yaml
```

See [charts/noxus-platform/README.md](charts/noxus-platform/README.md) for the
values reference and cloud-specific examples.

## Layout rationale

**Modules are cloud-specific; stacks are opinionated compositions.** A module
(`terraform/modules/aws/postgres`) knows one resource well and takes no view on
how you assemble it. A stack (`terraform/stacks/kubernetes/aws-eks`) wires the
modules together into a working deployment, and is meant to be forked or copied
when your environment differs.

**The application layer is shared.** `terraform/modules/platform/noxus-release`
translates "here are my database, cache, bucket, and identity" into a Helm
release. All three Kubernetes stacks call it, so behaviour that must be identical
across clouds — how URLs are derived, how PgBouncer is wired, how the KEDA secret
is shaped — lives in exactly one place.

## Conventions

- **State backends are unconfigured.** Each stack declares an empty `backend`
  block; pass the bucket at `init` time. This repo makes no assumption about
  where your state lives.
- **`*.tfvars` is gitignored**, `*.tfvars.example` is not. Real values never land
  in the repo.
- **`prod` is a magic value.** Setting `environment = "prod"` turns on Multi-AZ
  databases, replicated caches, deletion protection, and regional clusters.
  Anything else gets the cheap single-AZ shape.
- **Modules pin provider ranges, stacks pin providers.** Modules use permissive
  ranges so they compose; stacks are where you lock a version for reproducibility.

## Local validation

```sh
tofu fmt -recursive terraform/
helm lint charts/noxus-platform
helm template noxus charts/noxus-platform -f charts/noxus-platform/ci/full-values.yaml
```

CI runs the same checks plus `tofu validate` on every module and stack — see
[.github/workflows/validate.yml](.github/workflows/validate.yml).
