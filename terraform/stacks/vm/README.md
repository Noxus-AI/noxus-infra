# Single-VM appliance

The whole platform — backend, frontend, worker, Postgres, Redis, MinIO, nginx —
as docker-compose on one machine, from a prebuilt image.

| Stack | Target |
|-------|--------|
| `gcp` | Google Compute Engine, via a managed instance group |
| `aws` | EC2, with RDS and ElastiCache alongside |

The Azure equivalent is a Marketplace offer rather than Terraform — see
[`marketplace/azure-vm/`](../../../marketplace/azure-vm/).

## When this is the right shape

Trials, proofs of concept, air-gapped networks, or a single small tenant where an
hour of downtime is acceptable.

**There is one of everything.** A host failure is an outage. Upgrades restart the
whole stack. Backups are disk snapshots, not managed database backups. Do not use
this where availability matters — see
[docs/choosing-a-deployment.md](../../../docs/choosing-a-deployment.md).

## How the image works

The appliance image is prebuilt and published per cloud by Noxus; it carries the
docker-compose definition and every service the platform needs. The Terraform
here provisions the machine, its network, and its data stores, and passes
configuration in through instance metadata or user data. On boot, systemd units
render an `env.vm` file from that configuration and start docker-compose.

Upgrades are driven by a version marker the VM watches rather than by replacing
the instance, so a version bump restarts the stack in place. Contact Noxus for
the image identifiers available in your cloud and region.

## Configuration

Both stacks take the same core inputs as every other deployment: a domain, Auth0
credentials, an admin email, and a version. Auth0 client credentials have **no
defaults** and must be supplied — they were previously shipped as variable
defaults in this repo, which was a mistake.

`vm_version` (GCP) and `ami_id` (AWS) select the appliance image. These must
correspond to the platform version you intend to run; there is no separate
`app_version` here because the image carries the compose file.

## Data

**GCP** runs Postgres inside the VM by default, on a persistent disk mounted at
`/backup/postgres`, unless `deploy_postgres = false` and you supply
`postgresql_url`. **AWS** provisions RDS and ElastiCache separately, so the VM is
stateless apart from local caches.

The GCP default means your database lives and dies with the disk. Snapshot it on
a schedule and test a restore before you rely on it.

## Certificates

The image ships a self-signed certificate so the appliance is reachable
immediately. Replace it before real use — `marketplace/azure-vm/cert.sh` shows
the swap, and the same approach applies on the other clouds.
