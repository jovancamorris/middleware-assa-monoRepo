# 📘 Panduan Lengkap Struktur File & Arsitektur ASSA Middleware
### *Buku Saku WSO2 Micro Integrator untuk Pemula & Tim Engineer Baru*

Selamat datang di proyek **ASSA Middleware**! Dokumen ini dirancang khusus sebagai panduan komprehensif yang ramah pemula untuk memahami seluruh struktur folder, fungsi setiap file, dan bagaimana file-file tersebut saling terhubung satu sama lain.

> **📌 Update v2 (Monorepo)**: Proyek kini berbentuk **monorepo multi-service** bernama `wso2-mi-monorepo`, bukan lagi single-project `middleware-assa`. Setiap domain (Branch, Customer, Vehicle, Vendor, SPK, Service Request) menjadi **service terpisah** di dalam `integrations/`, sedangkan sequence yang dipakai bersama (Auth, Logging, Error, Idempotency, Retry, DB, dll) dipusatkan di modul **`shared/`**. Konsep dasar WSO2 (API → Sequence → Endpoint) tetap sama; yang berubah adalah tata letak folder.

---

## 🧭 DAFTAR ISI
1. [Konsep Dasar untuk Pemula (Mental Model)](#1-konsep-dasar-untuk-pemula-mental-model)
2. [Peta Struktur Direktori Proyek](#2-peta-struktur-direktori-proyek)
3. [Bedah Detail Seluruh File & Fungsinya](#3-bedah-detail-seluruh-file--fungsinya)
   - [A. File Konfigurasi & Build Root](#a-file-konfigurasi--build-root)
   - [B. Folder Deployment (`deployment/`)](#b-folder-deployment-deployment)
   - [C. Layer API (`artifacts/apis/`)](#c-layer-api-artifactsapis)
   - [D. Layer Endpoint (`artifacts/endpoints/`)](#d-layer-endpoint-artifactsendpoints)
   - [E. Layer Orchestration & Reusable Sequences (`artifacts/sequences/`)](#e-layer-orchestration--reusable-sequences-artifactssequences)
   - [F. Layer Konfigurasi Aplikasi (`resources/conf/`)](#f-layer-konfigurasi-aplikasi-resourcesconf)
4. [Diagram Alur & Korelasi Antar File (Relationship Matrix)](#4-diagram-alur--korelasi-antar-file-relationship-matrix)
5. [Studi Kasus: Perjalanan 1 Buah Request (End-to-End)](#5-studi-kasus-perjalanan-1-buah-request-end-to-end)
6. [SOP Menambah Fitur / API Baru (Untuk Engineer Baru)](#6-sop-menambah-fitur--api-baru-untuk-engineer-baru)

---

## 1. Konsep Dasar untuk Pemula (Mental Model)

Sebelum melihat ratusan baris kode XML, mari kita pahami analogi sederhananya di dunia nyata:

### Apa itu Middleware?
> **Analogi:** Bayangkan sebuah **Restoran Mewah**:
> - **Pelanggan (Client / Frontend App)**: Duduk di meja, memesan makanan melalui menu.
> - **Dapur (Backend Server / SAP Core)**: Memasak makanan, bahasanya teknis, sangat sibuk, dan tidak boleh sembarang orang masuk dapur.
> - **Pelayan Profesional (Middleware)**: Menerima pesanan pelanggan, memeriksa apakah pelanggan punya voucher valid (Security), mencatat pesanan di buku kasir (Database Logging), mengantarkan pesanan ke dapur dengan format yang dimengerti koki, dan jika koki sedang sibuk/gagal, pelayan akan mencoba meminta ulang dengan ramah (Retry Mechanism).

### Komponen Kunci di WSO2 Micro Integrator (MI):
1. **API (`artifacts/apis/*.xml`)**: Pintu masuk / Resepsionis. Tugasnya hanya menentukan URL (contoh: `/api/branches`) dan HTTP Method (`GET`, `POST`).
2. **Sequence (`artifacts/sequences/*.xml`)**: SOP / Langkah-langkah kerja berurutan. Misalnya: langkah 1 cek token, langkah 2 catat log, langkah 3 panggil server luar, langkah 4 rapikan respons.
3. **Endpoint (`artifacts/endpoints/*.xml`)**: Buku alamat telepon server luar. Menentukan ke mana data dikirim melalui jaringan internet/intranet.
4. **Property / Message Context (`$ctx:*`)**: Buku catatan kecil sementara milik pelayan untuk menyimpan data selama alur berjalan (misalnya menyimpan user ID, waktu mulai, dll.).
5. **Database Mediator (`<dblookup>` / `<dbreport>`)**: Tangan yang menulis atau membaca data ke MariaDB lokal (Port 3307).

---

## 2. Peta Struktur Direktori Proyek (Monorepo)

Berikut tata letak monorepo `wso2-mi-monorepo/`. Perhatikan tiga bagian besar: **`shared/`** (dipakai semua), **`integrations/`** (service per domain), dan **`platform/`** (infra & base config).

```text
wso2-mi-monorepo/
├── pom.xml                                       # Parent/Aggregator POM (build semua module)
├── docker-compose.yml                            # Jalankan SEMUA service sekaligus (lokal)
├── .github/workflows/deploy-integrations.yml     # CI/CD (build → docker → deploy)
├── scripts/db/init_mariadb_schema.sql            # Skema DB
│
├── shared/                                       # 🧩 ARTEFAK BERSAMA (1 CAR: shared-artifacts)
│   ├── pom.xml
│   ├── connectors/                               # Connector pihak ketiga (opsional)
│   └── src/main/wso2mi/artifacts/sequences/      # Sequence reusable dipakai semua service:
│       ├── AuthGuardSeq.xml                       # 🛡️ Keamanan & Token App Registry
│       ├── LogRequestSeq.xml                      # 📊 Structured JSON Access Logger
│       ├── IdempotencyGuardSeq.xml                # 🔁 Anti Request Ganda & Cache Replay
│       ├── ResolveBaseUrlSeq.xml                  # 🌐 Resolusi Base URL 4-Layer
│       ├── SafeApiCallWithRetrySeq.xml            # 🔄 Panggilan Aman & Loop Retry
│       ├── ApiCallErrorHandlerSeq.xml             # ⚠️ Error Handler + 3x Retry
│       ├── DbRecordAttemptLogSeq.xml              # 📝 Log Attempt ke MariaDB
│       ├── DbRecordTransactionSeq.xml             # 💾 Update Status Transaksi
│       ├── RetryWorkerSeq.xml                     # ⚙️ Worker Asinkron
│       ├── GenericPaginationSeq.xml               # 📄 Response Standar & Pagination
│       ├── HealthCheckSeq.xml                     # 💓 Liveness & Readiness
│       ├── ErrorResponseSeq.xml                   # ❌ Format Error Standar JSON
│       └── FaultHandlerSequence.xml               # 🧯 Fault handler generik
│
├── integrations/                                 # 🚀 SEMUA SERVICE INTEGRASI (1 service = 1 CAR)
│   ├── branch-service/                           # Domain Branch (SAP Core)
│   │   ├── Dockerfile  ├── pom.xml
│   │   └── src/main/wso2mi/artifacts/
    │   │       ├── apis/       (BranchAPI, BranchHealthAPI, BranchReadinessAPI)
│   │       ├── sequences/  (BranchGetByCreateDateSeq)
    │   │       └── endpoints/  (service-specific endpoints)
│   ├── customer-service/                         # Domain Customer (CustomerAPI + CustomerGetByCreateDateSeq)
│   ├── vehicle-service/                          # Domain Vehicle (VehicleAPI + VehicleGetByLicensePlateSeq + ExtServiceDynamicEndpoint)
│   ├── vendor-service/                           # Vendor Master Data (VMD) → XML → FTP   [kerangka]
│   ├── spk-service/                              # SPK Duelist → XML → FTP                [kerangka]
│   └── service-request-service/                  # Service Request fan-out (ATLAS + Ext) + WorkerAPI [kerangka]
│       └── (tiap service punya: apis/, sequences/, endpoints/, resources/conf/config.properties)
│
└── platform/                                     # 🏗️ INFRA & BASE CONFIG
    ├── docker/deployment.toml.j2                 # Template base config WSO2 MI (Jinja2)
    ├── docker/entrypoint.sh                      # Bridge/DB forwarder 127.0.0.1:3307 → DB_HOST:DB_PORT
    └── k8s/base-deployment.yaml                  # Base K8s Deployment + Service
```

> **Kunci monorepo**: sequence di `shared/` **tidak** disalin ke tiap service. WSO2 me-resolve `<sequence key="AuthGuardSeq"/>` saat **runtime** selama `shared-artifacts` CAR ikut dideploy di server yang sama. Dockerfile & docker-compose sudah menyalin `shared/target/*.car` ke setiap image service.

---

## 3. Bedah Detail Seluruh File & Fungsinya

### A. File Konfigurasi & Build Root

#### 1. `pom.xml` (Parent / Aggregator)
- **Fungsi**: POM induk Maven multi-module.
- **Peran**: Mendaftarkan seluruh module (`<modules>`: `shared` + 6 service) dan memusatkan versi (runtime `4.6.0`, driver `3.3.3`, plugin CAR). Menjalankan `mvn clean install` dari sini akan mem-build **shared lebih dulu**, lalu tiap service menghasilkan `.car` sendiri.

#### 2. `<service>/pom.xml` (Per Service)
- **Fungsi**: Build satu service menjadi satu `.car`.
- **Peran**: Mendaftarkan driver MariaDB & connector HTTP, menjalankan `vscode-car-plugin`. **Tidak** mendeklarasikan `shared` sebagai dependency Maven — sequence shared di-resolve saat runtime:
  ```xml
  <dependency>
      <groupId>org.mariadb.jdbc</groupId>
      <artifactId>mariadb-java-client</artifactId>
      <version>${mariadb.driver.version}</version>
  </dependency>
  ```

#### 3. `shared/pom.xml`
- **Fungsi**: Mem-build `shared-artifacts_1.0.0.car` berisi semua sequence reusable.
- **Peran**: CAR ini dideploy bersama tiap service (disalin oleh Dockerfile) agar `<sequence key="..."/>` dapat di-resolve di server.

#### 4. `docker-compose.yml` & `.github/workflows/deploy-integrations.yml`
- **Fungsi**: Menjalankan semua service lokal (compose) dan pipeline CI/CD (build → docker matrix → deploy).
- **Korelasi**: Environment variable (`SAP_CORE_BASE_URL`, `ASSA_EXT_BASE_URL`, `DB_HOST`, `DB_PORT`) dibaca `ResolveBaseUrlSeq.xml` & `entrypoint.sh`.

---

### B. Folder Platform (`platform/`) & Deployment

#### 1. `platform/docker/deployment.toml.j2`
- **Fungsi**: Template base config server runtime WSO2 MI (Jinja2, per-environment).
- **Peran**: Mengatur port HTTP (`8290`), HTTPS (`8253`), VFS transport (untuk vendor/spk), parameter sistem, dan koneksi DB. Placeholder `{{ ... }}` dirender saat build/deploy.

#### 2. `platform/docker/entrypoint.sh`
- **Fungsi**: Bridge entrypoint kontainer.
- **Peran**: Menjalankan TCP forwarder `127.0.0.1:3307 → ${DB_HOST}:${DB_PORT}` sehingga config aplikasi tetap menunjuk `localhost:3307` tanpa diubah antar-environment.

#### 3. `platform/k8s/base-deployment.yaml`
- **Fungsi**: Base manifest Kubernetes (Deployment + Service) dengan probe service-specific `/health/<service>` & `/readiness/<service>`.
- **Peran**: Di-render per service (`__SERVICE_NAME__`, `__IMAGE__`) lalu `kubectl apply`.

#### 4. `<service>/deployment/libs/mariadb-java-client-3.3.3.jar`
- **Fungsi**: Driver JDBC MariaDB (diunduh otomatis oleh Maven per service).
- **Peran**: Memungkinkan WSO2 MI berbicara dengan MariaDB.

---

### C. Layer API (`artifacts/apis/`)

Setiap file di folder ini merepresentasikan satu grup endpoint REST:

#### 1. `BranchAPI.xml`
- **Context**: `/api/branches`
- **Fungsi**: Menerima request terkait cabang (contoh: `/getByCreateDate`).
- **Korelasi**: Memanggil `AuthGuardSeq` untuk cek izin scope `branches`, lalu meneruskan ke `BranchGetByCreateDateSeq`.

#### 2. `CustomerAPI.xml`
- **Context**: `/api/customers`
- **Fungsi**: Menerima request terkait pelanggan ASSA.
- **Korelasi**: Memanggil `AuthGuardSeq` untuk cek izin scope `customers`, lalu meneruskan ke `CustomerGetByCreateDateSeq`.

#### 3. `VehicleAPI.xml`
- **Context**: `/api/vehicles`
- **Fungsi**: Menerima request terkait data armada mobil (contoh: `/getByLicensePlate`).
- **Korelasi**: Memanggil `AuthGuardSeq` untuk cek scope `vehicles`, lalu ke `VehicleGetByLicensePlateSeq`.

#### 4. `HealthAPI.xml` and `ReadinessAPI.xml`
- **Contexts**: `/health/<service>` and `/readiness/<service>`
- **Fungsi**: Separate, service-specific MI liveness and readiness endpoints.
- **Keistimewaan**: Endpoint ini **bebas token** agar Kubernetes / AWS Load Balancer bisa memantau kesehatan server setiap detik tanpa otentikasi.

#### 5. `WorkerAPI.xml`
- **Context**: `/api/worker`
- **Fungsi**: Endpoint operasional (`POST /api/worker/retry`) untuk memicu background worker pemroses antrean retry yang gagal.

---

### D. Layer Endpoint (`artifacts/endpoints/`)

Endpoint adalah koneksi keluar menuju server external:

#### 1. `shared/SapCoreDynamicEndpoint.xml`
- **URL Template**: `{+uri.var.sapBackendUrl}`
- **Fungsi**: Shared and single HTTP exit point toward SAP Core ASSA for branch and customer services.
- **Mengapa Dinamis?**: Tidak ada URL yang di-hardcode. Tanda `+` mencegah WSO2 melakukan double-encode pada tanda tanya `?` atau `&` di URL.

#### 2. `ExtServiceDynamicEndpoint.xml`
- **URL Template**: `{+uri.var.extBackendUrl}`
- **Fungsi**: Pintu keluar HTTP menuju layanan eksternal ASSA Vehicle QA/Dev di AWS.

---

### E. Layer Orchestration & Reusable Sequences (`artifacts/sequences/`)

Inilah "otak" dari middleware:

#### 1. `AuthGuardSeq.xml` (Satpam Keamanan & App Registry)
- **Tugas**:
  1. Membaca header `Authorization: Bearer <token>`. Jika kosong, langsung tolak dengan **401 Unauthorized**.
  2. Mencocokkan token dengan App Registry di `config.properties`:
     - Token App A -> `appId = app_a`, scope: `branches, customers, vehicles`
     - Token App B -> `appId = app_b`, scope: `vehicles`
  3. Memeriksa apakah aplikasi berhak mengakses resource tersebut. Jika tidak berhak, tolak dengan **403 Forbidden**.
  4. Menetapkan atau membuat `X-Correlation-Id` untuk pelacakan end-to-end.

#### 2. `IdempotencyGuardSeq.xml` (Pelindung Transaksi Ganda)
- **Tugas**:
  1. Membaca `X-Transaction-Id` atau `X-Idempotency-Key`.
  2. Mengecek ke tabel `api_transaction` di MariaDB 3307:
     - **Kasus Sukses Sebelumnya**: Langsung mengembalikan respons dari cache (`X-Idempotent-Replay: true`) tanpa memanggil server eksternal lagi!
     - **Kasus Sedang Berjalan**: Mengembalikan **409 Conflict** untuk mencegah race condition.
     - **Kasus Baru**: Mencatat baris baru dengan status `PROCESSING`.

#### 3. `ResolveBaseUrlSeq.xml` (Pencari Alamat Cerdas 4-Layer)
- **Tugas**: Menentukan host URL backend tanpa ada hardcode di XML:
  1. *Layer 0 (Chaos Testing)*: Cek header override `X-Target-Backend-Url`.
  2. *Layer 1*: Cek Environment Variable sistem (`get-property('env', ...)`).
  3. *Layer 2*: Cek System Parameter server (`deployment.toml`).
  4. *Layer 3*: Cek File konfigurasi (`config.properties`).
  5. *Layer 4*: Fallback aman ke server development.

#### 4. `SafeApiCallWithRetrySeq.xml` (Pemanggil External Aman)
- **Tugas**: Menjalankan pemanggilan HTTP ke endpoint luar. Dilengkapi handler error terpusat (`onError="ApiCallErrorHandlerSeq"`). Menghitung waktu durasi eksekusi (`durationMs`), mencatat attempt sukses ke database, dan meneruskan ke pagination.

#### 5. `ApiCallErrorHandlerSeq.xml` (Penangan Error & Percobaan Ulang 3x)
- **Tugas**:
  1. Jika panggilan backend gagal, tangkap kode error dan pesan error.
  2. Catat kegagalan tersebut ke tabel `api_transaction_log`.
  3. Periksa apakah percobaan masih `< 3`:
     - **Ya**: Tampilkan notifikasi log retry, tunggu jeda (default 60 detik atau header `X-Retry-Interval-Seconds`), lalu panggil kembali `SafeApiCallWithRetrySeq`. Jeda dieksekusi native via MariaDB `DO SLEEP(?)`.
     - **Tidak (Sudah 3x gagal)**:
       - Cetak log: `[ALERT MONITORING] Transaksi ID: ... GAGAL setelah 3x percobaan.`
       - Update status di `api_transaction` menjadi `FAILED`.
       - Jadwalkan `next_retry_at` untuk diambil oleh Background Worker.
       - Kembalikan HTTP **502 Bad Gateway** ke client.

#### 6. `DbRecordAttemptLogSeq.xml` & `DbRecordTransactionSeq.xml`
- **Tugas**: Helper mediator untuk melakukan perintah SQL `INSERT INTO api_transaction_log` dan `UPDATE api_transaction` ke MariaDB port 3307.

#### 7. `RetryWorkerSeq.xml` (Pekerja Latar Belakang / Background Worker)
- **Tugas**: Memeriksa tabel `api_transaction` mencari transaksi `FAILED` yang sudah jatuh tempo (`next_retry_at <= NOW()`). Mengubah statusnya menjadi `RETRY` dengan penundaan 5 menit dan mencatat log audit agar transaksi penting tidak hilang saat server backend sempat down beberapa jam.

#### 8. `GenericPaginationSeq.xml`
- **Tugas**: Memformat respons JSON menjadi format standar korporat ASSA yang rapi:
  ```json
  {
    "count": 10,
    "data": [ ... ],
    "pagination": { "page": 1, "perPage": 10, "total": 100 }
  }
  ```

#### 9. `ErrorResponseSeq.xml`
- **Tugas**: Memastikan semua pesan error seragam formatnya:
  ```json
  {
    "error": true,
    "message": "Bad Request / Unauthorized / Bad Gateway",
    "detail": "Keterangan jelas apa yang salah..."
  }
  ```

#### 10. `LogRequestSeq.xml`
- **Tugas**: Menulis access log terstruktur format JSON ke file log server mencakup `timestamp`, `correlationId`, `appId`, `endpoint`, dan `params`.

#### 11. Domain Sequences (`BranchGetByCreateDateSeq`, `CustomerGetByCreateDateSeq`, `VehicleGetByLicensePlateSeq`)
- **Tugas**: Mengorkestrasi parameter URL khusus domain bisnis masing-masing, memvalidasi input wajib, dan menghubungkan flow ke `IdempotencyGuardSeq` dan `SafeApiCallWithRetrySeq`.

---

### F. Layer Konfigurasi Aplikasi (`<service>/src/main/wso2mi/resources/conf/`)

#### `config.properties` (per service)
- **Fungsi**: Sumber konfigurasi tiap service (ada satu salinan di masing-masing service).
- **Isi**:
  - Base URL Dev & Prod SAP Core (`https://devsapcoreapi.assa.id`)
  - Base URL ASSA External Services (`https://assa-ext-services.assa.id/qa`)
  - API Keys & Tokens (Token App A, App B, QA)
  - Pengaturan Database MariaDB (`db.url=jdbc:mariadb://localhost:3307/assa_middleware_db`)
  - Pengaturan Retry Policy (`retry.max.attempts=3`, `retry.interval.seconds=60`)

> **Catatan monorepo**: karena `config.properties` disalin per service, hati-hati agar tidak divergen. Nilai environment-spesifik sebaiknya di-override lewat env var / K8s ConfigMap (dibaca `ResolveBaseUrlSeq`), bukan diedit manual di tiap file.

---

## 4. Diagram Alur & Korelasi Antar File (Relationship Matrix)

Berikut adalah diagram relasi bagaimana setiap komponen saling memanggil:

```mermaid
flowchart TD
    Client["Client / Aplikasi Konsumen"] -->|"HTTP Request + Bearer Token"| API["artifacts/apis/*API.xml"]
    
    subgraph S1 ["1. Keamanan & Identifikasi"]
        API -->|"Wajib Masuk"| AuthGuard["AuthGuardSeq.xml"]
        AuthGuard -.->|"Baca Token & Scope"| Config["resources/conf/config.properties"]
        AuthGuard -->|"Gagal (401/403)"| ErrResp["ErrorResponseSeq.xml"]
    end
    
    subgraph S2 ["2. Domain Orchestration"]
        AuthGuard -->|"Lolos Auth"| DomainSeq["*GetBy*Seq.xml (Branch / Customer / Vehicle)"]
        DomainSeq --> LogReq["LogRequestSeq.xml"]
        DomainSeq --> Idemp["IdempotencyGuardSeq.xml"]
    end
    
    subgraph S3 ["3. Idempotency & Database (Port 3307)"]
        Idemp -->|"Cek Transaksi"| MariaDB[("MariaDB: api_transaction")]
        Idemp -->|"Duplikat Sukses"| CachedResp["Replay Respons Cache (200 OK)"]
        Idemp -->|"In-Flight"| Conflict["409 Conflict"]
    end
    
    subgraph S4 ["4. Resolusi Alamat & Pemanggilan"]
        DomainSeq --> Resolve["ResolveBaseUrlSeq.xml"]
        DomainSeq --> SafeCall["SafeApiCallWithRetrySeq.xml"]
        SafeCall --> Endpoint["artifacts/endpoints/*DynamicEndpoint.xml"]
    end
    
    subgraph S5 ["5. Eksekusi External & Resiliency"]
        Endpoint -->|"Panggil Jaringan"| ExtBackend["Backend Eksternal (SAP Core / AWS)"]
        SafeCall -->|"Sukses (200)"| DbLogSukses["DbRecordAttemptLogSeq.xml"]
        SafeCall -->|"Sukses (200)"| Pagination["GenericPaginationSeq.xml"]
        SafeCall -->|"Gagal / Error"| ErrHandler["ApiCallErrorHandlerSeq.xml"]
    end
    
    subgraph S6 ["6. Retry Loop & Worker"]
        ErrHandler -->|"Catat Attempt"| DbLogFail["DbRecordAttemptLogSeq.xml"]
        ErrHandler -->|"Percobaan < 3x"| SleepDB["MariaDB DO SLEEP(?)"]
        SleepDB -->|"Ulangi Panggilan"| SafeCall
        ErrHandler -->|"Gagal 3x"| Alert["[ALERT MONITORING]"]
        ErrHandler -->|"Update FAILED"| DbTrx["DbRecordTransactionSeq.xml"]
        WorkerAPI["WorkerAPI.xml (/api/worker/retry)"] --> WorkerSeq["RetryWorkerSeq.xml"]
        WorkerSeq -->|"Polling Transaksi FAILED"| MariaDB
    end
    
    CachedResp --> Client
    Conflict --> Client
    Pagination -->|"JSON Standar"| Client
    ErrResp --> Client
```

---

## 5. Studi Kasus: Perjalanan 1 Buah Request (End-to-End)

Mari ikuti apa yang terjadi saat sebuah aplikasi Android ASSA memanggil API:
`GET http://localhost:8290/api/branches/getByCreateDate?companyCode=1000`

1. **Client mengirim HTTP Request** dengan header:
   `Authorization: Bearer 3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013`.
2. **`BranchAPI.xml`** menyambut request tersebut di pintu gerbang `/api/branches/getByCreateDate`.
3. Pintu gerbang mengarahkan pertama kali ke **`AuthGuardSeq.xml`**:
   - Token dicocokkan ke `config.properties`.
   - Ditemukan: token milik `app_a`, memiliki scope izin `branches`. Lolos!
   - Diberi nomor tanda terima pelacakan: `X-Correlation-Id: corr-20260914...`.
4. Masuk ke **`BranchGetByCreateDateSeq.xml`**:
   - Membaca parameter `companyCode=1000`.
   - Memanggil **`LogRequestSeq.xml`** untuk mencatat jejak audit ke log server.
   - Memanggil **`IdempotencyGuardSeq.xml`**: Mengecek ke MariaDB port 3307 apakah request ini pernah sukses sebelumnya. Belum pernah? Buat catatan transaksi baru status `PROCESSING`.
   - Memanggil **`ResolveBaseUrlSeq.xml`**: Mencari tahu URL SAP Core (`https://devsapcoreapi.assa.id`).
   - Menyusun URL lengkap: `https://devsapcoreapi.assa.id/api/Branches/GetByCreateDate?companyCode=1000...`.
5. Memanggil **`SafeApiCallWithRetrySeq.xml`**:
   - Menghubungi **`SapCoreDynamicEndpoint.xml`**.
   - **Jika Server Hidup**: Menerima data JSON mentah, mencatat Attempt 1 sukses ke tabel `api_transaction_log`, mengupdate `api_transaction` menjadi `SUCCESS`, merapikan bentuk respons lewat **`GenericPaginationSeq.xml`**, dan mengirimkan ke Client (`200 OK`).
   - **Jika Server Mati / Error**:
     - Ditangkap oleh **`ApiCallErrorHandlerSeq.xml`**.
     - Percobaan ke-1 gagal dicatat ke `api_transaction_log`.
     - Sistem istirahat sejenak selama 60 detik (`DO SLEEP(60)` di MariaDB).
     - Mencoba Percobaan ke-2... masih gagal, catat lagi.
     - Mencoba Percobaan ke-3... masih gagal, catat lagi.
     - Batas 3x habis! Status di `api_transaction` diubah menjadi `FAILED`.
     - Alert monitoring tercetak di konsol server.
     - Transaksi disimpan di antrean untuk dicoba ulang nanti oleh **`RetryWorkerSeq`**.
     - Client menerima respons rapi dari **`ErrorResponseSeq.xml`**: `502 Bad Gateway - Max Retries Exhausted`.

---

## 6. SOP Menambah Fitur / API Baru (Untuk Engineer Baru)

Di monorepo, tentukan dulu **service mana** yang relevan (mis. fitur Customer → `integrations/customer-service/`). Semua sequence shared (Auth, Log, Idempotency, dll) sudah tersedia di `shared/` dan **tidak perlu dibuat ulang** — cukup rujuk via `<sequence key="..."/>`. Untuk domain benar-benar baru, buat service baru di `integrations/` dan daftarkan di parent `pom.xml` (`<modules>`) + `docker-compose.yml`.

Contoh menambah API Approval (`POST /api/customers/approve`) pada **customer-service** — 3 langkah:

### Langkah 1: Daftarkan Path di `config.properties`
Buka `integrations/customer-service/src/main/wso2mi/resources/conf/config.properties` dan tambahkan:
```properties
sap.api.path.customer.approve=/api/Customer/Approve
```

### Langkah 2: Daftarkan Resource di `CustomerAPI.xml`
Buka `integrations/customer-service/src/main/wso2mi/artifacts/apis/CustomerAPI.xml` dan tambahkan:
```xml
<resource methods="POST" uri-template="/approve">
    <inSequence>
        <property name="requiredScope" value="customers" scope="default" type="STRING"/>
        <sequence key="AuthGuardSeq"/>
        <sequence key="CustomerApproveSeq"/>
    </inSequence>
    <faultSequence>
        <sequence key="ErrorResponseSeq"/>
    </faultSequence>
</resource>
```

### Langkah 3: Buat Sequence Bisnis `CustomerApproveSeq.xml`
Buat file baru di `integrations/customer-service/src/main/wso2mi/artifacts/sequences/CustomerApproveSeq.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<sequence name="CustomerApproveSeq" trace="disable" xmlns="http://ws.apache.org/ns/synapse">
    <!-- 1. Ambil Parameter -->
    <property name="api.endpoint" value="/api/customers/approve" scope="default" type="STRING"/>
    
    <!-- 2. Observability & Idempotency -->
    <sequence key="LogRequestSeq"/>
    <sequence key="IdempotencyGuardSeq"/>
    
    <!-- 3. Dapatkan URL Backend dari Config -->
    <property name="baseUrlConfigKey" value="sap.core.customer.base.url" scope="default" type="STRING"/>
    <property name="envVarKey" value="SAP_CORE_BASE_URL" scope="default" type="STRING"/>
    <sequence key="ResolveBaseUrlSeq"/>
    
    <property name="sapApiPath" expression="get-property('file', 'sap.api.path.customer.approve')" scope="default" type="STRING"/>
    <property name="uri.var.sapBackendUrl" expression="fn:concat($ctx:resolvedBaseUrl, $ctx:sapApiPath)" scope="default" type="STRING"/>
    
    <!-- 4. Panggil Endpoint Aman dengan 3x Retry & MariaDB Logging -->
    <property name="targetEndpointKey" value="SapCoreDynamicEndpoint" scope="default" type="STRING"/>
    <sequence key="SafeApiCallWithRetrySeq"/>
</sequence>
```

Selesai! API baru Anda secara otomatis telah memiliki:
- 🛡️ Proteksi otentikasi token per-aplikasi & scope guard
- 🔁 Pencegahan transaksi ganda (idempotency)
- 🔄 Ketahanan 3x retry otomatis jika server backend sempat timeout
- 📊 Audit logging lengkap di MariaDB port 3307
- ⚙️ Masuk antrean background worker jika terjadi gangguan backend

> **Build & jalankan**: dari root monorepo jalankan `mvn clean install` (mem-build shared + semua service jadi `.car`), lalu `docker compose up --build` untuk menjalankan semua service lokal. Untuk deploy Kubernetes, lihat `docs/GUIDE_DOCKER_KUBERNETES.md`.

### Menambah Service Baru (Domain Baru)
1. Buat folder `integrations/<nama>-service/` berisi `pom.xml`, `Dockerfile`, dan `src/main/wso2mi/artifacts/`.
2. Daftarkan di parent `pom.xml` pada blok `<modules>`.
3. Tambahkan service di `docker-compose.yml` (port host unik) dan CI/CD matrix.
4. Rujuk sequence shared via `<sequence key="..."/>` — jangan menyalin ulang.

---
*Dokumen ini disusun sebagai panduan standar rekayasa perangkat lunak ASSA Middleware (v2, arsitektur monorepo). Simpan dan bagikan dokumen ini kepada setiap anggota tim pengembang baru.*
