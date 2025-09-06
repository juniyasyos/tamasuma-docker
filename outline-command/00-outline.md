# 00 — Outline Besar

Tujuan:
- Menyusun ulang struktur repo agar jelas pemisahan concerns: docker assets, compose parts, scripts, docs, dan source app.
- Memecah Docker Compose menjadi potongan kecil yang dapat dikombinasikan sesuai kebutuhan (reusable + scalable).
- Menyederhanakan bootstrap (run.sh) agar bisa memilih parts dengan flag/env.

Deliverables (tahap awal):
- Struktur direktori baru yang konsisten (tanpa memutus kompatibilitas bila memungkinkan).
- Katalog file compose parts dengan naming konvensi yang jelas.
- Dokumentasi cara merakit stack dari parts.

Fase Pekerjaan:
1) Audit & Target Struktur
   - Inventaris file Docker, Compose, scripts, dan env.
   - Tetapkan struktur target dan naming scheme.

2) Refactor Struktur Direktori
   - Konsolidasi docker assets (php/nginx/caddy/entrypoint) dan template config.
   - Rapikan `compose/` menjadi hierarki `base/`, `services/`, `addons/`.

3) Modularisasi Docker Compose
   - Buat parts granular per concern (web server, DB varian, cache, mail, admin UI, worker, node).
   - Tambah anchors (`x-`), profiles, dan networks yang konsisten untuk reuse.

4) Update Tooling/Script
   - Adaptasi `run.sh` untuk merakit parts via env/flag (tanpa memaksa 1 layout saja).
   - Tambah preset kombinasi umum.

5) Validasi & Dokumentasi
   - Uji kombinasi umum (Caddy+Postgres, Nginx+MariaDB, +Redis, +Mailpit, +Worker, +Node).
   - Perbarui README dan cheat-sheet commands.

Kriteria Selesai (iterasi 1):
- Tersedia minimal: base.yml + web.{caddy|nginx}.yml + db.{postgres|mariadb}.yml + cache.redis.yml + mail.mailpit.yml + admin.{pgadmin|phpmyadmin}.yml + worker.queue.yml + node.dev.yml.
- Semua parts dapat dirakit dengan 1–2 perintah compose tanpa konflik nama network/volume.
- Dokumen contoh kombinasi tersedia.

