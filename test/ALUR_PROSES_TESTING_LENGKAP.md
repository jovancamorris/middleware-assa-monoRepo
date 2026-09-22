# 📘 Panduan Arsitektur & Alur Proses Pengujian Lengkap ASSA Middleware
## *Materi Belajar Engineer & Panduan Presentasi Arsitektur Enterprise (End-to-End Flow)*

Dokumen ini menjelaskan secara mendalam **bagaimana setiap tes dijalankan, komponen WSO2 Micro Integrator (MI) mana saja yang aktif, logika filter/kondisi internal yang dievaluasi, interaksi ke Database MariaDB port 3307, hingga format respons akhir** yang diterima oleh klien.

Dokumen ini dirancang khusus sebagai **bahan presentasi arsitektur** dan **materi onboarding** bagi software engineer atau siapa pun yang baru mempelajari integrasi enterprise.

---

## 🏛️ Arsitektur Aliran Request (High-Level Overview)

Sebelum membedah alur per tes, berikut adalah peta perjalanan sebuah request ketika masuk ke ASSA Middleware:

```mermaid
flowchart TD
    Client(["💻 Klien / Frontend / API Caller"]) --> Entrypoint["🚪 API Entrypoint (WSO2 MI Port 8290)"]
    
    subgraph SecurityLayer ["1. Lapisan Keamanan (Auth & Scope Guard)"]
        Entrypoint --> CheckHeader{"Header Authorization ada?"}
        CheckHeader -- "Tidak" --> Err401["❌ 401 Unauthorized (Header Bearer Wajib)"]
        CheckHeader -- "Ya" --> ValidateToken{"Validasi Token & Role Registry"}
        ValidateToken -- "Palsu / Tidak Terdaftar" --> Err401Token["❌ 401 Unauthorized (Token Invalid)"]
        ValidateToken -- "Valid (App A / B / QA)" --> CheckScope{"Cek Izin Scope (RBAC)"}
        CheckScope -- "Tidak Berhak" --> Err403["❌ 403 Forbidden (Scope Ditolak)"]
    end

    subgraph ObservabilityLayer ["2. Lapisan Observability & Validasi"]
        CheckScope -- "Lolos" --> GenCorrId["Generate / Echo X-Correlation-Id"]
        GenCorrId --> ConsoleLog["Print Structured JSON Log ke Console"]
        ConsoleLog --> ParamValidation{"Validasi Parameter Wajib"}
        ParamValidation -- "Kosong" --> Err400["❌ 400 Bad Request"]
    end

    subgraph IdempotencyLayer ["3. Lapisan Idempotency & Database Tracking"]
        ParamValidation -- "Lolos" --> CheckTrxId{"Header X-Transaction-Id ada?"}
        CheckTrxId -- "Ya" --> LookupDB[("🔍 Query MariaDB api_transaction")]
        LookupDB --> IsDuplicate{"Pernah SUCCESS sebelumnya?"}
        IsDuplicate -- "Ya (Duplikat)" --> ReturnCache["⚡ Replay Response Payload dari DB Cache (X-Idempotent-Replay: true)"]
        IsDuplicate -- "Belum (Baru)" --> InsertDB[("📝 Insert api_transaction (Status: PROCESSING)")]
        CheckTrxId -- "Tidak" --> SkipIdemp["Lanjut tanpa pelacakan database"]
    end

    subgraph ResiliencyLayer ["4. Lapisan Resiliency & 3x Retry Loop"]
        InsertDB --> ResolveURL["Resolve Dynamic Backend URL (4-Layer Priority)"]
        SkipIdemp --> ResolveURL
        ResolveURL --> CallBackend["🚀 Panggil External Backend (AWS QA / SAP Core)"]
        CallBackend --> BackendResult{"Hasil Pemanggilan Backend"}
        
        BackendResult -- "Sukses (200 OK)" --> UpdateSuccess[("✅ Update DB: SUCCESS + Insert Log Percobaan")]
        UpdateSuccess --> Return200["📤 Return HTTP 200 OK ke Klien"]
        
        BackendResult -- "Gagal (5xx / Timeout)" --> RecordFailLog[("⚠️ Insert api_transaction_log (Percobaan Gagal)")]
        RecordFailLog --> CheckRetry{"Attempt < 3?"}
        CheckRetry -- "Ya (Attempt 1 atau 2)" --> WaitInterval["⏳ Jeda Waktu (DO SLEEP interval detik)"]
        WaitInterval --> CallBackend
        CheckRetry -- "Tidak (Sudah 3x Gagal)" --> MarkFailed[("🚨 Update DB: FAILED + Jadwal Antrean Asinkron")]
        MarkFailed --> AlertConsole["📢 Trigger ALERT MONITORING Log"]
        AlertConsole --> Return502["❌ Return HTTP 502 Bad Gateway (Max Retries Exhausted)"]
    end

    ReturnCache --> Client
    Return200 --> Client
    Return400 --> Client
    Return401 --> Client
    Return401Token --> Client
    Err403 --> Client
    Return502 --> Client
```

---

# 📑 DAFTAR ISI PENJELASAN TES

