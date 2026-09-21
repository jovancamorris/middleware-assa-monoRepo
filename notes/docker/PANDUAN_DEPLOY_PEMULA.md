# Panduan Step-by-Step Deploy Server Dev (Pemula)
## Menggunakan PuTTY & WinSCP — WSO2 MI Monorepo ASSA Middleware

Panduan ini disusun khusus untuk pengguna Windows pemula agar proses deployment ke server dev Linux berjalan mudah, cepat, dan minim kesalahan dengan memanfaatkan kombinasi dua aplikasi:
1. **WinSCP**: File manager visual (SFTP) untuk navigasi folder, membuat/upload file, dan mengedit file konfigurasi (`.env`, `docker-compose.yml`, `nginx.conf`) menggunakan antarmuka grafis seperti Windows Explorer.
2. **PuTTY**: Terminal remote (SSH) untuk mengeksekusi perintah server (Docker, git, build, monitoring log, dan pengujian API).

> **Rujukan Arsitektur & Spesifikasi Lengkap**: [GUIDE_DEPLOY_SERVER_DEV_DOCKER.md](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-monorepo/notes/docker/GUIDE_DEPLOY_SERVER_DEV_DOCKER.md)  
> **Folder Target di Server**: `/var/www/devmiddleware/`

---

## Prasyarat: Persiapan Aplikasi di Windows

