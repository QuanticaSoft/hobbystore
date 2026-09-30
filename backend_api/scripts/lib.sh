# Funciones comunes de los scripts de backend_api. Se usa con "source".
set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
BACKEND_DIR="$REPO_ROOT/backend_api"
REMOTE_HOST="flamenco"
REMOTE_DB="gyros"

schema_for_env() {
  case "$1" in
    dev|prod) echo "hobbystore" ;;
    staging)  echo "hobbystore_staging" ;;
    *) echo "Entorno inválido: $1 (dev|staging|prod)" >&2; exit 1 ;;
  esac
}

# staging solo desde develop; prod solo desde un tag vX.Y.Z contenido en main.
require_git_ref_for_env() {
  local env="$1"
  [[ "$env" == "dev" ]] && return 0

  if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
    echo "Hay cambios sin commitear. Abortando." >&2; exit 1
  fi

  if [[ "$env" == "staging" ]]; then
    local branch
    branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
    [[ "$branch" == "develop" ]] || { echo "staging se despliega desde develop (estás en $branch)." >&2; exit 1; }
  else
    local tag
    tag="$(git -C "$REPO_ROOT" describe --exact-match --tags HEAD 2>/dev/null || true)"
    [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "prod requiere HEAD en un tag vX.Y.Z." >&2; exit 1; }
    git -C "$REPO_ROOT" merge-base --is-ancestor HEAD main \
      || { echo "El tag $tag no está en main." >&2; exit 1; }
  fi
}

confirm_prod() {
  [[ "$1" == "prod" ]] || return 0
  read -r -p "Vas a modificar PRODUCCIÓN. Escribe 'prod' para continuar: " answer
  [[ "$answer" == "prod" ]] || { echo "Cancelado." >&2; exit 1; }
}

# Ejecuta psql leyendo el SQL de stdin; los argumentos extra son flags simples (p.ej. -At).
run_psql() {
  local env="$1"; shift
  if [[ "$env" == "dev" ]]; then
    docker compose -f "$REPO_ROOT/infra/docker-compose.dev.yml" exec -T db \
      psql -X -q -v ON_ERROR_STOP=1 -U hobby -d hobbystore_dev "$@"
  else
    ssh -o BatchMode=yes "$REMOTE_HOST" psql -X -q -v ON_ERROR_STOP=1 -d "$REMOTE_DB" "$@"
  fi
}
