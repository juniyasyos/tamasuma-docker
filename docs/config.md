# Konfigurasi

Template ini memisahkan konfigurasi ke dua file utama:

1) `.stack.env` (template/stack level, per project)
2) `.env.docker` (variabel environment untuk container, khususnya DB)

## .stack.env

Contoh lengkap ada di `.stack.env.example`. Variabel yang didukung:

- `STACK_NAME`: Prefix untuk `container_name` agar tidak bentrok antar project. Contoh: `tamasuma`, `kaidoapp`.
- `WEB_HTTP_PORT`: Port host untuk HTTP Caddy. Default `8080`.
- `APP_REPO`: URL Git penuh atau `owner/repo`. Contoh: `juniyasyos/tamasuma-backend`.
- `APP_REPO_BRANCH`: Branch yang di-checkout. Contoh: `development`.
- `APP_REPO_SSH`: `true|false` gunakan SSH remote.
- `APP_DIR`: Nama folder target di `./site` tempat repo backend disimpan.
- (opsional) `SERVICE_APP`, `SERVICE_WEB`, `SERVICE_DB`, `SERVICE_NODE`: nama service Compose (default: `app`, `web`, `db`, `node`).
- (opsional) `DB_PORT`: Port host untuk Postgres (container selalu 5432). Default `5432`.
  (Catatan: jika `COMPOSE_PROJECT_NAME` tidak diset, `run.sh` akan menset default ke `STACK_NAME` untuk namespacing volume/network.)

File ini akan di-load otomatis oleh `run.sh` dan juga diberikan ke Compose via `--env-file` supaya substitusi variabel di `docker-compose.yml` berjalan.

## .env.docker

Digunakan oleh service `db` (Postgres) dan sebagai sumber mirror untuk `.env` Laravel saat bootstrap.

Variabel penting:
- `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`: kredensial Postgres dalam container DB.
- Mirror opsional: `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD` (dipakai oleh beberapa tooling & disinkronkan ke `.env` aplikasi pada saat bootstrap).

Contoh lengkap: lihat `.env.docker.example`.

## Substitusi Variabel di docker-compose.yml

`docker-compose.yml` menggunakan variabel berikut:
- `${STACK_NAME}`: prefix `container_name`.
- `${APP_DIR}`: nama folder backend di `./site` untuk volume dan build context.
- `${WEB_HTTP_PORT}`: pemetaan port host untuk HTTP Caddy.
- `${DB_PORT}`: pemetaan port host untuk Postgres.

## Override Lanjutan

- Jalankan dengan file env berbeda tanpa menyalin/rename:
  - `STACK_ENV_FILE=.stack.projA.env ./run.sh`
- Namespacing Compose project (network/volume) secara eksplisit:
  - `COMPOSE_PROJECT_NAME=projA ./run.sh`

## Compose Pecahan (Optional)

Layanan tambahan tersedia sebagai file di `compose/` dan dapat digabungkan dengan base `docker-compose.yml`.
Contoh: `docker compose -f docker-compose.yml -f compose/redis.yml up -d`.
