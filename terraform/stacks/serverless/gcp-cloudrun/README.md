# Noxus on Google Cloud Run

One self-contained OpenTofu/Terraform root that deploys the whole platform into
a single GCP project: five Cloud Run services, Cloud SQL for PostgreSQL,
Memorystore for Redis, Cloud Storage, and Vertex AI as the model provider. No
Kubernetes and no VMs.

```
                        https://<domain>
                               │
             External HTTPS load balancer, Google-managed certificate
                               │
   ┌───────────────────────────┼─────────────────────── VPC ──────────────────┐
   │                       frontend                                           │
   │              /api/backend │ /api/relay                                   │
   │                 ┌─────────┴─────────┐                                    │
   │              backend   worker     relay        sandbox                   │
   │                 │         │         │    (own identity, own bucket,      │
   │                 └─────────┼─────────┘     no access to private ranges)   │
   │       Cloud SQL (private IP) · Memorystore (private IP)                  │
   │       Cloud Storage · Vertex AI          (Private Google Access)         │
   │                                                                          │
   │       everything else ──▶ Cloud NAT ──▶ one static egress IP             │
   └──────────────────────────────────────────────────────────────────────────┘
```

| Service | Image | Reachable from | Notes |
|---|---|---|---|
| frontend | `noxus-frontend` | The load balancer only (the internet, without a domain) | Serves the app and proxies `/api/backend/*` to the backend and `/api/relay/*` to the relay, so users, API clients and webhooks all use one hostname |
| backend | `noxus-backend` | Inside the VPC | Creates its databases and runs migrations on boot |
| worker | `noxus-worker` | Inside the VPC | Workflow runs, agents, knowledge-base ingestion, scheduled jobs |
| relay | `noxus-relays` | Inside the VPC | Receives webhooks and channel events, through the frontend |
| sandbox | `noxus-agentsandbox` | Inside the VPC | Runs user code: Run Code, plugins, browser automation |

Every service is pinned to a fixed instance count, and nothing scales to zero.

## What you need first

**From Noxus**

