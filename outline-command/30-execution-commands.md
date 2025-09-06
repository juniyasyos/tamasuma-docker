# 30 — Eksekusi & Preset Commands

Preset Umum
- Dev standar (Caddy + Postgres):
  - `docker compose -f compose/base.yml up -d`
- + Redis + Mailpit:
  - `docker compose -f compose/base.yml -f compose/services/cache.redis.yml -f compose/services/mail.mailpit.yml up -d`
- Nginx + MariaDB + phpMyAdmin + Worker:
  - `docker compose -f compose/base.yml -f compose/services/web.nginx.yml -f compose/services/db.mariadb.yml -f compose/services/admin.phpmyadmin.yml -f compose/services/worker.queue.yml up -d`
- Tambah Node (sekali jalan build):
  - `docker compose -f compose/base.yml -f compose/services/node.dev.yml run --rm node npm ci && npm run build`

Workflow `run.sh` (rencana penyesuaian):
- Tambah ENV preset, mis.: `STACK_PRESET=dev_caddy_pg_redis_mail` yang akan dirangkai menjadi daftar `-f` secara otomatis.
- Atau opsi CLI: `./run.sh --with redis,mailpit --web nginx --db mariadb` agar skrip merakit parts.

Perintah Validasi Cepat
- Cek services aktif: `docker compose ls && docker compose ps`
- Logs satu service: `docker compose logs -f app` (atau `web`, `db`, `redis`)
- Healthcheck DB: `docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' $(docker compose ps -q db)`
- Exec ke container: `docker compose exec app bash`

Cleanup
- Hentikan: `docker compose down`
- Fresh (hapus volumes): `docker compose down -v`

