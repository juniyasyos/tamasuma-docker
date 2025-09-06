#!/usr/bin/env bash
set -euo pipefail

# run.sh — sekali jalan untuk setup & jalanin stack

# ---- Konfigurasi yang bisa dioverride via ENV ----
COMPOSE_BIN="${COMPOSE_BIN:-docker compose}"
SERVICE_APP="${SERVICE_APP:-app}"      # contoh: app
SERVICE_WEB="${SERVICE_WEB:-web}"      # contoh: web
SERVICE_DB="${SERVICE_DB:-db}"         # contoh: db
SERVICE_NODE="${SERVICE_NODE:-node}"   # contoh: node (nama service, bukan container)
NODE_BUILD="${NODE_BUILD:-true}"       # set false untuk skip npm build
CLEAN_NODE_MODULES="${CLEAN_NODE_MODULES:-false}" # true untuk rm -rf node_modules setelah build
SKIP_CLONE="${SKIP_CLONE:-false}"      # true untuk melewati proses clone/update backend

# File env untuk konfigurasi stack/template (APP_DIR, APP_REPO, dll)
STACK_ENV_FILE="${STACK_ENV_FILE:-.stack.env}"
# --------------------------------------------------

REBUILD=false
FRESH=false

usage() {
  cat <<EOF
Pemakaian: ./run.sh [opsi]

Opsi:
  --rebuild   Rebuild image sebelum up
  --fresh     down -v sebelum up (hapus data DB)
  -h, --help  Bantuan
Variabel ENV penting:
  COMPOSE_BIN, SERVICE_APP, SERVICE_WEB, SERVICE_DB, SERVICE_NODE,
  NODE_BUILD=[true|false], CLEAN_NODE_MODULES=[true|false]
EOF
}

require() { command -v "$1" >/dev/null 2>&1 || { echo "Error: '$1' tidak ditemukan." >&2; exit 1; }; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rebuild) REBUILD=true; shift ;;
    --fresh)   FRESH=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opsi tidak dikenal: $1" >&2; usage; exit 2 ;;
  esac
