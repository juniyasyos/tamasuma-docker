#!/usr/bin/env bash
set -euo pipefail

# run.sh — sekali jalan untuk setup dan jalanin stack
#
# - Cek dependency (docker, docker compose, git)
# - Clone/update backend ke ./site/tamasuma-backend
# - Buat .env.docker kalau belum ada
# - docker compose up -d --build
# - Inisialisasi Laravel (key, migrate, storage link)
#
# Opsi:
#   --rebuild    Force rebuild images
#   --fresh      Hapus volumes (data DB) sebelum up
#   -h|--help    Tampilkan bantuan

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_BIN="docker compose"
REBUILD=false
FRESH=false

usage() {
  cat <<EOF
Pemakaian: ./run.sh [opsi]

Menjalankan seluruh stack sekali jalan.

Opsi:
  --rebuild   Rebuild image sebelum up
  --fresh     Hapus volumes (data DB) sebelum up
  -h, --help  Tampilkan bantuan ini
EOF
}

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "Error: '$1' tidak ditemukan." >&2; exit 1; }
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rebuild) REBUILD=true; shift ;;
    --fresh)   FRESH=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opsi tidak dikenal: $1" >&2; usage; exit 2 ;;
  esac
done

echo "[1/6] Cek dependency..."
require docker
require git
# Pastikan docker compose tersedia (plugin bawaan docker)
if ! docker compose version >/dev/null 2>&1; then
  echo "Error: 'docker compose' tidak tersedia. Install Docker Desktop/Engine terbaru." >&2
  exit 1
fi

echo "[2/6] Clone/update backend ke ./site/tamasuma-backend..."
mkdir -p "$PROJECT_ROOT/site"
chmod +x "$PROJECT_ROOT/scripts/clone_tamasuma_backend.sh"
"$PROJECT_ROOT/scripts/clone_tamasuma_backend.sh" --dir "$PROJECT_ROOT/site"

echo "[3/6] Siapkan .env.docker..."
if [[ ! -f "$PROJECT_ROOT/.env.docker" ]]; then
  if [[ -f "$PROJECT_ROOT/.env.docker.example" ]]; then
    cp "$PROJECT_ROOT/.env.docker.example" "$PROJECT_ROOT/.env.docker"
  else
    cat > "$PROJECT_ROOT/.env.docker" <<'ENVEOF'
# Konfigurasi default untuk docker-compose
POSTGRES_DB=laravel
POSTGRES_USER=laravel
POSTGRES_PASSWORD=laravel

# (opsional) nilai mirror untuk konsistensi
DB_DATABASE=laravel
DB_USERNAME=laravel
DB_PASSWORD=laravel
ENVEOF
  fi
  echo "Dibuat: .env.docker"
else
  echo ".env.docker sudah ada — dilewati"
fi

if [[ "$FRESH" == true ]]; then
  echo "[4/6] Fresh start: hapus volumes..."
  $COMPOSE_BIN down -v || true
fi

echo "[4.5/6] Sinkronkan entrypoint ke build context..."
# Dockerfile mengharapkan 'entrypoint.sh' di dalam build context (site/tamasuma-backend)
if [[ -f "$PROJECT_ROOT/docker/entrypoint.sh" ]]; then
  cp "$PROJECT_ROOT/docker/entrypoint.sh" "$PROJECT_ROOT/site/tamasuma-backend/entrypoint.sh"
else
  echo "Warning: docker/entrypoint.sh tidak ditemukan di root; pastikan tersedia." >&2
fi

echo "[5/6] Jalankan docker compose..."
UP_ARGS=(up -d)
if [[ "$REBUILD" == true ]]; then
  UP_ARGS=(--progress=plain build)
  $COMPOSE_BIN "${UP_ARGS[@]}"
  UP_ARGS=(up -d)
fi
$COMPOSE_BIN "${UP_ARGS[@]}"

echo "[6/6] Inisialisasi aplikasi Laravel di container..."
# Tunggu kontainer app siap menerima perintah ringan
tries=0; until $COMPOSE_BIN exec -T app php -v >/dev/null 2>&1; do
  tries=$((tries+1)); if [[ $tries -gt 30 ]]; then echo "Timeout menunggu container app" >&2; exit 1; fi; sleep 2;
done

# Pastikan composer install selesai (vendor/autoload.php ada)
if ! $COMPOSE_BIN exec -T app test -f vendor/autoload.php; then
  echo "Menjalankan composer install di container..."
  # Pakai dev deps secara default (lebih nyaman untuk lokal)
  $COMPOSE_BIN exec -T app /bin/sh -lc 'export COMPOSER_CACHE_DIR=/tmp/composer-cache COMPOSER_HOME=/tmp/composer-home COMPOSER_TMP_DIR=/tmp; composer install --prefer-dist --no-interaction --no-progress' || true
fi

# Siapkan .env di dalam app jika belum ada (entrypoint juga melakukan ini, ini hanya fallback)
$COMPOSE_BIN exec -T app php -r 'file_exists(".env") || copy(".env.example", ".env");' || true

# Sinkron DB config ke .env (fallback jika entrypoint belum menyetel)
$COMPOSE_BIN exec -T app /bin/sh -lc 'set -e; \
  if [ -f .env ]; then \
    set_kv() { key="$1"; val="$2"; if grep -qE "^${key}=.*$" .env; then sed -i "s#^${key}=.*#${key}=${val}#" .env; else echo "${key}=${val}" >> .env; fi; }; \
    set_kv DB_CONNECTION pgsql; \
    set_kv DB_HOST db; \
    set_kv DB_PORT 5432; \
    set_kv DB_DATABASE "${DB_DATABASE:-${POSTGRES_DB:-laravel}}"; \
    set_kv DB_USERNAME "${DB_USERNAME:-${POSTGRES_USER:-laravel}}"; \
    set_kv DB_PASSWORD "${DB_PASSWORD:-${POSTGRES_PASSWORD:-laravel}}"; \
  fi'

# Generate APP_KEY, migrasi database, dan storage link (aman dijalankan berulang)
$COMPOSE_BIN exec -T app php artisan key:generate --force || true
$COMPOSE_BIN exec -T app php artisan migrate --force || true
$COMPOSE_BIN exec -T app php artisan storage:link || true

echo
echo "Selesai! Aplikasi siap di: http://localhost:8080"
echo "Kontainer: web (Caddy), app (PHP-FPM), db (Postgres)"
