# Panduan Deployment Endpoint Dokumentasi & WSO2 Middleware
## ASSA Middleware — Server Dev (`https://devmiddleware.assa.id`)

Panduan ini menjelaskan konfigurasi dan alur deployment untuk endpoint dokumentasi API dan layanan WSO2:
- 👉 **Dokumentasi Swagger UI**: `https://devmiddleware.assa.id/docs` (atau `http://devmiddleware.assa.id:6030/docs`)
- 👉 **Layanan Backend WSO2 MI**: `https://devmiddleware.assa.id/api/*`
- ℹ️ **WSO2 API Manager (APIM 4.3.0 GUI)**: *Untuk sementara dikomentari / di-hashtag (`#`) agar resource server ringan, namun sudah siap diaktifkan kapan saja.*

---

## 1. Arsitektur Layanan di Server

Dalam stack Docker Compose, terdapat komponen utama:
1. **WSO2 MI (Micro Integrator) (`middleware-wso2-api`)**:
   Backend runtime integrasi berkecepatan tinggi yang mengeksekusi sequence Synapse, transformasi payload, dan koneksi ke database / SAP / Atlas.
2. **MariaDB (`mariadb`)**:
   Database internal untuk idempotency tracking, dead letter queue, dan metadata storage.
3. **Nginx Reverse Proxy (`nginx`)**:
   Single entrypoint port 80/443 yang merutekan request ke WSO2 MI (`/api/*`, `/health`) dan Swagger docs (`/docs/*`).
4. **WSO2 API Manager 4.3.0 (`api-manager`) [SEMENTARA DI-HASHTAG / COMMENT OUT]**:
   GUI Web Portal (Publisher & DevPortal). Konfigurasinya sudah tersedia lengkap di `docker-compose.yml` dan `nginx.conf` dalam status dikomentari (`#`) dan dapat diaktifkan kembali sewaktu-waktu.

---

## 2. Berkas Konfigurasi di `notes/folder-server/`

Semua berkas konfigurasi di folder `notes/folder-server/` sudah disiapkan agar Anda **cukup drag & drop file konfigurasinya saja ke server**:

| Berkas | Deskripsi & Perubahan |
|---|---|
| [`nginx.conf`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/notes/folder-server/nginx.conf) | 1. `server_name devmiddleware.assa.id localhost _;`<br>2. Endpoint `/docs/` dengan CORS dan auto-redirect.<br>3. Blok APIM (`/publisher`, `/devportal`, dll.) sementara di-hashtag (`#`). |
| [`docker-compose.yml`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/notes/folder-server/docker-compose.yml) | 1. Init container `doc-init` yang otomatis mengekstrak file Swagger dari image WSO2 ke volume Nginx.<br>2. Service `api-manager` sementara di-hashtag (`#`) agar stack lebih ringan. |
| [`.env`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/notes/folder-server/.env) & [`.env.example`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/notes/folder-server/.env.example) | Konfigurasi runtime server dev, kredensial MariaDB, API keys, dan variabel APIM (di-hashtag). |

---

## 3. Cara Penggunaan / Deployment ke Server

Anda cukup drag and drop file konfigurasi di folder `folder-server/` ke folder kerja server (misal: `/var/www/devmiddleware/`):

### File yang Di-upload ke Server:
- `docker-compose.yml`
- `nginx.conf`
- `.env` (disalin dari `.env.example` dan diisi kredensial)

### Perintah di Server (`/var/www/devmiddleware/`):
```bash
cd /var/www/devmiddleware

# Login registry jika image bersifat private
docker login registry.assa.id

# Pull image terbaru
docker compose pull

# Jalankan semua service
docker compose up -d
```

### Verifikasi Health & Status:
```bash
docker compose ps
docker compose logs -f nginx
```

---

## 4. Struktur Endpoint yang Tersedia

### A. Swagger UI & OpenAPI Specification (Aktif)
- **Swagger UI Interactive Dashboard**:
  `https://devmiddleware.assa.id/docs`
- **Metadata Manifest Service (JSON)**:
  `https://devmiddleware.assa.id/docs/openapi/services.json`
- **Spesifikasi OpenAPI 3.0 YAML per Service**:
  - `https://devmiddleware.assa.id/docs/openapi/branch-service.yaml`
  - `https://devmiddleware.assa.id/docs/openapi/customer-service.yaml`
  - `https://devmiddleware.assa.id/docs/openapi/vehicle-service.yaml`
  - `https://devmiddleware.assa.id/docs/openapi/vendor-service.yaml`
  - `https://devmiddleware.assa.id/docs/openapi/spk-service.yaml`
  - `https://devmiddleware.assa.id/docs/openapi/service-request-service.yaml`

### B. Portal GUI WSO2 API Manager (Opsional — Saat Ini Di-hashtag / Nonaktif)
> *Status saat ini:* Dikomentari (`#`) di `docker-compose.yml` dan `nginx.conf` agar server ringan. Jika ingin mengaktifkan kembali, cukup hapus tanda `#` pada service `api-manager` di `docker-compose.yml` dan blok upstream & location APIM di `nginx.conf`, lalu jalankan `docker compose up -d`.

- **Publisher Portal** (Desain API GUI & Publish):
  👉 `https://devmiddleware.assa.id/publisher` *(Login default: `admin` / `admin`)*
- **Developer Portal** (Katalog API untuk Client / Pengembang):
  👉 `https://devmiddleware.assa.id/devportal`
- **Admin Portal** (Konfigurasi Throttling Tier & Key Manager):
  👉 `https://devmiddleware.assa.id/admin`

*(Untuk panduan lengkap langkah demi langkah pembuatan API via GUI, lihat dokumen: [PANDUAN_LOWCODE_APIM_GUI.md](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/notes/PANDUAN_LOWCODE_APIM_GUI.md))*
