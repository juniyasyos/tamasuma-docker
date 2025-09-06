# Multi-Project (Menjalankan Banyak Project Sekaligus)

Template ini mendukung menjalankan banyak project Laravel secara paralel di mesin yang sama.

## Opsi A — Satu Folder per Project (Paling Sederhana)

1) Duplikasi repo template ini ke folder berbeda, misalnya:
   - `~/projects/projA-docker`
   - `~/projects/projB-docker`
2) Di masing-masing folder:
   - `cp .stack.env.example .stack.env`
   - Isi variabel unik: `STACK_NAME`, `WEB_HTTP_PORT`, `DB_PORT`, `APP_REPO`, `APP_DIR`
3) Jalankan `./run.sh` pada masing-masing folder.

Keuntungan: isolasi alami karena root path berbeda.

## Opsi B — Satu Repo, Banyak File Env

1) Buat beberapa file env di root:
   - `.stack.projA.env`
   - `.stack.projB.env`
2) Jalankan per project seperti ini:

```
STACK_ENV_FILE=.stack.projA.env COMPOSE_PROJECT_NAME=projA ./run.sh
STACK_ENV_FILE=.stack.projB.env COMPOSE_PROJECT_NAME=projB ./run.sh
```

Catatan:
- Pastikan `STACK_NAME`, `WEB_HTTP_PORT`, dan `DB_PORT` berbeda untuk tiap project.
- `COMPOSE_PROJECT_NAME` membantu namespacing network/volume untuk mencegah bentrok.

## Kenapa Tidak Bentrok

- `container_name`: diprefix oleh `${STACK_NAME}` → `myapp-web|app|db|node`.
- Port host: dikonfigurasi via `WEB_HTTP_PORT` dan `DB_PORT`.
- Network/Volume: dipisah dengan `COMPOSE_PROJECT_NAME` atau path root berbeda.

