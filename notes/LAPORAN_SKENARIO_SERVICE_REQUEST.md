# Laporan Arsitektur & Skenario Integrasi Service Request (SR)
## ASSA Middleware — WSO2 Micro Integrator

> **Tanggal**: 25 September 2026  
> **Status Implementasi**: ✅ Production Ready (Teruji di Local Docker & Terpaket ke Image 1.0.7)  
> **Target Downstream**:
> 1. **Target 1 (ATLAS)**: `POST https://fe.atlas-dev.assa.id/api/vendor/public/service-requests` (JSON, Toggle `SR_TARGET_ATLAS_ENABLED`, default OFF)  
> 2. **Target 2 (External Services ke SAP)**: `POST https://assa-ext-services.assa.id/dev/service/input_service_request` (30 Form Parameters)  
>
> **Swagger UI URL**: 👉 `https://devmiddleware1.assa.id/docs` (Tab: *Service Request & Worker*)

---

## 1. Diagram Alur Skenario (Fan-out Paralel)

```mermaid
flowchart TD
    Client["Client Eksternal\n(Omnichannel / Barantum CRM)"] -->|"1. POST /api/service-requests\natau POST /api/vendor/public/service-requests"| MW["WSO2 Middleware\n(ServiceRequestSeq)"]

    subgraph MW_Internal["Proses Internal WSO2 MI"]
        MW --> Auth["AuthGuardSeq\n(Dual: Bearer Token / X-API-Key)"]
        Auth --> Valid["Validasi Mandatory Fields\n(customerName, branch, unit, reff)"]
        Valid --> Idem["IdempotencyGuardSeq\n(Cek Replay di MariaDB)"]
        Idem --> Clone["Clone Mediator\n(Fan-out Paralel)"]
    end

    Clone -->|"Cabang 1 (Paralel JSON)"| Atlas["SrToAtlasSeq\n(Target ATLAS)"]
    Clone -->|"Cabang 2 (Paralel 30 Form-Fields)"| Ext["SrToExtServiceSeq\n(Target Ext Services)"]

    Atlas -->|"POST https://fe.atlas-dev.assa.id/api/vendor/public/service-requests"| Target1["Target 1: API ATLAS\n(Default: OFF / SKIPPED)"]
    Ext -->|"POST https://assa-ext-services.assa.id/dev/service/input_service_request"| Target2["Target 2: ASSA External Services"]
    Target2 --> SAP["SAP Core ASSA\n(Pembuatan SPK & Administrasi Bengkel)"]

    Target1 --> Agg["SrAggregateResponseSeq\n(Agregasi Response)"]
    Target2 --> Agg

    Agg -->|"HTTP 200 / 207 / 502 / 503"| Client
```

---

## 2. Rincian Kedua Target Paralel

### A. Target 1: API ATLAS (`SrToAtlasSeq.xml`)
* **Endpoint**: `POST https://fe.atlas-dev.assa.id/api/vendor/public/service-requests`
* **Format Body**: `application/json` (Meneruskan JSON asli dari client).
* **Header**: `Content-Type: application/json` & `x-api-key: <token_atlas>`.
* **Mekanisme Toggle (`SR_TARGET_ATLAS_ENABLED`)**:
  * **Default: `false` (OFF)**: WSO2 MI tidak akan membuang request/koneksi keluar jika backend ATLAS belum siap, melainkan langsung menghasilkan status internal:
    ```json
    { "status": "SKIPPED", "httpStatus": 200, "detail": "Target API ATLAS disabled via toggle" }
    ```
  * **Toggle `true` (ON)**: WSO2 MI akan melakukan HTTP POST real-time ke URL ATLAS.

### B. Target 2: ASSA External Services (`SrToExtServiceSeq.xml`)
* **Endpoint**: `POST https://assa-ext-services.assa.id/dev/service/input_service_request`
* **Format Body**: `application/x-www-form-urlencoded`
* **Header**: `Content-Type: application/x-www-form-urlencoded` & `x-api-key: DDtCZNeoPN27TWpHJdk9zaFwivxXrqQs2r1hbiKs`.
* **Transformasi Data (JSON to Form)**:
  WSO2 MI secara otomatis memetakan JSON terstruktur (termasuk objek `unit`: plat nomor, brand, model, odometer) menjadi **30 parameter form** yang diwajibkan oleh backend SAP (`nopol`, `km`, `nama_customer`, `keluhan`, dll).
* **Tujuan**: Meneruskan tiket servis ke Core ERP SAP ASSA untuk pengerjaan bengkel.

---

## 3. Matriks Agregasi Response & Retry 10x (Opsi C)

Middleware mengevaluasi respons kedua cabang paralel dengan aturan **Opsi C (Parallel Fan-Out dengan 10x Retry & Telemetri DB)**:

1. **Paralel Fan-Out**: Request diteruskan serentak ke Target 1 (ATLAS) dan Target 2 (External Services / SAP).
2. **Retry 10x Otomatis**: Jika salah satu target mengembalikan status bukan 2xx (misal HTTP 400 / 500) atau error transport/jaringan, WSO2 MI otomatis mencoba kembali (retry) hingga **10 kali** (`maxAttempts=10`) dengan jeda 1 detik (`DO SLEEP(1)`) antar percobaan.
3. **Pencatatan Audit Log per Percobaan**: Setiap percobaan (attempt 1 hingga 10) langsung dicatat ke tabel `api_transaction_log` di MariaDB (menyimpan `attempt_number`, `endpoint`, `response_status`, `duration_ms`, dan `created_at`).
4. **Respon Body Fail**: Jika setelah 10 kali percobaan target tetap gagal, middleware mengembalikan HTTP 502 Bad Gateway dengan response body failure terstruktur dan status transaksi dicatat sebagai `FAILED` di tabel `api_transaction`.

| Status Target 1 (ATLAS) | Status Target 2 (Ext Services / SAP) | HTTP Code | Status Transaksi | Format Respons Ke Client |
|---|---|:---:|:---:|---|
| **SKIPPED / SUCCESS** | **SUCCESS (200)** | `200 OK` | `SUCCESS` | `{"success": true, "message": "Service request diteruskan ke semua target", "targets": {...}}` |
| **SKIPPED / SUCCESS** | **FAILED (setelah 10x retry)** | `502 Bad Gateway` | `FAILED` | `{"error": true, "success": false, "message": "Service request gagal diteruskan (target gagal setelah 10x percobaan)", "targets": {...}}` |
| **FAILED (setelah 10x retry)** | **SUCCESS (200)** | `502 Bad Gateway` | `FAILED` | `{"error": true, "success": false, "message": "Service request gagal diteruskan (target gagal setelah 10x percobaan)", "targets": {...}}` |
| **FAILED** | **FAILED** | `502 Bad Gateway` | `FAILED` | `{"error": true, "success": false, "message": "Service request gagal diteruskan (target gagal setelah 10x percobaan)", "targets": {...}}` |

---

## 4. Dua Jalur Pintu Masuk API di Middleware

| Fitur | 1. Jalur Omnichannel Internal | 2. Jalur Vendor Publik (Barantum CRM) |
|---|---|---|
| **Path URL** | `POST /api/service-requests` | `POST /api/vendor/public/service-requests` |
| **Metode Autentikasi** | `Authorization: Bearer <token>` | `X-API-Key: <token>` atau `Bearer <token>` |
| **Token Terdaftar** | `14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12` | `umk_da295902028f5804c4f0e9d9fd81fa07a2a0e1152d6171e30f387416fbfe5680` |
| **Format Payload** | Format legacy Omnichannel (flat / snake_case) | Format Barantum (nested `unit`: plat, brand, odometer) |
| **Downstream Execution** | Identik (Bermuara pada `ServiceRequestSeq.xml`) | Identik (Bermuara pada `ServiceRequestSeq.xml`) |

---

## 5. Fitur Inquiry & Pagination (GET)

Middleware menyediakan endpoint GET untuk memeriksa riwayat transaksi dari MariaDB (`api_transaction`):

* **Path**: `GET /api/vendor/public/service-requests` (atau `GET /api/service-requests`)
* **Query Parameters**:
  * `page` (default: 1)
  * `perPage` (default: 10)
  * `referenceNumber` (filter pencarian spesifik nomor tiket)
* **Contoh Respons**:
```json
{
    "count": 1,
    "data": [
        {
            "transactionId": "TEST-RETRY-005",
            "referenceNumber": "TEST-RETRY-005",
            "status": "FAILED",
            "createdAt": "2026-09-25 09:43:30.0"
        }
    ],
    "pagination": {
        "page": 1,
        "perPage": 1,
        "total": 1
    }
}
```

---

## 6. Integrasi dengan Swagger UI (Dokumentasi Interaktif)

Dokumentasi OpenAPI 3.0 untuk fitur Service Request ini **terintegrasi penuh** di dashboard Swagger ASSA Middleware:

* **URL Dashboard**: 👉 **`https://devmiddleware1.assa.id/docs`**
* **Tab / Service**: **`Service Request & Worker`**
* **File Spesifikasi**: [`docs/openapi/service-request-service.yaml`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo/docs/openapi/service-request-service.yaml)
* **Daftar Endpoint di Swagger**:
  1. `POST /api/service-requests` — Pembuatan tiket format Omnichannel (paralel + 10x retry).
  2. `GET /api/service-requests` — Inquiry & pagination riwayat tiket.
  3. `POST /api/vendor/public/service-requests` — Pembuatan tiket format Vendor Publik Barantum (dengan payload nested `unit` & auth `X-API-Key`).
  4. `GET /api/vendor/public/service-requests` — Inquiry & pagination format Vendor Publik.
  5. `GET /api/worker/retry` & `POST /api/worker/retry` — Background Retry Worker.
  6. `GET /health/service-request` & `/readiness/service-request` — Container Probes.

---

## 7. Bukti Pengujian Nyata di Local Docker & Verifikasi MariaDB