- A Docker Hub token for the private `noxusai` images. Not needed if you mirror the images yourself (`image_registry`).
- An Auth0 application dedicated to this deployment: a client ID and secret. Send Noxus the `auth0_application_settings` output (or, for a domain, `https://<domain>/auth/callback`) so it can allow your URLs. See [Single sign-on](#single-sign-on).

**On your side**

- A GCP project with billing enabled.
- The [gcloud CLI](https://cloud.google.com/sdk/docs/install) and
  [OpenTofu](https://opentofu.org/docs/intro/install/) ≥ 1.5 (Terraform ≥ 1.5 works too).
- A domain you control, if you want one. A Cloud DNS zone for it in the same project lets the stack create the record.

**Permissions for whoever runs `apply`.** Project Owner covers everything. Otherwise:

| Role | For |
|---|---|
| `roles/serviceusage.serviceUsageAdmin` | Enabling APIs |
| `roles/compute.networkAdmin` | VPC, subnet, NAT, addresses, load balancer backends |
| `roles/compute.loadBalancerAdmin` | Load balancer, certificate |
| `roles/compute.securityAdmin` | Sandbox firewall rule, TLS policy |
| `roles/cloudsql.admin`, `roles/redis.admin` | Databases |
| `roles/run.admin` | Cloud Run services |
| `roles/iam.serviceAccountAdmin`, `roles/iam.serviceAccountUser` | Creating the runtime identities and attaching them |
| `roles/resourcemanager.projectIamAdmin` | Granting the platform identity Vertex AI access |
| `roles/secretmanager.admin` | Secrets and their access grants |
| `roles/artifactregistry.admin` | The image repository |
| `roles/storage.admin` | Buckets |
| `roles/dns.admin` | Only with `dns_managed_zone` |

**Organisation policies that commonly get in the way**

- Cloud Run ingress restrictions must allow *internal* and *internal and Cloud Load Balancing*. Without a domain, the frontend needs *all*.
- Cloud Run VPC egress restrictions must allow *all traffic*, which is what every service uses.
- A policy that forbids disabling the Cloud Run invoker IAM check blocks this stack. The platform authenticates its own requests and does not send Google identity tokens between services.
- Load balancer type restrictions must allow the global external Application Load Balancer when a domain is set.
- Resource location restrictions must include `region`. Secrets are replicated only there.

The stack grants nothing to `allUsers`, so domain-restricted sharing does not affect it.

## Deploy

**1. Prepare the project** (once). The stack enables every API it uses, but
reading the project before that needs two of them already on, and local
credentials need a project to bill API calls to.

```sh
PROJECT=my-gcp-project
REGION=europe-west2

gcloud auth login
gcloud auth application-default login
gcloud auth application-default set-quota-project "$PROJECT"
gcloud services enable cloudresourcemanager.googleapis.com serviceusage.googleapis.com --project "$PROJECT"
```

**2. Create a bucket for state.** State holds the database password and every
generated key, so keep it private and versioned. For a throwaway evaluation you
can delete `backend.tf` instead and keep state on your machine.

```sh
gcloud storage buckets create "gs://$PROJECT-tfstate" --project "$PROJECT" \
  --location "$REGION" --uniform-bucket-level-access --public-access-prevention
gcloud storage buckets update "gs://$PROJECT-tfstate" --versioning
```

**3. Fill in the variables and apply.** `terraform.tfvars.example` lists every
input with comments; `minimal.tfvars.example` is the smallest working set.

```sh
cp terraform.tfvars.example terraform.tfvars    # fill it in

tofu init \
  -backend-config="bucket=$PROJECT-tfstate" \
  -backend-config="prefix=noxus/cloudrun"

tofu plan
tofu apply
```

The first apply is slow. Cloud SQL takes a while to create, and the backend's
first boot applies the whole database schema before it reports healthy. The
worker, relay and frontend wait for it. `tofu apply` only returns once every
service has passed its health check, so a clean finish means the platform is
running. If it fails, see [Troubleshooting](#troubleshooting).

**4. Then:**

1. **DNS.** Unless `dns_managed_zone` is set, create the A record from
   `tofu output required_dns_records`. The certificate only issues once the
   record resolves, and that can take up to an hour after it does. Until then,
   HTTPS fails with a handshake error.
2. **Auth0.** Confirm with Noxus that the URLs in
   `tofu output auth0_application_settings` are allowed on your application.
3. **First login.** Open `tofu output url` and sign up or log in as
   `admin_email` with email and password. Then set up
   [single sign-on](#single-sign-on), or invite users from the organisation
   settings.
4. **Models.** Gemini and the embedding models work immediately, through Vertex
   AI in this project. Other providers' keys go in the admin panel.

## Single sign-on

Users sign in through Auth0, which brokers your identity provider (for example
Microsoft Entra ID). The platform never contacts the identity provider itself:
the browser goes from Auth0 to Microsoft and back. So SSO adds no egress from
the VPC beyond the Auth0 domain.

**Noxus sets up, on its Auth0 tenant:**

- The application dedicated to this deployment, allowing the URLs in
  `tofu output auth0_application_settings`.
- An enterprise connection to your identity provider, as SAML or OpenID
  Connect, enabled for this application only.
- The `Username-Password-Authentication` connection on the same application,
  with the Password and Refresh Token grants, and sign-ups allowed (or the
  admin's user created in advance). The platform's own login form uses it for
  the first admin, until SSO is confirmed working.

**Your admin then, in the platform's authentication settings:**

1. Adds the SSO connection: its type (SAML or OIDC, matching what Noxus
   created), the Auth0 connection name Noxus gives you, and the button label.
   The login page shows the button from then on.
2. Once SSO works, turns off email and password login.

Mapping identity-provider groups to workspaces and roles additionally needs an
Auth0 Action that puts the groups in the token (Noxus sets it up) and a group
mapping in the platform's authentication configuration.

**No Management API credentials.** The stack can pass Auth0 Management API
credentials (`auth0_mgmt_client_id` / `_secret`), and leaves them out by
default. They are tenant-wide: on a shared tenant they would also expose other
organisations' users and connections. Without them, the login page lists the
connections configured in the platform instead of asking Auth0. The only things
lost are the admin page listing Auth0 users and resending verification emails,
and neither applies to SSO users.

## Network access

Inbound, only the load balancer is public (or the frontend itself, without a
domain). Everything else accepts traffic from inside the VPC only.

Outbound, every service sends all traffic through the VPC. Google APIs (Vertex
AI, Cloud Storage, the services' own `run.app` addresses) go over Private Google
Access and never reach the internet. Everything else leaves through Cloud NAT from
the address in `tofu output egress_ip`. If your firewall denies egress by
default, these are the destinations to open:

| Destination (HTTPS) | Used for | If blocked |
|---|---|---|
| The Auth0 domain (`noxus-oncloud.eu.auth0.com`) | The backend fetches Auth0's signing keys at startup; every login | **The backend does not start**, and nobody can log in |
| `license.app.noxus.ai`, `ncs.app.noxus.ai` | Deployment registration on boot; Noxus control service | Each backend boot can wait up to a minute on registration, then carries on. `extra_env = { USE_NCS = "false" }` stops the control-service calls |
| `*.ingest.de.sentry.io` | Error reports to Noxus | Noxus does not see errors. `extra_env = { SENTRY_URL = "" }` turns reporting off |
| `raw.githubusercontent.com` | Hourly refresh of model pricing | The bundled pricing table is used |
| `pypi.org`, `files.pythonhosted.org` (from the sandbox) | Installing packages for plugins and Run Code | Only preinstalled packages are available |
| Model providers other than Vertex, such as `api.openai.com` | Only if configured in the admin panel | That provider is unavailable |
| Each integration's API, such as Microsoft Graph for SharePoint and Teams | Only for integrations you connect | That integration fails |

Inbound webhooks (Slack, Teams, WhatsApp, Telegram, generic webhook triggers)
arrive at `https://<domain>/api/relay/...` (`tofu output webhook_base_url`), so
those senders must be able to reach the load balancer.

Images are not on this list. The Artifact Registry remote repository fetches
them from Docker Hub on Google's side, outside your VPC.

## Configuration

Everything is in [`variables.tf`](variables.tf). The ones you are likely to touch:

| Variable | Default | |
|---|---|---|
| `domain` | `""` | Empty: no load balancer, and the URL is the frontend's `run.app` address |
| `dns_managed_zone` | `""` | Let the stack create the A record |
| `image_registry` | `""` | Pull from your own mirror instead of the remote repository this stack creates |
| `network`, `subnetwork` | `""` | Deploy into an existing (for example Shared) VPC |
| `auth0_domain`, `auth0_api_audience` | Noxus tenant | Change only if Noxus gives you an application on another tenant or domain; the Auth0 egress rule follows `auth0_domain` |
| `auth0_mgmt_client_id` / `_secret` | `""` | Leave unset on a shared tenant, see [Single sign-on](#single-sign-on) |
| `database` | 2 vCPU / 8 GB, 50 GB SSD | Cloud SQL sizing |
| `redis_memory_size_gb` | `1` | |
| `backend` / `frontend` / `worker` / `relay` | 2/4Gi · 1/2Gi · 4/8Gi · 1/2Gi | `cpu`, `memory`, `instances` |
| `deploy_sandbox`, `sandbox` | `true`, 4/8Gi | Without it, Run Code runs on the worker and there are no plugins or browser features |
| `sandbox_provider` | `gvisor` | See below |
| `extra_env` | `{}` | Any other platform setting |
| `deletion_protection` | `true` | Database and bucket protection |

The stack generates `AUTH0_SECRET`, `ADMIN_API_KEY` and
`CREDENTIAL_ENCRYPTION_KEY` and stores them in Secret Manager. Keep the state:
the encryption key protects every stored integration credential.

## Environment variables

This is the complete set the stack gives each service, and the minimum a Cloud
Run deployment needs. It is also a checklist for anyone wiring the services by
hand. Everything else keeps the platform default; see
[docs/configuration.md](../../../../docs/configuration.md) for the full
reference. `extra_env` adds to or overrides the plain variables on the backend,
worker, relay and frontend.

**Backend, worker and relay**

| Variable | Value | Without it |
|---|---|---|
| `DEPLOYMENT_ENV` | `deployment_env` (`prod`) | The service does not start |
| `ON_PREM` | `true` | Features that assume Noxus-hosted services stay on; no deployment registration |
| `IS_PROD` | `true` | Requests without a token are not rejected; no error reporting |
| `BILLING_ENABLED` | `false` | SaaS billing switches on (the default is `true`) |
| `SECRETS_SOURCE` | `db` | The service does not start: the default, `file`, reads a vault file the images do not contain |
| `ADMIN_EMAIL` | `admin_email` | First boot creates no tenant, so nobody can log in |
| `FRONTEND_URL` | the `url` output | The service does not start |
| `BACKEND_URL` | `<url>/api/backend` | The service does not start |
| `RELAY_URL` | `<url>/api/relay` | Webhook URLs given to Slack, Teams, Telegram and others point at an internal default |
| `MCP_SERVER_URL` | backend's internal URL + `/mcp/` | Agents call the Noxus MCP server through the frontend's proxy, which is built for browser sessions |
| `AUTH0_DOMAIN` | `auth0_domain` | The backend does not start |
| `AUTH0_ISSUER_BASE_URL` | `https://<auth0_domain>` | The frontend's connection lookup fails |
| `AUTH0_API_AUDIENCE`, `AUTH0_CLIENT_ID` | from the variables | No login |
| `AUTH0_BASE_URL`, `APP_BASE_URL` | the `url` output | No login |
| `AUTH0_MGMT_CLIENT_ID` | `auth0_mgmt_client_id`, normally empty | See [Single sign-on](#single-sign-on) |
| `REDIS_URL` | Memorystore host, no scheme or port | The service does not start |
| `BUCKET_CLIENT` | `gcloud` | |
| `SPOTFLOW_STORAGE_BUCKET`, `SPOTFLOW_PUBLIC_STORAGE_BUCKET` | the platform bucket | The service does not start |
| `VERTEX_PROJECT_ID` | `project_id` | No models |
| `SANDBOX_MANAGER_URL`, `USE_REMOTE_SANDBOX=true` | sandbox's internal URL | With the sandbox only. No plugins or browser features, and Run Code runs on the worker |
| `PLATFORM_HEALTH_SANDBOX_ENABLED=false` | | Without the sandbox only: the status page reports a sandbox that does not exist as down |
| `WHITELABEL_LOGO` | `whitelabel_logo` | Only when set |

From Secret Manager:

| Variable | Value | Without it |
|---|---|---|
| `POSTGRESQL_URL`, `VECTOR_POSTGRESQL_URL` | `noxus:<password>@<private IP>:5432`, no scheme and no database name | The service does not start |
| `AUTH0_CLIENT_SECRET` | `auth0_client_secret` | No login |
| `AUTH0_SECRET` | generated | No login. Changing it signs everyone out |
| `ADMIN_API_KEY` | generated | Falls back to a published key that grants admin on the backend; the platform then refuses to use the sandbox |
| `CREDENTIAL_ENCRYPTION_KEY` | generated, or `credential_encryption_key` | Integration credentials are stored unencrypted |
| `AUTH0_MGMT_CLIENT_SECRET` | `auth0_mgmt_client_secret` | Only with `auth0_mgmt_client_id` |

**Backend only**

| Variable | Value | Without it |
|---|---|---|
| `RUN_MIGRATIONS` | `1` | No schema |
| `RUN_BOOTSTRAP` | `1` | No first tenant |
| `NOXUS_BACKEND_URL` | `http://localhost:8080` | The Noxus MCP tools call the backend's public address and are refused |

**Frontend.** The same plain variables, except that `BACKEND_URL` and
`RELAY_URL` are the backend's and the relay's internal URLs, which its server
proxies to. Of the secrets it gets only `AUTH0_CLIENT_SECRET` and
`AUTH0_SECRET`. It needs the rest of the plain set because it passes `ON_PREM`,
`FRONTEND_URL` and whether plugins exist (`SANDBOX_MANAGER_URL`) to the
browser.

**Sandbox.** Deliberately minimal, since it runs untrusted code:

| Variable | Value | Without it |
|---|---|---|
| `DEPLOYMENT_ENV` | `deployment_env` | |
| `SECRETS_SOURCE` | `env` | |
| `SANDBOX_PROVIDER` | `sandbox_provider` | The platform default, `syd` |
| `BUCKET_CLIENT` | `gcloud` | |
| `SPOTFLOW_STORAGE_BUCKET`, `SPOTFLOW_PUBLIC_STORAGE_BUCKET` | the sandbox bucket | |
| `SANDBOX_FS_ENABLED`, `SANDBOX_FS_PREFIX`, `SANDBOX_FS_SYNC_INTERVAL` | `true`, `sandboxes`, `300` | Persistent sandboxes (agent workspaces, installed plugins) are lost on every restart |
| `EXTERNAL_BASE_URL` | its own internal URL | Plugins cannot connect: the sandbox hands out `localhost` addresses |
| `ADMIN_API_KEY` | from Secret Manager | Its control plane accepts the published default key, and the platform refuses to use it |

## Upgrading

Set `noxus_version` to the new release and apply. The backend rolls first and
migrates on boot. Read [docs/upgrades.md](../../../../docs/upgrades.md) before
skipping several releases.

## Removing it

```sh
# set deletion_protection = false, then
tofu apply
tofu destroy
```

## Troubleshooting

Service logs:

```sh
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="noxus-backend"' \
  --project "$PROJECT" --limit 100 --format 'value(timestamp,textPayload)'
```

| Symptom | Usual cause |
|---|---|
| `plan` fails saying the Cloud Resource Manager API is disabled, or asks for a quota project | Step 1 of [Deploy](#deploy) was skipped |
| An organisation policy error during `apply` | See [the policies above](#what-you-need-first) |
| A service fails to start with an image pull error | Wrong `docker_hub_token` or `docker_hub_username`, or a `noxus_version` that does not exist |
| `apply` waits on the backend and then fails, and its log stops after `[mcp-registry] generated ... MCP integration classes` | The backend cannot reach the Auth0 domain. Open egress to it ([Network access](#network-access)) |
| The backend restarts during its first boot | The startup probe allows 15 minutes for the first migration. Look for a database error earlier in the log |
| HTTPS handshake error on the domain | The certificate is still provisioning. Check the DNS record, then `gcloud compute ssl-certificates describe noxus-cert --global --format 'value(managed.status)'` |
| Auth0 shows "Callback URL mismatch" | The URLs in `tofu output auth0_application_settings` are not allowed on the application yet |
| The login form says "This login method is not configured" | The Password grant is not enabled on the Auth0 application |
| No SSO button on the login page | The connection is not yet in the platform's authentication settings ([Single sign-on](#single-sign-on)) |

Resource names above assume the default `name_prefix` of `noxus`.

## Design notes

- **One hostname.** The frontend's own server proxies the API and the webhook
  receivers. So the backend, worker and relay stay internal, and the deployment
  needs one certificate and one DNS record.
- **All egress through the VPC.** A Cloud Run service only counts as internal
  to another's internal ingress when its own egress goes through the VPC. That
  is also what gives the deployment a single, fixed egress address.
- **Service URLs are computed, not read.** Cloud Run's URLs are deterministic
  (`https://<service>-<project number>.<region>.run.app`). Computing them lets
  each service be configured with the others' addresses, and its own, in a
  single apply.
- **Three identities.** Backend, worker and relay share one service account
  (Vertex AI, the platform bucket, their secrets). The frontend can read only
  the two Auth0 secrets. The sandbox can read its own bucket and the key the
  platform calls it with, nothing else.
- **The sandbox.** It runs untrusted code. With `gvisor`, that code shares the
  sandbox service's network, so a firewall rule denies the sandbox private
  ranges (Cloud SQL, Memorystore, anything peered). The metadata server cannot
  be firewalled on Cloud Run, which is why the sandbox's own identity has no
  access beyond its bucket. `syd` adds its own network jail, but Cloud Run has
  not been verified to grant the capabilities it needs.
- **One backend.** The backend migrates on boot, and two instances booting at
  once would race. Scale the worker instead.

## Known limitations

- The Noxus MCP server is reachable from agents inside the platform, not from
  external MCP clients. Exposing it means routing `/mcp/*` on the load balancer
  to the backend and changing `MCP_SERVER_URL`.
- Deleting a tenant does not clear its sandbox state from the sandbox bucket.
- Identity-Aware Proxy in front of the frontend has not been tested by Noxus.
