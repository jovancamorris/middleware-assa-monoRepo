# Guide — Deploy ke Server Dev (Docker + Nginx + Container Registry)
## WSO2 MI Monorepo — ASSA Middleware

> **Target Server**: `/var/www/devmiddleware/`  
> **Image Registry**: `registry.assa.id/middleware-assa/middleware:1.0.3` (GitLab Container Registry ASSA)  
> **Tujuan**: Menjalankan seluruh service middleware ASSA dalam 1 container WSO2 MI Monorepo + 1 container MariaDB + 1 container Nginx reverse proxy di server dev **tanpa perlu clone repository Git atau build source code di server**.  
> **Tool yang digunakan**: **WinSCP** (untuk upload file config) & **PuTTY** (untuk remote SSH & command Docker).

---

## Daftar Isi
1. [Arsitektur Deployment](#1-arsitektur-deployment)
2. [Prasyarat Server & Client](#2-prasyarat-server--client)
3. [File Konfigurasi yang Dibutuhkan](#3-file-konfigurasi-yang-dibutuhkan)
4. [Langkah 1 — Upload File via WinSCP](#4-langkah-1--upload-file-via-winscp)
5. [Langkah 2 — Eksekusi Deployment via PuTTY](#5-langkah-2--eksekusi-deployment-via-putty)
6. [Referensi Konfigurasi File](#6-referensi-konfigurasi-file)
   - [File 1: `docker-compose.yml`](#file-1-docker-composeyml)
   - [File 2: `.env`](#file-2-env)
   - [File 3: `nginx.conf`](#file-3-nginxconf)
   - [File 4: `init_mariadb_schema.sql`](#file-4-init_mariadb_schemasql)
7. [Verifikasi & Pengujian Endpoint](#7-verifikasi--pengujian-endpoint)
8. [Update / Redeploy Versi Baru (misal: 1.0.4)](#8-update--redeploy-versi-baru-misal-104)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Arsitektur Deployment

```mermaid
flowchart TB
    Client["Client / Omnichannel / ATLAS / Postman"] -->|"HTTP :6030 (atau :80)"| NGINX["Nginx Reverse Proxy\n(:80 internal)"]
    subgraph DockerCompose["Docker Compose @ /var/www/devmiddleware"]
        NGINX -->|"/health, /api/*"| MI["middleware-api :8290\n(registry.assa.id/middleware-assa/middleware:1.0.3)\nSemua 6 Service WSO2 MI"]
        MI -->|"Port 3306"| DB[("mi-mariadb :3306\n(mariadb:11)")]
    end
    MI -->|HTTPS| FMS["devfmsapi.assa.id"]
    MI -->|HTTPS| SAP["devsapcoreapi.assa.id & sapcoreapi.assa.id"]
    MI -->|POST| EXT["assa-ext-services.assa.id/dev"]
    MI -->|POST| ATLAS["atlas-api.assa.id/dev (toggle)"]
    MI -->|"XML → FTP :21"| FTP["devqaxmlpool.assa.id"]
```

### Mengapa Menggunakan Pola Ini?
- **Zero Build Time di Server**: Image `registry.assa.id/middleware-assa/middleware:1.0.3` sudah berisi seluruh artefak CAR WSO2 MI (`branch`, `customer`, `vehicle`, `vendor`, `spk`, `service-request`, `worker`). Server dev tidak perlu install Maven, JDK, atau melakukan build Docker berulang kali.
- **Tanpa Git Clone di Server**: Server bersih dari kode sumber, cukup menyimpan file konfigurasi orkestrasi (`docker-compose.yml`, `.env`, `nginx.conf`, `init_mariadb_schema.sql`).
- **Nginx sebagai Reverse Proxy**: Mengarahkan seluruh trafik API client (port host `6030`) ke internal container WSO2 MI (port `8290`) secara transparan dan aman.

---

## 2. Prasyarat Server & Client

### Di Komputer Lokal (Windows)
1. **WinSCP** terpasang untuk mentransfer file konfigurasi.
2. **PuTTY** terpasang untuk akses terminal SSH.
3. Private key SSH (file `.ppk`, contoh: `dev-o-jovanca.morris.ppk`).
4. Kredensial akun GitLab ASSA (`username` & `Personal Access Token` dengan scope `read_registry`).

### Di Server Dev (Linux)
1. Docker Engine & Docker Compose plugin terpasang (`docker --version` & `docker compose version`).
2. Akses egress jaringan internet/intranet ke:
   - `registry.assa.id` (untuk pull image)
   - `devsapcoreapi.assa.id` & `sapcoreapi.assa.id`
   - `devfmsapi.assa.id`
   - `assa-ext-services.assa.id`
   - `devqaxmlpool.assa.id` (port FTP 21 & port passive range)
3. Port host bebas:
   - `6030` (atau port lain yang diatur di `NGINX_HTTP_PORT`)
   - `3308` (untuk akses database MariaDB dari luar/DBeaver)

---

## 3. File Konfigurasi yang Dibutuhkan

Di server pada folder `/var/www/devmiddleware/`, Anda **hanya butuh 4 file** berikut yang semuanya sudah tersedia di folder lokal `notes/docker/`:

| No | Nama File | Sumber di Lokal | Keterangan |
|---|---|---|---|
| 1 | `docker-compose.yml` | `notes/docker/docker-compose.yml` | Orkestrasi container (middleware-api + mariadb + nginx) |
| 2 | `.env` | Buat dari `notes/docker/.env.example` | Environment variable (URLs, API keys, password FTP, DB) |
| 3 | `nginx.conf` | `notes/docker/nginx.conf` | Konfigurasi reverse proxy rute API WSO2 MI |
| 4 | `init_mariadb_schema.sql` | `notes/docker/init_mariadb_schema.sql` | Inisialisasi skema tabel transaksi & retry MariaDB |

---

## 4. Langkah 1 — Upload File via WinSCP

1. Buka aplikasi **WinSCP**.
2. Masukkan parameter login:
   - **File Protocol**: `SFTP` (atau `SCP`)
   - **Host Name**: Masukkan IP atau Hostname server dev Anda
   - **Port Number**: `22` (atau port SSH server)
   - **User Name**: Masukkan username server Anda (misal: `o-jovanca.morris` / `ubuntu`)
3. Pasang Private Key:
   - Klik tombol **Advanced...**
   - Pilih menu **SSH** -> **Authentication**
   - Pada kolom **Private key file**, klik browse `[...]` lalu pilih file `.ppk` Anda (contoh: `notes/dev-o-jovanca.morris.ppk`)
   - Klik **OK**
4. Klik **Login**.
5. Buka folder target di sisi Server (panel kanan):
   - Masuk ke folder `/var/www/devmiddleware/` (jika folder belum ada, buat folder baru `devmiddleware` di dalam `/var/www/`).
6. Siapkan file di sisi Komputer Lokal (panel kiri):
   - Masuk ke folder repository lokal Anda: `.../notes/docker/`.
   - Pastikan Anda sudah membuat file `.env` dari `.env.example` (isi password FTP dan database jika ada).
7. Upload (Drag & Drop):
   - Pilih 4 file berikut dari panel kiri ke panel kanan (`/var/www/devmiddleware/`):
     - `docker-compose.yml`
     - `.env`
     - `nginx.conf`
     - `init_mariadb_schema.sql`

---

## 5. Langkah 2 — Eksekusi Deployment via PuTTY

1. Buka aplikasi **PuTTY**.
2. Masukkan parameter sesi:
   - **Host Name (or IP address)**: Masukkan IP server dev
   - **Port**: `22`
   - **Connection type**: `SSH`
3. Pasang Private Key:
   - Pada panel kategori kiri: pilih **Connection** -> **SSH** -> **Auth** (atau **Credentials** pada PuTTY versi baru).
   - Pada bagian **Private key file for authentication**, klik **Browse** lalu pilih file `.ppk` Anda.
4. Klik **Open** untuk membuka terminal SSH, lalu login dengan username Anda.
5. Masuk ke direktori aplikasi:
   ```bash
   cd /var/www/devmiddleware
   ```
6. Amankan permission file `.env`:
   ```bash
   chmod 600 .env
   ```
7. Login ke Container Registry GitLab ASSA:
   ```bash
   docker login registry.assa.id
   ```
   - Masukkan **Username** GitLab ASSA Anda.
   - Masukkan **Password** (disarankan menggunakan **Personal Access Token** GitLab dengan scope `read_registry`).
   - Pastikan muncul pesan: `Login Succeeded`.
8. Pull image container:
   ```bash
   docker compose pull
   ```
   Docker akan men-download image `registry.assa.id/middleware-assa/middleware:1.0.3`, `mariadb:11`, dan `nginx:alpine`.
9. Jalankan seluruh container di background:
   ```bash
   docker compose up -d
   ```
10. Pantau status container dan log:
    ```bash
    docker compose ps
    ```
    Untuk melihat log real-time WSO2 MI:
    ```bash
    docker compose logs -f middleware-api
    ```
    *(Tunggu sekitar 20–40 detik hingga WSO2 MI selesai inisialisasi dan memuat semua Carbon Applications)*.

---

## 6. Referensi Konfigurasi File

### File 1: `docker-compose.yml`

```yaml
services:
  # ---- MariaDB Database (Idempotency & Retry Tracking) ----
  mariadb:
    image: ${DB_IMAGE:-mariadb:11}
    container_name: mi-mariadb
    restart: unless-stopped
    environment:
      MARIADB_ALLOW_EMPTY_ROOT_PASSWORD: "yes"
      MARIADB_DATABASE: ${DB_NAME:-assa_middleware_db}
    ports:
      - "${COMPOSE_DB_PORT:-3308}:3306"
    volumes:
      - mariadb_data:/var/lib/mysql
      - ./init_mariadb_schema.sql:/docker-entrypoint-initdb.d/01_init.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "mariadb-admin ping -h localhost --silent"]
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 20s

  # ---- WSO2 MI Monorepo (Single Image from GitLab Container Registry) ----
  middleware-api:
    image: ${MIDDLEWARE_IMAGE:-registry.assa.id/middleware-assa/middleware:1.0.3}
    container_name: middleware-api
    restart: unless-stopped
    env_file:
      - .env
    environment:
      DB_HOST: ${DB_HOST:-mariadb}
      DB_PORT: ${DB_PORT:-3306}
    depends_on:
      mariadb:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "nc -z localhost 8290 || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  # ---- Nginx Reverse Proxy (Satu Pintu Akses HTTP) ----
  nginx:
    image: nginx:alpine
    container_name: middleware-nginx
    restart: unless-stopped
    ports:
      - "${NGINX_HTTP_PORT:-6030}:80"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - middleware-api

volumes:
  mariadb_data:
```

---

### File 2: `.env`

Salin dari `.env.example` ke file `.env` di `/var/www/devmiddleware/.env`:

```dotenv
# ==============================================================================
# ASSA MIDDLEWARE ENVIRONMENT VARIABLES (.env)
# ==============================================================================

# ---- 1. Backend Hosts & External Base URLs ----
SAP_CORE_BASE_URL=https://devsapcoreapi.assa.id
SAP_CORE_CUSTOMER_BASE_URL=https://sapcoreapi.assa.id
ASSA_EXT_BASE_URL=https://devfmsapi.assa.id
ASSA_EXT_SR_BASE_URL=https://assa-ext-services.assa.id/dev
SR_TARGET_ATLAS_BASE_URL=https://atlas-api.assa.id/dev

# ---- 2. External Service API Keys ----
ASSA_EXT_VEHICLE_APIKEY=XxfOtMSMhjoMQEPUHju4u7jkCEpZ09
ASSA_EXT_SR_APIKEY=DDtCZNeoPN27TWpHJdk9zaFwivxXrqQs2r1hbiKs
SR_TARGET_ATLAS_APIKEY=ATLAS_PLACEHOLDER_KEY

# ---- 3. Application Registry Authentication Tokens (Bearer Tokens) ----
AUTH_APP_A_TOKEN=3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013
AUTH_APP_B_TOKEN=988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881
AUTH_APP_QA_TOKEN=ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d
AUTH_APP_ATLAS_TOKEN=513736d17f45657e2e448779cbc89320691f0fc246728f34250c0abf166f494a
AUTH_APP_OMNICHANNEL_TOKEN=14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12

# ---- 4. Database Configuration (MariaDB di Docker Compose) ----
DB_HOST=mariadb
DB_PORT=3306
DB_NAME=assa_middleware_db
DB_USERNAME=root
DB_PASSWORD=
COMPOSE_DB_PORT=3308
DB_IMAGE=mariadb:11

# ---- 5. FTP SAP Vendor Interface (VMD) & SPK Interface ----
FTP_SAP_HOST=devqaxmlpool.assa.id
FTP_SAP_PORT=21
FTP_SAP_TARGET=/vmd
FTP_SAP_USERNAME=middlewaredev
FTP_SAP_PASSWORD="Gu34S5a#*232"

FTP_SPK_HOST=devqaxmlpool.assa.id
FTP_SPK_PORT=21
FTP_SPK_TARGET=/duelist
FTP_SPK_USERNAME=middlewaredev
FTP_SPK_PASSWORD="Gu34S5a#*232"

# ---- 6. Feature Flags ----
SR_TARGET_ATLAS_ENABLED=false
SR_TARGET_EXTSERVICE_ENABLED=true

# ---- 7. Image & Host Port Settings ----
MIDDLEWARE_IMAGE=registry.assa.id/middleware-assa/middleware:1.0.3
NGINX_HTTP_PORT=6030
```

---

### File 3: `nginx.conf`

Routing dari Nginx langsung ke port internal `8290` container WSO2 MI:

```nginx
upstream middleware_backend {
    server middleware-api:8290;
    keepalive 32;
}

server {
    listen 80;
    server_name _;

    client_max_body_size 20m;

    # Health Check
    location /health {
        proxy_pass http://middleware_backend/health;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Branch Service
    location /api/branches/ {
        proxy_pass http://middleware_backend/api/branches/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
    }

    # Customer Service
    location /api/customers/ {
        proxy_pass http://middleware_backend/api/customers/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
    }

    # Vehicle Service
    location /api/vehicles/ {
        proxy_pass http://middleware_backend/api/vehicles/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
    }

    # Vendor Service
    location /api/vendors/ {
        proxy_pass http://middleware_backend/api/vendors/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
    }

    # SPK Duelist Service
    location /api/spk/ {
        proxy_pass http://middleware_backend/api/spk/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
    }

    # Service Request Service
    location /api/service-requests/ {
        proxy_pass http://middleware_backend/api/service-requests/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
    }

    # Worker Service
    location /api/worker/ {
        proxy_pass http://middleware_backend/api/worker/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
    }

    # General API fallback
    location /api/ {
        proxy_pass http://middleware_backend/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
    }

    # Default root fallback
    location / {
        proxy_pass http://middleware_backend/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

### File 4: `init_mariadb_schema.sql`

Otomatis dijalankan saat pertama kali container `mi-mariadb` dibuat:

```sql
CREATE DATABASE IF NOT EXISTS assa_middleware_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE assa_middleware_db;

CREATE TABLE IF NOT EXISTS api_transaction (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    transaction_id VARCHAR(100) NOT NULL,
    idempotency_key VARCHAR(100) NULL,
    endpoint VARCHAR(255) NOT NULL,
    http_method VARCHAR(10) NOT NULL DEFAULT 'GET',
    request_payload LONGTEXT NULL,
    response_payload LONGTEXT NULL,
    status ENUM('PENDING', 'PROCESSING', 'SUCCESS', 'RETRY', 'FAILED') NOT NULL DEFAULT 'PENDING',
    attempt_count INT NOT NULL DEFAULT 0,
    max_attempts INT NOT NULL DEFAULT 3,
    retry_interval_seconds INT NOT NULL DEFAULT 60,
    next_retry_at DATETIME NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_transaction_id (transaction_id),
    INDEX idx_status_next_retry (status, next_retry_at),
    INDEX idx_idempotency (idempotency_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS api_transaction_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    transaction_id VARCHAR(100) NOT NULL,
    attempt_number INT NOT NULL,
    endpoint VARCHAR(255) NOT NULL,
    request_payload LONGTEXT NULL,
    response_status INT NULL,
    response_body LONGTEXT NULL,
    error_message TEXT NULL,
    duration_ms INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_trx_id (transaction_id),
    CONSTRAINT fk_trx_id
        FOREIGN KEY (transaction_id)
        REFERENCES api_transaction (transaction_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## 7. Verifikasi & Pengujian Endpoint

Setelah container berjalan via PuTTY, uji endpoint berikut langsung dari server atau via Postman dari PC Anda (`http://<IP_SERVER>:6030`):

### 1. Health Check
```bash
curl -i http://localhost:6030/health
```

### 2. Uji Branch Service (SAP Core)
```bash
curl -i http://localhost:6030/api/branches/get-branch \
  -H "Authorization: Bearer 3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013"
```

### 3. Uji Customer Service (SAP Core)
```bash
curl -i http://localhost:6030/api/customers/get-customer \
  -H "Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881"
```

### 4. Uji Vehicle Service (FMS API)
```bash
curl -i "http://localhost:6030/api/vehicles/get-vehicle?nopol=B1234XYZ" \
  -H "Authorization: Bearer 513736d17f45657e2e448779cbc89320691f0fc246728f34250c0abf166f494a"
```

### 5. Uji Service Request (POST)
```bash
curl -i --location 'http://localhost:6030/api/service-requests' \
  --header 'Authorization: Bearer 14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12' \
  --header 'Content-Type: application/json' \
  --data '{
    "app_id": "sr_app_id",
    "reff_number": "sr_reff_number",
    "branch_code": "sr_branch_code",
    "created_datetime": "12-12-2022",
    "created_by": "testing",
    "ticket_no": "test"
  }'
```

### 6. Cek Database MariaDB
Untuk memastikan skema dan data transaksi tercatat:
```bash
docker exec -it mi-mariadb mariadb -uroot assa_middleware_db -e "SHOW TABLES; SELECT * FROM api_transaction LIMIT 5;"
```

---

## 8. Update / Redeploy Versi Baru (misal: 1.0.4)

Jika ada rilis image container baru dari tim GitLab CI/CD (contoh tag `1.0.4`):

1. Buka PuTTY, masuk ke `/var/www/devmiddleware`.
2. Ubah tag image di file `.env` (atau buka WinSCP dan edit `.env`):
   ```dotenv
   MIDDLEWARE_IMAGE=registry.assa.id/middleware-assa/middleware:1.0.4
   ```
3. Di terminal PuTTY, jalankan:
   ```bash
   cd /var/www/devmiddleware
   docker compose pull middleware-api
   docker compose up -d middleware-api
   ```
4. Verifikasi log:
   ```bash
   docker compose logs -f middleware-api
   ```
> **Keuntungan**: Database MariaDB tidak akan terhapus/restart, dan proses upgrade image selesai hanya dalam hitungan detik!

---

## 9. Troubleshooting

| Gejala | Kemungkinan Penyebab | Solusi |
|---|---|---|
| `docker login` gagal / `unauthorized` | Personal Access Token expired atau kurang izin `read_registry` | Buat token baru di GitLab: **User Settings** -> **Access Tokens** -> Checklist `read_registry`. |
| Nginx mengembalikan `502 Bad Gateway` | WSO2 MI masih dalam proses booting (warm-up) | WSO2 MI butuh waktu ~20-40 detik saat pertama kali start. Pantau log: `docker compose logs -f middleware-api`. |
| Port `6030` bentrok (sudah dipakai proses lain) | Port host `6030` sedang digunakan service lain di server dev | Ubah `NGINX_HTTP_PORT=8080` (atau port bebas lainnya) di `.env`, lalu jalankan `docker compose up -d nginx`. |
| Database MariaDB error connect | Container MariaDB belum berstatus `healthy` | Cek status `docker compose ps`. Cek log MariaDB: `docker compose logs mi-mariadb`. |
| FTP gagal upload (vendor / SPK) | Server dev diblokir firewall keluar port 21 / passive port | Uji koneksi dari server ke FTP: `nc -zv devqaxmlpool.assa.id 21` atau `telnet devqaxmlpool.assa.id 21`. |
| Ingin restart bersih | Perlu me-restart semua container | Jalankan `docker compose restart`. Jika ingin mematikan: `docker compose down` (data DB aman di volume `mariadb_data`). |

---

*Panduan ini telah disesuaikan dengan image container GitLab ASSA `registry.assa.id/middleware-assa/middleware:1.0.3` dan konfigurasi monorepo aktual.*
