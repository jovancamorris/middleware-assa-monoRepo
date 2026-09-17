# 🐳 Panduan Lengkap Setup & Menjalankan ASSA Middleware di Docker

Panduan ini mendokumentasikan secara lengkap arsitektur, konfigurasi, dan langkah-langkah untuk menjalankan **ASSA Middleware (WSO2 Micro Integrator)** di dalam lingkungan **Docker** dan **Docker Compose**.

---

## 📑 Daftar Isi
1. [Arsitektur & Komponen Docker](#1-arsitektur--komponen-docker)
2. [Prasyarat Sistem](#2-prasyarat-sistem)
3. [Struktur File Terkait Docker](#3-struktur-file-terkait-docker)
4. [Langkah-Langkah Menjalankan Middleware](#4-langkah-langkah-menjalankan-middleware)
5. [Dua Mode Menjalankan Database](#5-dua-mode-menjalankan-database)
6. [Pengujian Otomatis (Test Suite)](#6-pengujian-otomatis-test-suite)
7. [Perintah Praktis Docker (Cheat Sheet)](#7-perintah-praktis-docker-cheat-sheet)
8. [Troubleshooting & Solusi](#8-troubleshooting--solusi)

---

## 1. Arsitektur & Komponen Docker

Middleware ini dibangun di atas **WSO2 Micro Integrator (MI)** yang mengemas artefak integrasi enterprise:
- **Base Image**: `wso2/wso2mi:4.6.0`
- **Application Package**: `middleware-assa_1.0.0.car` (Composite Application Archive)
- **Database Driver**: `mariadb-java-client-3.3.3.jar` (di-inject ke `/home/wso2carbon/wso2mi-4.6.0/lib/`)
- **Smart Entrypoint Bridge (`entrypoint.sh`)**: Skrip cerdas yang secara otomatis menjembatani koneksi database `127.0.0.1:3307` dari dalam container ke host Windows (`host.docker.internal:3307`) atau container MariaDB tanpa perlu memodifikasi kode XML sequence!

### Pemetaan Port (Exposed Ports)
| Port | Protokol | Keterangan |
| :--- | :--- | :--- |
| `8290` | HTTP | **Endpoint Utama REST API** (Pass-through transport) |
| `8253` | HTTPS | Secure REST API |
| `9164` | HTTPS | WSO2 MI Management API |
| `3307` | TCP | Database MariaDB (Host / Container) |

---

## 2. Prasyarat Sistem

1. **Docker Desktop**: Pastikan Docker Desktop dalam keadaan **Running**.
2. **Java & Maven Wrapper**: Terinstall untuk kompilasi `.car` (sudah tersedia `mvnw.cmd`).
3. **Database MariaDB**: MariaDB lokal aktif di port `3307` (atau gunakan mode container standalone).

---

## 3. Struktur File Terkait Docker

```text
middleware-assa-all/
├── docker-compose.yml                       # Docker Compose root
├── PANDUAN_SETUP_DOCKER.md                  # Dokumentasi panduan ini
├── scripts/
│   └── init_mariadb.sql                     # Skrip DDL tabel & indeks
└── middleware-assa/middleware-assa/middleware-assa/
    ├── Dockerfile                           # Definisi image middleware
    ├── docker-compose.yml                   # Docker Compose sub-project
    ├── .env                                 # Konfigurasi environment variabel
    ├── test_all.ps1                         # Automated test suite
    ├── deployment/
    │   ├── deployment.toml                  # Konfigurasi server WSO2
    │   ├── docker/
    │   │   └── entrypoint.sh                # Script jembatan port DB forwarder
    │   └── libs/
    │       └── mariadb-java-client-3.3.3.jar# JDBC Driver MariaDB
    └── target/
        └── middleware-assa_1.0.0.car        # Artefak biner WSO2
```

---

## 4. Langkah-Langkah Menjalankan Middleware

### Langkah 1: Pastikan Docker Desktop Aktif
Periksa status Docker di terminal PowerShell:
```powershell
docker info
```

### Langkah 2: Build Ulang File `.car` (Jika ada perubahan kode)
Masuk ke direktori proyek dan jalankan:
```powershell
cd middleware-assa\middleware-assa\middleware-assa
.\mvnw.cmd clean compile
```
*File `target/middleware-assa_1.0.0.car` akan dibuat secara otomatis.*

### Langkah 3: Jalankan Container dengan Docker Compose
Dari folder proyek (atau dari root workspace):
```powershell
docker compose up -d
```

### Langkah 4: Cek Status Container
```powershell
docker compose ps
```
Tunggu sekitar 15–20 detik hingga status menampilkan:
`Up (healthy)`

### Langkah 5: Uji Health Check Endpoint
Buka browser atau terminal:
```powershell
Invoke-RestMethod -Uri "http://localhost:8290/health"
```
Respons:
```json
{
  "status": "UP",
  "timestamp": "2026-09-15T09:25:51"
}
```

---

## 5. Dua Mode Menjalankan Database

### Mode A: Menggunakan MariaDB Lokal di Host Windows (Default)
Secara default, container WSO2 MI akan terhubung ke MariaDB di laptop/komputer Anda (port `3307`).
- File `.env`:
  ```properties
  DB_HOST=host.docker.internal
  DB_PORT=3307
  ```
- Cukup jalankan:
  ```powershell
  docker compose up -d
  ```

### Mode B: Menjalankan MariaDB Sepenuhnya di Docker (Standalone)
Jika di komputer lain yang tidak memiliki MariaDB lokal, jalankan MariaDB di dalam Docker dengan skema otomatis dari `init_mariadb.sql`:
```powershell
docker compose --profile standalone up -d
```
*MariaDB container akan otomatis terinisiasi dan listen di port `3308` host (agar tidak bentrok dengan 3307).*

---

## 6. Pengujian Otomatis (Test Suite)

Setelah container aktif di port `8290`, Anda dapat menjalankan seluruh skenario pengujian (11 skenario) menggunakan PowerShell:

```powershell
cd middleware-assa\middleware-assa\middleware-assa
powershell -ExecutionPolicy Bypass -File .\test_all.ps1
```

### Daftar Skenario Pengujian:
1. `[TEST 1]` **Health Check Liveness** (`/health`) -> `200 OK`
2. `[TEST 2]` **Health Check Readiness** (`/health/ready`) -> `200 OK`
3. `[TEST 3]` **Auth Guard: Tanpa Token** -> `401 Unauthorized`
4. `[TEST 4]` **Auth Guard: Token Palsu** -> `401 Unauthorized`
5. `[TEST 5]` **Scope Guard: App B panggil Branch** -> `403 Forbidden`
6. `[TEST 6]` **Scope Guard: App B panggil Customer** -> `403 Forbidden`
7. `[TEST 7]` **Validasi Parameter: Vehicle tanpa plat** -> `400 Bad Request`
8. `[TEST 8]` **Vehicle Service Live (App B Token)** -> `200 OK` + Catat DB
9. `[TEST 9]` **Vehicle Service Live (QA Token)** -> `200 OK` + Catat DB
10. `[TEST 10]` **Customer Service (App A Token)** -> `200 OK` + Catat DB
11. `[TEST 11]` **Branch Service (App A Token)** -> `200 OK` + Catat DB

### Verifikasi Catatan di Database MariaDB
Periksa apakah transaksi dan audit log berhasil dicatat:
```powershell
& "C:\Users\eksad\Downloads\assa\mariadb\bin\mariadb.exe" -u root -P 3307 -D assa_middleware_db -e "SELECT id, transaction_id, endpoint, status, attempt_count, created_at FROM api_transaction ORDER BY id DESC LIMIT 5;"
```

---

## 7. Perintah Praktis Docker (Cheat Sheet)

| Kebutuhan | Perintah |
| :--- | :--- |
| **Menjalankan Middleware** | `docker compose up -d` |
| **Melihat Log Real-time** | `docker compose logs -f middleware-assa` |
| **Melihat Status Container** | `docker compose ps` |
| **Menghentikan Middleware** | `docker compose stop` |
| **Menghapus Container** | `docker compose down` |
| **Build Ulang Image Docker** | `docker compose build --no-cache` |
| **Masuk ke Shell Container** | `docker exec -it middleware-assa bash` |

---

## 8. Troubleshooting & Solusi

### 1. Error: `failed to connect to the docker API at npipe:...`
- **Penyebab**: Docker Desktop belum dibuka atau servicenya berhenti.
- **Solusi**: Buka aplikasi Docker Desktop di Windows dan tunggu hingga ikon Docker di taskbar menunjukkan warna hijau (*Engine running*).

### 2. Error: `Socket fail to connect to host (Connection refused)`
- **Penyebab**: MariaDB di host port `3307` belum aktif.
- **Solusi**: Pastikan service MariaDB berjalan di port 3307. Anda bisa mengeceknya via PowerShell:
  ```powershell
  Test-NetConnection -ComputerName localhost -Port 3307
  ```

### 3. Hot-Reloading Kode WSO2
Jika Anda mengedit API atau Sequence di VS Code:
1. Jalankan `.\mvnw.cmd clean compile`
2. Container Docker otomatis membaca file `.car` terbaru karena telah di-mount via volume di `docker-compose.yml`!
3. WSO2 MI akan otomatis melakukan hot-deploy dalam ~3 detik tanpa perlu restart container.
