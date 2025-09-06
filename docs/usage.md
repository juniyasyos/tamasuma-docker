# Penggunaan Cepat

Ikuti langkah berikut untuk menjalankan 1 project Laravel (starterkit Kaido) dengan stack ini.

1) Salin file konfigurasi stack dan sesuaikan

```
cp .stack.env.example .stack.env
# Edit .stack.env → set APP_REPO, APP_REPO_BRANCH, APP_DIR, WEB_HTTP_PORT, STACK_NAME
```

Variabel penting di `.stack.env`:
- `APP_REPO`: URL Git atau `owner/repo` (contoh: `juniyasyos/tamasuma-backend`)
- `APP_REPO_BRANCH`: branch yang ingin digunakan (contoh: `development`)
- `APP_DIR`: nama folder target di `./site` (contoh: `tamasuma-backend`)
- `WEB_HTTP_PORT`: port publik HTTP (default `8080`)
 - `STACK_NAME`: prefix nama container (hindari bentrok antar project)

2) Siapkan variabel database untuk container Postgres

```
cp .env.docker.example .env.docker
# Ubah POSTGRES_DB/USER/PASSWORD bila perlu
```

3) Jalankan stack

```
./run.sh
```

Yang dilakukan otomatis:
- Clone/update repo backend ke `./site/$APP_DIR`
- Menjalankan container `web` (Caddy), `app` (PHP-FPM), `db` (Postgres)
- Inisialisasi Laravel: install vendor (bila perlu), generate `APP_KEY`, migrasi DB, `storage:link`

4) Akses aplikasi

```
http://localhost:${WEB_HTTP_PORT}
```

5) Opsi umum

- Rebuild image: `./run.sh --rebuild`
- Fresh restart (hapus data DB): `./run.sh --fresh`

---
# Layanan Opsional (Compose Pecahan)

Stack base bersifat minimal. Layanan tambahan tersedia di folder `compose/` dan dapat digabung sesuai kebutuhan.

Contoh umum:
- Redis: `docker compose -f docker-compose.yml -f compose/redis.yml up -d`
- Mailpit: `docker compose -f docker-compose.yml -f compose/mailpit.yml up -d`
- pgAdmin: `docker compose -f docker-compose.yml -f compose/pgadmin.yml up -d`
- MariaDB/MySQL sebagai pengganti Postgres: `docker compose -f docker-compose.yml -f compose/mysql.yml up -d`
- Nginx sebagai pengganti Caddy: `docker compose -f docker-compose.yml -f compose/nginx.yml up -d`
- Node container (dev): `docker compose -f docker-compose.yml -f compose/node.yml run --rm node npm run build`

Catatan:
- `run.sh` akan tetap berfungsi dengan base; bagian Node akan dilewati jika service `node` tidak disertakan.