Sebelum mulai, pastikan Anda sudah mengunduh dan menginstal:
- [PuTTY](https://www.putty.org/) (Aplikasi terminal SSH)
- [WinSCP](https://winscp.net/) (Aplikasi SFTP transfer & file manager)

### A. Konfigurasi & Login via PuTTY
1. Buka aplikasi **PuTTY**.
2. Di bagian **Host Name (or IP address)**, masukkan IP Server Dev (misal: `10.x.x.x` atau domain server dev Anda).
3. Pastikan **Port**: `22` dan **Connection type**: `SSH`.
4. Di kolom **Saved Sessions**, ketikkan nama sesi (contoh: `ASSA-Dev-Middleware`), lalu klik **Save** agar Anda tidak perlu mengetik ulang IP di kemudian hari.
5. Klik tombol **Open**.
   > *Catatan*: Jika muncul pop-up *"PuTTY Security Alert"* saat koneksi pertama kali, klik **Accept** atau **Yes**.
6. Masukkan user login server Anda:
   - `login as: <username-anda>` (lalu tekan Enter)
   - `password: <password-anda>` (lalu tekan Enter)
   > *Tips Penting*: Saat mengetik password di terminal Linux/PuTTY, kursor tidak akan bergerak dan karakter bintang (`*`) memang tidak ditampilkan demi keamanan. Langsung ketik password Anda sampai selesai lalu tekan Enter.

---

### B. Konfigurasi & Login via WinSCP
1. Buka aplikasi **WinSCP**.
2. Pada dialog *Login*, isi data berikut:
   - **File protocol**: `SFTP`
   - **Host name**: IP Server Dev Anda
   - **Port number**: `22`
   - **User name**: username login server
   - **Password**: password login server
3. Klik tombol **Save** (simpan nama sesi, misal `ASSA-Dev-Server`), lalu klik **Login**.
4. Anda akan melihat antarmuka terbagi menjadi dua panel:
   - **Panel Kiri (Local)**: File di laptop Windows Anda.
   - **Panel Kanan (Remote)**: File di server Linux dev.

> [!TIP]
> **Integrasi Cepat PuTTY dari WinSCP (`Ctrl + P`)**:  
> Saat Anda sedang berada di folder tertentu di panel kanan WinSCP, tekan tombol **`Ctrl + P`** (atau klik menu *Commands > Open in PuTTY*). WinSCP akan otomatis membuka sesi terminal PuTTY yang langsung berada pada direktori server tersebut!

---

## Step 1 (PuTTY) — Cek Docker & Docker Compose

Buka terminal **PuTTY** Anda, lalu jalankan perintah berikut untuk memastikan server siap:
```bash
docker --version
docker compose version
```
*(Jika kedua perintah menampilkan versi Docker dan Docker Compose, silakan lanjut ke Step 2).*

---

## Step 2 (PuTTY) — Siapkan Folder Kerja & Clone Monorepo

Jalankan perintah berikut di terminal **PuTTY**:

```bash
# 1. Buat folder kerja deployment di /var/www/devmiddleware
sudo mkdir -p /var/www/devmiddleware

# 2. Berikan hak kepemilikan folder ke user Anda
sudo chown -R $USER:$USER /var/www/devmiddleware

# 3. Masuk ke folder kerja
cd /var/www/devmiddleware

# 4. Clone branch 'restructure-monorepo' ke subfolder 'wso2-mi-monorepo'
git clone -b restructure-monorepo https://gitlab.assa.id/nobi.sumariga/middleware-assa.git wso2-mi-monorepo
```

> Hasilnya, struktur folder Anda di server saat ini adalah:
> `/var/www/devmiddleware/wso2-mi-monorepo/`

---

## Step 3 (WinSCP) — Siapkan 4 File Konfigurasi di `/var/www/devmiddleware/`

Sekarang gunakan aplikasi **WinSCP** untuk membuat 4 file konfigurasi tanpa perlu mengetik manual di terminal Linux:

1. Buka **WinSCP**.
2. Di **Panel Kanan (Remote Server)**, buka folder target: `/var/www/devmiddleware`.  
   *(Tips: Tekan tombol **`Ctrl + G`**, ketik `/var/www/devmiddleware`, lalu tekan Enter).*
3. Anda akan melihat folder `wso2-mi-monorepo` yang baru saja di-clone.
4. Buat 4 file berikut di root folder `/var/www/devmiddleware/` menggunakan langkah di bawah.

### Cara Membuat File Baru di WinSCP:
- Klik kanan pada area kosong di panel kanan > pilih **New** > **File...** (atau tekan **Shift + F4**).
- Masukkan nama file (contoh: `.env`).
- Jendela editor teks internal WinSCP akan terbuka.
- **Copy isi konfigurasi** di bawah ini, lalu **Paste** ke editor WinSCP.
- Tekan **Ctrl + S** untuk menyimpan, lalu tutup jendela editor.

---

### 3.1. File 1: `.env`
Beri nama file: `.env`  
Copy-paste isi berikut:

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
```

> [!IMPORTANT]
> **Kunci Izin Hak Akses File `.env` (chmod 600) via WinSCP**:  
> 1. Di WinSCP panel kanan, klik kanan pada file `.env` > pilih **Properties** (atau tekan tombol **F9**).  
> 2. Pada kolom **Octal**, ubah nilainya menjadi **`0600`** (hanya Owner yang bisa Read & Write).  
> 3. Klik **OK**.  
> *(Atau bila lewat PuTTY: jalankan `chmod 600 /var/www/devmiddleware/.env`).*

---

### 3.2. File 2: `nginx.conf`
Beri nama file: `nginx.conf`  
Copy-paste isi berikut:

```nginx
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
```

---

### 3.3. File 3: `Dockerfile.nginx`
Beri nama file: `Dockerfile.nginx`  
Copy-paste isi berikut:

```dockerfile
FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
HEALTHCHECK --interval=15s --timeout=5s --retries=5 \
    CMD wget -qO- http://localhost/health || exit 1
```

---

### 3.4. File 4: `docker-compose.yml`
Beri nama file: `docker-compose.yml`  
Copy-paste isi berikut:

```yaml
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
```

> **Verifikasi Struktur Folder di WinSCP**:  
> Pastikan di panel kanan `/var/www/devmiddleware/` sekarang terdapat:
> ```text
> ├── .env
> ├── nginx.conf
> ├── Dockerfile.nginx
> ├── docker-compose.yml
> └── wso2-mi-monorepo/
> ```

---

## Step 4 (PuTTY) — Build Image Docker

Kembali ke jendela **PuTTY** (pastikan posisi direktori di `/var/www/devmiddleware`):

```bash
cd /var/www/devmiddleware
docker compose build
```
*(Proses build pertama ini akan memakan waktu beberapa menit karena mengunduh base image WSO2 MI dan library Maven).*

---

## Step 5 (PuTTY) — Jalankan Semua Service

Setelah proses build selesai tanpa error, jalankan seluruh container:

```bash
docker compose up -d
```

---

## Step 6 (PuTTY) — Pantau Status & Log Container

WSO2 Micro Integrator membutuhkan waktu start-up sekitar 30–60 detik. Pantau statusnya:

```bash
docker compose ps
```
> Pastikan semua kolom status bertuliskan **`Up`** atau **`Up (healthy)`**.

Untuk memantau log container:
```bash
# 1. Pantau log Nginx
docker compose logs -f nginx

# 2. Pantau log service tertentu (contoh: service-request-service)
docker compose logs -f service-request-service

# (Tekan tombol Ctrl + C di keyboard untuk keluar dari tampilan log)
```

---

## Step 7 (PuTTY) — Verifikasi & Pengujian API

Lakukan pengujian langsung dari terminal PuTTY:

### 1. Uji Health Check Nginx Reverse Proxy
```bash
curl http://localhost:4002/health
```

### 2. Cek Skema Database MariaDB (Pastikan tabel otomatis terbuat)
```bash
docker exec -it mi-mariadb mariadb -uroot assa_middleware_db -e "SHOW TABLES;"
```

### 3. Uji Kirim Data ke Service Request via Port Nginx 4002
```bash
curl --location 'http://localhost:4002/api/service-requests' \
  --header 'Authorization: Bearer token-assa-omnichannel-secret-99999' \
  --header 'Content-Type: application/json' \
  --data '{ "app_id":"sr_app_id", "reff_number":"sr_reff_number", "branch_code":"sr_branch_code", "created_datetime":"12-12-2022", "created_by":"testing", "ticket_no":"test" }'
```

---

## Tips Produktivitas Pemula: PuTTY & WinSCP

| Tips / Fitur | Cara Melakukan | Penjelasan |
|---|---|---|
| **Copy-Paste di PuTTY** | **Copy di Windows** (`Ctrl + C`) → **Klik Kanan Mouse 1x** di PuTTY | Jangan tekan `Ctrl + V` di PuTTY. Klik kanan mouse langsung menempelkan teks. |
| **Copy Teks dari PuTTY** | **Sorot / Blok Teks** menggunakan mouse | Teks yang diblok di PuTTY otomatis tersimpan ke clipboard Windows Anda. |
| **Buka PuTTY dari WinSCP** | Tekan **`Ctrl + P`** di WinSCP | Terminal PuTTY akan langsung terbuka dan masuk ke folder server yang aktif di WinSCP. |
| **Edit File Cepat** | **Double Click** file di WinSCP (mis. `.env` atau `nginx.conf`) | File terbuka di text editor WinSCP. Tekan `Ctrl + S`, file otomatis tersimpan langsung di server. |
| **Ubah Permission File** | Klik kanan file di WinSCP → **Properties** (`F9`) | Ubah angka Octal (misal `0600` untuk `.env` atau `0755` untuk script). |

---

## Cheat Sheet: Alur Pembaruan & Perintah Sehari-hari

### A. Jika Ada Update Kodingan di Gitlab:
Jalankan urutan ini di **PuTTY**:
```bash
cd /var/www/devmiddleware/wso2-mi-monorepo
git pull
cd /var/www/devmiddleware
docker compose build
docker compose up -d
```

### B. Jika Hanya Mengubah File `.env`:
1. Buka WinSCP, double-click `.env` di `/var/www/devmiddleware/`.
2. Edit nilainya, lalu simpan (**Ctrl + S**).
3. Di **PuTTY**, jalankan perintah agar container menerapkan nilai baru:
   ```bash
   cd /var/www/devmiddleware && docker compose up -d
   ```

### C. Jika Hanya Mengubah `nginx.conf`:
1. Edit file `nginx.conf` di WinSCP, lalu simpan (**Ctrl + S**).
2. Di **PuTTY**, rebuild dan restart Nginx:
   ```bash
   cd /var/www/devmiddleware && docker compose build nginx && docker compose up -d nginx
   ```

### D. Perintah Manajemen Docker Cepat:
| Kebutuhan | Perintah di PuTTY |
|---|---|
| Menghentikan semua service | `docker compose down` |
| Menjalankan kembali service | `docker compose up -d` |
| Rebuild 1 service saja (misal `vehicle-service`) | `docker compose build vehicle-service && docker compose up -d vehicle-service` |
| Restart 1 service saja (misal `nginx`) | `docker compose restart nginx` |
| Melihat log seluruh container realtime | `docker compose logs -f` |
| Menghapus container + volume database *(Hati-hati: data DB terhapus)* | `docker compose down -v` |
