# Laravel Docker Template (Kaido-ready)

Template Docker Compose untuk menjalankan aplikasi Laravel (starterkit Kaido) dengan Caddy dan Postgres. Dirancang agar bisa dipakai berulang-ulang di banyak project dengan memisahkan konfigurasi proyek ke file env terpisah.

## Struktur Proyek
- `docker/` — assets container (php, nginx, entrypoint)
- `compose/` — pecahan optional Docker Compose (redis, mailpit, pgadmin, mysql, nginx, node)
- `site/` — sumber kode backend hasil clone (sesuai `.stack.env`)
- `scripts/` — utilitas (sinkronisasi repo, dsb.)
- `docs/` — dokumentasi
- `Caddyfile`, `docker-compose.yml`, `run.sh`, `.stack.env*`, `.env.docker*`

## Prasyarat
- Docker Engine + `docker compose`
- Git

## Sekali Jalan (Disarankan)
1) Salin dan sesuaikan konfigurasi template:

```
cp .stack.env.example .stack.env
# Edit .stack.env → set APP_REPO, APP_REPO_BRANCH, APP_DIR, WEB_HTTP_PORT, dll
```

2) Jalankan script berikut dari root repo:

```
./run.sh
```

Apa yang dilakukan:
- Clone/update backend ke `./site/$APP_DIR` sesuai `.stack.env`
- Membuat `.env.docker` jika belum ada (pakai default aman)
- Menjalankan `docker compose up -d` dan inisialisasi Laravel (key, migrate, storage link)

Opsi:
- `./run.sh --rebuild` : rebuild image sebelum up
- `./run.sh --fresh`   : hapus volumes (data DB) lalu up ulang

Aplikasi akan tersedia di: http://localhost:${WEB_HTTP_PORT}

## Struktur Layanan (Base)
- `web` (Caddy) — reverse proxy + static, port `8080`
- `app` (PHP-FPM) — menjalankan Laravel
- `db` (Postgres 16) — database

Layanan opsional tersedia sebagai pecahan di folder `compose/` (lihat di bawah).

## Konfigurasi
- `.stack.env` (per-project):
  - `STACK_NAME`: prefix container (opsional)
  - `WEB_HTTP_PORT`: port publik HTTP (default 8080)
  - `APP_REPO`: URL atau `owner/repo` Kaido starterkit kamu
  - `APP_REPO_BRANCH`: branch yang digunakan
  - `APP_REPO_SSH`: `true|false` pakai SSH
  - `APP_DIR`: nama folder di `./site`
- `.env.docker` (per-project, untuk kontainer DB):
  - `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`
  - Mirror opsional: `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`
  - Contoh: lihat `.env.docker.example`

## Perintah Umum
- Start: `docker compose up -d`
- Stop: `docker compose down`
- Logs: `docker compose logs -f`
- Masuk app: `docker compose exec app bash`

## Compose Pecahan (Optional Services)
Tambahkan layanan opsional dengan menggabungkan file di `compose/`.

Contoh:
- Tambah Redis: `docker compose -f docker-compose.yml -f compose/redis.yml up -d`
- Tambah Mailpit: `docker compose -f docker-compose.yml -f compose/mailpit.yml up -d`
- Tambah pgAdmin: `docker compose -f docker-compose.yml -f compose/pgadmin.yml up -d`
- Ganti DB ke MariaDB/MySQL: `docker compose -f docker-compose.yml -f compose/mysql.yml up -d`
- Ganti webserver ke Nginx: `docker compose -f docker-compose.yml -f compose/nginx.yml up -d`
- Tambah container Node (untuk dev): `docker compose -f docker-compose.yml -f compose/node.yml run --rm node npm run build`

Catatan:
- File `docker-compose.yml` adalah base minimal (web+app+db Postgres).
- File di `compose/` bersifat opsional dan dapat digabung sesuai kebutuhan.
- Script `run.sh` tetap bekerja dengan base, dan akan otomatis melewati langkah Node bila service `node` tidak diikutkan.

## Catatan
- Volume kode: `./site/${APP_DIR}:/var/www/html`
- Build context `app`: `./site/${APP_DIR}` memakai `docker/php/Dockerfile`
- Caddy melayani dokumen root `public/` dan meneruskan PHP ke `app:9000`. Alternatif Nginx tersedia via `compose/nginx.yml`.

## Troubleshooting Cepat
- Port 8080 dipakai: ubah mapping port di `docker-compose.yml`
- Migrasi gagal saat awal: jalankan `docker compose exec -T app php artisan migrate --force`
- Bersih total: `./run.sh --fresh`
