# Perintah Harian

## Script Orkestrasi

- `./run.sh` — jalankan stack, clone/update repo backend, dan bootstrap Laravel.
  - Opsi:
    - `--rebuild` — rebuild image sebelum up
    - `--fresh` — down -v (hapus data DB) lalu up
  - Env berguna:
    - `STACK_ENV_FILE=.stack.env` — pilih file env stack
    - `COMPOSE_PROJECT_NAME=xxx` — namespace network/volume Compose

## Docker Compose

- Start: `docker compose up -d`
- Stop: `docker compose down`
- Logs: `docker compose logs -f`
- Masuk shell app: `docker compose exec app bash`
- Jalankan artisan: `docker compose exec -T app php artisan <command>`

Tips: bila memakai banyak file env, sertakan `--env-file .stack.env` saat menjalankan perintah Compose manual:

```
docker compose --env-file .stack.env up -d
docker compose --env-file .stack.env exec -T app php artisan migrate --force
```

## Node/NPM (opsional)

`run.sh` akan menjalankan `npm ci && npm run build` via service `node` bila `NODE_BUILD=true` (default). Nonaktifkan dengan:

```
NODE_BUILD=false ./run.sh
```

