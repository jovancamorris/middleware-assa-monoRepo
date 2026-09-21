# Panduan Step-by-Step Deploy Server Dev (Pemula)
## WSO2 MI Monorepo — ASSA Middleware

Panduan ini dibuat seringkas dan sejelas mungkin agar Anda bisa langsung copy-paste perintahnya dari terminal server (Linux) dari kondisi 0.

---

## Prasyarat Awal: Masuk ke Server
Buka terminal di komputer Anda, lalu login ke server dev via SSH:
```bash
ssh username@ip-server-dev
```

---

## Step 1 — Cek Docker & Compose
Pastikan Docker dan Docker Compose sudah terpasang di server:
```bash
docker --version
docker compose version
```
*(Jika perintah ini menampilkan versi Docker, silakan lanjut ke Step 2).*

---

## Step 2 — Siapkan Folder Kerja & Clone Monorepo
Kita siapkan folder kerja di `/var/www/devmiddleware`:

```bash
# 1. Buat folder dan atur hak akses user
sudo mkdir -p /var/www/devmiddleware
sudo chown -R $USER:$USER /var/www/devmiddleware
cd /var/www/devmiddleware

# 2. Clone source code monorepo ke subfolder 'wso2-mi-monorepo'
git clone -b restructure-monorepo https://gitlab.assa.id/nobi.sumariga/middleware-assa.git wso2-mi-monorepo
```

---

## Step 3 — Buat 4 File Konfigurasi di `/var/www/devmiddleware/`

Pastikan posisi terminal Anda saat ini berada di folder `/var/www/devmiddleware`.  
Cukup **copy-paste** blok perintah di bawah ini satu per satu:

### 3.1. Buat File `.env`
```bash
cat << 'EOF' > /var/www/devmiddleware/.env
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
AUTH_APP_A_TOKEN=token-assa-app-a-secret-12345
AUTH_APP_B_TOKEN=token-assa-app-b-secret-67890
AUTH_APP_QA_TOKEN=ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d
AUTH_APP_ATLAS_TOKEN=token-assa-atlas-vmd-secret-99999
AUTH_APP_OMNICHANNEL_TOKEN=token-assa-omnichannel-secret-99999

# ---- Database (Internal Docker) ----
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

# ---- Base Image & Port ----
BASE_IMAGE=wso2/wso2mi:4.6.0
NGINX_HTTP_PORT=4002
EOF

# Kunci hak akses agar aman
chmod 600 /var/www/devmiddleware/.env
```

---

### 3.2. Buat File `nginx.conf`
```bash
cat << 'EOF' > /var/www/devmiddleware/nginx.conf
worker_processes auto;
events { worker_connections 1024; }

http {
    sendfile on;
    keepalive_timeout 65;
    client_max_body_size 20m;

    # Upstream tiap service (resolusi nama via Docker Compose DNS)
    upstream branch_up          { server branch-service:8290; }
    upstream customer_up        { server customer-service:8290; }
    upstream vehicle_up         { server vehicle-service:8290; }
    upstream vendor_up          { server vendor-service:8290; }
    upstream spk_up             { server spk-service:8290; }
    upstream servicerequest_up  { server service-request-service:8290; }

    server {
        listen 80;
        server_name _;

        # Health probe gabungan
        location = /health {
            proxy_pass http://branch_up/health;
        }

        # Routing per domain
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
EOF
```

---

### 3.3. Buat File `Dockerfile.nginx`
```bash
cat << 'EOF' > /var/www/devmiddleware/Dockerfile.nginx
FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
HEALTHCHECK --interval=15s --timeout=5s --retries=5 \
    CMD wget -qO- http://localhost/health || exit 1
EOF
```

---

### 3.4. Buat File `docker-compose.yml`
```bash
cat << 'EOF' > /var/www/devmiddleware/docker-compose.yml
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
EOF
```

---

## Step 4 — Build Image Docker
Jalankan proses compile Maven & build Docker image:
```bash
docker compose build
```
*(Build pertama akan memakan waktu beberapa menit karena mengunduh base image WSO2 dan dependency Maven).*

---

## Step 5 — Jalankan Semua Service
Jalankan semua container di background:
```bash
docker compose up -d
```

---

## Step 6 — Pantau Status Container
WSO2 MI butuh waktu warm-up awal sekitar 30–60 detik. Cek statusnya:
```bash
docker compose ps
```
> Pastikan status semua service bertuliskan **`Up`** atau **`Up (healthy)`**.

Untuk memantau log:
```bash
# Log Nginx
docker compose logs -f nginx

# Log salah satu service (misal service-request). Tekan Ctrl+C untuk keluar.
docker compose logs -f service-request-service
```

---

## Step 7 — Verifikasi & Testing
Jalankan tes langsung di terminal server:

1. **Tes Health Check Nginx:**
   ```bash
   curl http://localhost:4002/health
   ```

2. **Cek Database MariaDB (Pastikan tabel otomatis terbuat):**
   ```bash
   docker exec -it mi-mariadb mariadb -uroot assa_middleware_db -e "SHOW TABLES;"
   ```

3. **Uji Service Request via Nginx:**
   ```bash
   curl --location 'http://localhost:4002/api/service-requests' \
     --header 'Authorization: Bearer token-assa-omnichannel-secret-99999' \
     --header 'Content-Type: application/json' \
     --data '{ "app_id":"sr_app_id", "reff_number":"sr_reff_number", "branch_code":"sr_branch_code", "created_datetime":"12-12-2022", "created_by":"testing", "ticket_no":"test" }'
   ```

---

## Cheat Sheet: Perintah Sehari-hari

| Kebutuhan | Perintah |
|---|---|
| **Stop semua container** | `docker compose down` |
| **Start kembali** | `docker compose up -d` |
| **Ada update kodingan terbaru** | `cd wso2-mi-monorepo && git pull && cd .. && docker compose build && docker compose up -d` |
| **Rebuild 1 service saja** (contoh: service-request) | `docker compose build service-request-service && docker compose up -d service-request-service` |
| **Restart Nginx saja** | `docker compose restart nginx` |
| **Lihat semua log realtime** | `docker compose logs -f` |