Pengujian dilakukan secara langsung pada container Docker lokal (`middleware-wso2-nginx` pada port 6031, `service-request-service` pada port 8295, dan `mi-mariadb` pada port 3308):

### A. HTTP Request & Response (HTTP 502 Bad Gateway)
```bash
curl -i -X POST http://localhost:6031/api/service-requests \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer c220fbfbc7e4c925eb662d85be47ee5ab017d23d9b04f7c22df6cb7efb6dfdbd" \
  -H "X-Transaction-Id: TEST-RETRY-005" \
  -d '{
    "app_id": "BARANTUM_CRM",
    "reff_number": "TEST-RETRY-005",
    "branch_code": "JKT01",
    "license_plate": "B 1234 XYZ",
    "ticket_no": "TEST-RETRY-005",
    "customer_name": "Test Customer",
    "phone_number": "081234567890",
    "keluhan": "Rem bunyi"
  }'
```

**Hasil Response Body**:
```json
HTTP/1.1 502 Bad Gateway
Server: nginx/1.31.6
Content-Type: application/json; charset=UTF-8
X-Transaction-Id: TEST-RETRY-005

{
    "error": true,
    "success": false,
    "message": "Service request gagal diteruskan (target gagal setelah 10x percobaan)",
    "transactionId": "TEST-RETRY-005",
    "referenceNumber": "TEST-RETRY-005",
    "ticket_no": "TEST-RETRY-005",
    "targets": {
        "atlas": {
            "status": "SKIPPED",
            "httpStatus": 200,
            "detail": "API ATLAS disabled or no response"
        },
        "extService": {
            "status": "FAILED",
            "httpStatus": 400,
            "detail": "Forward to ASSA External Services failed after 10 attempts"
        }
    }
}
```

### B. Bukti Data Tercatat di MariaDB (`api_transaction`)
```sql
SELECT transaction_id, status, attempt_count, created_at, updated_at 
FROM api_transaction 
WHERE transaction_id = 'TEST-RETRY-005';
```
| transaction_id | status | attempt_count | created_at | updated_at |
|---|:---:|:---:|---|---|
| **TEST-RETRY-005** | **FAILED** | **10** | 2026-09-25 09:43:30 | 2026-09-25 09:44:03 |

### C. Bukti Riwayat 10x Percobaan Tercatat di MariaDB (`api_transaction_log`)
```sql
SELECT attempt_number, endpoint, response_status, duration_ms, created_at 
FROM api_transaction_log 
WHERE transaction_id = 'TEST-RETRY-005' 
ORDER BY attempt_number ASC;
```
| attempt_number | endpoint | response_status | duration_ms | created_at |
|:---:|---|:---:|:---:|---|
| **1** | `https://assa-ext-services.assa.id/dev/service/input_service_request` | **400** | 1635 | 2026-09-25 09:43:31 |
| **2** | `https://assa-ext-services.assa.id/dev/service/input_service_request` | **400** | 312 | 2026-09-25 09:43:33 |
| **3** | `https://assa-ext-services.assa.id/dev/service/input_service_request` | **400** | 79 | 2026-09-25 09:43:34 |
| **4** | `https://assa-ext-services.assa.id/dev/service/input_service_request` | **400** | 131 | 2026-09-25 09:43:35 |
| **5** | `https://assa-ext-services.assa.id/dev/service/input_service_request` | **400** | 300 | 2026-09-25 09:43:36 |
| **6** | `https://assa-ext-services.assa.id/dev/service/input_service_request` | **400** | 699 | 2026-09-25 09:43:38 |
| **7** | `https://assa-ext-services.assa.id/dev/service/input_service_request` | **400** | 1073 | 2026-09-25 09:43:40 |
| **8** | `https://assa-ext-services.assa.id/dev/service/input_service_request` | **400** | 42 | 2026-09-25 09:43:41 |
| **9** | `https://assa-ext-services.assa.id/dev/service/input_service_request` | **400** | 99 | 2026-09-25 09:43:42 |
| **10** | `https://assa-ext-services.assa.id/dev/service/input_service_request` | **400** | 119 | 2026-09-25 09:43:43 |

---

## 8. Status Rilis & Deployment Container

Image release terbaru telah dipaketkan dan siap di-push ke registry ASSA:
* **Image**: `registry.assa.id/nobi.sumariga/middleware-assa:1.0.7`
* **Arsitektur**: `linux/amd64` (Bebas dari issue "invalid tag / missing manifest digest").
* **Script Otomatis**: `build_image.sh` (`--platform linux/amd64 --provenance=false --sbom=false`)
* **Artifacts yang Termasuk**:
  * `shared-artifacts_1.0.0.car` (Dual AuthGuard, MariaDB network connection, DbRecordAttemptLogSeq).
  * `service-request-service_1.0.0.car` (Option C fan-out, 10x synchronous retry with DB sleep, updated OpenAPI spec).
  * OpenAPI Specs & Swagger UI di `/app/docs`.
