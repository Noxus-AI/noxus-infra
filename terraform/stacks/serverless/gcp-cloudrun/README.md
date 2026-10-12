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

- A GCP project, and `tofu` ≥ 1.5 or `terraform` ≥ 1.5 authenticated with `gcloud auth application-default login`.
- A domain you control, if you want one. A Cloud DNS zone for it in the same project lets the stack create the record.
- A bucket for state (see `backend.tf`). State holds the database password and every generated key.

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

```sh
cp terraform.tfvars.example terraform.tfvars    # fill it in

tofu init \
  -backend-config="bucket=my-tfstate" \
  -backend-config="prefix=noxus/cloudrun"

tofu plan
tofu apply
```

The first apply is slow. Cloud SQL takes a while to create, and the backend's
first boot applies the whole database schema before it reports healthy. The
worker, relay and frontend wait for it.

Then:

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
  with the Password and Refresh Token grants. The platform's own login form
  uses it for the first admin, until SSO is confirmed working.

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

Platform settings are described in
[docs/configuration.md](../../../../docs/configuration.md). The stack sets the ones
a deployment needs and generates `AUTH0_SECRET`, `ADMIN_API_KEY` and
`CREDENTIAL_ENCRYPTION_KEY`. All three are stored in Secret Manager. Keep
the state: the encryption key protects every stored integration credential.

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
