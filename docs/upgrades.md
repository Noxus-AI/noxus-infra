# Upgrades

## What a version bump changes

`app_version` (Terraform) or `appVersion` (chart values) selects the image tags:
`spotflow-backend-<version>`, `spotflow-frontend-<version>`,
`spotflow-worker-<version>`, `spotflow-relays-<version>`,
`agentsandbox-<version>`.

All services move together. Running mixed versions is not supported — the worker
and backend share a schema and a job serialisation format.

## The ordering that matters

The backend runs Alembic migrations at startup when `RUN_MIGRATIONS=1`. With
several backend replicas the migration is guarded, so only one runs it — but
**workers do not wait for it.** A worker on the new image can pick up a job
before the schema it expects exists.

For a routine patch bump this rarely bites. For anything with a migration:

```sh
# 1. Stop consuming work. In-flight jobs finish; nothing new starts.
kubectl scale deployment -n noxus -l app=worker --replicas=0

# 2. Upgrade. The backend migrates as it rolls.
tofu apply -var app_version=0.9.0

# 3. Confirm the migration landed before letting workers back in.
kubectl logs -n noxus -l app=backend --tail=100 | grep -i alembic

# 4. Resume.
kubectl scale deployment -n noxus -l app=worker --replicas=<original>
```

Terraform will scale workers back to their configured count on the next apply, so
step 4 is only needed if you are not applying again immediately.

## Before you upgrade

**Back up the database.** Managed automated backups are continuous, but take an
explicit snapshot so you have a known-good point to name:

```sh
# AWS
aws rds create-db-snapshot \
  --db-instance-identifier noxus-prod-postgres \
  --db-snapshot-identifier noxus-pre-0-9-0

# GCP
gcloud sql backups create --instance=noxus-prod-postgres --description="pre 0.9.0"

# Azure — Flexible Server uses PITR; note the timestamp instead
date -u +%FT%TZ
```

**Read the release notes** for chart-level changes. Values are not always
backward compatible; the sandbox/plugin change below is the kind of thing that
appears there.

**Pull the current chart.** The chart version and the platform version move
independently — a new platform version may need new values, renamed keys, or a
new component:

```sh
git pull                            # pick up chart changes
git diff HEAD@{1} -- charts/        # read them before upgrading
helm dependency update charts/noxus-platform
helm template noxus charts/noxus-platform -f charts/noxus-platform/ci/full-values.yaml
```

The chart's `version` tracks chart changes; its `appVersion` is the default
platform version it deploys. Pin `app_version` explicitly in your Terraform or
values rather than inheriting `appVersion`, so a chart update never moves your
platform version as a side effect.

### Known breaking change: plugins moved into the sandbox

The standalone plugin-server was removed. Plugins now execute inside the agent
sandbox, and `SANDBOX_MANAGER_URL` — the switch that turns plugin loading on —
is only injected when `sandbox.enabled=true`.

A deployment that previously ran `pluginServer.enabled=true` **must** set
`sandbox.enabled=true` (or `sandbox_enabled = true` in the Terraform stacks), or
its plugin nodes and triggers silently fail to load. Nothing errors; the plugins
are just absent.

## Rolling back

**Application rollback is straightforward.** Set the previous `app_version` and
apply, or `helm rollback noxus`.

**Schema rollback is not.** Alembic migrations are not automatically reversed,
and the platform does not run downgrade paths on startup. If a migration has run
and you need to go back:

1. Restore the database from the pre-upgrade snapshot.
2. Deploy the previous `app_version`.

Which means the snapshot in the "before you upgrade" step is the actual rollback
plan. Data written after the snapshot is lost — this is why the worker-drain
ordering above matters, since it bounds how much work happened during the window.

For a rollback that only touches infrastructure — instance sizes, replica counts,
network changes — Terraform handles it normally.

## Zero-downtime considerations

The chart sets PodDisruptionBudgets and rolling update strategies, so a bump with
no migration and more than one replica per service is close to seamless.

What still causes a blip:

- **Single-replica services.** `backend.replicaCount: 1` means a gap during the
  roll.
- **Migrations that lock.** A long `ALTER TABLE` blocks reads on that table for
  its duration, regardless of replica count.
- **Worker drain.** `terminationGracePeriodSeconds: 600` lets in-flight runs
  finish; runs longer than that are killed and retried.
- **PgBouncer restart.** Every connection drops and reconnects. Brief, but
  visible as a burst of errors.

## Infrastructure upgrades

**Kubernetes version.** Bump `kubernetes_version` and apply. Managed node groups
and GKE node pools roll with surge; EKS Auto Mode handles it. Do this separately
from a platform version bump so you know which change caused any problem.

**Database major version.** `allow_major_version_upgrade` is deliberately false
on the AWS module. Major version upgrades need a maintenance window and a tested
restore, and should not be a side effect of a routine apply.

**Terraform provider versions.** Modules use ranges, stacks pin. Bump the stack's
`versions.tf`, run `tofu init -upgrade`, and read the plan carefully — provider
upgrades occasionally want to replace resources that look unchanged.
