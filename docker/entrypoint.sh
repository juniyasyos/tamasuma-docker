#!/usr/bin/env bash
set -euo pipefail

# entrypoint.sh — bootstrap ringan untuk container PHP-FPM Laravel
#
# Fitur:
# - Pastikan berada di /var/www/html
# - Composer install jika vendor belum ada
# - Buat .env dari .env.example jika belum ada
# - Opsi tunggu DB (Postgres/MySQL) via env LARAVEL_WAIT_FOR_DB=true|false
# - Generate APP_KEY jika kosong
# - Storage link jika belum dibuat
# - Cache optimize saat production, clear saat non-production
# - (Opsional) jalankan migrasi via env LARAVEL_RUN_MIGRATIONS=true

APP_DIR="/var/www/html"
cd "$APP_DIR" || { echo "Gagal cd ke $APP_DIR" >&2; exit 1; }

# Helper: artisan wrapper aman
artisan() {
  if [[ -f artisan ]]; then
    php artisan "$@"
  else
    echo "Lewati artisan $* (file artisan tidak ditemukan)"
  fi
}

# Helper: echo step
step() { echo "[entrypoint] $*"; }

# Default envs
: "${APP_ENV:=production}"
: "${LARAVEL_WAIT_FOR_DB:=true}"
: "${LARAVEL_RUN_MIGRATIONS:=false}"
: "${LARAVEL_STORAGE_LINK:=true}"

step "Environment: APP_ENV=$APP_ENV"

# 1) Composer install jika vendor belum ada
if [[ -f composer.json ]] && [[ ! -f vendor/autoload.php ]]; then
  step "Menjalankan composer install (vendor belum ada)"
  mkdir -p vendor && chown -R www:www vendor || true
  if [[ "${APP_ENV}" == "production" ]]; then
    composer install --no-dev --prefer-dist --no-interaction --no-progress --optimize-autoloader || true
  else
    composer install --prefer-dist --no-interaction --no-progress || true
  fi
else
  step "Lewati composer install (vendor sudah ada atau composer.json tidak ada)"
fi

# 2) Siapkan .env
if [[ -f .env ]]; then
  step ".env sudah ada"
elif [[ -f .env.example ]]; then
  step "Membuat .env dari .env.example"
  cp .env.example .env || true
else
  step "Lewati pembuatan .env (tidak ada .env maupun .env.example)"
fi

# 2b) Sinkronkan pengaturan DB ke .env bila memungkinkan
set_env() {
  local key="$1"; shift
  local val="$1"; shift || true
  [[ -f .env ]] || return 0
  if grep -qE "^${key}=.*$" .env; then
    sed -i "s#^${key}=.*#${key}=${val}#" .env
  else
    echo "${key}=${val}" >> .env
  fi
}

if [[ -f .env ]]; then
  # Derive DB values from envs provided by compose
  DB_CONNECTION_DEFAULT="${DB_CONNECTION:-pgsql}"
  DB_HOST_DEFAULT="${DB_HOST:-db}"
  DB_PORT_DEFAULT="${DB_PORT:-5432}"
  DB_NAME_DEFAULT="${DB_DATABASE:-${POSTGRES_DB:-laravel}}"
  DB_USER_DEFAULT="${DB_USERNAME:-${POSTGRES_USER:-laravel}}"
  DB_PASS_DEFAULT="${DB_PASSWORD:-${POSTGRES_PASSWORD:-laravel}}"

  set_env DB_CONNECTION "$DB_CONNECTION_DEFAULT"
  set_env DB_HOST "$DB_HOST_DEFAULT"
  set_env DB_PORT "$DB_PORT_DEFAULT"
  set_env DB_DATABASE "$DB_NAME_DEFAULT"
  set_env DB_USERNAME "$DB_USER_DEFAULT"
  set_env DB_PASSWORD "$DB_PASS_DEFAULT"
  step "Sinkron DB config ke .env (connection=$DB_CONNECTION_DEFAULT host=$DB_HOST_DEFAULT)"
fi

# 3) Pastikan direktori writable
mkdir -p storage bootstrap/cache || true
chown -R www:www storage bootstrap/cache || true
chmod -R ug+rwX storage bootstrap/cache || true

# 4) Tunggu DB opsional
if [[ "${LARAVEL_WAIT_FOR_DB}" == "true" ]]; then
  DB_CONNECTION="${DB_CONNECTION:-}"
  DB_HOST="${DB_HOST:-}"
  DB_PORT="${DB_PORT:-}"
  DB_DATABASE="${DB_DATABASE:-}"
  DB_USERNAME="${DB_USERNAME:-}"
  DB_PASSWORD="${DB_PASSWORD:-}"

  if [[ -n "$DB_HOST" ]]; then
    step "Menunggu database siap di $DB_HOST:$DB_PORT ($DB_CONNECTION)"
    # Gunakan PHP PDO untuk cek koneksi agar minim dependensi
    php -d detect_unicode=0 -r '
      $c = getenv("DB_CONNECTION") ?: "";
      $h = getenv("DB_HOST") ?: "";
      $p = getenv("DB_PORT") ?: ($c === "mysql" ? 3306 : 5432);
      $d = getenv("DB_DATABASE") ?: "";
      $u = getenv("DB_USERNAME") ?: "";
      $w = getenv("DB_PASSWORD") ?: "";
      $max = 60; $i = 0;
      if (!$h) { fwrite(STDERR, "No DB_HOST set; skipping wait\n"); exit(0);} 
      while (true) {
        try {
          if ($c === "mysql") {
            $dsn = "mysql:host={$h};port={$p};dbname={$d}";
          } else {
            $dsn = "pgsql:host={$h};port={$p};dbname={$d}";
          }
          new PDO($dsn, $u, $w, [PDO::ATTR_TIMEOUT => 3]);
          break;
        } catch (Throwable $e) {
          if (++$i > $max) { fwrite(STDERR, "DB not ready after {$max} tries\n"); exit(1);} 
          usleep(500000);
        }
      }
    ' || { step "Database tidak siap dalam batas waktu"; exit 1; }
  else
    step "DB_HOST tidak diset — lewati tunggu DB"
  fi
else
  step "LARAVEL_WAIT_FOR_DB=false — lewati tunggu DB"
fi

# 5) APP_KEY
if [[ -f artisan ]]; then
  if ! grep -qE '^APP_KEY=.+$' .env 2>/dev/null; then
    step "Generate APP_KEY"
    artisan key:generate --force || true
  fi
fi

# 6) Storage link opsional
if [[ "${LARAVEL_STORAGE_LINK}" == "true" ]] && [[ -f artisan ]]; then
  if [[ ! -e public/storage ]]; then
    step "Membuat storage:link"
    artisan storage:link || true
  fi
fi

# 7) Cache/optimize tergantung APP_ENV
if [[ -f artisan ]]; then
  if [[ "$APP_ENV" == "production" ]]; then
    step "Optimizing caches (config, route, view)"
    artisan config:cache || true
    artisan route:cache || true
    artisan view:cache || true
  else
    step "Clearing caches (non-production)"
    artisan config:clear || true
    artisan route:clear || true
    artisan view:clear || true
  fi
fi

# 8) Migrasi opsional
if [[ "${LARAVEL_RUN_MIGRATIONS}" == "true" ]] && [[ -f artisan ]]; then
  step "Menjalankan migrasi --force"
  artisan migrate --force || true
fi

step "Bootstrap selesai; menjalankan proses utama: $*"
exec "$@"
