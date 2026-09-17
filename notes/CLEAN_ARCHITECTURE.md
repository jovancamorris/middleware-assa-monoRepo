# 🏛️ Clean Architecture — ASSA Middleware (WSO2 Micro Integrator)

Dokumen ini mendefinisikan **arsitektur ideal (target state)** untuk monorepo integrasi ASSA
berbasis WSO2 Micro Integrator (MI). Tujuannya: mengelola **200+ API** ke backend SAP Core
secara konsisten, aman, dan bebas duplikasi, dengan pemisahan tanggung jawab yang jelas.

> Status: **Blueprint / Target Architecture.** Dokumen ini adalah acuan "seharusnya",
> bukan cerminan kondisi kode saat ini. Gap terhadap implementasi nyata dicatat di bagian 9.
>
> Dokumen ini menerjemahkan konsep dari `KONSEP_BESAR.md` (visi), `KONSEP.md` (autentikasi
> token per-aplikasi), dan `KONSEP_MONITORING.md` (observability) menjadi komponen teknis.

---

## 1. Prinsip Desain (Design Principles)

Arsitektur dibangun di atas prinsip berikut:

| Prinsip | Penerapan di WSO2 MI |
|---|---|
| **Separation of Concerns** | API (routing) ≠ Orchestration (sequence) ≠ Connectivity (endpoint) ≠ Config |
| **DRY (Don't Repeat Yourself)** | Logika pagination, search, resolusi URL, dan logging dipusatkan di reusable sequence |
| **Single Source of Truth** | Semua konfigurasi (URL, path, default) berasal dari config eksternal, bukan XML |
| **Externalized Configuration** | Tidak ada nilai environment-specific yang di-hardcode di artifact |
| **Convention over Configuration** | Penamaan artifact mengikuti pola baku sehingga API ke-3..200 mudah ditambah |
| **Secure by Default** | Semua akses wajib token per-aplikasi (Auth Guard di depan); tidak ada rahasia di artifact |
| **Fail Safe & Observable** | Setiap resource punya fault handler; setiap request tervalidasi, tercatat (structured log), dan dapat ditelusuri (correlationId) |

> Konsep keamanan token per-aplikasi dijabarkan di `KONSEP.md`, dan konsep monitoring di
> `KONSEP_MONITORING.md`. Dokumen ini menerjemahkan keduanya menjadi komponen arsitektur konkret.

---

## 2. Layered Architecture (Logical View)

```
┌──────────────────────────────────────────────────────────────────┐
│  CLIENT LAYER                                                      │
│  (curl / Postman / Browser / PowerShell / aplikasi konsumen)      │
└───────────────────────────────┬──────────────────────────────────┘
                                 │ HTTP (REST + query params)
┌───────────────────────────────▼──────────────────────────────────┐
│  API LAYER  —  artifacts/apis/*.xml                               │
│  • Routing: context + uri-template  →  memetakan ke sequence      │
│  • Cross-cutting: faultSequence (error handling standar)          │
│  • TIDAK berisi logika bisnis atau URL backend                    │
└───────────────────────────────┬──────────────────────────────────┘
                                 │ sequence key
┌───────────────────────────────▼──────────────────────────────────┐
│  SECURITY LAYER (Auth Guard)  —  AuthGuardSeq (dipanggil paling    │
│  awal di setiap resource)                                         │
│  • Wajib token per-aplikasi (Authorization: Bearer <token>)       │
│  • Validasi token → App Registry → set properti appId             │
│  • Gagal → ErrorResponseSeq (401/403) & hentikan alur             │
│  • Lihat KONSEP.md untuk detail konsep                            │
└───────────────────────────────┬──────────────────────────────────┘
                                 │ lolos auth (appId ter-set)
┌───────────────────────────────▼──────────────────────────────────┐
│  ORCHESTRATION LAYER  —  artifacts/sequences/<Domain><Op>Seq.xml   │
│  • Baca parameter request                                         │
│  • Terapkan default dari config                                   │
│  • Resolusi Base URL (4-layer chain)  →  delegasi ke helper       │
│  • Susun URL backend  →  panggil endpoint                         │
│  • Delegasi ke reusable pagination/response                       │
└───────────────┬───────────────────────────────┬──────────────────┘
                │ reusable                       │ reusable
┌───────────────▼───────────────┐   ┌───────────▼──────────────────┐
│  SHARED / UTILITY LAYER        │   │  CONNECTIVITY LAYER           │
│  artifacts/sequences/          │   │  artifacts/endpoints/         │
│   • AuthGuardSeq (security)    │   │   • SapCoreDynamicEndpoint    │
│   • GenericPaginationSeq       │   │     (1 endpoint dinamis)      │
│   • ResolveBaseUrlSeq (helper) │   │                               │
│   • LogRequestSeq (structured) │   │                               │
│   • ErrorResponseSeq           │   │                               │
│   • HealthCheckSeq (liveness/  │   │                               │
│     readiness)                 │   │                               │
└───────────────┬────────────────┘   └───────────┬──────────────────┘
                │                                 │ HTTP
┌───────────────▼─────────────────────────────────▼─────────────────┐
│  CONFIGURATION LAYER  (Single Source of Truth)                     │
│  Priority:  ENV VAR  >  deployment.toml  >  config.properties      │
│  • Base URL, API paths, default query params, log path             │
│  • App Registry (appId → token hash, status, scopes) untuk Auth    │
└───────────────────────────────┬──────────────────────────────────┘
                                 │ HTTPS (outbound)
┌───────────────────────────────▼──────────────────────────────────┐
│  BACKEND LAYER  —  SAP Core API (https://<env>sapcoreapi.assa.id)  │
└───────────────────────────────────────────────────────────────────┘
```

**Aturan dependensi (Dependency Rule):** aliran hanya boleh ke bawah.
API tahu tentang Sequence; Sequence tahu tentang Endpoint & Shared; tidak ada layer bawah
yang tahu tentang layer di atasnya. Backend tidak pernah di-referensi langsung dari API layer.

---

## 3. Struktur Monorepo (Physical View)

```
assa_middleware/                                 <-- Monorepo Root
├── pom.xml                                       <-- Parent POM (multi-module reactor)
├── CLEAN_ARCHITECTURE.md                         <-- Dokumen ini
├── mvnw / mvnw.cmd / .mvn/                        <-- Maven wrapper
│
├── customer-integration/                         <-- Domain: Customer & Branch
│   ├── pom.xml
│   ├── deployment/
│   │   ├── deployment.toml                        <-- Config server + system.parameter
│   │   └── docker/Dockerfile                      <-- Image per-domain (opsional)
│   └── src/main/wso2mi/
│       ├── artifacts/
│       │   ├── apis/
│       │   │   └── BranchAPI.xml                  <-- Routing (context: /api/branches)
│       │   ├── endpoints/
│       │   │   └── SapCoreDynamicEndpoint.xml     <-- [Connectivity] 1 endpoint dinamis
│       │   └── sequences/
│       │       ├── BranchByBranchCodeSeq.xml      <-- Orchestration per operasi
│       │       ├── BranchByCreateDateSeq.xml
│       │       ├── AuthGuardSeq.xml               <-- [Shared] validasi token per-app (KONSEP.md)
│       │       ├── ResolveBaseUrlSeq.xml          <-- [Shared] resolusi URL 4-layer
│       │       ├── GenericPaginationSeq.xml       <-- [Shared] pagination + search
│       │       ├── LogRequestSeq.xml              <-- [Shared] structured access logging
│       │       ├── HealthCheckSeq.xml             <-- [Shared] liveness/readiness (KONSEP_MONITORING.md)
│       │       └── ErrorResponseSeq.xml           <-- [Shared] format error standar
│       └── resources/conf/
│           └── config.properties                  <-- [Config] default + App Registry token
│
├── finance-integration/                          <-- Domain: Finance (Invoices, GL, Billing)
│   └── (struktur identik dengan customer-integration)
│
└── procurement-integration/                      <-- Domain: Procurement (Vendors, PO)
    └── (struktur identik dengan customer-integration)
```

**Prinsip modularisasi:** setiap domain = satu Maven module = satu CAR file independen.
Domain dapat di-deploy, di-scale, dan di-rilis terpisah tanpa memengaruhi domain lain.

---

## 4. Tanggung Jawab Tiap Komponen (Component Responsibilities)

### 4.1 API Layer (`artifacts/apis/<Domain>API.xml`)
- **HANYA** mendefinisikan `context`, `uri-template`, dan method.
- Mendelegasikan setiap resource ke tepat satu sequence orchestration.
- Memanggil `AuthGuardSeq` **paling awal** di `inSequence` (gerbang token).
- Menyertakan `faultSequence` yang memanggil `ErrorResponseSeq` (bukan inline error).
- **DILARANG**: menyimpan URL, logika bisnis, atau transformasi payload.

### 4.2 Security Layer / Auth Guard (`artifacts/sequences/AuthGuardSeq.xml`)
- Dipanggil **pertama** sebelum logika bisnis apa pun.
- Membaca header `Authorization: Bearer <token>`.
- Memvalidasi token terhadap **App Registry** (config statis → DB → OAuth2/JWT, bertahap).
- Menetapkan properti `appId` (dipakai untuk logging & audit).
- Jika token kosong/invalid → `ErrorResponseSeq` (401); jika tak berhak → 403; hentikan alur.
- Detail konsep: lihat `KONSEP.md`.
- **DILARANG**: menyimpan token plain di artifact; melewati validasi untuk endpoint bisnis.

### 4.3 Orchestration Layer (`artifacts/sequences/<Domain><Op>Seq.xml`)
- Berjalan **hanya** setelah Auth Guard lolos.
- Membaca parameter request (`$url:*`).
- Menerapkan default dari config bila parameter kosong.
- Memanggil `LogRequestSeq` (observability, menyertakan `appId` & `correlationId`).
- Memanggil `ResolveBaseUrlSeq` (delegasi resolusi URL, bukan copy-paste 4-layer).
- Menyusun `uri.var.sapBackendUrl` dari base URL + path (dari config) + query.
- Memanggil `SapCoreDynamicEndpoint`, lalu `GenericPaginationSeq`.
- **DILARANG**: hardcode URL/path; duplikasi blok resolusi URL; menangani auth sendiri.

### 4.4 Connectivity Layer (`artifacts/endpoints/SapCoreDynamicEndpoint.xml`)
- Satu endpoint dinamis untuk semua panggilan backend: `uri-template="{+uri.var.sapBackendUrl}"`.
- Operator `+` (RFC 6570) mencegah double-encoding query string.
- Mengatur suspend/retry policy terpusat.

### 4.5 Shared / Utility Layer
| Sequence | Tanggung Jawab |
|---|---|
| `AuthGuardSeq` | Validasi token per-aplikasi terhadap App Registry; set `appId`; tolak 401/403 — **satu-satunya** gerbang auth |
| `ResolveBaseUrlSeq` | Resolusi Base URL 4-layer (ENV → system → file → fallback) & support testing header `X-Target-Backend-Url` |
| `IdempotencyGuardSeq` | Proteksi duplikasi transaksi via MariaDB (replay respons sukses cache, cegah in-flight concurrency 409) |
| `SafeApiCallWithRetrySeq` | Panggilan backend aman dengan 3x retry loop terkonfigurasi dinamis & pencatatan audit attempt 1..3 |
| `ApiCallErrorHandlerSeq` | Error handler & retry scheduler dengan jeda non-hardcoded via MariaDB `DO SLEEP(?)` dan alert monitoring |
| `DbRecordAttemptLogSeq` | Menulis setiap kali percobaan pemanggilan (attempt 1, 2, 3) ke tabel `api_transaction_log` |
| `DbRecordTransactionSeq` | Memperbarui status transaksi (`PROCESSING`, `SUCCESS`, `FAILED`, `RETRY`) di tabel `api_transaction` |
| `RetryWorkerSeq` | Worker asinkron untuk memproses antrean transaksi `FAILED` / `RETRY` yang siap dieksekusi ulang |
| `GenericPaginationSeq` | Pagination + search case-insensitive + format response standar ASSA |
| `LogRequestSeq` | **Structured** access logging (JSON): `timestamp`, `correlationId`, `appId`, `endpoint`, `params` |
| `HealthCheckSeq` | Liveness probe `/health` untuk monitoring infrastruktur (tanpa token) |
| `ErrorResponseSeq` | Format JSON error konsisten untuk semua kondisi (400, 401, 403, 404, 409, 500, 502) |

### 4.6 Configuration Layer
- **Chain resolusi (prioritas tertinggi → terendah):**
  1. **Environment Variable** (`SAP_CORE_BASE_URL`) — untuk Docker/K8s/PROD.
  2. **`deployment.toml` → `[system.parameter]`** — per-environment.
  3. **`config.properties`** — default untuk development lokal.
  4. **Safety fallback** — dibaca dari config, **bukan** URL hardcode di XML.
- **Database Configuration (MariaDB Port 3307)**:
  - `db.driver=org.mariadb.jdbc.Driver`
  - `db.url=jdbc:mariadb://localhost:3307/assa_middleware_db?useSSL=false&allowPublicKeyRetrieval=true`
  - `db.username=root` / `db.password=`
- **Retry Policy**:
  - `retry.max.attempts=3`
  - `retry.interval.seconds=60` (override via header `X-Retry-Interval-Seconds`)
  - `retry.worker.interval.seconds=120`

### 4.7 Database & Resiliency Layer (MariaDB Port 3307)
- **Tabel `api_transaction`**: Mencatat transaksi utama, status (`PENDING`, `PROCESSING`, `SUCCESS`, `RETRY`, `FAILED`), jumlah attempt, dan jadwal retry asinkron (`next_retry_at`).
- **Tabel `api_transaction_log`**: Audit trail teknis setiap pemanggilan external API (attempt 1, 2, 3), HTTP status code, pesan error, dan latency (`duration_ms`).
- **Asynchronous Retry Queue**: Jika pemanggilan gagal 3x berturut-turut, transaksi tidak hilang melainkan masuk ke Retry Queue untuk diproses oleh Background Worker (`POST /api/worker/retry`).

---

## 5. Aliran Request End-to-End (Runtime View)

```
Client → GET /api/branches/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11
         Header: Authorization: Bearer <token milik aplikasi>
                 X-Transaction-Id: TRX-12345 (opsional)
   │
   ▼
BranchAPI.xml (routing)
   │  match uri-template /getByCreateDate → inSequence
   ▼
AuthGuardSeq.xml
   │  0a. baca header Authorization
   │  0b. validasi token → App Registry
   │  0c. token invalid/kosong → ErrorResponseSeq (401) & STOP
   │      token valid tapi tak berhak → ErrorResponseSeq (403) & STOP
   │  0d. token valid → set appId, generate/ambil correlationId → lanjut
   ▼
BranchGetByCreateDateSeq.xml
   │  1.  baca param URL & isi default dari config jika kosong
   │  2.  LogRequestSeq            (structured log: appId, correlationId, endpoint, params)
   │  3.  IdempotencyGuardSeq      (cek cache sukses -> replay / cek in-flight -> 409 / catat trx)
   │  4.  ResolveBaseUrlSeq        (dapatkan sapBaseUrl dari 4-layer chain)
   │  5.  bangun uri.var.sapBackendUrl = baseUrl + path(config) + query
   │  6.  SafeApiCallWithRetrySeq  (3x retry non-hardcoded interval, MariaDB audit attempt 1..3)
   ▼
SapCoreDynamicEndpoint.xml → HTTPS GET ke SAP Core API
   │  respons mentah (array / {values} / {data}) (catat backendMs & attempt ke api_transaction_log)
   ▼
GenericPaginationSeq.xml
   │  filter (search) + slice (pagination) + bentuk { count, data, pagination }
   ▼
Client menerima JSON standar ASSA (HTTP 200)
   │  (LogRequestSeq & DbRecordTransactionSeq mencatat status=SUCCESS & durationMs)

── Jalur Idempotency Replay ──
X-Transaction-Id / Idempotency Key duplikat sukses → Langsung jawab dari cache MariaDB (X-Idempotent-Replay: true, tanpa panggil backend)

── Jalur Retry & Failure ──
Gagal panggil backend → Coba sampai 3x dengan jeda (config: retry.interval.seconds) → Gagal 3x → Status FAILED di api_transaction, log semua attempt di api_transaction_log, picu [ALERT MONITORING], masukkan ke Retry Queue untuk Background Worker (/api/worker/retry), kirim HTTP 502 ke client.

── Jalur auth gagal ──
Token kosong/invalid → 401 · Token valid tak berhak → 403  (via ErrorResponseSeq)

── Jalur error ──
Fault di titik manapun → faultSequence resource → ErrorResponseSeq → JSON error (HTTP 5xx)

── Jalur health check ──
GET /health (liveness) · GET /health/ready (readiness) → HealthCheckSeq (tanpa token)
```

---

## 6. Kontrak Response Standar (Response Contract)

Semua endpoint list mengembalikan bentuk yang sama:

```json
{
  "count": 5,
  "data": [ /* item halaman ini */ ],
  "pagination": {
    "page": 1,
    "perPage": 10,
    "total": 5,
    "totalPages": 1,
    "search": "jakarta"
  }
}
```

Semua error mengembalikan bentuk yang sama:

```json
{
  "error": true,
  "message": "<pesan ringkas>",
  "detail": "<detail teknis>"
}
```

Status yang dihasilkan Auth Guard, error handler, dan resiliency:

| Kondisi | HTTP Status | `message` contoh |
|---|---|---|
| Token valid & berhak | `200 OK` | — |
| Request duplikat sukses terdeteksi | `200 OK` (`X-Idempotent-Replay: true`) | — (Replay respons cache) |
| Transaksi identik sedang diproses | `409 Conflict` | `Conflict` |
| Tanpa header `Authorization` / token invalid | `401 Unauthorized` | `Unauthorized` |
| Token valid tapi tidak berhak ke endpoint/domain | `403 Forbidden` | `Forbidden` |
| 3x Percobaan backend gagal / habis | `502 Bad Gateway` | `Bad Gateway - Max Retries Exhausted` |
| Fault internal / backend gagal | `5xx` | `Internal Server Error` |

---

## 7. Konvensi Penamaan (Naming Conventions)

| Artifact | Pola | Contoh |
|---|---|---|
| API | `<Domain>API.xml`, context `/api/<domain-plural>` | `BranchAPI.xml` → `/api/branches` |
| Sequence operasi | `<Domain><Operation>Seq.xml` | `BranchGetByCreateDateSeq.xml` |
| Shared sequence | `<Fungsi>Seq.xml` | `GenericPaginationSeq.xml`, `IdempotencyGuardSeq.xml` |
| Config key — base URL | `sap.core.base.url` | — |
| Config key — path | `sap.api.path.<operation>` | `sap.api.path.branch.getByCreateDate` |
| Config key — default | `<domain>.default.<field>` | `default.companyCode` |
| Config key — token app | `auth.app.<appId>.token` (hash) | `auth.app.app_a.token` |
| Config key — scope app | `auth.app.<appId>.scopes` | `auth.app.app_a.scopes` |
| App identity | `appId` (huruf kecil, `snake_case`) | `app_a`, `app_b` |

---

## 8. SOP Menambah API Baru (Scale ke 200+)

Menambah API baru **tidak pernah** memerlukan file endpoint baru. Cukup 3 langkah:

**Langkah 1 — Tambah path & default di `config.properties`:**
```properties
sap.api.path.customer.getById=/api/Customers/GetById
```

**Langkah 2 — Tambah resource di `<Domain>API.xml`:**
```xml
<resource methods="GET" uri-template="/getById">
    <inSequence>
        <property name="requiredScope" value="customers" scope="default" type="STRING"/>
        <sequence key="AuthGuardSeq"/>       <!-- gerbang token WAJIB, paling awal -->
        <sequence key="CustomerGetByIdSeq"/>
    </inSequence>
    <faultSequence>
        <sequence key="ErrorResponseSeq"/>
    </faultSequence>
</resource>
```

**Langkah 3 — Buat sequence ringkas `<Domain><Op>Seq.xml`:**
```xml
<sequence name="CustomerGetByIdSeq" xmlns="http://ws.apache.org/ns/synapse">
    <!-- 1. Parameter -->
    <property name="api.endpoint" value="/api/customers/getById" scope="default" type="STRING"/>
    <property name="customerId"   expression="$url:id" scope="default" type="STRING"/>
    <property name="api.params"   expression="fn:concat('id=', $ctx:customerId)" scope="default" type="STRING"/>

    <!-- 2. Observability & Idempotency Guard -->
    <sequence key="LogRequestSeq"/>
    <sequence key="IdempotencyGuardSeq"/>

    <!-- 3. Resolusi Base URL (TIDAK di-copy-paste — delegasi ke helper) -->
    <property name="baseUrlConfigKey" value="sap.core.customer.base.url" scope="default" type="STRING"/>
    <property name="envVarKey" value="SAP_CORE_BASE_URL" scope="default" type="STRING"/>
    <sequence key="ResolveBaseUrlSeq"/>

    <!-- 4. Path dari config, bukan hardcode -->
    <property name="sapApiPath" expression="get-property('file', 'sap.api.path.customer.getById')" scope="default" type="STRING"/>

    <!-- 5. Susun URL backend -->
    <property name="uri.var.sapBackendUrl"
              expression="fn:concat($ctx:resolvedBaseUrl, $ctx:sapApiPath, '?id=', $ctx:customerId)"
              scope="default" type="STRING"/>

    <!-- 6. Panggil Endpoint Dinamis dengan Proteksi 3x Retry & DB Auditing -->
    <property name="targetEndpointKey" value="SapCoreDynamicEndpoint" scope="default" type="STRING"/>
    <sequence key="SafeApiCallWithRetrySeq"/>
</sequence>
```

---

## 9. Status Implementasi & Migration Notes

Status implementasi terhadap blueprint arsitektur:

1. ✅ **`ResolveBaseUrlSeq` extracted:** Resolusi Base URL 4-layer dipusatkan di shared helper sequence dan mendukung header chaos testing `X-Target-Backend-Url`.
2. ✅ **`ErrorResponseSeq` extracted:** Response error terstandarisasi untuk 400, 401, 403, 404, 409, 500, dan 502.
3. ✅ **No hardcoded path/credentials:** Seluruh URL, endpoint, token, dan konfigurasi database dikelola di `config.properties` dan `deployment.toml`.
4. ✅ **`AuthGuardSeq` + App Registry:** Autentikasi token per-aplikasi (App A, App B, QA) dengan scopes, audit token, dan penanganan correlation ID.
5. ✅ **`LogRequestSeq` structured logging:** Format JSON structured logging mencakup `appId`, `correlationId`, `endpoint`, dan `params`.
6. ✅ **`HealthCheckSeq` + endpoint `/health`:** Liveness probe terintegrasi tanpa token untuk Kubernetes / load balancer health check.
7. ✅ **MariaDB Local (Port 3307) Integration:** Driver MariaDB `3.3.3` terpasang di WSO2 MI dengan connection pool ke `assa_middleware_db`.
8. ✅ **Tabel `api_transaction` & `api_transaction_log`:** Schema lengkap untuk audit transaksi, tracking status, dan riwayat setiap attempt.
9. ✅ **Resiliency & 3x Retry Loop:** `SafeApiCallWithRetrySeq` + `ApiCallErrorHandlerSeq` dengan delay non-hardcoded via MariaDB `DO SLEEP(?)`, alert monitoring jika gagal 3x, dan HTTP 502 Bad Gateway.
10. ✅ **Idempotency Guard:** Mencegah eksekusi ganda via `IdempotencyGuardSeq` dengan automatic replay dari cached response (`X-Idempotent-Replay: true`) dan deteksi konkurensi (409 Conflict).
11. ✅ **Asynchronous Background Worker:** Endpoint `/api/worker/retry` dan sequence `RetryWorkerSeq` untuk memproses antrean transaksi `FAILED`/`RETRY` secara asinkron dengan exponential backoff schedule.

---

## 10. Perintah Build & Testing

```bash
# Dari root proyek — compile dan build CAR
cd middleware-assa/middleware-assa/middleware-assa
./mvnw.cmd clean package -DskipTests

# Menjalankan pengujian otomatis Resiliency, Retry, Idempotency & MariaDB
cd test
powershell -ExecutionPolicy Bypass -File "run_resiliency_tests.ps1"
```

---

## 11. Dokumen Terkait

- `DATABASE_SETUP_GUIDE.md` — Panduan integrasi MariaDB lokal port 3307, skema tabel, retry policy, idempotency, dan worker.
- `KONSEP.md` — Visi & konsep besar platform (the why), autentikasi token per-aplikasi (`AuthGuardSeq` & App Registry).
- `KONSEP_MONITORING.md` — Monitoring & observability (structured logging, metrics, alerting, dan health check).
- `PANDUAN_TESTING_LENGKAP.md` & `MANUAL_TESTING_GUIDE.md` — Panduan pengujian integrasi manual dan otomatis.

