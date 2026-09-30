#!/usr/bin/env bash
# Respaldo solo del schema de Hobby Store (nunca del resto de gyros).
# Uso: backend_api/scripts/backup.sh staging|prod
source "$(dirname "$0")/lib.sh"

ENV="${1:-}"
[[ "$ENV" == "staging" || "$ENV" == "prod" ]] || { echo "Uso: backup.sh staging|prod" >&2; exit 1; }
SCHEMA="$(schema_for_env "$ENV")"

mkdir -p "$REPO_ROOT/backups"
out="$REPO_ROOT/backups/${SCHEMA}-$(date +%Y%m%d-%H%M%S).dump"
ssh -o BatchMode=yes "$REMOTE_HOST" pg_dump -d "$REMOTE_DB" -n "$SCHEMA" -Fc > "$out"
echo "Backup: $out"
