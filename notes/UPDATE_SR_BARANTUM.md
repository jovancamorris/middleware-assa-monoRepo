# API Guide — Service Request (SR) Fan-out Paralel & Public Gateway
## ASSA Middleware — WSO2 Micro Integrator

> **Document Version**: 2.0 (Updated)  
> **Last Updated**: 25 September 2026  
> **Author**: Nobi Sumariga / Integration Team  
> **Consumer**: 
> 1. **Barantum CRM** (via Public Gateway `/api/vendor/public/service-requests` dengan `X-API-Key`)
> 2. **Omnichannel** (via Internal API `/api/service-requests` dengan `Authorization: Bearer`)  
> **Tujuan**: 
> - Menyediakan endpoint `POST` penerimaan Service Request (SR) baik dari format payload baru Barantum CRM (nested `unit`) maupun format flat legacy Omnichannel.
> - Mengubah dan memetakan field ke 30 parameter downstream yang dibutuhkan oleh backend `input_service_request`.
> - Meneruskan request secara **PARALEL** (fan-out) ke:
>   1. **API ATLAS** (`SrToAtlasSeq` — configurable & dapat di-toggle via `sr.target.atlas.enabled`).
>   2. **ASSA External Services**: `POST https://assa-ext-services.assa.id/dev/service/input_service_request` (`SrToExtServiceSeq` — meneruskan data ke SAP).
> - Menyediakan endpoint `GET` untuk **inquiry transaksi SR dengan pagination standar** (`page`, `perPage`, `total`, `totalPages`, `hasNext`, `hasPrev`) melalui `GenericPaginationSeq`.

---