done

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "[0/7] Muat konfigurasi stack (jika ada)…"
if [[ -f "$PROJECT_ROOT/$STACK_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$PROJECT_ROOT/$STACK_ENV_FILE"
  echo "  - Loaded $STACK_ENV_FILE"
else
  echo "  - $STACK_ENV_FILE tidak ditemukan; menggunakan default"
fi

# Variabel penting dari stack env dengan default
APP_DIR="${APP_DIR:-tamasuma-backend}"
APP_REPO="${APP_REPO:-${APP_REPO_URL:-juniyasyos/tamasuma-backend}}"
APP_REPO_BRANCH="${APP_REPO_BRANCH:-development}"
APP_REPO_SSH="${APP_REPO_SSH:-false}"

# Argumen global docker compose (agar .stack.env dipakai untuk substitusi variable)
COMPOSE_ARGS=()
if [[ -f "$PROJECT_ROOT/$STACK_ENV_FILE" ]]; then
  COMPOSE_ARGS+=("--env-file" "$PROJECT_ROOT/$STACK_ENV_FILE")
fi

# Namespace default untuk network/volume
if [[ -z "${COMPOSE_PROJECT_NAME:-}" && -n "${STACK_NAME:-}" ]]; then
  export COMPOSE_PROJECT_NAME="$STACK_NAME"
fi

# Wrapper docker compose dengan --env-file
# Catatan: sengaja tidak mengutip $COMPOSE_BIN agar "docker compose"
# terpecah menjadi dua argumen (bash word-splitting) dan tidak dianggap
# sebagai satu nama perintah.
compose() { $COMPOSE_BIN "${COMPOSE_ARGS[@]}" "$@"; }

echo "[1/7] Cek dependency…"
require docker
require git
# Deteksi Compose v2/v1 dan set COMPOSE_BIN otomatis bila belum di-override
if [[ -z "${COMPOSE_BIN_OVERRIDE_DETECTED:-}" ]]; then
  if docker compose version >/dev/null 2>&1; then
    COMPOSE_BIN=${COMPOSE_BIN:-"docker compose"}
  elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_BIN=${COMPOSE_BIN:-docker-compose}
    echo "  - Info: memakai legacy 'docker-compose' (disarankan upgrade ke Docker Compose v2)"
  else
    echo "Error: Docker Compose tidak ditemukan (coba instal plugin 'docker compose' atau binary 'docker-compose')." >&2
    echo "  - Linux: apt install docker-compose-plugin (atau docker-compose)" >&2
    echo "  - Docker Desktop: pastikan Compose V2 aktif" >&2
    exit 1
  fi
fi

if [[ "$SKIP_CLONE" == "true" ]]; then
  echo "[2/7] Lewati clone/update backend (SKIP_CLONE=true)"
else
  echo "[2/7] Clone/update backend ke ./site/$APP_DIR…"
  mkdir -p "$PROJECT_ROOT/site"
  chmod +x "$PROJECT_ROOT/scripts/sync_repo.sh"
  CLONE_ARGS=(--dir "$PROJECT_ROOT/site" --branch "$APP_REPO_BRANCH" --repo "$APP_REPO" --name "$APP_DIR")
  if [[ "$APP_REPO_SSH" == "true" ]]; then CLONE_ARGS+=(--ssh); fi
  "$PROJECT_ROOT/scripts/sync_repo.sh" "${CLONE_ARGS[@]}"
fi

echo "[3/7] Siapkan .env.docker…"
if [[ ! -f "$PROJECT_ROOT/.env.docker" ]]; then
  if [[ -f "$PROJECT_ROOT/.env.docker.example" ]]; then
    cp "$PROJECT_ROOT/.env.docker.example" "$PROJECT_ROOT/.env.docker"
  else
    cat > "$PROJECT_ROOT/.env.docker" <<'ENVEOF'
POSTGRES_DB=laravel
POSTGRES_USER=laravel
POSTGRES_PASSWORD=laravel
DB_DATABASE=laravel
DB_USERNAME=laravel
DB_PASSWORD=laravel
ENVEOF
  fi
  echo "Dibuat: .env.docker"
else
  echo ".env.docker sudah ada — dilewati"
fi

# Hindari override APP_KEY dari environment compose
if grep -qE '^APP_KEY=' "$PROJECT_ROOT/.env.docker"; then
  echo "[3b/7] Menonaktifkan APP_KEY di .env.docker (hindari override)"
  # sed GNU & BSD kompatibel
  tmp="$(mktemp)"; awk 'BEGIN{done=0} {if(!done && $0 ~ /^APP_KEY=/){print "# APP_KEY moved to app .env"; done=1} else print $0}' "$PROJECT_ROOT/.env.docker" > "$tmp" && mv "$tmp" "$PROJECT_ROOT/.env.docker"
fi

if [[ "$FRESH" == true ]]; then
  echo "[4/7] Fresh start: docker compose down -v…"
  compose down -v || true
fi

echo "[4.5/7] Sinkronkan entrypoint ke build context (jika ada)…"
if [[ -f "$PROJECT_ROOT/docker/entrypoint.sh" ]]; then
  mkdir -p "$PROJECT_ROOT/site/$APP_DIR"
  cp "$PROJECT_ROOT/docker/entrypoint.sh" "$PROJECT_ROOT/site/$APP_DIR/entrypoint.sh"
else
  echo "Warning: docker/entrypoint.sh tidak ditemukan; lewati."
fi

echo "[5/7] Build & up…"
if [[ "$REBUILD" == true ]]; then
  compose build --progress=plain
fi
compose up -d

# Tunggu database healthy (jika healthcheck tersedia)
echo "[5b/7] Menunggu database healthy…"
db_cid=$(compose ps -q "$SERVICE_DB" || true)
if [[ -n "$db_cid" ]]; then
  tries=0
  while true; do
    status=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$db_cid" 2>/dev/null || echo "none")
    if [[ "$status" == "healthy" || "$status" == "none" ]]; then
      break
    fi
    tries=$((tries+1)); [[ $tries -gt 60 ]] && { echo "  - Timeout menunggu DB healthy"; break; }
    sleep 2
  done
else
  echo "  - Service DB tidak ditemukan di compose; lewati"
fi

echo "[6/7] Inisialisasi Laravel…"
# Tunggu service APP siap
echo "  - Menunggu service '$SERVICE_APP' siap…"
tries=0
until compose exec -T "$SERVICE_APP" php -v >/dev/null 2>&1; do
  tries=$((tries+1)); [[ $tries -gt 30 ]] && { echo "Timeout menunggu '$SERVICE_APP'"; exit 1; }
  sleep 2
done

# Pastikan vendor ada (kepemilikan akan ditangani entrypoint saat user=root)
compose exec -T "$SERVICE_APP" sh -lc 'mkdir -p vendor' || true

# Pastikan vendor terpasang
if ! compose exec -T "$SERVICE_APP" test -f vendor/autoload.php; then
  echo "  - composer install…"
  compose exec -T "$SERVICE_APP" /bin/sh -lc 'export COMPOSER_CACHE_DIR=/tmp/composer-cache COMPOSER_HOME=/tmp/composer-home COMPOSER_TMP_DIR=/tmp; composer install --prefer-dist --no-interaction --no-progress' || true
fi

# Pastikan .env ada
compose exec -T "$SERVICE_APP" php -r 'file_exists(".env") || copy(".env.example", ".env");' || true

# Bersih cache config (hindari MissingAppKey akibat cache lama)
compose exec -T "$SERVICE_APP" sh -lc 'rm -f bootstrap/cache/config.php bootstrap/cache/services.php || true'
compose exec -T "$SERVICE_APP" php artisan optimize:clear || true

# Sinkron DB config
compose exec -T "$SERVICE_APP" /bin/sh -lc 'set -e; \
  set_kv() { k="$1"; v="$2"; if grep -qE "^${k}=.*$" .env; then sed -i "s#^${k}=.*#${k}=${v}#" .env; else echo "${k}=${v}" >> .env; fi; }; \
  set_kv DB_CONNECTION pgsql; \
  set_kv DB_HOST '"$SERVICE_DB"'; \
  set_kv DB_PORT 5432; \
  set_kv DB_DATABASE "${DB_DATABASE:-${POSTGRES_DB:-laravel}}"; \
  set_kv DB_USERNAME "${DB_USERNAME:-${POSTGRES_USER:-laravel}}"; \
  set_kv DB_PASSWORD "${DB_PASSWORD:-${POSTGRES_PASSWORD:-laravel}}"; \
'

# APP_KEY + migrasi + storage link
compose exec -T "$SERVICE_APP" php artisan key:generate --force || true
compose exec -T "$SERVICE_APP" php -r 'if(!preg_match("/^APP_KEY=.+$/m", file_get_contents(".env"))){$k="base64:".base64_encode(random_bytes(32)); $e=file_get_contents(".env"); if(preg_match("/^APP_KEY=.*$/m",$e)){$e=preg_replace("/^APP_KEY=.*$/m","APP_KEY=".$k,$e);}else{$e.="\nAPP_KEY=".$k."\n";} file_put_contents(".env",$e);}'

# compose exec -T "$SERVICE_APP" php artisan migrate --force || true
compose exec -T "$SERVICE_APP"  git config --global --add safe.directory /var/www/html || true
compose exec -T "$SERVICE_APP" php artisan storage:link || true
compose exec -T "$SERVICE_APP" composer run setup || true

# ---- Bagian Node/npm (sekali jalan) ----
if [[ "$NODE_BUILD" == "true" ]]; then
  echo "[6b/7] Build frontend (npm)…"
  # Gunakan `run --rm` agar tidak butuh service node selalu hidup.
  if compose config --services | grep -qx "$SERVICE_NODE"; then
    if [[ -f "$PROJECT_ROOT/site/$APP_DIR/package.json" ]]; then
      compose run --rm "$SERVICE_NODE" npm ci --no-fund --no-audit || compose run --rm "$SERVICE_NODE" npm install --no-fund --no-audit
      compose run --rm "$SERVICE_NODE" npm run build
      if [[ "$CLEAN_NODE_MODULES" == "true" ]]; then
        compose run --rm "$SERVICE_NODE" /bin/sh -lc 'rm -rf node_modules'
      fi
    else
      echo "  - package.json tidak ditemukan; lewati build frontend."
    fi
  else
    echo "  - Warning: service '$SERVICE_NODE' tidak didefinisikan di docker-compose; lewati build frontend."
  fi
else
  echo "[6b/7] Skip build frontend (NODE_BUILD=false)"
fi

# Cache config untuk production
compose exec -T "$SERVICE_APP" sh -lc 'if [ "${APP_ENV:-production}" = "production" ]; then php artisan config:cache || true; fi'

echo
echo "[7/7] Selesai! Aplikasi siap di: http://localhost:${WEB_HTTP_PORT:-8080}"
echo "Kontainer: $SERVICE_WEB (web), $SERVICE_APP (php-fpm), $SERVICE_DB (db)$( [[ "$NODE_BUILD" == "true" ]] && echo ", $SERVICE_NODE (npm run)")"
