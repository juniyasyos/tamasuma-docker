# 20 — Modularisasi Docker Compose (Parts)

Tujuan:
- Pecah layanan menjadi parts terpisah sehingga bisa dirakit sesuai skenario.
- Gunakan anchors (`x-`), profiles, dan network/volume yang konsisten.

Base
- `compose/base.yml`
  - Menentukan network `app_net` dan volumes umum (mis. `pg_data`, `vendor_data`, `caddy_*` bila tetap dipakai).
  - Memuat layanan inti minimal: `app`, `web` (default: Caddy), `db` (default: Postgres).
  - Menetapkan env subst `.stack.env` via tooling (run.sh) agar variabel konsisten.

Services (parts)
- Web:
  - `compose/services/web.caddy.yml` — Caddy reverse proxy → `app:9000`.
  - `compose/services/web.nginx.yml` — Nginx → `app:9000` dengan `docker/nginx/*`.
- Database:
  - `compose/services/db.postgres.yml` — Postgres 16 + healthcheck, volume `pg_data`.
  - `compose/services/db.mariadb.yml` — MariaDB 10.11 + healthcheck, volume `mysql_data`.
- Cache/Queue:
  - `compose/services/cache.redis.yml` — Redis AOF + volume `redis_data`.
  - `compose/services/worker.queue.yml` — Laravel queue + scheduler.
- Mail & Admin UI:
  - `compose/services/mail.mailpit.yml` — Mailpit (SMTP + web UI).
  - `compose/services/admin.pgadmin.yml` — pgAdmin 4.
  - `compose/services/admin.phpmyadmin.yml` — phpMyAdmin.
- Frontend/Node:
  - `compose/services/node.dev.yml` — Container Node untuk build/asset pipeline.

Pola Reuse
- Network tunggal: semua services join ke `app_net`.
- Volumes:
  - `vendor_data` (untuk vendor composer di container) tetap dipakai agar tidak polusi bind mount.
  - `pg_data`, `mysql_data`, `redis_data`, `caddy_data`, `caddy_config` sesuai part yang dipakai.
- Anchors (`x-`):
  - `x-app-volume-bind`: definisikan sekali bind `./site/${APP_DIR}:/var/www/html` agar dipakai ulang.
  - `x-common-env`: environment yang sering dibagi (opsional, jangan bocorkan rahasia).

Profiles (opsional):
- Tandai part tertentu dengan `profiles: [dev]` atau `profiles: [admin]` sehingga komposisi default ringkas.

Contoh Perakitan
- Base Caddy + Postgres:
  - `docker compose -f compose/base.yml up -d`
- Base + Redis + Mailpit:
  - `docker compose -f compose/base.yml -f compose/services/cache.redis.yml -f compose/services/mail.mailpit.yml up -d`
- Nginx + MariaDB + phpMyAdmin + Worker:
  - `docker compose -f compose/base.yml -f compose/services/web.nginx.yml -f compose/services/db.mariadb.yml -f compose/services/admin.phpmyadmin.yml -f compose/services/worker.queue.yml up -d`
- Tambah Node untuk build asset:
  - `docker compose -f compose/base.yml -f compose/services/node.dev.yml run --rm node npm run build`

Kontrak Antar Parts
- `app` service harus ada (dari base) dengan nama konsisten — parts lain berasumsi `app:9000` endpoint PHP-FPM.
- `web` dapat di-override dengan parts lain (Caddy vs Nginx) — gunakan alias nama service yang sama atau gunakan profile.
- `db` dapat di-override (postgres vs mariadb) — JANGAN gabungkan dua DB sekaligus.

Langkah Implementasi (nanti):
1) Salin isi `docker-compose.yml` ke `compose/base.yml` (penyesuaian minor untuk network/volumes).
2) Pindahkan setiap file di `compose/*.yml` ke `compose/services/*.yml` dengan rename sesuai konvensi.
3) Pastikan semua service join `app_net` dan tidak mendefinisikan network baru tanpa perlu.
4) Uji kombinasi per contoh di atas.

