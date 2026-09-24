# Panduan Penggunaan Postman Collection: ASSA Middleware Server Dev
## Server Port: 6031 (`<DEV_HOST>:6031`)

Dokumentasi ini adalah panduan lengkap (*User & Testing Guide*) untuk penggunaan file Postman Collection:
📁 [`ASSA Middleware Server Dev.postman_collection.json`]

Panduan ini mencakup penjelasan arsitektur environment, manajemen variabel & token otentikasi, alur pengujian otomatis (*Pre-request Script & Tests*), penjelasan fungsional untuk **setiap 33 request**, serta alternatif perintah **cURL** siap pakai.

---

## Daftar Isi
1. [Arsitektur & Konteks Server Dev (Port 6031)](#1-arsitektur--konteks-server-dev-port-6031)
2. [Konfigurasi Environment & Variabel Koleksi](#2-konfigurasi-environment--variabel-koleksi)
3. [Mekanisme Otomasi Koleksi (Scripts & Guards)](#3-mekanisme-otomasi-koleksi-scripts--guards)
4. [Katalog Lengkap Request & Alternatif cURL](#4-katalog-lengkap-request--alternatif-curl)
   - [Folder 1 — Health & Readiness (All Services)](#folder-1--health--readiness-all-services)
   - [Folder 2 — Branch Service (Port 8290)](#folder-2--branch-service-port-8290)
   - [Folder 3 — Customer Service (Port 8291)](#folder-3--customer-service-port-8291)
   - [Folder 4 — Vehicle Service (Port 8292)](#folder-4--vehicle-service-port-8292)
   - [Folder 5 — Vendor Service (Port 8293)](#folder-5--vendor-service-port-8293)
   - [Folder 6 — SPK Service (Port 8294)](#folder-6--spk-service-port-8294)
   - [Folder 7 — Service Request Service (Port 8295)](#folder-7--service-request-service-port-8295)
   - [Folder 8 — Security & Negative Tests (401 & 403 Guards)](#folder-8--security--negative-tests-401--403-guards)
   - [Folder 9 — Background Retry Worker (Port 8295)](#folder-9--background-retry-worker-port-8295)
5. [Panduan Eksekusi (Postman GUI & Newman CLI)](#5-panduan-eksekusi-postman-gui--newman-cli)
6. [Troubleshooting & Solusi Error Umum](#6-troubleshooting--solusi-error-umum)

---

## 1. Arsitektur & Konteks Server Dev (Port 6031)

Pada lingkungan server pengembangan (**Server Dev ASSA**), seluruh microservice WSO2 MI dikemas ke dalam satu kontainer monorepo (`middleware-api`) dan dilayani oleh **Nginx Reverse Proxy** pada port **6031**:

```
+-----------------------------------------------------------------------------------+
|  Client (Postman / cURL / Frontend ATLAS / Omnichannel)                           |
+-----------------------------------------------------------------------------------+
                                         │
                                         ▼ HTTP Port 6031
+───────────────────────────────────────────────────────────────────────────────────+
|  Nginx Reverse Proxy (Container: <NGINX_CONTAINER>, Server Dev: <DEV_HOST>:6031)  |
|  - <DEV_HOST>:6031                                                               |
+───────────────────────────────────────────────────────────────────────────────────+
       │                     │                     │                     │
       ▼ /health/*           ▼ /api/branches/*     ▼ /api/vehicles/*     ▼ /api/vendors/*
       ▼ /api/customers/*    ▼ /api/spk/*          ▼ /api/service-req/*  ▼ /api/worker/*
+───────────────────────────────────────────────────────────────────────────────────+
|  WSO2 Micro Integrator Monorepo (Container: middleware-api :8290)                 |
|  - Seluruh CApp aktif dalam satu runtime engine WSO2 MI                           |
+───────────────────────────────────────────────────────────────────────────────────+
          │                                                    │
          ▼ SQL                                                ▼ XML over FTP
+───────────────────────+                            +──────────────────────────────+
| MariaDB (<DB_CONTAINER>) |                          | Dev QA FTP Server            |
| Port Internal: <DB_PORT> |                          | <FTP_HOST>:<FTP_PORT>       |
+───────────────────────+                            +──────────────────────────────+
```

### Keuntungan Port Tunggal (6031):
- **Satu Pintu Masuk**: Anda tidak perlu berganti-ganti port 8290, 8291, 8292, dst. Semua request diarahkan ke `<DEV_BASE_URL>`.
- **Rute Path Presisi**: Nginx memetakan path seperti `/api/branches/`, `/api/customers/`, `/api/vehicles/`, `/api/vendors/`, `/api/spk/`, `/api/service-requests/`, dan `/api/worker/` langsung ke backend WSO2 MI secara transparan.

---

## 2. Konfigurasi Environment & Variabel Koleksi

Koleksi ini menggunakan **Collection Variables** bawaan sehingga dapat langsung dijalankan setelah di-import tanpa perlu konfigurasi environment eksternal tambahan.

### 2.1. Variabel Base URL

| Nama Variabel | Nilai Default Koleksi | Keterangan | Alternatif Direct Local |
|---|---|---|---|
| `baseUrlBranch` | `<DEV_BASE_URL>` | Endpoint Branch Service & Health | `http://localhost:8290` |
| `baseUrlCustomer` | `<DEV_BASE_URL>` | Endpoint Customer Service | `http://localhost:8291` |
| `baseUrlVehicle` | `<DEV_BASE_URL>` | Endpoint Vehicle Service & Atlas | `http://localhost:8292` |
| `baseUrlVendor` | `<DEV_BASE_URL>` | Endpoint Vendor Create (VMD) | `http://localhost:8293` |
| `baseUrlSPK` | `<DEV_BASE_URL>` | Endpoint SPK Duelist | `http://localhost:8294` |
| `baseUrlSR` | `<DEV_BASE_URL>` | Endpoint Service Request & Worker | `http://localhost:8295` |

> [!TIP]
> Jika server dapat diakses melalui domain internal DNS, Anda dapat mengubah nilai variabel di atas menjadi `<DEV_BASE_URL>:6031`.

### 2.2. Token Otentikasi & Hak Akses (Scope Matrix)

Middleware ASSA menerapkan pengamanan ganda: **Auth Guard** (verifikasi token terdaftar) dan **Scope Guard** (hak akses per-service).

| Nama Variabel | Nilai Token (Bearer) | Scope yang Dimiliki | Boleh Mengakses |
|---|---|---|---|
| `token_app_a` | `<TOKEN_APP_A>` | `branches`, `customers` | Branch & Customer API |
| `token_app_b` | `<TOKEN_APP_B>` | `vehicles` | Vehicle API saja |
| `token_qa` | `<TOKEN_QA>` | `vehicles`, `vendors`, `spk` | Vehicle, Vendor, SPK API |
| `token_omnichannel` | `<TOKEN_OMNICHANNEL>` | `service_requests` | Service Request API |
| *(Token Palsu)* | `<INVALID_TOKEN>` | *(Tidak ada)* | Digunakan untuk tes respons `401 Unauthorized` |

### 2.3. Variabel Data & Transaksi

| Nama Variabel | Nilai Awal | Keterangan |
|---|---|---|
| `companyCode` | `<COMPANY_CODE>` | Kode entitas perusahaan default |
| `vendor_trx_id` | `<TRANSACTION_ID>` | Di-update otomatis saat request Vendor Create dijalankan |
| `spk_trx_id` | `<TRANSACTION_ID>` | Di-update otomatis saat request SPK Duelist dijalankan |
| `sr_trx_id` | `<TRANSACTION_ID>` | Di-update otomatis saat request Service Request dijalankan |

---

## 3. Mekanisme Otomasi Koleksi (Scripts & Guards)

Koleksi Postman ini dirancang untuk dapat diuji secara mandiri maupun beruntun (*Collection Runner*) berkat script otomatis berikut:

### 3.1. Pre-request Script (Otomasi Idempotency Key)
Pada request pembuatan data (`Vendor Create`, `SPK Duelist`, dan `Service Request`), terdapat skrip yang otomatis membangkitkan transaction ID unik berbasis timestamp sebelum request dikirim:
```javascript
// Contoh pada Vendor Create:
const trxId = 'TRX-POSTMAN-' + Date.now();
pm.collectionVariables.set('vendor_trx_id', trxId);
```
Dengan skrip ini:
1. **Request 1 (Create)** mengirim ID baru `TRX-POSTMAN-xxxx` -> Server memproses dan mengembalikan `201 Created`.
2. **Request 2 (Idempotency Replay)** menggunakan variabel `vendor_trx_id` yang sama persis tanpa mengubah nilainya -> Server mendeteksi duplikasi transaksi dan mengembalikan cache `200 OK` (Replay).

### 3.2. Tests Script (Validasi Otomatis)
Setiap request dilengkapi assertion pengujian otomatis untuk memvalidasi:
- **HTTP Status Code**: Memastikan respon sesuai (`200`, `201`, `400`, `401`, `403`).
- **Health Status**: Memastikan payload JSON berstatus `UP` (`pm.expect(jsonData.status).to.eql('UP')`).

---

## 4. Katalog Lengkap Request & Alternatif cURL

---

### Folder 1 — Health & Readiness (All Services)
Fungsi: Memeriksa kesiapan container, modul WSO2 MI, dan database MariaDB.

#### 1.1. Health Check - Branch Service (8290)
- **Fungsi**: Memeriksa liveness modul Branch Service.
- **Method / Path**: `GET /health/branch`
- **URL Postman**: `{{baseUrlBranch}}health/branch`
- **Auth**: None
- **Expected Status**: `200 OK` (`{"status":"UP", ...}`)
- **Alternatif cURL**:
  ```bash
  curl -X GET "<DEV_BASE_URL>/health/branch"
  ```
  *(Direct Local: `curl -X GET "http://localhost:8290/health/branch"`)*

> [!NOTE]
> Pada URL raw Postman Request 1.1 tertulis `{{baseUrlBranch}}health/branch`. Pastikan variabel `baseUrlBranch` memiliki trailing slash `/` di akhir jika path tidak diawali garis miring.

#### 1.2. Health Check - Readiness (8290)
- **Fungsi**: Memeriksa kesiapan WSO2 MI menerima traffic routing.
- **Method / Path**: `GET /health/ready`
- **URL Postman**: `{{baseUrlBranch}}/health/ready`
- **Auth**: None
- **Expected Status**: `200 OK`
- **Alternatif cURL**:
  ```bash
  curl -X GET "<DEV_BASE_URL>/health/ready"
  ```

#### 1.3. Health Check - Customer Service (8291)
- **Fungsi**: Memeriksa status kesehatan modul Customer Service.
- **Method / Path**: `GET /health/customer`
- **URL Postman**: `{{baseUrlCustomer}}/health/customer`
- **Auth**: None
- **Expected Status**: `200 OK`
- **Alternatif cURL**:
  ```bash
  curl -X GET "<DEV_BASE_URL>/health/customer"
  ```

#### 1.4. Health Check - Vehicle Service (8292)
- **Fungsi**: Memeriksa modul Vehicle Service & konektivitas backend vehicle.
- **Method / Path**: `GET /health/vehicle`
- **URL Postman**: `{{baseUrlVehicle}}/health/vehicle`
- **Auth**: None
- **Expected Status**: `200 OK`
- **Alternatif cURL**:
  ```bash
  curl -X GET "<DEV_BASE_URL>/health/vehicle"
  ```

#### 1.5. Health Check - Vendor Service (8293)
- **Fungsi**: Memeriksa kesiapan modul Vendor dan koneksi FTP/DB MariaDB.
- **Method / Path**: `GET /health/vendor`
- **URL Postman**: `{{baseUrlVendor}}/health/vendor`
- **Auth**: None
- **Expected Status**: `200 OK`
- **Alternatif cURL**:
  ```bash
  curl -X GET "<DEV_BASE_URL>/health/vendor"
  ```

#### 1.6. Health Check - SPK Service (8294)
- **Fungsi**: Memeriksa kesiapan modul SPK Duelist.
- **Method / Path**: `GET /health/spk`
- **URL Postman**: `{{baseUrlSPK}}/health/spk`
- **Auth**: None
- **Expected Status**: `200 OK`
- **Alternatif cURL**:
  ```bash
  curl -X GET "<DEV_BASE_URL>/health/spk"
  ```

#### 1.7. Health Check - Service Request (8295)
- **Fungsi**: Memeriksa modul Service Request & background retry worker.
- **Method / Path**: `GET /health/service-request`
- **URL Postman**: `{{baseUrlSR}}/health/service-request`
- **Auth**: None
- **Expected Status**: `200 OK`
- **Alternatif cURL**:
  ```bash
  curl -X GET "<DEV_BASE_URL>/health/service-request"
  ```

---

### Folder 2 — Branch Service (Port 8290)

#### 2.1. Get Branches by Create Date (App A)
- **Fungsi**: Mengambil data cabang ASSA dari backend SAP Core berdasarkan rentang tanggal pembuatan dan kode perusahaan.
- **Method / Path**: `GET /api/branches/getByCreateDate`
- **Auth**: `Bearer {{token_app_a}}`
- **Headers**:
  - `X-Correlation-Id: corr-branch-001`
- **Query Params**:
  - `companyCode`: `<COMPANY_CODE>` (dari variabel `{{companyCode}}`)
  - `dateStart`: `2020-01-01`
  - `dateEnd`: `<END_DATE>`
  - `page`: `1`
  - `perPage`: `10`
- **Expected Status**: `200 OK`
- **Alternatif cURL**:
  ```bash
  curl -X GET "<DEV_BASE_URL>/api/branches/getByCreateDate?companyCode=<COMPANY_CODE>&dateStart=<START_DATE>&dateEnd=<END_DATE>&page=1&perPage=10" \
    -H "Authorization: Bearer <TOKEN_APP_A>" \
    -H "X-Correlation-Id: corr-branch-001"
  ```

---

### Folder 3 — Customer Service (Port 8291)

#### 3.1. Get Customers by Create Date (App A)
- **Fungsi**: Mengambil data pelanggan dari SAP Core berdasarkan rentang tanggal pembuatan.
- **Method / Path**: `GET /api/customers/getByCreateDate`
- **Auth**: `Bearer {{token_app_a}}`
- **Headers**:
  - `X-Correlation-Id: corr-cust-001`
- **Query Params**:
  - `companyCode`: `<COMPANY_CODE>`
  - `dateStart`: `2020-01-01`
  - `dateEnd`: `<END_DATE>`
  - `page`: `1`
  - `perPage`: `10`
- **Expected Status**: `200 OK`
- **Alternatif cURL**:
  ```bash
  curl -X GET "<DEV_BASE_URL>/api/customers/getByCreateDate?companyCode=<COMPANY_CODE>&dateStart=<START_DATE>&dateEnd=<END_DATE>&page=1&perPage=10" \
    -H "Authorization: Bearer <TOKEN_APP_A>" \
    -H "X-Correlation-Id: corr-cust-001"
  ```

---

### Folder 4 — Vehicle Service (Port 8292)

#### 4.1. Get Vehicle by License Plate (App B - plate_no)
- **Fungsi**: Mencari spesifikasi dan status kendaraan berdasarkan nomor plat (`plate_no`) menggunakan Token App B (khusus vehicle).
- **Method / Path**: `GET /api/vehicles/getByLicensePlate`
- **Auth**: `Bearer {{token_app_b}}`
- **Query Params**:
  - `plate_no`: `<PLATE_NUMBER>`
- **Expected Status**: `200 OK`
- **Alternatif cURL**:
  ```bash
  curl -X GET "<DEV_BASE_URL>/api/vehicles/getByLicensePlate?plate_no=<PLATE_NUMBER>" \
    -H "Authorization: Bearer <TOKEN_APP_B>"
  ```

#### 4.2. Get Vehicle Atlas (QA Token)
- **Fungsi**: Memanggil endpoint pencarian kendaraan khusus integrasi ATLAS (`/vehicleatlas`) menggunakan Token QA.
- **Method / Path**: `GET /api/vehicles/vehicleatlas`
- **Auth**: `Bearer {{token_qa}}`
- **Query Params**:
  - `plate_no`: `<PLATE_NUMBER>`
- **Expected Status**: `200 OK`
- **Alternatif cURL**:
  ```bash
  curl -X GET "<DEV_BASE_URL>/api/vehicles/vehicleatlas?plate_no=<PLATE_NUMBER>" \
    -H "Authorization: Bearer <TOKEN_QA>"
  ```

#### 4.3. Vehicle Tanpa Parameter (Expect 400 Bad Request)
- **Fungsi**: Uji validasi input saat client tidak menyertakan query parameter identitas kendaraan (`plate_no` atau `equipment_no`).
- **Method / Path**: `GET /api/vehicles/getByLicensePlate`
- **Auth**: `Bearer {{token_app_b}}`
- **Query Params**:
  - `companyCode`: `<COMPANY_CODE>` *(tanpa `plate_no`)*
- **Expected Status**: `400 Bad Request`
- **Alternatif cURL**:
  ```bash
  curl -X GET "<DEV_BASE_URL>/api/vehicles/getByLicensePlate?companyCode=<COMPANY_CODE>" \
    -H "Authorization: Bearer <TOKEN_APP_B>"
  ```

---

### Folder 5 — Vendor Service (Port 8293)

#### 5.1. Vendor Create - Valid Payload (201 Created)
- **Fungsi**: Menerima 17 field data master vendor V2 ATLAS, membentuk file XML (`Transaction` -> `Header` Key2=VMD + `TransactionDatas`), menyimpannya ke database MariaDB, dan mengunggahnya ke server FTP inbound SAP (`<FTP_HOST>:/vmd`).
- **Pre-request Script**: Membangkitkan `vendor_trx_id` baru (misal `TRX-POSTMAN-<TIMESTAMP>`).
- **Method / Path**: `POST /api/vendors/create`
- **Auth**: `Bearer {{token_qa}}`
- **Headers**:
  - `Content-Type: application/json`
  - `X-Transaction-Id: {{vendor_trx_id}}`
- **Request Body (JSON)**:
  ```json
  {
    "companyTitle": "PT",
    "companyName": "Example Company Ltd",
    "otv": "No",
    "paymentCycle": "Monthly",
    "accountNumber": "<ACCOUNT_NUMBER>",
    "accountName": "Example Account Holder",
    "bankName": "Example Bank",
    "hoEmail": "vendor@example.invalid",
    "hoPhone": "<PHONE_NUMBER>",
    "hoAddress": "<BUSINESS_ADDRESS>",
    "contactName": "Example Contact",
    "contactPhone": "<CONTACT_PHONE>",
    "npwp": "<TAX_ID>",
    "accountGroup": "V010",
    "top": "T014",
    "glAccount": "<GL_ACCOUNT>",
    "documentNumber": "<VENDOR_DOCUMENT_ID>"
  }
  ```
- **Expected Status**: `201 Created`
- **Alternatif cURL**:
  ```bash
  TRX="TRX-VMD-$(date +%s)"
  curl -X POST "<DEV_BASE_URL>/api/vendors/create" \
    -H "Authorization: Bearer <TOKEN_QA>" \
    -H "Content-Type: application/json" \
    -H "X-Transaction-Id: $TRX" \
    -d '{
      "companyTitle": "PT",
      "companyName": "Example Company Ltd",
      "otv": "No",
      "paymentCycle": "Monthly",
      "accountNumber": "<ACCOUNT_NUMBER>",
      "accountName": "Example Account Holder",
      "bankName": "Example Bank",
      "hoEmail": "vendor@example.invalid",
      "hoPhone": "<PHONE_NUMBER>",
      "hoAddress": "<BUSINESS_ADDRESS>",
      "contactName": "Example Contact",
      "contactPhone": "<CONTACT_PHONE>",
      "npwp": "<TAX_ID>",
      "accountGroup": "V010",
      "top": "T014",
      "glAccount": "<GL_ACCOUNT>",
      "documentNumber": "<VENDOR_DOCUMENT_ID>"
    }'
  ```

#### 5.2. Vendor Create - Idempotency Replay (200 Replay)
- **Fungsi**: Mengirim ulang payload yang sama dengan `X-Transaction-Id` yang persis sama dari Request 5.1 untuk memverifikasi proteksi Idempotency Guard (transaksi tidak diproses ulang ke FTP, melainkan mengembalikan cache status sukses).
- **Method / Path**: `POST /api/vendors/create`
- **Auth**: `Bearer {{token_qa}}`
- **Headers**:
  - `Content-Type: application/json`
  - `X-Transaction-Id: {{vendor_trx_id}}`
- **Request Body**: Sama seperti 5.1.
- **Expected Status**: `200 OK` (Replay)
- **Alternatif cURL**:
  ```bash
  # Menggunakan nilai $TRX yang sama dari eksekusi sebelumnya:
  curl -X POST "<DEV_BASE_URL>/api/vendors/create" \
    -H "Authorization: Bearer <TOKEN_QA>" \
    -H "Content-Type: application/json" \
    -H "X-Transaction-Id: $TRX" \
    -d '{ ...payload sama... }'
  ```

#### 5.3. Vendor Create - Invalid Payload (400 Bad Request)
- **Fungsi**: Memastikan validasi skema menolak payload dengan nilai title yang tidak valid (`companyTitle: "INVALID_TITLE"`) atau field wajib yang hilang.
- **Method / Path**: `POST /api/vendors/create`
- **Auth**: `Bearer {{token_qa}}`
- **Headers**: `Content-Type: application/json`
- **Request Body (JSON)**:
  ```json
  {
    "companyTitle": "INVALID_TITLE",
    "companyName": "PT Test",
    "otv": "No"
  }
  ```
- **Expected Status**: `400 Bad Request`
- **Alternatif cURL**:
  ```bash
  curl -X POST "<DEV_BASE_URL>/api/vendors/create" \
    -H "Authorization: Bearer <TOKEN_QA>" \
    -H "Content-Type: application/json" \
    -d '{"companyTitle": "INVALID_TITLE", "companyName": "PT Test", "otv": "No"}'
  ```

---

### Folder 6 — SPK Service (Port 8294)

#### 6.1. SPK Duelist - Valid Payload + Total Check (201 Created)
- **Fungsi**: Menerima data SPK (Surat Perintah Kerja) Duelist, memvalidasi kesesuaian total harga dengan rincian detail, membentuk file XML SPK, menyimpannya ke MariaDB, dan mengirimkannya ke folder FTP SAP `/spk`.
- **Pre-request Script**: Membangkitkan `spk_trx_id` baru.
- **Method / Path**: `POST /api/spk/duelist`
- **Auth**: `Bearer {{token_qa}}`
- **Headers**:
  - `Content-Type: application/json`
  - `X-Transaction-Id: {{spk_trx_id}}`
  - `X-Forwarded-For: <CLIENT_IP>`
  - `X-Validate-Total: true`
- **Request Body (JSON)**:
  ```json
  {
    "noSpk": "<SPK_NUMBER>",
    "type": "Maintenance",
    "noPolisi": "<PLATE_NUMBER>",
    "noSr": "<SERVICE_REQUEST_ID>",
    "category": "Maintenance",
    "subCategory": "Adhoc",
    "vendorReferensi": "<VENDOR_REFERENCE>",
    "namaVendor": "Example Workshop",
    "picService": "<SERVICE_CONTACT_ID>",
    "namaPicService": "Example Service Contact",
    "spkRework": "No",
    "totalPrice": 1000,
    "createdAt": "<CREATED_AT>",
    "createdBy": "<CREATED_BY>",
    "poSpkNumber": "<PO_NUMBER>",
    "invoiceNumber": "<INVOICE_NUMBER>",
    "invoiceDate": "<INVOICE_DATE>",
    "invoiceAmount": 1000,
    "memo": "Example repair",
    "taxInvoiceNumber": "<TAX_INVOICE_NUMBER>",
    "taxInvoiceDate": "<TAX_INVOICE_DATE>",
    "businessArea": "<BUSINESS_AREA>",
    "details": [
      {
        "jenis": "Jasa",
        "description": "Example service",
        "qty": 1,
        "price": 100
      },
      {
        "jenis": "Parts",
        "description": "Example part",
        "qty": 1,
        "price": 900
      }
    ]
  }
  ```
- **Expected Status**: `201 Created`
- **Alternatif cURL**:
  ```bash
  SPK_TRX="SPK-$(date +%s)"
  curl -X POST "<DEV_BASE_URL>/api/spk/duelist" \
    -H "Authorization: Bearer <TOKEN_QA>" \
    -H "Content-Type: application/json" \
    -H "X-Transaction-Id: $SPK_TRX" \
    -H "X-Forwarded-For: <CLIENT_IP>" \
    -H "X-Validate-Total: true" \
    -d '{
      "noSpk": "<SPK_NUMBER>",
      "type": "Maintenance",
      "noPolisi": "<PLATE_NUMBER>",
      "totalPrice": 1000,
      "details": [
         {"jenis": "Jasa", "description": "Example service", "qty": 1, "price": 100},
         {"jenis": "Parts", "description": "Example part", "qty": 1, "price": 900}
      ]
    }'
  ```

#### 6.2. SPK Duelist - Idempotency Replay (200 Replay)
- **Fungsi**: Memverifikasi idempotency SPK saat request dengan ID yang sama dikirim ulang.
- **Method / Path**: `POST /api/spk/duelist`
- **Auth**: `Bearer {{token_qa}}`
- **Headers**: Sama dengan 6.1 (`X-Transaction-Id: {{spk_trx_id}}`).
- **Expected Status**: `200 OK` (Replay)

#### 6.3. SPK Duelist - Missing noSpk (400 Bad Request)
- **Fungsi**: Uji validasi saat field wajib `noSpk` tidak disertakan.
- **Method / Path**: `POST /api/spk/duelist`
- **Auth**: `Bearer {{token_qa}}`
- **Request Body (JSON)**:
  ```json
  {
    "type": "Maintenance",
    "noPolisi": "<PLATE_NUMBER>",
    "details": []
  }
  ```
- **Expected Status**: `400 Bad Request`
- **Alternatif cURL**:
  ```bash
  curl -X POST "<DEV_BASE_URL>/api/spk/duelist" \
    -H "Authorization: Bearer <TOKEN_QA>" \
    -H "Content-Type: application/json" \
    -d '{"type": "Maintenance", "noPolisi": "<PLATE_NUMBER>", "details": []}'
  ```

#### 6.4. SPK Duelist - Total Mismatch (400 Bad Request)
- **Fungsi**: Uji validasi header `X-Validate-Total: true`. Request ditolak jika `totalPrice` (`1001`) tidak sama dengan total rincian `details` (`1000`).
- **Method / Path**: `POST /api/spk/duelist`
- **Auth**: `Bearer {{token_qa}}`
- **Headers**: `X-Validate-Total: true`
- **Request Body (JSON)**:
  ```json
  {
    "noSpk": "<SPK_NUMBER>",
    "type": "Maintenance",
    "totalPrice": 1001,
    "details": [
      {
        "jenis": "Jasa",
        "description": "Example service",
        "qty": 1,
        "price": 1000
      }
    ]
  }
  ```
- **Expected Status**: `400 Bad Request`
- **Alternatif cURL**:
  ```bash
  curl -X POST "<DEV_BASE_URL>/api/spk/duelist" \
    -H "Authorization: Bearer <TOKEN_QA>" \
    -H "Content-Type: application/json" \
    -H "X-Validate-Total: true" \
    -d '{
      "noSpk": "<SPK_NUMBER>",
      "type": "Maintenance",
      "totalPrice": 1001,
      "details": [{"jenis": "Jasa", "description": "Example service", "qty": 1, "price": 1000}]
    }'
  ```

---

### Folder 7 — Service Request Service (Port 8295)

#### 7.1. Service Request - Valid Fan-out Paralel (200 OK)
- **Fungsi**: Menerima tiket perawatan/perbaikan dari Omnichannel, lalu melakukan **Fan-out Paralel**:
  1. Mengirim data ke External Service (`<EXTERNAL_SERVICE_HOST>`).
  2. Mengirim data ke sistem ATLAS (jika toggle aktif).
  3. Mencatat riwayat ke MariaDB.
- **Pre-request Script**: Membangkitkan `sr_trx_id` baru.
- **Method / Path**: `POST /api/service-requests`
- **Auth**: `Bearer {{token_omnichannel}}`
- **Headers**:
  - `Content-Type: application/json`
  - `X-Transaction-Id: {{sr_trx_id}}`
- **Request Body (JSON)**:
  ```json
  {
    "app_id": "<APPLICATION_ID>",
    "reff_number": "<REFERENCE_NUMBER>",
    "branch_code": "<BRANCH_CODE>",
    "equipment_number": "<EQUIPMENT_NUMBER>",
    "license_plate": "<PLATE_NUMBER>",
    "customer_code": "<CUSTOMER_CODE>",
    "customer_name": "Example Customer",
    "channel": "Omnichannel-Web",
    "cp_title": "Bpk",
    "cp_name": "Example Contact",
    "cp_phone": "<CONTACT_PHONE>",
    "cp_email": "contact@example.invalid",
    "cp_address": "<CONTACT_ADDRESS>",
    "km": "<ODOMETER_READING>",
    "description": "Example scheduled maintenance request",
    "service_datetime": "<SERVICE_DATETIME>",
    "service_location": "<SERVICE_LOCATION>",
    "jenis_permintaan": "Service Berkala",
    "incident_datetime": "<INCIDENT_DATETIME>",
    "tipe_tiket": "Regular",
    "judul": "Service Berkala Kendaraan Operasional",
    "nama_kunjungan": "Example Contact",
    "telepon_kunjungan": "<CONTACT_PHONE>",
    "alamat_kunjungan": "<VISIT_ADDRESS>",
    "pool_name": "<POOL_NAME>",
    "area_bengkel": "<SERVICE_AREA>",
    "task": "Example maintenance task",
    "created_datetime": "<CREATED_DATE>",
    "created_by": "<CREATED_BY>",
    "ticket_no": "<TICKET_NUMBER>"
  }
  ```
- **Expected Status**: `200 OK`
- **Alternatif cURL**:
  ```bash
  SR_TRX="SR-$(date +%s)"
  curl -X POST "<DEV_BASE_URL>/api/service-requests" \
    -H "Authorization: Bearer <TOKEN_OMNICHANNEL>" \
    -H "Content-Type: application/json" \
    -H "X-Transaction-Id: $SR_TRX" \
    -d '{
      "app_id": "<APPLICATION_ID>",
      "reff_number": "<REFERENCE_NUMBER>",
      "branch_code": "<BRANCH_CODE>",
      "equipment_number": "<EQUIPMENT_NUMBER>",
      "license_plate": "<PLATE_NUMBER>",
      "ticket_no": "<TICKET_NUMBER>"
    }'
  ```

#### 7.2. Service Request - Idempotency Replay (200 Replay)
- **Fungsi**: Mengirim ulang request SR dengan `X-Transaction-Id` sama untuk memastikan tiket tidak di-fanout ganda.
- **Method / Path**: `POST /api/service-requests`
- **Auth**: `Bearer {{token_omnichannel}}`
- **Expected Status**: `200 OK` (Replay)

#### 7.3. Service Request - Missing app_id (400 Bad Request)
- **Fungsi**: Validasi input saat field wajib `app_id` tidak ada dalam payload JSON.
- **Method / Path**: `POST /api/service-requests`
- **Auth**: `Bearer {{token_omnichannel}}`
- **Request Body (JSON)**:
  ```json
  {
    "reff_number": "<REFERENCE_NUMBER>",
    "branch_code": "<BRANCH_CODE>",
    "ticket_no": "<TICKET_NUMBER>"
  }
  ```
- **Expected Status**: `400 Bad Request`
- **Alternatif cURL**:
  ```bash
  curl -X POST "<DEV_BASE_URL>/api/service-requests" \
    -H "Authorization: Bearer <TOKEN_OMNICHANNEL>" \
    -H "Content-Type: application/json" \
    -d '{"reff_number": "<REFERENCE_NUMBER>", "branch_code": "<BRANCH_CODE>", "ticket_no": "<TICKET_NUMBER>"}'
  ```

---

### Folder 8 — Security & Negative Tests (401 & 403 Guards)
Fungsi: Memastikan keandalan sistem keamanan API Gateway WSO2 MI dari akses ilegal dan pelanggaran otorisasi scope.

#### 8.1. Branch - Missing Token (401 Unauthorized)
- **Method / Path**: `GET /api/branches/getByCreateDate?companyCode=<COMPANY_CODE>`
- **Auth**: *(Tanpa Header Authorization)*
- **Expected Status**: `401 Unauthorized`
- **cURL**:
  ```bash
  curl -X GET "<DEV_BASE_URL>/api/branches/getByCreateDate?companyCode=<COMPANY_CODE>"
  ```

#### 8.2. Branch - Invalid Fake Token (401 Unauthorized)
- **Method / Path**: `GET /api/branches/getByCreateDate?companyCode=<COMPANY_CODE>`
- **Auth**: `Bearer <INVALID_TOKEN>`
- **Expected Status**: `401 Unauthorized`
- **cURL**:
  ```bash
  curl -X GET "<DEV_BASE_URL>/api/branches/getByCreateDate?companyCode=<COMPANY_CODE>" \
    -H "Authorization: Bearer <INVALID_TOKEN>"
  ```

#### 8.3. Branch - App B Access Branch (403 Forbidden)
- **Keterangan**: App B hanya memiliki scope `vehicles`. Akses ke Branch ditolak.
- **Method / Path**: `GET /api/branches/getByCreateDate?companyCode=<COMPANY_CODE>`
- **Auth**: `Bearer {{token_app_b}}`
- **Expected Status**: `403 Forbidden`
- **cURL**:
  ```bash
  curl -X GET "<DEV_BASE_URL>/api/branches/getByCreateDate?companyCode=<COMPANY_CODE>" \
    -H "Authorization: Bearer <TOKEN_APP_B>"
  ```

#### 8.4. Customer - App B Access Customer (403 Forbidden)
- **Keterangan**: App B tidak memiliki scope `customers`.
- **Method / Path**: `GET /api/customers/getByCreateDate?companyCode=<COMPANY_CODE>`
- **Auth**: `Bearer {{token_app_b}}`
- **Expected Status**: `403 Forbidden`
- **cURL**:
  ```bash
  curl -X GET "<DEV_BASE_URL>/api/customers/getByCreateDate?companyCode=<COMPANY_CODE>" \
    -H "Authorization: Bearer <TOKEN_APP_B>"
  ```

#### 8.5. Vendor - Missing Token (401 Unauthorized)
- **Method / Path**: `POST /api/vendors/create`
- **Auth**: *(Tanpa Token)*
- **Expected Status**: `401 Unauthorized`
- **cURL**:
  ```bash
  curl -X POST "<DEV_BASE_URL>/api/vendors/create" \
    -H "Content-Type: application/json" \
    -d "{}"
  ```

#### 8.6. Vendor - App B without vendors scope (403 Forbidden)
- **Keterangan**: Token App B mencoba melakukan create vendor.
- **Method / Path**: `POST /api/vendors/create`
- **Auth**: `Bearer {{token_app_b}}`
- **Expected Status**: `403 Forbidden`
- **cURL**:
  ```bash
  curl -X POST "<DEV_BASE_URL>/api/vendors/create" \
    -H "Authorization: Bearer <TOKEN_APP_B>" \
    -H "Content-Type: application/json" \
    -d "{}"
  ```

#### 8.7. SPK - Missing Token (401 Unauthorized)
- **Method / Path**: `POST /api/spk/duelist`
- **Auth**: *(Tanpa Token)*
- **Expected Status**: `401 Unauthorized`
- **cURL**:
  ```bash
  curl -X POST "<DEV_BASE_URL>/api/spk/duelist" \
    -H "Content-Type: application/json" \
    -d "{}"
  ```

#### 8.8. SPK - App B without spk scope (403 Forbidden)
- **Method / Path**: `POST /api/spk/duelist`
- **Auth**: `Bearer {{token_app_b}}`
- **Expected Status**: `403 Forbidden`
- **cURL**:
  ```bash
  curl -X POST "<DEV_BASE_URL>/api/spk/duelist" \
    -H "Authorization: Bearer <TOKEN_APP_B>" \
    -H "Content-Type: application/json" \
    -d "{}"
  ```

#### 8.9. Service Request - Missing Token (401 Unauthorized)
- **Method / Path**: `POST /api/service-requests`
- **Auth**: *(Tanpa Token)*
- **Expected Status**: `401 Unauthorized`
- **cURL**:
  ```bash
  curl -X POST "<DEV_BASE_URL>/api/service-requests" \
    -H "Content-Type: application/json" \
    -d "{}"
  ```

#### 8.10. Service Request - App B without scope (403 Forbidden)
- **Method / Path**: `POST /api/service-requests`
- **Auth**: `Bearer {{token_app_b}}`
- **Expected Status**: `403 Forbidden`
- **cURL**:
  ```bash
  curl -X POST "<DEV_BASE_URL>/api/service-requests" \
    -H "Authorization: Bearer <TOKEN_APP_B>" \
    -H "Content-Type: application/json" \
    -d "{}"
  ```

---

### Folder 9 — Background Retry Worker (Port 8295)

#### 9.1. Trigger Manual Retry Worker (200 OK)
- **Fungsi**: Memicu pemrosesan manual antrean transaksi yang berstatus `PENDING` atau `FAILED` pada tabel database `service_request_retry` / `vendor_transactions` untuk dikirimkan kembali ke target endpoint.
- **Method / Path**: `GET /api/worker/retry`
- **URL Postman**: `{{baseUrlSR}}/api/worker/retry`
- **Auth**: None
- **Expected Status**: `200 OK`
- **Alternatif cURL**:
  ```bash
  curl -X GET "<DEV_BASE_URL>/api/worker/retry"
  ```

---

## 5. Panduan Eksekusi (Postman GUI & Newman CLI)

### 5.1. Cara Import ke Postman GUI
1. Buka aplikasi **Postman**.
2. Klik tombol **Import** di pojok kiri atas.
3. Seret (*drag & drop*) file [`ASSA Middleware Server Dev (sanitized).postman_collection.json`] atau browse melalui file dialog.
4. Klik **Import**. Koleksi akan muncul dengan nama `ASSA Middleware Server Dev (sanitized)`.
5. *(Opsional)* Jika ingin menguji lokal, ubah variabel `baseUrl...` menjadi `http://localhost:829x` atau buat Postman Environment baru.

### 5.2. Menjalankan Seluruh Koleksi (Collection Runner)
1. Klik kanan pada nama koleksi di Postman, pilih **Run collection**.
2. Pastikan seluruh 33 request terpilih.
3. Klik tombol **Run ASSA Middleware Server Dev...**.
4. Semua pengujian otomatis (*tests*) akan berjalan secara berurutan:
   - Request Create akan mendahului Request Replay.
   - Hasil akan menampilkan badge hijau `PASS` untuk semua skenario positif maupun negatif (401/403/400).

### 5.3. Eksekusi Otomatis via Terminal / CI dengan Newman
Bila ingin menjalankan pengujian otomatis di server Linux atau terminal CI/CD:
```bash
# Pastikan newman terpasang
npm install -g newman

# Jalankan pengujian langsung dari file koleksi
newman run "ASSA Middleware Server Dev (sanitized).postman_collection.json" \
  --reporters cli,junit \
  --reporter-junit-export report.xml
```

---

## 6. Troubleshooting & Solusi Error Umum

| Gejala Error | Penyebab | Solusi |
|---|---|---|
| `Connection refused` ke port `6031` | Container Nginx belum berjalan atau port 6031 diblokir firewall server. | Di server dev, jalankan `docker compose ps` di direktori deployment dan pastikan container Nginx berstatus `Up`. |
| `502 Bad Gateway` dari Nginx | Container `middleware-api` (WSO2 MI) belum selesai startup atau restart mendadak. | Tunggu 30-60 detik saat inisialisasi awal WSO2 MI. Periksa log: `docker compose logs -f middleware-api`. |
| `401 Unauthorized` pada Request Positif | Token Bearer terhapus atau variabel token tidak terbaca. | Pastikan variabel `token_app_a`, `token_app_b`, `token_qa`, atau `token_omnichannel` di Postman terisi sesuai tabel Section 2.2. |
| `403 Forbidden` pada Request Positif | Token yang digunakan tidak memiliki scope untuk service terkait. | Sesuaikan token dengan hak aksesnya (misal: Branch wajib `token_app_a`, Vendor wajib `token_qa`). |
| `400 Bad Request` pada Idempotency Replay | Header `X-Transaction-Id` kosong. | Pastikan request Create dijalankan lebih dulu agar `Pre-request Script` mengisi variabel `trx_id`. |
| Respon FTP Error pada Vendor/SPK | Koneksi FTP ke `<FTP_HOST>:<FTP_PORT>` bermasalah. | Pastikan server dev memiliki rute egress jaringan ke server FTP dan kredensial FTP di `.env` sudah benar. |
