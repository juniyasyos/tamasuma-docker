# 10 — Struktur Direktori (Usulan) & Rencana Pemindahan

Struktur Target (ringkas):

```
docker/
  php/
    Dockerfile
    entrypoint.sh            # (opsional, shared)
  nginx/
    nginx.conf
    default.conf
  caddy/
    Caddyfile                # pindahkan dari root bila diinginkan (symlink/relocate)

compose/
  base.yml                   # layanan inti minimal (app, web default, db default)
  services/
    web.caddy.yml
    web.nginx.yml
    db.postgres.yml
    db.mariadb.yml
    cache.redis.yml
    mail.mailpit.yml
    admin.pgadmin.yml
    admin.phpmyadmin.yml
    worker.queue.yml
    node.dev.yml
  addons/
    observability.yml        # (opsional: loki/promtail/grafana, dsb.)

scripts/
  run.sh                     # tetap, update untuk merakit parts
  sync_repo.sh               # tetap (lokasi sekarang sudah ok)

site/
  <APP_DIR>

docs/
  ...
```

Catatan kompatibilitas:
- `docker-compose.yml` saat ini tetap bisa menjadi alias ke `compose/base.yml` (opsional symlink/redirect), atau dibiarkan sebagai base minimal. Target akhir adalah `compose/base.yml` sebagai sumber kebenaran.
- File `compose/*.yml` yang saat ini ada akan dipindahkan dan/atau dipecah ulang ke `compose/services/` dengan penamaan konsisten.

Rencana Pemindahan (mapping awal):
- `docker-compose.yml` → `compose/base.yml` (copy, lalu dokumentasi menyarankan pakai ini sebagai base)
- `compose/nginx.yml` → `compose/services/web.nginx.yml`
- `compose/mysql.yml` → `compose/services/db.mariadb.yml`
- `compose/redis.yml` → `compose/services/cache.redis.yml`
- `compose/mailpit.yml` → `compose/services/mail.mailpit.yml`
- `compose/pgadmin.yml` → `compose/services/admin.pgadmin.yml`
- `compose/phpmyadmin.yml` → `compose/services/admin.phpmyadmin.yml`
- `compose/worker.yml` → `compose/services/worker.queue.yml`
- `compose/node.yml` → `compose/services/node.dev.yml`
- `Caddyfile` (root) → opsional dipindah ke `docker/caddy/Caddyfile` (atau tetap di root lalu base.yml menyesuaikan path)

Konvensi Penamaan:
- `web.<impl>.yml` (caddy|nginx)
- `db.<engine>.yml` (postgres|mariadb)
- `cache.<type>.yml` (redis)
- `mail.<impl>.yml` (mailpit)
- `admin.<tool>.yml` (pgadmin|phpmyadmin)
- `worker.<role>.yml` (queue)
- `node.<mode>.yml` (dev)

Networks & Volumes:
- Gunakan network tunggal `app_net` agar services konsisten saling resolve: `networks: { app_net: { } }` pada semua parts.
- Gunakan volume dinamis bernamespace `STACK_NAME` atau nama default agar tidak tabrakan. Dokumentasikan di base.yml.

