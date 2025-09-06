# Troubleshooting

Berikut masalah umum dan solusinya.

- Port 8080 sudah dipakai
  - Ubah `WEB_HTTP_PORT` di `.stack.env` (mis. 8081), lalu `./run.sh --rebuild` atau `docker compose up -d`.

- Tidak bisa clone repo backend
  - Pastikan `APP_REPO` valid (URL penuh atau `owner/repo`). Jika pakai private repo, gunakan `APP_REPO_SSH=true` dan pastikan SSH key siap.

- Migrasi gagal saat pertama kali
  - Jalankan manual: `docker compose --env-file .stack.env exec -T app php artisan migrate --force`
  - Cek kredensial `.env.docker` dan koneksi DB.

- APP_KEY hilang atau error enkripsi
  - `docker compose --env-file .stack.env exec -T app php artisan key:generate --force`

- Permission error pada storage
  - `docker compose --env-file .stack.env exec -T app bash -lc 'chmod -R ug+rwX storage bootstrap/cache'`

- Ingin bersih total (reset DB)
  - `./run.sh --fresh`

- Variabel `.stack.env` tidak terbaca saat jalankan `docker compose` manual
  - Sertakan `--env-file .stack.env` pada setiap perintah Compose manual, atau gunakan `COMPOSE_PROJECT_NAME` yang konsisten.