## Daftar Isi
1. [Ringkasan Fitur & Spesifikasi Terbaru](#1-ringkasan-fitur--spesifikasi-terbaru)
2. [Diagram Alur Sistem](#2-diagram-alur-sistem)
3. [Autentikasi Ganda (Bearer & X-API-Key)](#3-autentikasi-ganda-bearer--x-api-key)
4. [Kontrak API Middleware](#4-kontrak-api-middleware)
   - [POST Service Request (Format Barantum CRM)](#a-post-service-request-format-barantum-crm)
   - [POST Service Request (Format Legacy Omnichannel)](#b-post-service-request-format-legacy-omnichannel)
   - [GET Service Request dengan Pagination](#c-get-service-request-dengan-pagination)
5. [Spesifikasi Pemetaan Field (Barantum ke 30 Field Backend)](#5-spesifikasi-pemetaan-field-barantum-ke-30-field-backend)
6. [Strategi Fan-out Paralel & Agregasi Response](#6-strategi-fan-out-paralel--agregasi-response)
7. [Konfigurasi (Properties & Envs)](#7-konfigurasi-properties--envs)
8. [Panduan Pengujian di Local Docker (Step-by-Step)](#8-panduan-pengujian-di-local-docker-step-by-step)
9. [Panduan Pengujian via Postman](#9-panduan-pengujian-via-postman)
10. [Checklist Acceptance & Verifikasi](#10-checklist-acceptance--verifikasi)

---

## 1. Ringkasan Fitur & Spesifikasi Terbaru

| Item | Nilai |
|---|---|
| **Fitur** | Service Request (SR) Fan-out Paralel ke ATLAS & ASSA External Services + Public Vendor Endpoint |
| **Endpoint POST (Public Barantum)** | `POST /api/vendor/public/service-requests` |
| **Endpoint POST (Omnichannel)** | `POST /api/service-requests` |
| **Endpoint GET (Inquiry Pagination)** | `GET /api/vendor/public/service-requests?page=1&perPage=10`<br>`GET /api/service-requests?page=1&perPage=10` |
| **Port Akses Local** | Direct MI: `8295` \| Reverse Proxy Nginx: `6031` \| Gateway Prod: `4002` |
| **Autentikasi** | **Dual Auth**: `X-API-Key` (Barantum) ATAU `Authorization: Bearer <token>` (Omnichannel) |
| **Token Barantum CRM** | `umk_da295902028f5804c4f0e9d9fd81fa07a2a0e1152d6171e30f387416fbfe5680` |
| **Origin Header (Barantum)** | `Origin: https://barantum.internal` |
| **Target Backend 1** | `POST` API ATLAS *(toggle `sr.target.atlas.enabled`, default: false)* |
| **Target Backend 2** | `POST https://assa-ext-services.assa.id/dev/service/input_service_request` (`x-www-form-urlencoded`, 30 parameter) |
| **Idempotency** | Didukung via `referenceNumber` / `X-Transaction-Id` (mencegah double submission) |
| **Pagination Metadata** | Standar WSO2 MI: `count`, `pagination: { page, perPage, total, totalPages, hasNext, hasPrev }`, `data` |

---

## 2. Diagram Alur Sistem

```mermaid
flowchart TD
    subgraph Consumers
        BRT["Barantum CRM\n(X-API-Key: umk_...)\n(Origin: barantum.internal)"]
        OMNI["Omnichannel Client\n(Bearer Token)"]
    end

    subgraph Nginx Gateway ["Nginx / Reverse Proxy (Port 6031 / 4002)"]
        NG1["/api/vendor/public/service-requests"]
        NG2["/api/service-requests"]
    end

    subgraph WSO2 MI ["WSO2 Micro Integrator (Port 8295)"]
        API_PUB["PublicServiceRequestAPI.xml\n(/api/vendor/public/service-requests)"]
        API_PRIV["ServiceRequestAPI.xml\n(/api/service-requests)"]

        AUTH["AuthGuardSeq\n(Mendukung Bearer & X-API-Key\nScope: service_requests)"]

        subgraph POST Flow ["POST Dispatcher"]
            SR_SEQ["ServiceRequestSeq\n(Normalize JSON -> 30 Params Downstream)"]
            IDEM["IdempotencyGuardSeq\n(Menggunakan referenceNumber / X-Transaction-Id)"]
            CLONE["Clone Mediator (Paralel Fan-out)"]

            ATLAS["SrToAtlasSeq\n(Target ATLAS - Toggle)"]
            EXT["SrToExtServiceSeq\n(Target ASSA Ext Service)"]
            AGG["SrAggregateResponseSeq\n(Agregasi 200/207/502)"]
        end

        subgraph GET Flow ["GET Inquiry Flow"]
            GET_SEQ["ServiceRequestGetSeq\n(Inquiry api_transaction via MariaDB)"]
            PAGE_SEQ["GenericPaginationSeq\n(Bungkus data & pagination metadata)"]
        end
    end

    subgraph Backends
        SRV_ATLAS["ATLAS API (Dev/Staging)"]
        SRV_EXT["ASSA Ext Services\n(input_service_request)"]
        SAP["SAP ECC/S4HANA"]
        DB[(MariaDB 3308\napi_transaction)]
    end

    BRT --> NG1 --> API_PUB
    OMNI --> NG2 --> API_PRIV

    API_PUB --> AUTH
    API_PRIV --> AUTH

    AUTH -->|Method POST| SR_SEQ
    AUTH -->|Method GET| GET_SEQ

    SR_SEQ --> IDEM --> CLONE
    CLONE --> ATLAS --> SRV_ATLAS
    CLONE --> EXT --> SRV_EXT --> SAP

    ATLAS --> AGG
    EXT --> AGG

    GET_SEQ --> DB
    GET_SEQ --> PAGE_SEQ
```

---

## 3. Autentikasi Ganda (Bearer & X-API-Key)

`AuthGuardSeq.xml` telah diperbarui untuk menerima kredensial klien dari salah satu dari dua header berikut:
1. `Authorization: Bearer <token>` (standar OAuth2 / API Key internal)
2. `X-API-Key: <token>` atau `x-api-key: <token>` (standar Public Vendor seperti Barantum CRM)

### Registry App Barantum:
- **App ID**: `app_barantum`
- **Token**: `umk_da295902028f5804c4f0e9d9fd81fa07a2a0e1152d6171e30f387416fbfe5680`
- **Scope**: `service_requests`
- **App Name**: `Barantum CRM Public Gateway`

---

## 4. Kontrak API Middleware

### A. POST Service Request (Format Barantum CRM)

Format ini adalah format payload baru dari Barantum CRM dengan nested object `unit`.

- **Method**: `POST`
- **Path**: `/api/vendor/public/service-requests` (atau `/api/service-requests`)
- **Headers**:
  ```http
  Content-Type: application/json
  X-API-Key: umk_da295902028f5804c4f0e9d9fd81fa07a2a0e1152d6171e30f387416fbfe5680
  Origin: https://barantum.internal
  X-Transaction-Id: BRT-2026-000123 (opsional, auto-fallback ke referenceNumber)
  ```
- **Request Body**:
  ```json
  {
    "customerName": "Budi Santoso",
    "requestorName": "Budi Santoso",
    "requestorPhone": "081234567890",
    "branch": "Jakarta Pusat",
    "referenceNumber": "BRT-2026-000123",
    "unit": {
      "licensePlate": "B 1234 XYZ",
      "brand": "Toyota",
      "model": "Avanza",
      "odometer": 25000
    }
  }
  ```

- **Response Body (200 OK — Fan-out Sukses)**:
  ```json
  {
    "success": true,
    "message": "Service request diteruskan ke semua target",
    "transactionId": "BRT-2026-000123",
    "referenceNumber": "BRT-2026-000123",
    "ticket_no": "BRT-2026-000123",
    "targets": {
      "atlas": {
        "status": "SKIPPED",
        "detail": "ATLAS target disabled via toggle"
      },
      "extService": {
        "status": "SUCCESS",
        "httpStatus": 200
      }
    }
  }
  ```

---

### B. POST Service Request (Format Legacy Omnichannel)

Format ini tetap didukung 100% (*backward compatibility*).

- **Method**: `POST`
- **Path**: `/api/service-requests`
- **Headers**:
  ```http
  Content-Type: application/json
  Authorization: Bearer dev-token-omnichannel-12345
  X-Transaction-Id: SR-TRX-20260925-001
  ```
- **Request Body**:
  ```json
  {
    "app_id": "sr_app_omnichannel",
    "reff_number": "REF-SR-20260925-001",
    "branch_code": "JKT01",
    "equipment_number": "EQ-998877",
    "license_plate": "B-1234-SSA",
    "customer_code": "CUST-00123",
    "customer_name": "PT Maju Bersama ASSA",
    "channel": "Omnichannel-Web",
    "cp_title": "Bpk",
    "cp_name": "Ahmad Fauzi",
    "cp_phone": "081234567890",
    "cp_email": "ahmad.fauzi@example.com",
    "cp_address": "Jl. Gatot Subroto No. 45 Jakarta",
    "km": "25000",
    "description": "Perawatan berkala 25.000 KM dan pengecekan rem",
    "service_datetime": "2026-09-28 10:00:00",
    "service_location": "Bengkel Resmi ASSA Sunter",
    "jenis_permintaan": "Service Berkala",
    "incident_datetime": "2026-09-25 09:00:00",
    "tipe_tiket": "Regular",
    "judul": "Service Berkala Kendaraan Operasional",
    "nama_kunjungan": "Ahmad Fauzi",
    "telepon_kunjungan": "081234567890",
    "alamat_kunjungan": "Jl. Danau Sunter Barat Blok A",
    "pool_name": "Pool Sunter",
    "area_bengkel": "Jakarta Utara",
    "task": "Ganti Oli Mesin dan Filter Oli",
    "created_datetime": "25-09-2026",
    "created_by": "omnichannel_agent",
    "ticket_no": "TICKET-SR-99901"
  }
  ```

---

### C. GET Service Request dengan Pagination

Endpoint ini digunakan untuk meng-query riwayat transaksi Service Request yang tersimpan di database dengan pagination standar.

- **Method**: `GET`
- **Path**: `/api/vendor/public/service-requests` atau `/api/service-requests`
- **Headers**:
  ```http
  X-API-Key: umk_da295902028f5804c4f0e9d9fd81fa07a2a0e1152d6171e30f387416fbfe5680
  (atau Authorization: Bearer <token>)
  ```
- **Query Parameters**:
  - `page`: nomor halaman (integer, default: `1`)
  - `perPage`: jumlah data per halaman (integer, default: `10`, alias: `limit`)
  - `referenceNumber`: filter berdasarkan ID transaksi / reference number (opsional)

- **Contoh Request**:
  ```http
  GET /api/vendor/public/service-requests?page=1&perPage=5
  ```

- **Response Body (200 OK dengan Pagination Metadata)**:
  ```json
  {
    "count": 5,
    "pagination": {
      "page": 1,
      "perPage": 5,
      "total": 12,
      "totalPages": 3,
      "hasNext": true,
      "hasPrev": false
    },
    "data": [
      {
        "transactionId": "BRT-2026-000123",
        "endpoint": "/api/vendor/public/service-requests",
        "status": "SUCCESS",
        "httpStatus": 200,
        "requestPayload": "{\"customerName\":\"Budi Santoso\", ...}",
        "createdAt": "2026-09-25 10:15:30"
      },
      {
        "transactionId": "BRT-2026-000122",
        "endpoint": "/api/vendor/public/service-requests",
        "status": "SUCCESS",
        "httpStatus": 200,
        "requestPayload": "{\"customerName\":\"Siti Rahma\", ...}",
        "createdAt": "2026-09-25 09:45:10"
      }
    ]
  }
  ```

---

## 5. Spesifikasi Pemetaan Field (Barantum ke 30 Field Backend)

Backend `https://assa-ext-services.assa.id/dev/service/input_service_request` menerima **30 parameter form-urlencoded**.  
Tabel di bawah menjelaskan bagaimana field JSON dari Barantum CRM dipetakan secara otomatis:

| No | Parameter Backend | Sumber Field Barantum | Fallback Default Jika Kosong |
|---|---|---|---|
| 1 | `app_id` | `app_id` | `"sr_barantum"` |
| 2 | `reff_number` | `referenceNumber` | auto-generated UUID |
| 3 | `branch_code` | `branch` | `"JKT01"` |
| 4 | `equipment_number` | `equipment_number` | `""` |
| 5 | `license_plate` | `unit.licensePlate` | `""` |
| 6 | `customer_code` | `customer_code` | `"BARANTUM-CUST"` |
| 7 | `customer_name` | `customerName` | `"Pelanggan Barantum"` |
| 8 | `channel` | `channel` | `"Barantum-CRM"` |
| 9 | `cp_title` | `cp_title` | `"Bpk/Ibu"` |
| 10 | `cp_name` | `requestorName` | `customerName` |
| 11 | `cp_phone` | `requestorPhone` | `""` |
| 12 | `cp_email` | `cp_email` | `""` |
| 13 | `cp_address` | `cp_address` | `branch` |
| 14 | `km` | `unit.odometer` | `"0"` |
| 15 | `description` | `description` | `"Service Request Barantum - unit.brand unit.model"` |
| 16 | `service_datetime` | `service_datetime` | Current Datetime (`YYYY-MM-DD HH:mm:ss`) |
| 17 | `service_location` | `service_location` | `branch` |
| 18 | `jenis_permintaan` | `jenis_permintaan` | `"Service Request"` |
| 19 | `incident_datetime` | `incident_datetime` | Current Datetime |
| 20 | `tipe_tiket` | `tipe_tiket` | `"Regular"` |
| 21 | `judul` | `judul` | `"Service Request - licensePlate (unit.brand unit.model)"` |
| 22 | `nama_kunjungan` | `requestorName` | `customerName` |
| 23 | `telepon_kunjungan` | `requestorPhone` | `""` |
| 24 | `alamat_kunjungan` | `alamat_kunjungan` | `branch` |
| 25 | `pool_name` | `pool_name` | `branch` |
| 26 | `area_bengkel` | `area_bengkel` | `branch` |
| 27 | `task` | `task` | `"Service Request dari Barantum CRM"` |
| 28 | `created_datetime` | `created_datetime` | Current Date (`DD-MM-YYYY`) |
| 29 | `created_by` | `requestorName` | `"barantum_api"` |
| 30 | `ticket_no` | `referenceNumber` | auto-generated UUID |

---

## 6. Strategi Fan-out Paralel & Agregasi Response

WSO2 Micro Integrator menggunakan mediator `<clone>` untuk mengeksekusi dua cabang secara independen:
1. **Cabang 1 (`SrToAtlasSeq`)**:
   - Memeriksa toggle `sr.target.atlas.enabled`. Jika bernilai `false`, cabang langsung mencatat status `SKIPPED`.
2. **Cabang 2 (`SrToExtServiceSeq`)**:
   - Membangun payload `application/x-www-form-urlencoded` berisi 30 field.
   - Menambahkan header `x-api-key: DDtCZNeoPN27TWpHJdk9zaFwivxXrqQs2r1hbiKs`.
   - Melakukan POST ke target backend ASSA External Services dengan timeout 30 detik.
3. **Agregasi (`SrAggregateResponseSeq`)**:
   - Menggabungkan hasil eksekusi kedua cabang.
   - Jika kedua target sukses (atau target external sukses dan ATLAS skipped) -> `200 OK`.
   - Jika salah satu gagal -> `207 Multi-Status / Partial-Success`.
   - Jika semua target gagal -> `502 Bad Gateway`.

---

## 7. Konfigurasi (Properties & Envs)

### File: `service-request-service/src/main/wso2mi/resources/conf/config.properties`
```properties
# Target 2: ASSA External Services
assa.ext.base.url.dev=https://assa-ext-services.assa.id/dev
assa.api.path.service_request=/service/input_service_request
assa.ext.sr.apikey=DDtCZNeoPN27TWpHJdk9zaFwivxXrqQs2r1hbiKs

# Target 1: API ATLAS
sr.target.atlas.enabled=false
sr.target.atlas.base.url=https://atlas-api.assa.id/dev
sr.target.atlas.path=/service-request
sr.target.atlas.apikey=__USE_SECURE_VAULT__

# Target External Toggle
sr.target.extservice.enabled=true

# Auth App Barantum (Public Gateway)
auth.app.app_barantum.token=umk_da295902028f5804c4f0e9d9fd81fa07a2a0e1152d6171e30f387416fbfe5680
auth.app.app_barantum.name=Barantum CRM Public Gateway
auth.app.app_barantum.scopes=service_requests
```

---

## 8. Panduan Pengujian di Local Docker (Step-by-Step)

### Langkah 1: Pastikan Container Berjalan
Buka terminal dan pastikan container service berjalan:
```bash
cd /Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo
docker compose ps
```
Pastikan `service-request-service` (port `8295`) dan `middleware-wso2-nginx` (port `6031`) dalam status `Up`.

Jika container perlu di-rebuild/restart:
```bash
docker compose up -d --build service-request-service nginx
```

---

### Langkah 2: Uji Langsung ke WSO2 MI (Direct Port 8295)

#### Test 1 — POST Barantum Format Baru dengan `X-API-Key`
Jalankan perintah cURL berikut:
```bash
curl -i -X POST "http://localhost:8295/api/vendor/public/service-requests" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: umk_da295902028f5804c4f0e9d9fd81fa07a2a0e1152d6171e30f387416fbfe5680" \
  -H "Origin: https://barantum.internal" \
  -d '{
    "customerName": "Budi Santoso",
    "requestorName": "Budi Santoso",
    "requestorPhone": "081234567890",
    "branch": "Jakarta Pusat",
    "referenceNumber": "BRT-2026-TEST001",
    "unit": {
      "licensePlate": "B 1234 XYZ",
      "brand": "Toyota",
      "model": "Avanza",
      "odometer": 25000
    }
  }'
```
**Ekspektasi Output**:
- HTTP Status `200 OK`
- Body memuat `"success": true`, `"referenceNumber": "BRT-2026-TEST001"`, `"targets": { "atlas": {"status": "SKIPPED"}, "extService": {"status": "SUCCESS"} }`

---

#### Test 2 — GET Transaction Inquiry dengan Pagination
Jalankan query dengan parameter `page` dan `perPage`:
```bash
curl -i -X GET "http://localhost:8295/api/vendor/public/service-requests?page=1&perPage=5" \
  -H "X-API-Key: umk_da295902028f5804c4f0e9d9fd81fa07a2a0e1152d6171e30f387416fbfe5680"
```
**Ekspektasi Output**:
- HTTP Status `200 OK`
- Body memuat format pagination standar:
  ```json
  {
    "count": 1,
    "pagination": {
      "page": 1,
      "perPage": 5,
      "total": 1,
      "totalPages": 1,
      "hasNext": false,
      "hasPrev": false
    },
    "data": [ ... ]
  }
  ```

---

#### Test 3 — Uji Idempotency (Kirim Ulang Request yang Sama)
Kirim kembali payload dengan `referenceNumber: "BRT-2026-TEST001"`:
```bash
curl -i -X POST "http://localhost:8295/api/vendor/public/service-requests" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: umk_da295902028f5804c4f0e9d9fd81fa07a2a0e1152d6171e30f387416fbfe5680" \
  -H "Origin: https://barantum.internal" \
  -d '{
    "customerName": "Budi Santoso",
    "requestorName": "Budi Santoso",
    "requestorPhone": "081234567890",
    "branch": "Jakarta Pusat",
    "referenceNumber": "BRT-2026-TEST001",
    "unit": {
      "licensePlate": "B 1234 XYZ",
      "brand": "Toyota",
      "model": "Avanza",
      "odometer": 25000
    }
  }'
```
**Ekspektasi Output**:
- HTTP Status `200 OK` dengan header `X-Idempotency: Replay` (mengembalikan response tersimpan tanpa memproses ganda ke backend).

---

### Langkah 3: Uji via Nginx Reverse Proxy (Port 6031)

Endpoint juga dapat diakses melalui reverse proxy Nginx monorepo (port 6031):
```bash
curl -i -X POST "http://localhost:6031/api/vendor/public/service-requests" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: umk_da295902028f5804c4f0e9d9fd81fa07a2a0e1152d6171e30f387416fbfe5680" \
  -H "Origin: https://barantum.internal" \
  -d '{
    "customerName": "Siti Rahma",
    "requestorName": "Siti Rahma",
    "requestorPhone": "081987654321",
    "branch": "Surabaya",
    "referenceNumber": "BRT-2026-TEST002",
    "unit": {
      "licensePlate": "L 5678 ABC",
      "brand": "Daihatsu",
      "model": "Xenia",
      "odometer": 12000
    }
  }'
```

---

## 9. Panduan Pengujian via Postman

1. **Buka Postman** dan impor file collection:
   `middleware-assa/ASSA Middleware Server Dev (devmiddleware1.assa.id-6031).postman_collection.json`
2. **Cek Collection Variables**:
   - `baseUrl`: `http://localhost:6031` (atau `http://devmiddleware1.assa.id:6031`)
   - `baseUrlSR`: `http://localhost:8295`
   - `token_omnichannel`: `dev-token-omnichannel-12345`
   - `token_barantum`: `umk_da295902028f5804c4f0e9d9fd81fa07a2a0e1152d6171e30f387416fbfe5680`
3. **Buka Folder**: `7. Service Request Service (Port 8295)`
   - **Request 1: `Service Request (Barantum) - Public Endpoint POST (200 OK)`**:
     - Method: `POST`
     - URL: `{{baseUrlSR}}/api/vendor/public/service-requests` (atau ganti ke `{{baseUrl}}` untuk lewat port 6031)
     - Headers:
       - `X-API-Key`: `{{token_barantum}}`
       - `Origin`: `https://barantum.internal`
       - `Content-Type`: `application/json`
     - Body: Raw JSON Barantum
   - **Request 2: `Service Request - Get Paginated List (200 OK)`**:
     - Method: `GET`
     - URL: `{{baseUrlSR}}/api/vendor/public/service-requests?page=1&perPage=10`
     - Headers: `X-API-Key`: `{{token_barantum}}`
   - **Request 3: `Service Request - Valid Fan-out Paralel (200 OK)`**:
     - Method: `POST`
     - URL: `{{baseUrlSR}}/api/service-requests`
     - Auth: Bearer Token `{{token_omnichannel}}`
     - Body: Raw JSON 30 field Omnichannel
   - **Request 4: `Service Request - Missing Token (401 Unauthorized)`**:
     - Uji keamanan tanpa header Authorization / X-API-Key.
4. **Klik "Send"** pada masing-masing request dan verifikasi status code serta response body.

---

## 10. Checklist Acceptance & Verifikasi

- [x] Mendukung dual autentikasi (`X-API-Key` dengan token `umk_...` dan `Authorization: Bearer`).
- [x] Endpoint publik `/api/vendor/public/service-requests` aktif dan terhubung ke backend.
- [x] Payload Barantum CRM dengan nested `unit` diekstrak dan dipetakan ke 30 field form-urlencoded.
- [x] Endpoint `GET` mengembalikan daftar transaksi dengan metadata pagination lengkap (`page`, `perPage`, `total`, `totalPages`, `hasNext`, `hasPrev`).
- [x] Fan-out paralel via `<clone>` berjalan aman ke Target ATLAS (toggle) dan ASSA External Services.
- [x] Agregasi response menghasilkan JSON standar (`200` sukses, `207` partial, `502` bad gateway).
- [x] Idempotency berfungsi otomatis mencegah duplikasi transaksi.
- [x] Konfigurasi routing Nginx (`6031` dan `4002`) mengarah ke `service-request-service`.
