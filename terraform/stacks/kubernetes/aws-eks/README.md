# Noxus on EKS

Provisions a VPC, an EKS cluster, RDS PostgreSQL, ElastiCache Redis, S3 buckets,
an ACM certificate, the AWS Load Balancer Controller and external-dns, and
installs `charts/noxus-platform`.

## Prerequisites

- A Route53 hosted zone for your domain.
- An Auth0 tenant with an application for `https://<domain>`.
- AWS credentials with permission to create VPCs, EKS clusters, RDS, IAM roles.
- `aws` CLI on PATH — the Kubernetes provider shells out to it for auth tokens.
- `tofu` (or `terraform`) ≥ 1.5, `helm` ≥ 3.

## Deploy

```sh
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars

tofu init \
  -backend-config="bucket=my-tfstate" \
  -backend-config="key=noxus/prod/aws-eks.tfstate" \
  -backend-config="region=eu-west-1" \
  -backend-config="use_lockfile=true"

tofu apply
```

First apply takes roughly 25–35 minutes, most of it EKS and RDS.

## After the first apply

RDS is created with only the `spot` database and no extensions. Create the rest:

```sh
kubectl run pg-bootstrap --rm -it --restart=Never \
  --image=postgres:16-alpine \
  --env="PGPASSWORD=$(tofu output -raw postgres_password)" \
  -- sh
# then, inside the pod, run the SQL from scripts/bootstrap-postgres.sh
```

Or from a bastion in the VPC:

```sh
PGPASSWORD=$(tofu output -raw postgres_password) \
  ../../../../scripts/bootstrap-postgres.sh \
    --host "$(tofu output -raw postgres_address)" --user noxus
```

Then point kubectl at the cluster and check the rollout:

```sh
eval "$(tofu output -raw kubeconfig_command)"
kubectl get pods -n noxus
```

## Notable choices

**EKS Auto Mode is on by default.** AWS manages the nodes. Set
`eks_auto_mode = false` and populate `eks_managed_node_groups` if you need
specific instance types (GPU, memory-optimised) or a node-level agent that Auto
Mode's AMI will not run.

**Database access is gated on the node security group**, not the VPC CIDR — so
anything else you place in the VPC does not get database access for free.

**`grant_creator_admin` defaults to true** so the first apply leaves you with a
working cluster. Set it false and rely on `cluster_admin_principal_arns` once
you have confirmed your SSO role works, so cluster access does not depend on
which identity happened to run apply.

**Pods authenticate to S3 through IRSA.** No static keys are set. The trust
policy matches every ServiceAccount in `namespace`, so keep that namespace
dedicated to the platform.

**`environment = "prod"`** turns on Multi-AZ RDS, a Redis replica, one NAT
gateway per AZ, and deletion protection. Any other value gets the cheap shape.

## Sizing and worker pools

`extra_values` takes raw chart YAML, layered over what this stack computes. That
is where worker pools, replica counts, and resources go — see the example tfvars
and [docs/sizing.md](../../../../docs/sizing.md).

## Destroying

Deletion protection blocks `tofu destroy` in prod. To tear down deliberately:

```sh
tofu apply -var environment=staging   # drops deletion protection
tofu destroy
```

S3 buckets with `force_destroy = false` must be emptied first.
