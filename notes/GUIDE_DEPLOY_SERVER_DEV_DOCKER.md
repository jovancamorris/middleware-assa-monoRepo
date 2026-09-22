# Guide — Deploy ke Server Dev (Docker + Nginx)
## WSO2 MI Monorepo — ASSA Middleware

> **Target server**: `/var/www/devmiddleware/`
> **Tujuan**: Menjalankan seluruh service middleware (6 WSO2 MI + MariaDB) di server dev via Docker Compose, dengan **Nginx sebagai reverse proxy** di depan (satu pintu masuk HTTP → rute ke tiap service).
> **Isi folder server** (`/var/www/devmiddleware/`):
> 1. `docker-compose.yml` — orkestrasi semua container (termasuk Nginx)
> 2. `Dockerfile.nginx` — image Nginx reverse proxy
> 3. `nginx.conf` — konfigurasi routing Nginx
> 4. `.env` — environment variable (kredensial, base URL, DB, FTP) — **tidak di-commit**

---

## Daftar Isi
1. [Arsitektur Deployment](#1-arsitektur-deployment)
2. [Prasyarat Server](#2-prasyarat-server)
3. [Struktur Folder di Server](#3-struktur-folder-di-server)
4. [File 1 — `.env`](#4-file-1--env)
5. [File 2 — `nginx.conf`](#5-file-2--nginxconf)
6. [File 3 — `Dockerfile.nginx`](#6-file-3--dockerfilenginx)
7. [File 4 — `docker-compose.yml`](#7-file-4--docker-composeyml)
8. [Langkah Deploy](#8-langkah-deploy)
9. [Verifikasi](#9-verifikasi)
10. [Update / Redeploy](#10-update--redeploy)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Arsitektur Deployment

```mermaid
flowchart TB
    Client["Client / Omnichannel / ATLAS"] -->|"HTTP :80 / :4002"| NGINX["Nginx (reverse proxy)"]
    subgraph Compose["Docker Compose @ /var/www/devmiddleware"]
        NGINX -->|"/api/branches"| BR["branch-service :8290"]
        NGINX -->|"/api/customers"| CU["customer-service :8290"]
        NGINX -->|"/api/vehicles"| VE["vehicle-service :8290"]
        NGINX -->|"/api/vendors"| VN["vendor-service :8290"]
        NGINX -->|"/api/spk"| SP["spk-service :8290"]
        NGINX -->|"/api/service-requests"| SR["service-request-service :8290"]
        BR & CU & VE & VN & SP & SR --> DB[("mariadb :3306")]
    end
    VE -->|HTTPS| FMS["devfmsapi.assa.id"]
    SR -->|POST| EXT["assa-ext-services.assa.id/dev"]
    SR -->|POST| ATLAS["atlas-api.assa.id/dev (toggle)"]
    VN & SP -->|"XML → FTP"| FTP["devqaxmlpool.assa.id"]
```

Nginx menyatukan 6 service di belakang satu host/port, sehingga client cukup memanggil satu alamat (mis. `https://fe.atlas-dev.assa.id` atau `http://<server>:4002`) dan Nginx merutekan ke service yang tepat berdasarkan path.

---

## 2. Prasyarat Server

- Docker Engine + Docker Compose plugin terpasang (`docker --version`, `docker compose version`).
- Akses ke registry image ATAU source code monorepo di server (untuk build lokal).
- Akses jaringan (egress) dari server ke: `devsapcoreapi.assa.id`, `sapcoreapi.assa.id`, `devfmsapi.assa.id`, `assa-ext-services.assa.id`, `devqaxmlpool.assa.id` (FTP), dan `atlas-api.assa.id` (bila toggle ATLAS aktif).
- Port host yang dibutuhkan bebas: `4002` (atau `80`) untuk Nginx; opsional `8290-8295` bila ingin akses langsung; `3308` untuk MariaDB.

> **Dua pendekatan build image**:
> - **A. Build di server** dari source monorepo (butuh folder repo di server). Cocok untuk dev.
> - **B. Pull dari registry** (image sudah dibuild CI/CD). Lebih rapi untuk staging/prod.
> Guide ini memakai **pendekatan A (build di server)** karena ini server dev.

---

## 3. Struktur Folder di Server

```text
/var/www/devmiddleware/
├── docker-compose.yml        # orkestrasi (nginx + 6 service + mariadb)
├── Dockerfile.nginx          # image reverse proxy
├── nginx.conf                # routing per service
├── .env                      # environment (JANGAN commit)
└── wso2-mi-monorepo/         # source code monorepo (di-clone/di-copy ke server)
    ├── integrations/...
    ├── shared/...
    ├── platform/...
    ├── scripts/db/init_mariadb_schema.sql
    └── pom.xml
```

> Letakkan `docker-compose.yml`, `Dockerfile.nginx`, `nginx.conf`, `.env` **di root** `/var/www/devmiddleware/`, dan source monorepo di subfolder `wso2-mi-monorepo/`. Compose akan mereferensikan Dockerfile tiap service via path `wso2-mi-monorepo/integrations/<service>/Dockerfile`.

---

## 4. File 1 — `.env`

Salin `.env` dari `wso2-mi-monorepo/.env` ke `/var/www/devmiddleware/.env`, lalu **sesuaikan untuk server dev**. Nilai penting:

```dotenv
# ---- Backend & External ----
SAP_CORE_BASE_URL=https://devsapcoreapi.assa.id
SAP_CORE_CUSTOMER_BASE_URL=https://sapcoreapi.assa.id
ASSA_EXT_BASE_URL=https://devfmsapi.assa.id
ASSA_EXT_SR_BASE_URL=https://assa-ext-services.assa.id/dev
SR_TARGET_ATLAS_BASE_URL=https://atlas-api.assa.id/dev

# ---- API Keys ----
ASSA_EXT_VEHICLE_APIKEY=XxfOtMSMhjoMQEPUHju4u7jkCEpZ09
ASSA_EXT_SR_APIKEY=DDtCZNeoPN27TWpHJdk9zaFwivxXrqQs2r1hbiKs
SR_TARGET_ATLAS_APIKEY=ATLAS_PLACEHOLDER_KEY

# ---- App Registry Tokens ----
AUTH_APP_A_TOKEN=3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013
AUTH_APP_B_TOKEN=988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881
AUTH_APP_QA_TOKEN=ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d
AUTH_APP_ATLAS_TOKEN=513736d17f45657e2e448779cbc89320691f0fc246728f34250c0abf166f494a
AUTH_APP_OMNICHANNEL_TOKEN=14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12

# ---- Database (di dalam Docker) ----
DB_HOST=mariadb
DB_PORT=3306
DB_NAME=assa_middleware_db
DB_USERNAME=root
DB_PASSWORD=
COMPOSE_DB_PORT=3308
DB_IMAGE=mariadb:11

# ---- FTP (VMD & SPK) ----
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

# ---- Feature Flags ----
SR_TARGET_ATLAS_ENABLED=false
SR_TARGET_EXTSERVICE_ENABLED=true

# ---- Base Image ----
BASE_IMAGE=wso2/wso2mi:4.6.0

# ---- Nginx exposed port di host ----
NGINX_HTTP_PORT=4002
```

> **Keamanan**: `.env` memuat kredensial nyata (token, API key, password FTP). Pastikan permission ketat (`chmod 600 .env`) dan **tidak** masuk git. Untuk produksi, pindahkan ke secret manager.

---

## 5. File 2 — `nginx.conf`

Reverse proxy merutekan path ke masing-masing service (nama service = hostname di jaringan Docker Compose).

```nginx
worker_processes auto;
events { worker_connections 1024; }

http {
    sendfile on;
    keepalive_timeout 65;
    client_max_body_size 20m;

    # Upstream tiap service (resolusi nama via Docker DNS)
    upstream branch_up          { server branch-service:8290; }
    upstream customer_up        { server customer-service:8290; }
    upstream vehicle_up         { server vehicle-service:8290; }
    upstream vendor_up          { server vendor-service:8290; }
    upstream spk_up             { server spk-service:8290; }
    upstream servicerequest_up  { server service-request-service:8290; }

    server {
        listen 80;
        server_name _;

        # Health probe gabungan (arahkan ke salah satu service)
        location = /health {
            proxy_pass http://branch_up/health;
        }

        # Routing per domain berdasarkan prefix path
        location /api/branches         { proxy_pass http://branch_up; }
        location /api/customers        { proxy_pass http://customer_up; }
        location /api/vehicles         { proxy_pass http://vehicle_up; }
        location /api/vendors          { proxy_pass http://vendor_up; }
        location /api/spk              { proxy_pass http://spk_up; }
        location /api/service-requests { proxy_pass http://servicerequest_up; }
        location /api/worker           { proxy_pass http://servicerequest_up; }

        # Header standar proxy
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
    }
}
```

> Catatan: `X-Forwarded-For` diteruskan agar service-request-service dapat mengisi `IPAddress` bila diperlukan. Sesuaikan `client_max_body_size` bila payload besar.

---

## 6. File 3 — `Dockerfile.nginx`

```dockerfile
FROM nginx:1.27-alpine
# Ganti config default dengan konfigurasi routing kita
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
HEALTHCHECK --interval=15s --timeout=5s --retries=5 \
    CMD wget -qO- http://localhost/health || exit 1
```

---

## 7. File 4 — `docker-compose.yml`

Compose ini menambahkan **nginx** di depan compose monorepo, dan mereferensikan Dockerfile tiap service dari subfolder `wso2-mi-monorepo/`. Simpan sebagai `/var/www/devmiddleware/docker-compose.yml`.

```yaml
# /var/www/devmiddleware/docker-compose.yml
services:

  # ---- Reverse Proxy ----
  nginx:
    build:
      context: .
      dockerfile: Dockerfile.nginx
    image: assa/middleware-nginx:1.0.0
    container_name: middleware-nginx
    restart: unless-stopped
    depends_on:
      - branch-service
      - customer-service
      - vehicle-service
      - vendor-service
      - spk-service
      - service-request-service
    ports:
      - "${NGINX_HTTP_PORT:-4002}:80"

  # ---- Database ----
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
      - ./wso2-mi-monorepo/scripts/db/init_mariadb_schema.sql:/docker-entrypoint-initdb.d/01_init.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "mariadb-admin ping -h localhost --silent"]
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 20s

  # ---- Integration Services ----
  branch-service:
    build: { context: ./wso2-mi-monorepo, dockerfile: integrations/branch-service/Dockerfile }
    image: assa/branch-service:1.0.0
    container_name: branch-service
    restart: unless-stopped
    depends_on: { mariadb: { condition: service_healthy } }
    env_file: [ .env ]
    environment: &svc-env
      DB_HOST: ${DB_HOST:-mariadb}
      DB_PORT: ${DB_PORT:-3306}
    # port 8290-8295 TIDAK diekspos ke host (akses lewat Nginx).
    # Buka bila perlu debug langsung: ports: ["8290:8290"]

  customer-service:
    build: { context: ./wso2-mi-monorepo, dockerfile: integrations/customer-service/Dockerfile }
    image: assa/customer-service:1.0.0
    container_name: customer-service
    restart: unless-stopped
    depends_on: { mariadb: { condition: service_healthy } }
    env_file: [ .env ]
    environment: *svc-env

  vehicle-service:
    build: { context: ./wso2-mi-monorepo, dockerfile: integrations/vehicle-service/Dockerfile }
    image: assa/vehicle-service:1.0.0
    container_name: vehicle-service
    restart: unless-stopped
    depends_on: { mariadb: { condition: service_healthy } }
    env_file: [ .env ]
    environment: *svc-env

  vendor-service:
    build: { context: ./wso2-mi-monorepo, dockerfile: integrations/vendor-service/Dockerfile }
    image: assa/vendor-service:1.0.0
    container_name: vendor-service
    restart: unless-stopped
    depends_on: { mariadb: { condition: service_healthy } }
    env_file: [ .env ]
    environment: *svc-env

  spk-service:
    build: { context: ./wso2-mi-monorepo, dockerfile: integrations/spk-service/Dockerfile }
    image: assa/spk-service:1.0.0
    container_name: spk-service
    restart: unless-stopped
    depends_on: { mariadb: { condition: service_healthy } }
    env_file: [ .env ]
    environment: *svc-env

  service-request-service:
    build: { context: ./wso2-mi-monorepo, dockerfile: integrations/service-request-service/Dockerfile }
    image: assa/service-request-service:1.0.0
    container_name: service-request-service
    restart: unless-stopped
    depends_on: { mariadb: { condition: service_healthy } }
    env_file: [ .env ]
    environment: *svc-env

volumes:
  mariadb_data:
```

> **Kunci**: `env_file: [ .env ]` menyuntikkan seluruh variabel `.env` ke tiap service. Service `vendor`/`spk` membaca `FTP_*`, service-request membaca `ASSA_EXT_SR_*` & `SR_TARGET_ATLAS_*`. Port service internal tidak diekspos ke host — semua trafik masuk lewat Nginx.

---

## 8. Langkah Deploy

Semua perintah dijalankan di server, di dalam `/var/www/devmiddleware/`.

### Langkah 1 — Siapkan folder & source
```bash
cd /var/www/devmiddleware
# Clone/pull source monorepo ke subfolder (pilih branch yang benar)
git clone -b restructure-monorepo https://gitlab.assa.id/nobi.sumariga/middleware-assa.git wso2-mi-monorepo
# atau bila sudah ada: cd wso2-mi-monorepo && git pull && cd ..
```

### Langkah 2 — Siapkan 4 file di root
Pastikan `docker-compose.yml`, `Dockerfile.nginx`, `nginx.conf`, `.env` sudah ada di `/var/www/devmiddleware/`. Salin `.env`:
```bash
cp wso2-mi-monorepo/.env .env       # lalu edit sesuai server dev
chmod 600 .env
```

### Langkah 3 — Build image
```bash
docker compose build
```
Build multi-stage tiap service (compile `.car` dengan Maven → bungkus ke `wso2/wso2mi:4.6.0`) + image Nginx. Build pertama lama (download dependency WSO2).

### Langkah 4 — Jalankan
```bash
docker compose up -d
```

### Langkah 5 — Pantau startup
```bash
docker compose ps
docker compose logs -f nginx
docker compose logs -f service-request-service
```
Tunggu semua container `healthy` / `running` (WSO2 MI butuh warm-up ~30–60 dtk).

---

## 9. Verifikasi

```bash
# Health via Nginx
curl http://localhost:4002/health

# Uji Service Request lewat Nginx (pola dari ref curl)
curl --location 'http://localhost:4002/api/service-requests' \
  --header 'Authorization: Bearer 14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12' \
  --header 'Content-Type: application/json' \
  --data '{ "app_id":"sr_app_id", "reff_number":"sr_reff_number", "branch_code":"sr_branch_code", "created_datetime":"12-12-2022", "created_by":"testing", "ticket_no":"test" }'
```

Cek container & DB:
```bash
docker compose ps
docker exec -it mi-mariadb mariadb -uroot assa_middleware_db -e "SHOW TABLES;"
```

---

## 10. Update / Redeploy

Setelah ada perubahan kode / pull terbaru:
```bash
cd /var/www/devmiddleware/wso2-mi-monorepo && git pull && cd ..
docker compose build            # rebuild image yang berubah
docker compose up -d            # recreate container yang berubah
docker compose logs -f
```

Redeploy satu service saja (mis. service-request):
```bash
docker compose build service-request-service
docker compose up -d service-request-service
```

Restart Nginx setelah ubah `nginx.conf`:
```bash
docker compose build nginx && docker compose up -d nginx
```

---

## 11. Troubleshooting

| Gejala | Kemungkinan penyebab | Tindakan |
|---|---|---|
| Nginx `502 Bad Gateway` | Service belum `healthy` / nama upstream salah | `docker compose ps`, cek nama service = upstream di `nginx.conf` |
| Service restart terus | Warm-up WSO2 lebih lama / `.car` gagal deploy | `docker compose logs <service>`, naikkan `start_period` |
| Koneksi DB gagal | `DB_HOST/DB_PORT` salah | pastikan `.env` → `DB_HOST=mariadb`, `DB_PORT=3306`; cek `mariadb` healthy |
| FTP gagal (vendor/spk) | Kredensial/host FTP salah / egress diblok | verifikasi `FTP_*` di `.env`, tes koneksi ke `devqaxmlpool.assa.id:21` dari server |
| Backend eksternal gagal | egress server diblokir | tes `curl https://devfmsapi.assa.id` & `https://assa-ext-services.assa.id/dev` dari server |
| Skema DB tidak terbuat | path init SQL salah | pastikan mount `./wso2-mi-monorepo/scripts/db/init_mariadb_schema.sql` benar |
| Port `4002` bentrok | port terpakai proses lain | ubah `NGINX_HTTP_PORT` di `.env` |

Perintah bantu:
```bash
docker compose logs -f <service>
docker exec -it <service> sh -c "curl -s localhost:8290/health"
docker compose down            # stop semua (data DB tetap di volume)
docker compose down -v         # stop + hapus volume DB (HATI-HATI: data hilang)
```

---

## Catatan Penting

1. **`.env` jangan di-commit** — sudah di-ignore. Di server, set `chmod 600` dan batasi akses.
2. **Port service internal** (8290–8295) sengaja tidak diekspos ke host; semua akses lewat Nginx (`:4002`). Buka manual hanya untuk debugging.
3. **Toggle ATLAS** default `SR_TARGET_ATLAS_ENABLED=false` — service-request hanya hit ASSA Ext Services sampai ATLAS siap.
4. **HTTPS**: guide ini HTTP di sisi Nginx. Untuk domain `fe.atlas-dev.assa.id`, terminasi TLS biasanya di reverse proxy/ingress perusahaan di depan server ini — sesuaikan bila Nginx harus handle TLS sendiri (tambah `listen 443 ssl` + sertifikat).
5. **Egress**: pastikan server dev bisa menjangkau semua backend `.assa.id` (lihat `GUIDE_DOCKER_KUBERNETES.md` §12 soal egress).

---

*Guide ini mengikuti konfigurasi monorepo aktual (`docker-compose.yml`, `.env`, Dockerfile multi-stage per service) dan pola reverse proxy Nginx untuk server dev di `/var/www/devmiddleware/`.*
