#!/usr/bin/env bash
# Create the databases and extensions the Noxus platform expects.
#
#   scripts/bootstrap-postgres.sh --host db.internal --user noxus
#   PGPASSWORD=... scripts/bootstrap-postgres.sh --host db.internal --user noxus --check
#
# Terraform creates the databases where the cloud API allows it (Cloud SQL, Azure
# Flexible Server) but never the extensions — those need a real connection. RDS
# creates only the initial database, so this script is required there.
#
# The managed databases are reachable only from inside the VPC. Run this from a
# bastion, a `kubectl run` pod, or a port-forward.
set -euo pipefail

host=""
port="5432"
user="postgres"
maintenance_db="postgres"
check_only=false

usage() {
  cat <<'EOF'
Usage: bootstrap-postgres.sh --host HOST [options]

  --host HOST      PostgreSQL host (required)
  --port PORT      Port (default 5432)
  --user USER      Superuser or database owner (default postgres)
  --db DB          Maintenance database to connect to first (default postgres)
  --check          Report what is missing without changing anything
  -h, --help       This message

Password comes from PGPASSWORD or ~/.pgpass, as with any libpq client.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)  host="${2:-}"; shift 2 ;;
    --port)  port="${2:-}"; shift 2 ;;
    --user)  user="${2:-}"; shift 2 ;;
    --db)    maintenance_db="${2:-}"; shift 2 ;;
    --check) check_only=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "${host}" ]]; then
  echo "error: --host is required" >&2
  usage >&2
  exit 1
fi

command -v psql >/dev/null || { echo "error: psql not found on PATH" >&2; exit 1; }

# spot            application schema
# vectors         embeddings, written by the knowledge-base pipeline
# license         license server state
# procrastinate   the job queue the workers poll
# spot_userdata   Noxus Tables; only used when TABLES_ENABLED is on, but harmless
DATABASES=(spot vectors license procrastinate spot_userdata)

# Extensions the platform's Alembic migrations create on first boot. Creating them
# here is belt-and-braces on RDS and Cloud SQL, and on Azure Flexible Server it
# surfaces a missing azure.extensions allowlist entry now rather than as an opaque
# migration failure later.
declare -A EXTENSIONS=(
  [spot]="vector uuid-ossp pg_trgm"
  [vectors]="vector"
)

psql_run() {
  psql --host "${host}" --port "${port}" --username "${user}" \
       --dbname "$1" --no-password --quiet --tuples-only --no-align \
       -v ON_ERROR_STOP=1 -c "$2"
}

echo "Connecting to ${user}@${host}:${port}/${maintenance_db}"
psql_run "${maintenance_db}" "SELECT version();" >/dev/null

missing=0

for db in "${DATABASES[@]}"; do
  exists="$(psql_run "${maintenance_db}" "SELECT 1 FROM pg_database WHERE datname = '${db}';")"
  if [[ -n "${exists}" ]]; then
    echo "  database ${db}: present"
    continue
  fi

  missing=$((missing + 1))
  if [[ "${check_only}" == true ]]; then
    echo "  database ${db}: MISSING"
  else
    echo "  database ${db}: creating"
    psql_run "${maintenance_db}" "CREATE DATABASE \"${db}\";"
  fi
done

for db in "${!EXTENSIONS[@]}"; do
  # Skip extension work on a database we were only asked to report on.
  if [[ "${check_only}" == true ]]; then
    exists="$(psql_run "${maintenance_db}" "SELECT 1 FROM pg_database WHERE datname = '${db}';")"
    [[ -z "${exists}" ]] && continue
  fi

  for ext in ${EXTENSIONS[$db]}; do
    installed="$(psql_run "${db}" "SELECT 1 FROM pg_extension WHERE extname = '${ext}';")"
    if [[ -n "${installed}" ]]; then
      echo "  ${db}.${ext}: present"
      continue
    fi

    missing=$((missing + 1))
    if [[ "${check_only}" == true ]]; then
      echo "  ${db}.${ext}: MISSING"
    else
      echo "  ${db}.${ext}: creating"
      # On Azure this fails unless the extension is on the azure.extensions
      # allowlist — see terraform/modules/azure/postgres.
      psql_run "${db}" "CREATE EXTENSION IF NOT EXISTS \"${ext}\";"
    fi
  done
done

if [[ "${check_only}" == true ]]; then
  if [[ "${missing}" -gt 0 ]]; then
    echo "${missing} item(s) missing — re-run without --check to create them." >&2
    exit 1
  fi
  echo "All databases and extensions present."
else
  echo "Bootstrap complete."
fi