- **[BAGIAN I: Pengujian Fungsional, Keamanan & Validasi (Test 1 - 11)](#bagian-i-pengujian-fungsional-keamanan--validasi)**
  - [Tes 1: Liveness Probe (`/health`)](#tes-1-liveness-probe-health)
  - [Tes 2: Readiness Probe (`/health/ready`)](#tes-2-readiness-probe-healthready)
  - [Tes 3: Keamanan - Akses Tanpa Token (401)](#tes-3-keamanan---akses-tanpa-token-401)
  - [Tes 4: Keamanan - Akses dengan Token Palsu (401)](#tes-4-keamanan---akses-dengan-token-palsu-401)
  - [Tes 5: Scope Guard - App B Akses Branch (403)](#tes-5-scope-guard---app-b-akses-branch-403)
  - [Tes 6: Scope Guard - App B Akses Customer (403)](#tes-6-scope-guard---app-b-akses-customer-403)
  - [Tes 7: Validasi Parameter - Vehicle Tanpa Plat Nomor (400)](#tes-7-validasi-parameter---vehicle-tanpa-plat-nomor-400)
  - [Tes 8: Pemanggilan Sukses Live Backend - Vehicle Service (Token App B, 200)](#tes-8-pemanggilan-sukses-live-backend---vehicle-service-token-app-b-200)
  - [Tes 9: Pemanggilan Sukses Live Backend - Vehicle Service (Token QA, 200)](#tes-9-pemanggilan-sukses-live-backend---vehicle-service-token-qa-200)
  - [Tes 10: Integrasi Branch Service (Token App A, 200 / Graceful Non-VPN)](#tes-10-integrasi-branch-service-token-app-a-200--graceful-non-vpn)
  - [Tes 11: Integrasi Customer Service & Correlation ID Tracing (200)](#tes-11-integrasi-customer-service--correlation-id-tracing-200)
- **[BAGIAN II: Pengujian Resiliency, 3x Retry, Idempotency & MariaDB (Test 12 - 16)](#bagian-ii-pengujian-resiliency-3x-retry-idempotency--mariadb)**
  - [Tes 12: Pemanggilan Sukses & Pencatatan Transaksi MariaDB (Idempotency Key)](#tes-12-pemanggilan-sukses--pencatatan-transaksi-mariadb-idempotency-key)
  - [Tes 13: Idempotency Guard - Deteksi Request Duplikat & Replay Cache DB](#tes-13-idempotency-guard---deteksi-request-duplikat--replay-cache-db)
  - [Tes 14: Simulasi Backend Down - 3x Retry Loop dengan Jeda, Alerting & Status FAILED](#tes-14-simulasi-backend-down---3x-retry-loop-dengan-jeda-alerting--status-failed)
  - [Tes 15: Asynchronous Background Retry Worker (`/api/worker/retry`)](#tes-15-asynchronous-background-retry-worker-apiworkerretry)
  - [Tes 16: Audit Database MariaDB Port 3307 via DBeaver / CLI](#tes-16-audit-database-mariadb-port-3307-via-dbeaver--cli)
- **[Tabel Rangkuman Matriks untuk Presentasi](#-tabel-rangkuman-matriks-untuk-presentasi)**

---

# BAGIAN I: Pengujian Fungsional, Keamanan & Validasi

---

### Tes 1: Liveness Probe (`/health`)

#### 🎯 1. Tujuan & Skenario Bisnis
Memverifikasi apakah runtime engine WSO2 Micro Integrator menyala, sehat (*healthy*), dan siap menerima koneksi HTTP. Endpoint ini wajib ada untuk Kubernetes Pod Liveness Probe, Docker Healthcheck, atau Load Balancer (AWS ALB / NGINX).

#### 📥 2. Spesifikasi Request
- **Method & URL**: `GET http://localhost:8290/health`
- **Header**: Tidak memerlukan header atau token autentikasi.
- **cURL**:
  ```powershell
  curl.exe -i "http://localhost:8290/health"
  ```

#### ⚙️ 3. Alur Eksekusi Internal (Code Trace)
1. Request diterima oleh file [HealthAPI.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/apis/HealthAPI.xml) pada resource uri-template `/health`.
2. Masuk ke sequence [HealthCheckSeq.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/sequences/HealthCheckSeq.xml).
3. Mengambil tanggal & waktu sistem saat ini menggunakan XPath function `fn:concat(get-property('SYSTEM_DATE', 'yyyy-MM-dd'), 'T', get-property('SYSTEM_DATE', 'HH:mm:ss'))`.
4. Mediating PayloadFactory menyusun JSON format:
   ```json
   { "status": "UP", "timestamp": "$1" }
   ```
5. Properti `HTTP_SC` diset menjadi `200`. Mediator `<respond/>` langsung mengirimkan balikan ke klien.
6. **Interaksi Backend & Database**: **TIDAK ADA** (Zero latency, dijawab langsung dari memori runtime WSO2 MI).

#### 📤 4. Respons Akhir
- **HTTP Status**: `200 OK`
- **Body JSON**:
  ```json
  {
    "status": "UP",
    "timestamp": "2026-09-15T10:15:20"
  }
  ```

---

### Tes 2: Readiness Probe (`/health/ready`)

#### 🎯 1. Tujuan & Skenario Bisnis
Memverifikasi apakah middleware tidak hanya menyala, tetapi juga siap menyalurkan trafik ke sistem hilir (*upstream dependencies*). Digunakan oleh orchestrator sebelum mengarahkan trafik produksi ke instance ini.

#### 📥 2. Spesifikasi Request
- **Method & URL**: `GET http://localhost:8290/health/ready`
- **Header**: Tanpa token.
- **cURL**:
  ```powershell
  curl.exe -i "http://localhost:8290/health/ready"
  ```

#### ⚙️ 3. Alur Eksekusi Internal (Code Trace)
1. Request diterima oleh [HealthAPI.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/apis/HealthAPI.xml) pada resource `/health/ready`.
2. Sequence [HealthReadySeq.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/sequences/HealthReadySeq.xml) dijalankan.
3. Membaca konfigurasi konektivitas dasar, memastikan engine listener siap, dan menyusun JSON respons.
4. Mediating PayloadFactory mengembalikan properti status `"READY"` dan backend status `"UP"`.
5. Mediator `<respond/>` mengeksekusi pengembalian HTTP 200.

#### 📤 4. Respons Akhir
- **HTTP Status**: `200 OK`
- **Body JSON**:
  ```json
  {
    "status": "READY",
    "backend": "UP",
    "timestamp": "2026-09-15T10:15:21"
  }
  ```

---

### Tes 3: Keamanan - Akses Tanpa Token (401)

#### 🎯 1. Tujuan & Skenario Bisnis
Memastikan prinsip **Zero Trust Security**. Semua endpoint domain bisnis (`/api/branches/*`, `/api/customers/*`, `/api/vehicles/*`) wajib terlindungi. Jika ada pihak yang memanggil API tanpa header `Authorization`, sistem harus menolaknya di gerbang terluar sebelum membebani sumber daya internal.

#### 📥 2. Spesifikasi Request
- **Method & URL**: `GET http://localhost:8290/api/branches/getByCreateDate?companyCode=1000`
- **Header**: *Kosong* (Tanpa Authorization).
- **cURL**:
  ```powershell
  curl.exe -i "http://localhost:8290/api/branches/getByCreateDate?companyCode=1000"
  ```

#### ⚙️ 3. Alur Eksekusi Internal (Code Trace)
1. Request masuk ke [BranchAPI.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/apis/BranchAPI.xml).
2. Properti `requiredScope` di-set menjadi `"branches"`.
3. Memanggil sequence pengaman terpusat [AuthGuardSeq.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/sequences/AuthGuardSeq.xml).
4. `AuthGuardSeq` membaca header: `$trp:Authorization`.
5. Filter mengevaluasi kondisi: `string-length($ctx:authHeader) = 0` (Header kosong).
6. Masuk blok penolakan:
   - `ERROR_CODE` = `401`
   - `ERROR_MESSAGE` = `"Unauthorized"`
   - `ERROR_DETAIL` = `"Header Authorization wajib disertakan dengan format 'Bearer <token>'."`
7. Memanggil [ErrorResponseSeq.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/sequences/ErrorResponseSeq.xml) untuk standardisasi JSON RFC-7807 error format.
8. Mediator `<drop/>` dipanggil. Alur **berhenti seketika**. Backend SAP tidak dipanggil sama sekali.

#### 📤 4. Respons Akhir
- **HTTP Status**: `401 Unauthorized`
- **Body JSON**:
  ```json
  {
    "error": true,
    "message": "Unauthorized",
    "detail": "Header Authorization wajib disertakan dengan format 'Bearer <token>'."
  }
  ```

---

### Tes 4: Keamanan - Akses dengan Token Palsu (401)

#### 🎯 1. Tujuan & Skenario Bisnis
Mencegah serangan brute-force atau token yang tidak terdaftar/kadaluwarsa. Sistem memeriksa integritas token terhadap *App Registry*.

#### 📥 2. Spesifikasi Request
- **Method & URL**: `GET http://localhost:8290/api/branches/getByCreateDate?companyCode=1000`
- **Header**: `Authorization: Bearer token-ngawur-atau-palsu`
- **cURL**:
  ```powershell
  curl.exe -i "http://localhost:8290/api/branches/getByCreateDate?companyCode=1000" -H "Authorization: Bearer token-ngawur"
  ```

#### ⚙️ 3. Alur Eksekusi Internal (Code Trace)
1. Request masuk ke [BranchAPI.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/apis/BranchAPI.xml) lalu ke [AuthGuardSeq.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/sequences/AuthGuardSeq.xml).
2. Memeriksa format: string diawali dengan `"Bearer "` -> **Lolos**.
3. Mengekstrak raw token menggunakan XPath: `fn:substring-after($ctx:authHeader, 'Bearer ')` -> Nilai: `"token-ngawur"`.
4. Token dicocokkan bertingkat (*multi-tenant app lookup*):
   - Apakah sama dengan Token App A? -> *Bukan*.
   - Apakah sama dengan Token App B? -> *Bukan*.
   - Apakah sama dengan Token App QA? -> *Bukan*.
5. Karena tidak cocok dengan registry manapun, masuk ke blok `else`:
   - `ERROR_CODE` = `401`
   - `ERROR_MESSAGE` = `"Unauthorized"`
   - `ERROR_DETAIL` = `"Token tidak valid, tidak dikenal, atau telah dicabut."`
6. `ErrorResponseSeq` dipanggil dan eksekusi di-drop.

#### 📤 4. Respons Akhir
- **HTTP Status**: `401 Unauthorized`
- **Body JSON**:
  ```json
  {
    "error": true,
    "message": "Unauthorized",
    "detail": "Token tidak valid, tidak dikenal, atau telah dicabut."
  }
  ```

---

### Tes 5: Scope Guard - App B Akses Branch (403)

#### 🎯 1. Tujuan & Skenario Bisnis
Memverifikasi **Role-Based Access Control (RBAC)** dan *Principle of Least Privilege*. Aplikasi B (*App B*) adalah microservice yang secara kontrak bisnis hanya boleh mengelola kendaraan (`vehicles`). Jika App B mencoba mengakses data kantor cabang (`branches`), akses harus ditolak meskipun tokennya valid.

#### 📥 2. Spesifikasi Request
- **Method & URL**: `GET http://localhost:8290/api/branches/getByCreateDate?companyCode=1000`
- **Header**: `Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881` (Token Asli App B)
- **cURL**:
  ```powershell
  curl.exe -i "http://localhost:8290/api/branches/getByCreateDate?companyCode=1000" -H "Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881"
  ```

#### ⚙️ 3. Alur Eksekusi Internal (Code Trace)
1. [BranchAPI.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/apis/BranchAPI.xml) mendefinisikan: `<property name="requiredScope" value="branches"/>`.
2. Masuk ke [AuthGuardSeq.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/sequences/AuthGuardSeq.xml):
   - Token diekstrak: `"988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881"`.
   - Teridentifikasi sebagai: `appId = "app_b"`, `appScopes = "vehicles"`.
3. Masuk ke pengecekan scope:
   - Kondisi filter: `not(fn:contains($ctx:appScopes, $ctx:requiredScope))`
   - String `"vehicles"` **tidak mengandung** kata `"branches"`.
4. Evaluasi bernilai `TRUE` (Pelanggaran Scope):
   - `ERROR_CODE` = `403`
   - `ERROR_MESSAGE` = `"Forbidden"`
   - `ERROR_DETAIL` = `"Aplikasi (app_b) tidak memiliki izin untuk scope: branches"`
5. `ErrorResponseSeq` dipanggil dan pesan dikembalikan langsung ke klien dengan kode status 403.

#### 📤 4. Respons Akhir
- **HTTP Status**: `403 Forbidden`
- **Body JSON**:
  ```json
  {
    "error": true,
    "message": "Forbidden",
    "detail": "Aplikasi (app_b) tidak memiliki izin untuk scope: branches"
  }
  ```

---

### Tes 6: Scope Guard - App B Akses Customer (403)

#### 🎯 1. Tujuan & Skenario Bisnis
Mirip dengan Tes 5, memastikan App B dilarang membaca data rahasia pelanggan (*customers*).

#### 📥 2. Spesifikasi Request
- **Method & URL**: `GET http://localhost:8290/api/customers/getByCreateDate?companyCode=1000`
- **Header**: `Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881`
- **cURL**:
  ```powershell
  curl.exe -i "http://localhost:8290/api/customers/getByCreateDate?companyCode=1000" -H "Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881"
  ```

#### ⚙️ 3. Alur Eksekusi Internal (Code Trace)
1. [CustomerAPI.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/apis/CustomerAPI.xml) menetapkan: `requiredScope = "customers"`.
2. `AuthGuardSeq` mengenali token sebagai `app_b` dengan scope `vehicles`.
3. Karena `vehicles` tidak memiliki izin `customers`, filter memicu penolakan 403 Forbidden.
4. Response dikembalikan seketika.

#### 📤 4. Respons Akhir
- **HTTP Status**: `403 Forbidden`
- **Body JSON**:
  ```json
  {
    "error": true,
    "message": "Forbidden",
    "detail": "Aplikasi (app_b) tidak memiliki izin untuk scope: customers"
  }
  ```

---

### Tes 7: Validasi Parameter - Vehicle Tanpa Plat Nomor (400)

#### 🎯 1. Tujuan & Skenario Bisnis
Memvalidasi input pengguna sebelum diteruskan ke backend hilir (*fail-fast pattern*). Backend AWS ASSA memerlukan plat nomor kendaraan untuk mencari data. Jika parameter tidak dikirim, middleware langsung mengembalikan pesan error yang jelas dan ramah developer (*developer-friendly error*), mencegah pemborosan panggilan jaringan ke AWS.

#### 📥 2. Spesifikasi Request
- **Method & URL**: `GET http://localhost:8290/api/vehicles/getByLicensePlate?companyCode=1000`
- **Header**: `Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881`
- **cURL**:
  ```powershell
  curl.exe -i "http://localhost:8290/api/vehicles/getByLicensePlate?companyCode=1000" -H "Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881"
  ```

#### ⚙️ 3. Alur Eksekusi Internal (Code Trace)
1. Masuk ke [VehicleAPI.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/apis/VehicleAPI.xml) -> `AuthGuardSeq` meloloskan request (karena token `app_b` memiliki scope `vehicles`).
2. Masuk ke [VehicleGetByLicensePlateSeq.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/sequences/VehicleGetByLicensePlateSeq.xml).
3. Parameter diekstrak dari URL: `licensePlate = $url:licensePlate`.
4. Evaluasi filter: `string-length($ctx:licensePlate) = 0` -> **TRUE (Parameter Kosong)**.
5. Masuk ke blok penanganan error:
   - `ERROR_CODE` = `400`
   - `ERROR_MESSAGE` = `"Bad Request"`
   - `ERROR_DETAIL` = `"Query parameter 'licensePlate' wajib disertakan (contoh: B-9065-UCU)."`
6. `ErrorResponseSeq` merangkai payload JSON dan mengirimkannya dengan status 400.

#### 📤 4. Respons Akhir
- **HTTP Status**: `400 Bad Request`
- **Body JSON**:
  ```json
  {
    "error": true,
    "message": "Bad Request",
    "detail": "Query parameter 'licensePlate' wajib disertakan (contoh: B-9065-UCU)."
  }
  ```

---

### Tes 8: Pemanggilan Sukses Live Backend - Vehicle Service (Token App B, 200)

#### 🎯 1. Tujuan & Skenario Bisnis
Menguji skenario ideal / jalur utama (*Happy Path*): Klien mengirimkan parameter valid dengan token yang sesuai, middleware meneruskannya ke server backend eksternal AWS QA ASSA, dan mengembalikan data kendaraan riil.

#### 📥 2. Spesifikasi Request
- **Method & URL**: `GET http://localhost:8290/api/vehicles/getByLicensePlate?companyCode=1000&licensePlate=B-9065-UCU`
- **Header**: `Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881`
- **cURL**:
  ```powershell
  curl.exe -i "http://localhost:8290/api/vehicles/getByLicensePlate?companyCode=1000&licensePlate=B-9065-UCU" -H "Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881"
  ```

#### ⚙️ 3. Alur Eksekusi Internal (Code Trace)
1. **Security**: `AuthGuardSeq` memvalidasi token `app_b` dan mengizinkan scope `vehicles`.
2. **Validasi**: `licensePlate` bernilai `"B-9065-UCU"` -> Lolos validasi.
3. **Observability**: [LogRequestSeq.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/sequences/LogRequestSeq.xml) membuat `X-Correlation-Id` unik (misal: `corr-20260915102000123`) dan mencetak structured log JSON di console terminal.
4. **URL Resolution**: [ResolveBaseUrlSeq.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/sequences/ResolveBaseUrlSeq.xml) menyelesaikan target host AWS QA (`https://devapim.assa.id`).
5. **Dynamic Endpoint Call**: [SafeApiCallWithRetrySeq.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/sequences/SafeApiCallWithRetrySeq.xml) memanggil `ExtServiceDynamicEndpoint` dengan menyuntikkan API Key backend ASSA yang valid.
6. Backend AWS ASSA mengembalikan HTTP 200 dengan payload data mobil Daihatsu Gran Max.
7. Middleware menyalurkan data kembali ke klien secara utuh (*pass-through*).

#### 📤 4. Respons Akhir
- **HTTP Status**: `200 OK`
- **Body JSON**:
  ```json
  {
    "data": {
      "vehicle": {
        "equipment": "10034207",
        "license_plate": "B-9065-UCU",
        "type": "DAIHATSU GRAN MAX BLIND VAN AC 1.3 M/T",
        "year": "2019",
        "branch_code": "1103",
        "funloc": "ASSA-1103-01-LT",
        "funloc_desc": "Jakarta3-Sudirman-SewaLongTerm",
        "km": 139382
      },
      "cmd": { "code": null, "name": null, "address": null },
      "umd": { "name": "-", "telephone": "85782185488", "address": "---" }
    }
  }
  ```

---

### Tes 9: Pemanggilan Sukses Live Backend - Vehicle Service (Token QA, 200)

#### 🎯 1. Tujuan & Skenario Bisnis
Memverifikasi bahwa tim QA (*App QA*) yang memiliki hak akses penuh (*wildcard/all domains*) dapat mengakses endpoint vehicle menggunakan token QA khusus mereka (`ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d`).

#### 📥 2. Spesifikasi Request
- **Method & URL**: `GET http://localhost:8290/api/vehicles/getByLicensePlate?companyCode=1000&licensePlate=B-9065-UCU`
- **Header**: `Authorization: Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d`
- **cURL**:
  ```powershell
  curl.exe -i "http://localhost:8290/api/vehicles/getByLicensePlate?companyCode=1000&licensePlate=B-9065-UCU" -H "Authorization: Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d"
  ```

#### ⚙️ 3. Alur Eksekusi Internal (Code Trace)
1. Masuk ke `AuthGuardSeq`: Token cocok dengan entri QA Registry.
2. Diberikan identitas `appId = "app_qa"` dengan akses scope `branches, customers, vehicles`.
3. Lolos pengecekan scope dan diteruskan ke backend AWS eksternal.
4. Mendapatkan data kendaraan yang sama dengan status HTTP 200 OK.

---

### Tes 10: Integrasi Branch Service (Token App A, 200 / Graceful Non-VPN)

#### 🎯 1. Tujuan & Skenario Bisnis
Menguji integrasi dengan backend internal korporat ASSA (**SAP Core**). Aplikasi A (*App A*) memiliki izin scope `branches`. Jika laptop penguji terhubung ke VPN internal ASSA, data cabang akan didapatkan (200 OK). Jika tidak terhubung VPN, middleware mendeteksi koneksi terputus dan melakukan penanganan error secara anggun (*graceful failure*) tanpa menyebabkan runtime crash.

#### 📥 2. Spesifikasi Request
- **Method & URL**: `GET http://localhost:8290/api/branches/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11`
- **Header**: `Authorization: Bearer 3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013`
- **cURL**:
  ```powershell
  curl.exe -i "http://localhost:8290/api/branches/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11" -H "Authorization: Bearer 3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013"
  ```

#### ⚙️ 3. Alur Eksekusi Internal (Code Trace)
1. Token `app_a` diverifikasi dan memiliki izin untuk scope `branches`.
2. Masuk ke [BranchGetByCreateDateSeq.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/sequences/BranchGetByCreateDateSeq.xml):
   - Mengekstrak parameter: `companyCode`, `dateStart`, `dateEnd`.
   - Jika ada parameter kosong di URL, otomatis mengambil nilai default (`companyCode=1000`, `dateStart=2020-01-01`, `dateEnd=2026-09-11`).
3. Menyelesaikan alamat SAP Core melalui `ResolveBaseUrlSeq` (`https://sapcoreapi.assa.id` / `10.1.20.56`).
4. Memanggil `SapCoreDynamicEndpoint`.
   - **Kondisi A (Terhubung VPN ASSA)**: Berhasil mendapatkan list cabang -> mengembalikan HTTP 200 OK.
   - **Kondisi B (Non-VPN)**: Mengalami *Connection Reset / Timeout* -> ditangkap oleh fault sequence dan menghasilkan respons error terstruktur (500/502).

---

### Tes 11: Integrasi Customer Service & Correlation ID Tracing (200)

#### 🎯 1. Tujuan & Skenario Bisnis
Menguji propagasi header pelacakan (*Distributed Tracing*). Jika klien mengirimkan header `X-Correlation-Id`, middleware wajib mempertahankan (*echo back*) ID tersebut ke header respons agar memudahkan pelacakan log antar sistem (*end-to-end trace*).

#### 📥 2. Spesifikasi Request
- **Method & URL**: `GET http://localhost:8290/api/branches/getByCreateDate`
- **Header**:
  - `Authorization: Bearer 3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013`
  - `X-Correlation-Id: CUSTOM-TRACE-AUDIT-9999`
- **cURL**:
  ```powershell
  curl.exe -i "http://localhost:8290/api/branches/getByCreateDate" -H "Authorization: Bearer 3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013" -H "X-Correlation-Id: CUSTOM-TRACE-AUDIT-9999"
  ```

#### ⚙️ 3. Alur Eksekusi Internal (Code Trace)
1. Di dalam `LogRequestSeq`, middleware membaca `$trp:X-Correlation-Id`.
2. Nilai `"CUSTOM-TRACE-AUDIT-9999"` dideteksi dan tidak di-overwrite dengan UUID acak.
3. Middleware menyematkan header ini ke konteks pesan (`$axis2:X-Correlation-Id`).
4. Ketika respons dikirim kembali ke klien, header `X-Correlation-Id: CUSTOM-TRACE-AUDIT-9999` otomatis tertera pada HTTP response headers.

---

# BAGIAN II: Pengujian Resiliency, 3x Retry, Idempotency & MariaDB

Bagian ini adalah pengujian fitur inti kehandalan sistem (*enterprise resiliency*) yang berinteraksi langsung dengan **Database MariaDB lokal (Port 3307)**.

---

### Tes 12: Pemanggilan Sukses & Pencatatan Transaksi MariaDB (Idempotency Key)

#### 🎯 1. Tujuan & Skenario Bisnis
Mencatat seluruh siklus hidup transaksi ke dalam database audit. Ketika klien menyertakan header `X-Transaction-Id` (atau `Idempotency-Key`), transaksi harus dicatat ke tabel `api_transaction` dengan status `SUCCESS`, serta rincian latensi dan status HTTP pemanggilan dicatat di tabel `api_transaction_log`.

#### 📥 2. Spesifikasi Request
- **Method & URL**: `GET http://localhost:8290/api/vehicles/getByLicensePlate?companyCode=1000&licensePlate=B-9065-UCU`
- **Header**:
  - `Authorization: Bearer 3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013`
  - `X-Transaction-Id: TRX-MANUAL-001`
- **cURL**:
  ```powershell
  curl.exe -i "http://localhost:8290/api/vehicles/getByLicensePlate?companyCode=1000&licensePlate=B-9065-UCU" `
    -H "Authorization: Bearer 3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013" `
    -H "X-Transaction-Id: TRX-MANUAL-001"
  ```

#### ⚙️ 3. Alur Eksekusi Internal (Code Trace)
1. **Ekstraksi Key**: [IdempotencyGuardSeq.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/sequences/IdempotencyGuardSeq.xml) membaca header `X-Transaction-Id` bernilai `"TRX-MANUAL-001"`.
2. **Cek Database (Query DB)**:
   - Menjalankan mediator `<dblookup>` ke MariaDB Port 3307:
     ```sql
     SELECT status, response_payload FROM api_transaction WHERE transaction_id = 'TRX-MANUAL-001';
     ```
   - Karena transaksi ini baru pertama kali dikirim, hasil query adalah **KOSONG**.
3. **Pencatatan Awal Transaksi (Insert DB)**:
   - Menjalankan mediator `<dbreport>`:
     ```sql
     INSERT INTO api_transaction (transaction_id, endpoint, http_method, status, attempt_count) 
     VALUES ('TRX-MANUAL-001', '/api/vehicles/getByLicensePlate', 'GET', 'PROCESSING', 0);
     ```
4. **Pemanggilan Backend**:
   - `SafeApiCallWithRetrySeq` memanggil backend AWS ASSA.
   - Panggilan berhasil dengan status HTTP 200 dan payload diterima.
5. **Pencatatan Riwayat Percobaan**:
   - Memanggil `DbRecordAttemptLogSeq.xml`:
     ```sql
     INSERT INTO api_transaction_log (transaction_id, attempt_number, endpoint, response_status, duration_ms)
     VALUES ('TRX-MANUAL-001', 1, '/api/vehicles/getByLicensePlate', 200, 482);
     ```
6. **Pembaruan Status Akhir Transaksi**:
   - Menjalankan update ke `api_transaction`:
     ```sql
     UPDATE api_transaction 
     SET status = 'SUCCESS', attempt_count = 1, response_payload = '{"data":{...}}'
     WHERE transaction_id = 'TRX-MANUAL-001';
     ```
7. Header `X-Transaction-Id: TRX-MANUAL-001` disematkan pada respons klien.

#### 📊 4. Verifikasi di Database MariaDB
```sql
SELECT transaction_id, status, attempt_count FROM api_transaction WHERE transaction_id = 'TRX-MANUAL-001';
```
| transaction_id | status | attempt_count |
| :--- | :--- | :---: |
| `TRX-MANUAL-001` | **`SUCCESS`** | **`1`** |

```sql
SELECT transaction_id, attempt_number, response_status, duration_ms FROM api_transaction_log WHERE transaction_id = 'TRX-MANUAL-001';
```
| transaction_id | attempt_number | response_status | duration_ms |
| :--- | :---: | :---: | :---: |
| `TRX-MANUAL-001` | **`1`** | **`200`** | ~480 ms |

---

### Tes 13: Idempotency Guard - Deteksi Request Duplikat & Replay Cache DB

#### 🎯 1. Tujuan & Skenario Bisnis
Mencegah eksekusi ganda (*double processing*) pada kasus jaringan tidak stabil (misal: koneksi klien terputus sebelum menerima ACK, lalu klien me-retry request yang sama). Middleware **tidak boleh memanggil backend eksternal dua kali**. Cukup ambil data yang sudah pernah disimpan di database lalu balas langsung (*replay response*).

#### 📥 2. Spesifikasi Request
- **Method & URL**: Kirim **PERSIS SAMA** dengan Tes 12.
- **Header**: `X-Transaction-Id: TRX-MANUAL-001`
- **cURL**:
  ```powershell
  curl.exe -i "http://localhost:8290/api/vehicles/getByLicensePlate?companyCode=1000&licensePlate=B-9065-UCU" `
    -H "Authorization: Bearer 3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013" `
    -H "X-Transaction-Id: TRX-MANUAL-001"
  ```

#### ⚙️ 3. Alur Eksekusi Internal (Code Trace)
1. Request masuk ke `IdempotencyGuardSeq`.
2. Membaca header `X-Transaction-Id: TRX-MANUAL-001`.
3. Menjalankan query `<dblookup>` ke MariaDB:
   ```sql
   SELECT status, response_payload FROM api_transaction WHERE transaction_id = 'TRX-MANUAL-001';
   ```
4. Hasil query:
   - Properti `dbTrxStatus` bernilai `"SUCCESS"`.
   - Properti `dbSavedPayload` berisi JSON data kendaraan yang tersimpan di Tes 12.
5. Evaluasi filter: `($ctx:dbTrxStatus = 'SUCCESS') and (string-length($ctx:dbSavedPayload) > 0)` -> **TRUE (Request Duplikat Terdeteksi!)**.
6. Masuk ke blok Cache Replay:
   - Menambahkan header HTTP: `X-Idempotent-Replay: true`.
   - Memulihkan body pesan menggunakan `<payloadFactory>` dari `$ctx:dbSavedPayload`.
   - Memanggil `<respond/>`.
7. **Bukti Ketahanan**: Backend AWS ASSA **SAMA SEKALI TIDAK DITELEPON**. Waktu respons instan (< 10 ms).

#### 📤 4. Respons Akhir & Bukti di Database
- **HTTP Header**: Memuat `X-Idempotent-Replay: true`.
- **Query Verifikasi Database**:
  ```sql
  SELECT COUNT(*) FROM api_transaction_log WHERE transaction_id = 'TRX-MANUAL-001';
  ```
  *Hasil count:* **Tetap 1** (Membuktikan tidak ada penambahan panggilan backend baru).

---

### Tes 14: Simulasi Backend Down - 3x Retry Loop dengan Jeda, Alerting & Status FAILED

#### 🎯 1. Tujuan & Skenario Bisnis
Menguji skenario ketika backend hilir sedang *down*, *crashed*, atau *unreachable*. Middleware harus:
1. Menahan kegagalan sementara (*transient failure*) dengan mencoba hingga **maksimal 3 kali percobaan**.
2. Memberikan jeda waktu antar percobaan (dikonfigurasi dinamis, misal 1 detik saat tes).
3. Mencatat setiap kali kegagalan di tabel `api_transaction_log`.
4. Jika sudah 3x gagal berturut-turut, tandai transaksi sebagai **`FAILED`** di `api_transaction`.
5. Memicu log khusus `[ALERT MONITORING]` untuk sistem monitoring (seperti Grafana Loki / ELK).
6. Menjadwalkan waktu retry berikutnya (`next_retry_at`) ke dalam antrean asinkron.
7. Mengembalikan HTTP `502 Bad Gateway` ke klien.

#### 📥 2. Spesifikasi Request
- **Method & URL**: `GET http://localhost:8290/api/branches/getByCreateDate?companyCode=1000`
- **Header**:
  - `Authorization: Bearer 3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013`
  - `X-Transaction-Id: TRX-FAIL-MANUAL-001`
  - `X-Retry-Interval-Seconds: 1` *(Jeda retry 1 detik untuk percepatan testing)*
  - `X-Target-Backend-Url: http://127.0.0.1:59999` *(Port fiktif yang sengaja mati)*
- **cURL**:
  ```powershell
  curl.exe -i "http://localhost:8290/api/branches/getByCreateDate?companyCode=1000" `
    -H "Authorization: Bearer 3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013" `
    -H "X-Transaction-Id: TRX-FAIL-MANUAL-001" `
    -H "X-Retry-Interval-Seconds: 1" `
    -H "X-Target-Backend-Url: http://127.0.0.1:59999"
  ```

#### ⚙️ 3. Alur Eksekusi Internal (Code Trace)

```mermaid
sequenceDiagram
    autonumber
    actor Client
    participant WSO2 as WSO2 MI (Retry Loop)
    participant MariaDB as MariaDB (Port 3307)
    participant Backend as Backend Down (Port 59999)

    Client->>WSO2: GET /api/branches (X-Transaction-Id: TRX-FAIL-MANUAL-001)
    WSO2->>MariaDB: INSERT api_transaction (Status: PROCESSING)
    
    rect rgb(255, 235, 235)
        Note over WSO2,Backend: PERCOBAAN 1 (Attempt 1)
        WSO2->>Backend: Call http://127.0.0.1:59999
        Backend--xWSO2: Connection Refused (Error 101503)
        WSO2->>MariaDB: INSERT api_transaction_log (Attempt 1, Status: 500)
        WSO2->>MariaDB: DO SLEEP(1) [Jeda 1 detik]
    end

    rect rgb(255, 235, 235)
        Note over WSO2,Backend: PERCOBAAN 2 (Attempt 2)
        WSO2->>Backend: Call http://127.0.0.1:59999
        Backend--xWSO2: Connection Refused (Error 101503)
        WSO2->>MariaDB: INSERT api_transaction_log (Attempt 2, Status: 500)
        WSO2->>MariaDB: DO SLEEP(1) [Jeda 1 detik]
    end

    rect rgb(255, 220, 220)
        Note over WSO2,Backend: PERCOBAAN 3 (Attempt 3 - Final)
        WSO2->>Backend: Call http://127.0.0.1:59999
        Backend--xWSO2: Connection Refused (Error 101503)
        WSO2->>MariaDB: INSERT api_transaction_log (Attempt 3, Status: 500)
    end

    Note over WSO2: Max Retries Exhausted (3x Gagal)
    WSO2->>WSO2: Log [ALERT MONITORING] Transaksi TRX-FAIL-MANUAL-001 GAGAL
    WSO2->>MariaDB: UPDATE api_transaction SET status='FAILED', attempt_count=3, next_retry_at=NOW()+5m
    WSO2-->>Client: HTTP 502 Bad Gateway (Max Retries Exhausted)
```

1. Request diterima, `api_transaction` diinisialisasi dengan status `PROCESSING`.
2. **Attempt 1**:
   - Memanggil `http://127.0.0.1:59999`.
   - Mengalami *Connection Refused*. Fault handler aktif.
   - Menyimpan log baris ke-1 di `api_transaction_log` (attempt: 1, status: 500).
   - Menghitung `retryCount = 1` (< 3).
   - Menjalankan jeda waktu native database: `DO SLEEP(1)`.
3. **Attempt 2**:
   - Memanggil kembali backend. Tetap gagal.
   - Menyimpan log baris ke-2 di `api_transaction_log` (attempt: 2, status: 500).
   - `retryCount = 2` (< 3).
   - Menjalankan jeda `DO SLEEP(1)`.
4. **Attempt 3**:
   - Memanggil backend untuk ketiga kalinya. Tetap gagal.
   - Menyimpan log baris ke-3 di `api_transaction_log` (attempt: 3, status: 500).
   - `retryCount = 3` (Batas maksimal tercapai).
5. **Final Alert & Database Update**:
   - Mencetak log console penting:
     ```text
     [ALERT MONITORING] Transaksi ID: TRX-FAIL-MANUAL-001 GAGAL setelah 3x percobaan. Status akhir: FAILED. Dimasukkan ke Asynchronous Retry Queue (MariaDB).
     ```
   - Mengupdate tabel `api_transaction`:
     ```sql
     UPDATE api_transaction 
     SET status = 'FAILED', attempt_count = 3, next_retry_at = DATE_ADD(NOW(), INTERVAL 300 SECOND)
     WHERE transaction_id = 'TRX-FAIL-MANUAL-001';
     ```
   - Mengembalikan HTTP 502 Bad Gateway ke pemanggil.

#### 📤 4. Respons Akhir
- **HTTP Status**: `502 Bad Gateway`
- **Body JSON**:
  ```json
  {
    "error": true,
    "message": "Bad Gateway - Max Retries Exhausted",
    "detail": "External API gagal diakses setelah 3x percobaan berturut-turut. Transaksi (ID: TRX-FAIL-MANUAL-001) telah dicatat dengan status FAILED dan masuk ke antrean retry asinkron."
  }
  ```

#### 📊 5. Bukti Data di MariaDB (3 Percobaan Tercatat)
```sql
SELECT attempt_number, response_status, error_message FROM api_transaction_log WHERE transaction_id = 'TRX-FAIL-MANUAL-001';
```
| attempt_number | response_status | error_message |
| :---: | :---: | :--- |
| **`1`** | `500` | Error connecting to the back end |
| **`2`** | `500` | Error connecting to the back end |
| **`3`** | `500` | Error connecting to the back end |

---

### Tes 15: Asynchronous Background Worker (`/api/worker/retry`)

#### 🎯 1. Tujuan & Skenario Bisnis
Menjamin data transaksi **tidak pernah hilang** (*Zero Data Loss Guarantee*) saat backend eksternal mati berjam-jam. Setelah request gagal di sesi sinkron, worker asinkron ini dapat dijalankan secara periodik (misal via Cron / Windows Task Scheduler setiap 5 menit) untuk memindai transaksi yang `FAILED`, memperbarui status menjadi `RETRY`, dan menjadwalkan ulang eksekusi.

#### 📥 2. Spesifikasi Request
- **Method & URL**: `POST http://localhost:8290/api/worker/retry` (atau `GET`)
- **Header**: Tanpa token (Internal Worker Endpoint).
- **cURL**:
  ```powershell
  curl.exe -i -X POST "http://localhost:8290/api/worker/retry"
  ```

#### ⚙️ 3. Alur Eksekusi Internal (Code Trace)
1. Request masuk ke [WorkerAPI.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/apis/WorkerAPI.xml) pada uri-template `/retry`.
2. Mengeksekusi sequence [RetryWorkerSeq.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/sequences/RetryWorkerSeq.xml).
3. Melakukan eksekusi query update batch di MariaDB:
   ```sql
   UPDATE api_transaction 
   SET status = 'RETRY', next_retry_at = DATE_ADD(NOW(), INTERVAL 300 SECOND) 
   WHERE status IN ('FAILED', 'RETRY') 
     AND (next_retry_at IS NULL OR next_retry_at <= NOW());
   ```
4. Mencatat log eksekusi worker ke `api_transaction_log`:
   ```sql
   INSERT INTO api_transaction_log (transaction_id, attempt_number, endpoint, response_status, error_message)
   VALUES ('WORKER-CRON-RUN', 0, '/api/worker/retry', 202, 'Worker batch scan completed');
   ```
5. Mengembalikan laporan status eksekusi berformat JSON dengan status HTTP 200 OK.

#### 📤 4. Respons Akhir
- **HTTP Status**: `200 OK`
- **Body JSON**:
  ```json
  {
    "worker": "RetryWorker",
    "status": "COMPLETED",
    "timestamp": "2026-09-15T10:30:00",
    "message": "Background retry worker executed successfully."
  }
  ```

---

### Tes 16: Audit Database MariaDB Port 3307 via DBeaver / CLI

#### 🎯 1. Tujuan & Skenario Bisnis
Membuktikan secara visual kepada manajemen atau tim auditor bahwa middleware menyimpan jejak audit lengkap (*full audit trail*).

#### 💻 2. Parameter Koneksi DBeaver / MariaDB
- **Host**: `127.0.0.1` atau `localhost`
- **Port**: `3307` *(MariaDB khusus ASSA)*
- **Database**: `assa_middleware_db`
- **Username**: `root`
- **Password**: *(Kosongkan / no password)*

#### 📝 3. Query SQL Verifikasi
Buka jendela SQL Editor di DBeaver dan jalankan:

```sql
USE assa_middleware_db;

-- 1. Cek ringkasan transaksi utama, statusnya, dan jumlah percobaannya
SELECT 
    id, 
    transaction_id, 
    endpoint, 
    status, 
    attempt_count, 
    next_retry_at, 
    created_at, 
    updated_at
FROM api_transaction 
ORDER BY id DESC;

-- 2. Cek detail rekaman setiap percobaan pemanggilan (latency, response code, error)
SELECT 
    id, 
    transaction_id, 
    attempt_number, 
    endpoint, 
    response_status, 
    error_message, 
    duration_ms, 
    created_at
FROM api_transaction_log 
ORDER BY id DESC;
```

---

# 📊 Tabel Rangkuman Matriks untuk Presentasi

Gunakan tabel rangkuman ini saat menampilkan slide presentasi ke audiens atau tim lead:

| No. | Skenario Pengujian | Input Kunci | Expected HTTP Status | Interaksi Backend Eksternal | Interaksi MariaDB Port 3307 | Manfaat Bisnis / Arsitektur |
| :---: | :--- | :--- | :---: | :---: | :---: | :--- |
| **1** | Liveness Probe | `GET /health` | **200 OK** | Tidak ada | Tidak ada | Memastikan server menyala (K8s / LB) |
| **2** | Readiness Probe | `GET /health/ready` | **200 OK** | Tidak ada | Tidak ada | Memastikan siap melayani trafik |
| **3** | Auth: Tanpa Token | Tanpa header | **401 Unauthorized** | Tidak ada | Tidak ada | Perlindungan gerbang terluar (Zero Trust) |
| **4** | Auth: Token Palsu | `Bearer token-ngawur` | **401 Unauthorized** | Tidak ada | Tidak ada | Mencegah akses liar / ilegal |
| **5** | Scope: App B -> Branch | `token-app-b` | **403 Forbidden** | Tidak ada | Tidak ada | Pembatasan akses berbasis peran (RBAC) |
| **6** | Scope: App B -> Customer | `token-app-b` | **403 Forbidden** | Tidak ada | Tidak ada | Perlindungan data pribadi pelanggan |
| **7** | Validasi Parameter | Tanpa `licensePlate` | **400 Bad Request** | Tidak ada | Tidak ada | Fail-fast, cegah request sia-sia ke cloud |
| **8** | Vehicle Happy Path | `licensePlate=B-9065-UCU` | **200 OK** | Panggil AWS QA | Tidak ada | Menyalurkan data kendaraan nyata |
| **9** | QA Super Access | Token QA | **200 OK** | Panggil AWS QA | Tidak ada | Akses tim QA untuk validasi sistem |
| **10** | Branch Service | Token App A | **200 OK / 502** | Panggil SAP Core | Tidak ada | Integrasi SAP Korporat ASSA |
| **11** | Customer & Tracing | `X-Correlation-Id` | **200 OK / 502** | Panggil SAP Core | Tidak ada | Distributed Tracing memudahkan debug |
| **12** | Simpan Transaksi Baru | `X-Transaction-Id` baru | **200 OK** | Panggil AWS QA | **INSERT** `SUCCESS` + Log Attempt 1 | Pelacakan audit transaksi bisnis |
| **13** | Idempotency Cache Replay| `X-Transaction-Id` sama | **200 OK** | **TIDAK PANGGIL** | **READ ONLY** (Ambil dari cache DB) | Cegah eksekusi ganda, hemat kuota API |
| **14** | 3x Retry Loop Failover | Port down (59999) | **502 Bad Gateway** | Panggil 3x Loop | **INSERT** 3 log gagal + Status `FAILED` | Tahan gangguan sementara & catat antrean |
| **15** | Background Retry Worker | `POST /worker/retry` | **200 OK** | Tidak ada | **UPDATE** status `RETRY` + backoff | Menjamin transaksi tidak hilang saat down |
| **16** | Visual DB Audit | DBeaver / MariaDB CLI | Query Result | - | Audit Trail | Bukti kepatuhan & observabilitas data |
| **17** | Vendor Create FTP (VMD) | `POST /api/vendors/create` | **201 Created** | Upload XML ke FTP `devqaxmlpool.assa.id` | **INSERT** `SUCCESS` + Log Attempt 1 | Mengubah JSON V2 ATLAS ke XML resmi & deliver ke SAP |
| **18** | Service Request (SR) Fan-Out | `POST /api/service-requests` | **200 OK / 207** | Fan-out paralel: ATLAS (toggle) + ASSA Ext Services | **INSERT** `SUCCESS` + Log Attempt 1 | Integrasi paralel Omnichannel ke ATLAS & External Services |

---
*Dokumen ini dibuat otomatis sebagai panduan resmi arsitektur pengujian ASSA Middleware (WSO2 Micro Integrator).*
