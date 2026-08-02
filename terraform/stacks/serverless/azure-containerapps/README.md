# Azure Container Apps Deployment

Terraform configuration that deploys the Noxus stack on Azure Container Apps,
mirroring the GCP Cloud Run deployment in [`../gcp-cloudrun`](../gcp-cloudrun).

## Layout

| Path | What it is |
|---|---|
| `main.tf` | The root you run. Declares the provider and passes variables into `mod/`. |
| `mod/` | The module holding every resource. Edit here. |
| `flat/main.tf` | Generated single-file copy of `mod/`, for handing someone one file. Do not edit — run `python generate_tf.py`. |
| `terraform.tfvars.example` | Template for your own `deploy.tfvars`. |

`flat/` is a separate directory on purpose: Terraform loads every `*.tf` in a
directory, so a flattened copy next to `main.tf` would redeclare every variable
and resource.

## Resources Created

- **Azure Container Apps** (4 services): backend, frontend, worker, relay
- **Container App Environment** with VNet integration, a Consumption profile and
  a dedicated D4 profile for the worker
- **Azure Container Registry** with the `noxusai/noxus-*` images imported from
  Docker Hub (Container Apps would otherwise hit Docker Hub's pull rate limit)
- **Azure Database for PostgreSQL Flexible Server** (optional, `deploy_postgres`)
- **Azure Cache for Redis** (Premium, VNet-injected, TLS only)
- **Azure Storage Account** plus the `noxus` blob container
- **Azure Key Vault** holding every secret (when `use_managed_identity` is true)
- **User-Assigned Managed Identity** with ACR Pull, Key Vault and Storage roles
- **VNet** with dedicated subnets for Container Apps, PostgreSQL and Redis

## Not deployed

Two components the platform can use are absent from this stack. Neither breaks a
deployment, but both silently remove functionality:

**No scheduler.** The Cloud Run stack runs a fifth service, `beat` — the worker
image with `beat_start.sh` as its command — which drives everything time-based:
polling triggers, scheduled workflow runs, periodic maintenance. Nothing here
runs it, so that work never fires. Event-driven and user-initiated runs are
unaffected.

To add it, copy the `worker` container app, set its command to
`["bash", "./beat_start.sh"]`, and pin it to exactly one replica —
`min_replicas = 1` and `max_replicas = 1`. Two schedulers double-enqueue every
scheduled run, so the pin is not optional.

**No Agent Sandbox.** Plugins execute inside the sandbox, and the plugin system
is enabled by the presence of `SANDBOX_MANAGER_URL`. Without it, plugin nodes and
triggers do not load and nothing raises an error. Run Code also falls back to
worker-local execution. See [docs/architecture.md](../../../../docs/architecture.md).

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.5.7
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli),
  authenticated. The ACR image import runs through `az acr import`, so the CLI
  must be on `PATH` during `apply`.
- A Docker Hub token with access to the Noxus images
- Permission to create role assignments, or `use_managed_identity = false`

## Usage

```bash
cp terraform.tfvars.example deploy.tfvars   # then fill it in

az login
az account set --subscription <your-subscription-id>

terraform init
terraform plan  -var-file=deploy.tfvars
terraform apply -var-file=deploy.tfvars
terraform output
```

Every `*.tfvars` except `*.tfvars.example` is gitignored, as is state — both hold
credentials.

## Deployment modes

**Managed identity (default).** Secrets live in Key Vault and the container apps
resolve them at runtime through a user-assigned identity, which also pulls from
ACR. Needs `Microsoft.Authorization/roleAssignments/write` on the resource group.

**No managed identity (`use_managed_identity = false`).** No Key Vault, no role
assignments. Secrets are written directly onto each container app and ACR is
accessed with its admin credentials. Use this when you are deploying into a
subscription where you cannot create role assignments.

**Existing resource group (`create_resource_group = false`).** Deploys into a
group someone else manages; `location` is then taken from that group.

## Domains

Leave `domain` empty and the services answer on the Container App Environment's
own hostnames straight away — `frontend.<env-default-domain>`, `backend.…`,
`relay.…` — which is what `APP_BASE_URL`, `BACKEND_URL` and friends are set to.

