# Panduan Deployment Endpoint Dokumentasi (/docs)
## ASSA Middleware — Server Dev (`https://devmiddleware1.assa.id/docs`)

Panduan ini menjelaskan konfigurasi dan alur deployment untuk endpoint dokumentasi API yang diakses melalui URL:
👉 **`https://devmiddleware1.assa.id/docs`** (atau `http://devmiddleware1.assa.id:6031/docs`)

---

## 1. Ringkasan Perubahan di `folder-server/`

Tiga file utama pada folder [`folder-server/`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/folder-server) telah dikonfigurasi:

| Berkas | Perubahan yang Dilakukan |
|---|---|
| [`nginx.conf`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/folder-server/nginx.conf) | Menambahkan location block `location ^~ /doc`, `location ^~ /doc/openapi/`, serta redirect dari `/docs` ke `/doc`. Dilengkapi header CORS agar spec dapat di-fetch oleh frontend. |
| [`docker-compose.yml`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/folder-server/docker-compose.yml) | Menambahkan volume mount: `- ./doc:/usr/share/nginx/html/doc:ro` pada service `nginx` agar file dokumentasi langsung tersinkronisasi. |
| [`Dockerfile.nginx`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/folder-server/Dockerfile.nginx) | Menambahkan instruksi `COPY doc /usr/share/nginx/html/doc` sehingga saat image Nginx di-build dan di-push ke GitLab Container Registry, file dokumentasi sudah terkemas mandiri (*self-contained*). |
| [`doc/`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/folder-server/doc) | Direktori dokumen publik berisi `index.html` (interaktif preview per microservice) dan folder `openapi/` berisi 6 berkas YAML spesifikasi serta `services.json`. |

---

## 2. Struktur Direktori `doc/`

```text
folder-server/doc/
├── index.html                 # Halaman viewer interaktif awal (dengan tombol switcher 6 service)
└── openapi/
    ├── services.json          # Manifest metadata service untuk dibaca oleh frontend TypeScript
    ├── branch-service.yaml    # Kontrak Branch Service (:8290)
    ├── customer-service.yaml  # Kontrak Customer Service (:8291)
    ├── vehicle-service.yaml   # Kontrak Vehicle Service (:8292)
    ├── vendor-service.yaml    # Kontrak Vendor Service (:8293)
    ├── spk-service.yaml       # Kontrak SPK Service (:8294)
    └── service-request-service.yaml # Kontrak Service Request & Worker (:8295)
```

---

## 3. Integrasi UI Swagger TypeScript (Untuk Anda)

Sesuai rencana Anda untuk membuat UI Swagger kustom menggunakan **TypeScript**:
1. **Endpoint API Manifest**:
   Aplikasi dapat memanggil HTTP GET ke:
   ```text
   GET /docs/openapi/services.json
   ```
   Data JSON tersebut akan mengembalikan daftar 6 service lengkap dengan nama, port, dan path file `.yaml`-nya.
2. **Endpoint File Spesifikasi OpenAPI**:
   Dapat langsung mem-fetch file YAML masing-masing service di:
   - `/docs/openapi/branch-service.yaml`
   - `/docs/openapi/customer-service.yaml`
   - `/docs/openapi/vehicle-service.yaml`
   - `/docs/openapi/vendor-service.yaml`
   - `/docs/openapi/spk-service.yaml`
   - `/docs/openapi/service-request-service.yaml`
3. **Penyatuan Hasil Build**:
   Setelah project TypeScript Anda di-build (misal menggunakan Vite/Next/React `npm run build`), salin seluruh file hasil build (`index.html`, folder `assets/`, dll.) ke dalam folder [`folder-server/doc/`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/folder-server/doc).
   *(Pastikan subfolder `doc/openapi/` tetap dipertahankan).*

---

## 4. Alur Build & Push ke GitLab Container Registry

Jika tim Anda ingin men-deploy Nginx custom ini via GitLab Container Registry:

### Langkah A — Build Image Nginx Lokal
```bash
cd middleware-assa/folder-server

# Login ke registry ASSA
docker login registry.assa.id

# Build image Nginx dengan tag registry (contoh versi 1.0.0)
docker build -f Dockerfile.nginx -t registry.assa.id/nobi.sumariga/middleware-assa:nginx-1.0.0 .

# Push image ke GitLab Container Registry
docker push registry.assa.id/nobi.sumariga/middleware-assa:nginx-1.0.0
```

### Langkah B — Jalankan di Server Dev ASSA
Di server target `/var/www/devmiddleware/`:
1. Pastikan file `docker-compose.yml`, `nginx.conf`, dan folder `doc/` ter-upload (atau gunakan image `registry.assa.id/...:nginx-1.0.0`).
2. Jalankan perintah:
   ```bash
   docker compose pull
   docker compose up -d
   ```
3. Akses via browser:
   👉 **`https://devmiddleware1.assa.id/docs`**
