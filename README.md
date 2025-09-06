# Laravel Docker Template (Kaido-ready)

Template Docker Compose untuk menjalankan aplikasi Laravel (starterkit Kaido) dengan Caddy dan Postgres. Dirancang agar bisa dipakai berulang-ulang di banyak project dengan memisahkan konfigurasi proyek ke file env terpisah.

## Struktur Proyek
- `docker/` — assets container (php, nginx, entrypoint)
- `compose/` — komposisi modular:
  - `compose/base.yml` — base stack (Caddy + PHP-FPM + Postgres)
  - `compose/services/` — parts per layanan (nginx, mariadb, redis, mailpit, admin UI, worker, node)
  - `compose/all.profiles.yml` — agregator dengan `profiles` opsional (redis, mail, admin, worker, node)
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

Contoh overlay file-per-part (disarankan):
- Base + Redis + Mailpit:
  - `docker compose -f compose/base.yml -f compose/services/cache.redis.yml -f compose/services/mail.mailpit.yml up -d`
- Nginx + MariaDB + phpMyAdmin + Worker:
  - `docker compose -f compose/base.yml -f compose/services/web.nginx.yml -f compose/services/db.mariadb.yml -f compose/services/admin.phpmyadmin.yml -f compose/services/worker.queue.yml up -d`
- Tambah Node (sekali jalan build):
  - `docker compose -f compose/base.yml -f compose/services/node.dev.yml run --rm node npm run build`

Mode agregator dengan profiles (opsional):
- Aktifkan dengan menambahkan file `compose/all.profiles.yml` dan memilih profile:
  - `docker compose -f compose/base.yml -f compose/all.profiles.yml --profile redis --profile mail up -d`
- Atau gunakan env `COMPOSE_PROFILES`:
  - `COMPOSE_PROFILES=redis,mail docker compose -f compose/base.yml -f compose/all.profiles.yml up -d`

Catatan:
- Base default: `compose/base.yml`. File `docker-compose.yml` tetap ada sebagai kompatibilitas.
- File di `compose/services/` bersifat opsional dan dapat digabung sesuai kebutuhan.
- Script `run.sh` mendukung selector ergonomis via ENV: `WEB_IMPL=caddy|nginx`, `DB_IMPL=postgres|mariadb`, `WITH_PARTS=redis,mailpit,pgadmin,phpmyadmin,worker,node`.
- Untuk profiles agregator lewat `run.sh`, sertakan file agregator via `COMPOSE_FILES=compose/all.profiles.yml` dan pilih profile dengan `COMPOSE_PROFILES` saat memanggil `docker compose` langsung.

## Catatan
- Volume kode: `./site/${APP_DIR}:/var/www/html`
- Build context `app`: `./site/${APP_DIR}` memakai `docker/php/Dockerfile`
- Caddy melayani dokumen root `public/` dan meneruskan PHP ke `app:9000`. Alternatif Nginx tersedia via `compose/services/web.nginx.yml`.

## Troubleshooting Cepat
- Port 8080 dipakai: ubah mapping port di `docker-compose.yml`
- Migrasi gagal saat awal: jalankan `docker compose exec -T app php artisan migrate --force`
- Bersih total: `./run.sh --fresh`
