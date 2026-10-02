#!/usr/bin/env bash
# Carga los datos de demostración (seeds/demo.sql + imágenes) en dev o staging.
# Nunca en prod: ahí el catálogo lo crean las tiendas y los usuarios reales.
# Uso: backend_api/scripts/seed.sh dev|staging
# Las fotos se leen de $PICTURES_DIR (por defecto <repo>/pictures, fuera de git).
source "$(dirname "$0")/lib.sh"

ENV="${1:-}"
[[ "$ENV" == "dev" || "$ENV" == "staging" ]] || { echo "Uso: seed.sh dev|staging (prod no admite demo)." >&2; exit 1; }
SCHEMA="$(schema_for_env "$ENV")"
require_git_ref_for_env "$ENV"

PICTURES_DIR="${PICTURES_DIR:-$REPO_ROOT/pictures}"
BUILD_DIR="$BACKEND_DIR/seeds/.build/seed"
rm -rf "$BUILD_DIR"

# sips -Z también agranda: solo se reduce si la imagen supera el máximo.
resize() {
  local format="$1" max="$2" source="$3" target="$4"
  local largest
  largest="$(sips -g pixelWidth -g pixelHeight "$source" | awk '/pixel/ {print $2}' | sort -n | tail -1)"
  mkdir -p "$(dirname "$target")"
  if (( largest > max )); then
    sips -s format "$format" -s formatOptions 80 -Z "$max" "$source" --out "$target" >/dev/null
  else
    sips -s format "$format" -s formatOptions 80 "$source" --out "$target" >/dev/null
  fi
}

while IFS='|' read -r kind target source; do
  [[ -z "$kind" || "$kind" == \#* ]] && continue
  case "$kind" in
    product)
      resize jpeg 1200 "$PICTURES_DIR/$source" "$BUILD_DIR/$target.jpg"
      resize jpeg 400 "$PICTURES_DIR/$source" "$BUILD_DIR/${target}_t.jpg" ;;
    banner)
      resize jpeg 1600 "$PICTURES_DIR/$source" "$BUILD_DIR/$target.jpg" ;;
    store)
      resize png 256 "$BACKEND_DIR/seeds/media/stores/$source" "$BUILD_DIR/$target.png" ;;
    *) echo "Tipo desconocido en el manifiesto: $kind" >&2; exit 1 ;;
  esac
done < "$BACKEND_DIR/seeds/media-manifest.txt"
echo "Imágenes listas: $(find "$BUILD_DIR" -type f | wc -l | tr -d ' ') archivos."

if [[ "$ENV" == "dev" ]]; then
  rm -rf "$BACKEND_DIR/public/media/seed"
  mkdir -p "$BACKEND_DIR/public/media"
  cp -R "$BUILD_DIR" "$BACKEND_DIR/public/media/seed"
else
  remote "mkdir -p $MEDIA_DIR_STAGING/seed"
  rsync -az --delete -e "ssh ${SSH_OPTS[*]}" "$BUILD_DIR/" "$REMOTE_HOST:$MEDIA_DIR_STAGING/seed/"
fi

{
  echo "BEGIN;"
  echo "SET LOCAL search_path TO $SCHEMA;"
  cat "$BACKEND_DIR/seeds/demo.sql"
  echo "COMMIT;"
} | run_psql "$ENV"

echo "Demo cargada en $ENV ($SCHEMA)."