Set `domain` and those URLs switch to `<domain>`, `api.<domain>` and
`relay.<domain>`. Binding the custom domain and its certificate is a separate
step; point the DNS records at the FQDNs in `terraform output` first, otherwise
Auth0 callbacks will target a host that does not resolve.

## Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `admin_email` | yes | | Admin user created on first boot |
| `vm_version` | yes | | Tag of the `noxusai/noxus-*` images |
| `docker_hub_token` | yes | | Docker Hub token used for the ACR import |
| `location` | no | `westeurope` | Azure region |
| `resource_group_name` | no | `noxus-rg` | Resource group to create or reuse |
| `create_resource_group` | no | `true` | Create the group, or deploy into an existing one |
| `use_managed_identity` | no | `true` | Managed identity + Key Vault, or inline secrets |
| `deployment_name` | no | `noxus` | Naming prefix, 2–22 lowercase alphanumerics/hyphens |
| `domain` | no | `""` | Custom domain; empty uses the environment's default hostnames |
| `whitelabel_logo` | no | `""` | `WHITELABEL_LOGO` |
| `deployment_env` | no | `prod` | `DEPLOYMENT_ENV` |
| `auth0_domain` | no | `noxus-oncloud.eu.auth0.com` | Auth0 tenant |
| `auth0_api_audience` | no | `https://oncloud.noxus.ai` | Auth0 API audience |
| `auth0_client_id` | no | *(oncloud app)* | Auth0 application client ID |
| `auth0_client_secret` | no | `""` | Auth0 application client secret |
| `auth0_mgmt_client_id` | no | `""` | Auth0 M2M client ID for the Management API |
| `auth0_mgmt_client_secret` | no | `""` | Auth0 M2M client secret |
| `deploy_postgres` | no | `true` | Deploy a managed PostgreSQL Flexible Server |
| `postgresql_url` | no | `""` | External PG in `user:password@host:port` form, when `deploy_postgres` is false |
| `postgres_sku_name` | no | `GP_Standard_D2s_v3` | Flexible Server SKU |
| `postgres_storage_mb` | no | `131072` | Flexible Server storage |
| `postgres_max_connections` | no | `500` | `max_connections`; the ceiling scales with the SKU |
| `redis_capacity` | no | `1` | Premium capacity (1 = P1/6GB) |
| `backend_count` / `frontend_count` / `worker_count` / `relay_count` | no | `1` | Replicas per service (min and max are pinned to this) |
| `vertex_project_id` | no | `""` | `VERTEX_PROJECT_ID` |
| `firestore_project` | no | `""` | `FIRESTORE_PROJECT` |
| `tags` | no | `{}` | Tags applied to every resource |

## Notes on the platform coupling

A few settings are dictated by the application and are not free choices:

- `SPOTFLOW_STORAGE_BUCKET` must be the **storage account name** —
  `AzureBlobStorageClient` builds `https://<bucket>.blob.core.windows.net` from
  it and hardcodes the container name `noxus`.
- `REDIS_URL` is a bare hostname; the port, TLS flag and password are separate
  (`REDIS_PORT`, `REDIS_SSL`, `REDIS_PASSWORD`).
- `POSTGRESQL_URL` is `user:password@host:port` with no scheme and no database —
  the app appends both.
- `require_secure_transport` is turned **off** on the Flexible Server. The
  platform builds asyncpg URLs without an ssl argument and asyncpg does not
  negotiate TLS on its own, so the server's default would reject every async
  connection. The server has no public endpoint and is only reachable from the
  delegated subnet.
- `azure.extensions` must allowlist `vector`, or knowledge bases cannot create
  the pgvector extension.
- Container sizes on the Consumption profile must be exactly 2Gi of memory per
  core, and a replica on the dedicated D4 profile cannot request the whole node
  because the runtime reserves part of it.
- Only the backend gets `RUN_MIGRATIONS` / `RUN_BOOTSTRAP`; its entrypoint is
  the only one that reads them, and it also creates the `spot`, `vectors` and
  `procrastinate` databases on first boot.

## Bumping the image version

Change `vm_version` and apply. That replaces the `terraform_data.acr_import`
resources, which re-runs `az acr import` for the new tag, then rolls a new
revision of each container app.
