# Panduan Deployment Endpoint Dokumentasi (/docs)
## ASSA Middleware — Server Dev (`https://devmiddleware1.assa.id/docs`)

Panduan ini menjelaskan konfigurasi dan alur deployment untuk endpoint dokumentasi API yang diakses melalui URL:
👉 **`https://devmiddleware1.assa.id/docs`** (atau `http://devmiddleware1.assa.id:6031/docs`)

---

## 1. Mengapa Sebelumnya Terjadi "Page Can't Be Found" (404)?

1. **WSO2 MI Backend Bukan Web Server File Statis**:
   Di [`Dockerfile`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo/Dockerfile#L28), berkas dokumentasi disalin ke dalam image di path `/app/docs`. Namun, port 8290 di WSO2 MI hanya melayani endpoint integrasi Synapse/Carbon (seperti `/api/branches/`, `/health`, dll.), bukan server HTTP untuk file statis `.html` dan `.yaml`.
2. **Missing Location Block di Nginx**:
   Di `folder-server/nginx.conf`, belum ada blok konfigurasi `location /docs`. Akibatnya, request ke `/docs` dialihkan ke fallback root (`proxy_pass http://middleware_backend/`) menuju WSO2 MI port 8290, sehingga server mengembalikan respons *"Page can't be found"*.
3. **Missing Mount / Volume di Docker Compose**:
   Pada `folder-server/docker-compose.yml`, berkas atau volume dokumentasi belum dimount ke Nginx, dan belum ada init container `doc-init` yang mengekstrak `/app/docs` dari image kontainer WSO2.

---

## 2. Solusi & Perubahan yang Dilakukan di `folder-server/`

Semua berkas konfigurasi di folder [`folder-server/`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/folder-server) sudah disiapkan agar Anda **cukup drag & drop file konfigurasinya saja**:

| Berkas | Perubahan yang Dilakukan |
|---|---|
| [`nginx.conf`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/folder-server/nginx.conf) | Menambahkan `absolute_redirect off;` dan blok routing `location ^~ /docs/` (alias ke `/usr/share/nginx/html/docs/`), redirect `location = /docs`, redirect `location ^~ /doc`, serta header CORS (`Access-Control-Allow-*`). |
| [`docker-compose.yml`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/folder-server/docker-compose.yml) | 1. Menambahkan init container `doc-init` yang otomatis mengekstrak berkas `/app/docs/*` dari image kontainer WSO2 ke volume `doc_data`.<br>2. Menambahkan volume mount `doc_data:/usr/share/nginx/html/docs:ro` pada service `nginx`.<br>3. Mendaftarkan volume `doc_data`. |
| [`.env.example`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/folder-server/.env.example) | Template environment variable lengkap untuk server dev. |

> [!NOTE]
> **Tidak perlu copy folder `docs/` ke server!**
> Karena saat Anda mem-build image di `wso2-mi-monorepo`, folder `docs/` sudah ada di dalam image kontainer WSO2. Saat `docker compose up -d` dijalankan di server, container `doc-init` akan secara otomatis mengekstrak dokumen tersebut langsung dari image ke volume Nginx.

---

## 3. Cara Penggunaan / Deployment ke Server

Anda cukup drag and drop file konfigurasi di folder `folder-server/` ke server (misal: `/var/www/devmiddleware/`):

### File yang Di-upload ke Server:
- `docker-compose.yml`
- `nginx.conf`
- `.env` (disalin dari `.env.example` dan diisi kredensial)

### Perintah di Server (`/var/www/devmiddleware/`):
```bash
cd /var/www/devmiddleware

# Login registry jika image bersifat private
docker login registry.assa.id

# Pull image terbaru yang baru Anda build & push dari wso2-mi-monorepo
docker compose pull

# Jalankan semua service
docker compose up -d
```

### Verifikasi:
Buka di browser:
👉 **`https://devmiddleware1.assa.id/docs`**

---

## 4. Struktur Endpoint yang Tersedia

- **Swagger UI Interactive Dashboard**:
  `https://devmiddleware1.assa.id/docs`
- **Metadata Manifest Service (JSON)**:
  `https://devmiddleware1.assa.id/docs/openapi/services.json`
- **Spesifikasi OpenAPI 3.0 YAML per Service**:
  - `https://devmiddleware1.assa.id/docs/openapi/branch-service.yaml`
  - `https://devmiddleware1.assa.id/docs/openapi/customer-service.yaml`
  - `https://devmiddleware1.assa.id/docs/openapi/vehicle-service.yaml`
  - `https://devmiddleware1.assa.id/docs/openapi/vendor-service.yaml`
  - `https://devmiddleware1.assa.id/docs/openapi/spk-service.yaml`
  - `https://devmiddleware1.assa.id/docs/openapi/service-request-service.yaml`
