# Terraform

```
modules/
  aws/      network · postgres · redis · storage · eks · eks-addons · dns
  gcp/      network · postgres · redis · storage · gke
  azure/    network · postgres · redis · storage · aks
  platform/ noxus-release — installs the Helm chart from charts/
stacks/
  kubernetes/  aws-eks · gcp-gke · azure-aks
  serverless/  gcp-cloudrun · azure-containerapps
  vm/          aws · gcp
```

Written for OpenTofu ≥ 1.5; everything here works with Terraform ≥ 1.5 too.

## Modules vs stacks

A **module** provisions one thing well and takes no view on how you assemble it.
It declares permissive provider ranges so it composes with whatever else you are
running.

A **stack** is a deployable environment: it wires modules together into a working
deployment, pins provider versions, and is meant to be forked when your
requirements differ. Copying a stack and editing it is a supported workflow.

`modules/platform/noxus-release` is the seam between the two. It turns "here are
my database, cache, bucket, and pod identity" into a Helm release, so the parts
that must behave identically across clouds — URL derivation, PgBouncer wiring,
the KEDA secret shape — exist once.

## Conventions

**Naming.** Stacks build `${project_name}-${environment}` and pass it down as
`name`. Modules prefix their own resources from it.

**`environment = "prod"` is load-bearing.** It turns on Multi-AZ or regional
databases, cache replication, deletion protection, per-AZ NAT gateways, and the
paid cluster SLA tier. Anything else gets the cheap single-AZ shape. This keeps
the difference between environments in one variable rather than scattered across
a dozen.

**Backends are unconfigured.** Each stack declares an empty `backend` block;
supply the bucket at `tofu init` time or with a `backend.hcl`. This repo makes
no assumption about where your state lives.

**Secrets live in variables, not files.** `*.tfvars` is gitignored;
`*.tfvars.example` is not. Note that generated passwords end up in state — see
[docs/security.md](../docs/security.md#terraform-state-contains-secrets).

**Outputs name their consumer.** Where an output feeds a specific chart value the
description says so, e.g. `platform_url` is "the value for the chart's
`POSTGRESQL_URL`". The two Postgres URL shapes — scheme-less for the app, full
`postgresql://` for KEDA — are a known source of confusion, so both are emitted
explicitly rather than left to the caller to construct.

## Using a module on its own

Modules do not depend on the stacks. To add the platform to infrastructure you
already run:

```hcl
module "noxus" {
  source = "github.com/Noxus-AI/noxus-infra//terraform/modules/platform/noxus-release"

  app_version = "0.8.1"
  domain      = "noxus.example.com"
  admin_email = "admin@example.com"

  database = {
    host     = "my-existing-db.internal"
    port     = 5432
    name     = "spot"
    username = "noxus"
    password = var.db_password
  }
  redis   = { host = "my-existing-redis.internal" }
  storage = {
    client         = "s3"
    private_bucket = "my-artifacts"
    public_bucket  = "my-artifacts-public"
    region         = "eu-west-1"
  }
  auth0 = var.auth0

  ingress = {
    class_name  = "nginx"
    annotations = { "cert-manager.io/cluster-issuer" = "letsencrypt-prod" }
  }
}
```

`chart_path` defaults to `charts/noxus-platform` relative to the module, which
works for a local checkout. Set it explicitly when consuming the module by URL.

## Validating locally

```sh
tofu fmt -recursive terraform/

for dir in terraform/modules/*/*/ terraform/stacks/*/*/; do
  (cd "$dir" && tofu init -backend=false >/dev/null && tofu validate)
done
```

CI runs exactly this.
