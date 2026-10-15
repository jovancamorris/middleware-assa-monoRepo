# ASSA Middleware - Postman Collection & Test Suite

Koleksi Postman resmi untuk pengujian seluruh API ASSA Middleware WSO2 MI Monorepo & Nginx Gateway (Port 6031). Dilengkapi dengan **pre-request scripts dinamis** dan **automated test assertions** (`pm.test`) pada setiap request.

---

## 📁 Berkas yang Disediakan

### 1. Dua Koleksi Siap Pakai (Stand-Alone Collection)
Langsung dapat diimpor dan dijalankan tanpa perlu setup environment:

| Berkas Koleksi | Target Host & Port | Deskripsi |
|---|---|---|
| [`ASSA_Middleware_ServerDev.postman_collection.json`](./ASSA_Middleware_ServerDev.postman_collection.json) | `https://devmiddleware.assa.id` | Koleksi pre-configured untuk pengujian langsung ke **Server Dev**. |
| [`ASSA_Middleware_Local.postman_collection.json`](./ASSA_Middleware_Local.postman_collection.json) | `http://localhost:6031` | Koleksi pre-configured untuk pengujian di **Local Desktop**. |

*Salinan berkas ini juga tersedia di direktori `middleware-assa/`:*
- [`ASSA Middleware Server Dev (devmiddleware.assa.id).postman_collection.json`](../middleware-assa/ASSA%20Middleware%20Server%20Dev%20%28devmiddleware.assa.id%29.postman_collection.json)
- [`ASSA Middleware Local Desktop (localhost-6031).postman_collection.json`](../middleware-assa/ASSA%20Middleware%20Local%20Desktop%20%28localhost-6031%29.postman_collection.json)

---

### 2. Opsi Environment Switcher (Opsional)
Jika Anda lebih suka menggunakan 1 koleksi tunggal dengan pergantian environment:

| Berkas | Deskripsi |
|---|---|
| [`ASSA_Middleware_TestSuite.postman_collection.json`](./ASSA_Middleware_TestSuite.postman_collection.json) | Koleksi umum (Generic Test Suite). |
| [`ASSA_Middleware_ServerDev.postman_environment.json`](./ASSA_Middleware_ServerDev.postman_environment.json) | Environment variable untuk **Server Dev** (`https://devmiddleware.assa.id`). |
| [`ASSA_Middleware_Local.postman_environment.json`](./ASSA_Middleware_Local.postman_environment.json) | Environment variable untuk **Local Desktop** (`http://localhost:6031`). |

---

## 🚀 Panduan Import ke Postman Desktop

### Opsi A (Rekomendasi Cepat - Tanpa Perlu Environment)
1. Buka aplikasi **Postman**.
2. Klik tombol **Import** (atau `Cmd + O` di macOS / `Ctrl + O` di Windows).
3. Drag & drop kedua file koleksi:
   - `ASSA_Middleware_ServerDev.postman_collection.json`
   - `ASSA_Middleware_Local.postman_collection.json`
4. Kedua koleksi akan muncul di sidebar Postman:
   - **`ASSA Middleware - Server Dev (devmiddleware.assa.id)`**
   - **`ASSA Middleware - Local Desktop (localhost:6031)`**
5. Anda dapat langsung menjalankan salah satu atau keduanya!

### Opsi B (Menggunakan Postman Environment)
1. Impor `ASSA_Middleware_TestSuite.postman_collection.json`.
2. Impor kedua berkas environment:
   - `ASSA_Middleware_Local.postman_environment.json`
   - `ASSA_Middleware_ServerDev.postman_environment.json`
3. Pilih environment yang aktif di dropdown pojok kanan atas Postman.

---

## 🧪 Menjalankan Automated Test Runner

1. Pada sidebar kiri Postman, klik salah satu koleksi (Server Dev, Local Desktop, atau Test Suite).
2. Klik tombol **Run** (atau titik tiga `...` -> **Run collection**).
3. Pastikan urutan folder tercentang:
   - `1. Health & Readiness Probes` (16 request)
   - `2. Auth & Scope Security Guards` (15 request)
   - `3. Parameter Validation` (14 request)
   - `4. Inquiry & Pagination` (18 request)
   - `5. Transactional & Fan-Out Endpoints` (12 request)
   - `6. Background Retry Worker` (2 request)
4. Klik tombol biru **Run ASSA Middleware API Test Suite**.
5. Postman akan mengeksekusi seluruh 77 request secara otomatis dan menampilkan hasil verifikasi status code serta validasi payload.

---

## 📋 Cakupan 77 Skenario Pengujian Lengkap (Semua 7 Microservice)

### 1. Health & Readiness Probes (16 Endpoint)
- General Liveness Probe: `GET /health` (200 OK)
- General Readiness Probe: `GET /readiness` (200 OK)
- Branch Service: `/health/branch` & `/readiness/branch` (200 OK)
- Customer Service: `/health/customer` & `/readiness/customer` (200 OK)
- Vehicle Service: `/health/vehicle` & `/readiness/vehicle` (200 OK)
- Vendor Service: `/health/vendor` & `/readiness/vendor` (200 OK)
- SPK Service: `/health/spk` & `/readiness/spk` (200 OK)
- Service Request Service: `/health/service-request` & `/readiness/service-request` (200 OK)
- Payments Service: `/health/payments` & `/readiness/payments` (200 OK)

### 2. Auth & Scope Security Guards (15 Skenario)
- Request tanpa header `Authorization` (401 Unauthorized):
  - Branch Service (401)
  - Customer Service (401)
  - Vehicle Service (401)
  - Payments Service (401)
- Request dengan token palsu / invalid (401 Unauthorized)
- Consumer App B (hanya scope `vehicles`) memanggil:
  - Branch Service (403 Forbidden)
  - Customer Service (403 Forbidden)
  - Vendor Create (403 Forbidden)
  - SPK Duelist (403 Forbidden)
  - Service Request (403 Forbidden)
  - Payments Service (403 Forbidden)
- Consumer App ATLAS (hanya scope `vendors`) memanggil:
  - SPK Duelist (403 Forbidden)
  - Payments Service (403 Forbidden)
- Consumer App Omnichannel (hanya scope `service_requests`) memanggil:
  - Customer Service (403 Forbidden)
  - Payments Service (403 Forbidden)

### 3. Parameter & Input Validation (14 Skenario)
- Payments Service `currency` tidak valid / lebih dari 5 karakter (400 Bad Request)
- Payments Service `businessArea` lebih dari 10 karakter (400 Bad Request)
- Payments Service `accountingDocumentNumber` lebih dari 50 karakter (400 Bad Request)
- Vendor Create dengan `companyTitle` tidak valid (400 Bad Request)
- Vendor Create dengan `otv: "No"` tanpa kelengkapan rekening bank (400 Bad Request)
- SPK Duelist tanpa nomor `noSpk` (400 Bad Request)
- SPK Duelist dengan rincian total tidak cocok via header `X-Validate-Total` (400 Bad Request)
- SPK Duelist dengan data tagihan invoice parsial / tidak lengkap (400 Bad Request)
- Service Request tanpa field wajib `app_id` pada format legacy (400 Bad Request)
- Payments Service tanpa `accountingDocumentNumber` (400 Bad Request)
- Payments Service tanpa `documentDate` (400 Bad Request)
- Payments Service tanpa `postingDate` (400 Bad Request)
- Payments Service tanpa `businessArea` (400 Bad Request)
- Payments Service tanpa `glAccount` (400 Bad Request)

### 4. Inquiry, Search & Pagination (18 Skenario)
- Branch Inquiry GetByCreateDate:
  - Page 1 via App A Token (200 OK)
  - Page 2 via QA Token (200 OK)
- Customer Inquiry GetByCreateDate:
  - Page 1 via App A Token (200 OK)
  - Search kombinasi `CustomerCode` & `CustomerName` (200 OK)
  - Search `CustomerCode` saja (200 OK)
  - Search `CustomerName` saja (200 OK)
  - Page 2 via QA Token (200 OK)
- Vehicle Inquiry `/getByLicensePlate`:
  - Cari nomor plat via `plat_no` + Pagination (200 OK)
  - Cari nomor plat dengan spasi (auto-normalized ke tanda hubung) (200 OK)
  - Paginasi seluruh armada Page 1 (200 OK)
  - Cari via `equipment_no` (200 OK)
- Vehicle Inquiry `/vehicleatlas`:
  - Cari nomor plat via `plat_no` (200 OK)
  - Cari nomor plat dengan spasi auto-normalized (200 OK)
  - Paginasi seluruh armada Page 1 (200 OK)
  - Paginasi seluruh armada Page 2 (200 OK)
  - Cari via `equipment_no` (200 OK)
- Service Request Inquiry:
  - GET Inquiry paginated list (200 OK dengan JSON metadata `pagination`)
  - Public Endpoint Barantum CRM GET Inquiry (200 OK via `X-API-Key` & `Origin: https://barantum.internal`)

### 5. Transactional & Parallel Fan-Out POST (12 Skenario)
- Service Request Parallel Fan-Out (Format Flat Legacy Omnichannel):
  - Mengirim payload 30 field ke `/api/service-requests` dengan `X-Transaction-Id` dinamis (`TRX-SR-POSTMAN-<timestamp>`).
  - Menjalankan fan-out paralel ke ATLAS & ASSA ExtService.
  - Melakukan retry hingga 10x per target jika eksternal gagal.
- Service Request Re-Send / Re-Execution (Idempotency Re-try)
- Service Request Public Gateway Barantum CRM (Format Baru: Nested `unit` { `licensePlate`, `brand`, `model`, `odometer` }, header `Origin` & `X-API-Key`)
- Vendor Create POST ke FTP SAP (Payload V2 ATLAS 17 field via QA Token - 201 Created / 502)
- Vendor Create POST ke FTP SAP (Payload V2 ATLAS via App ATLAS Token scope `vendors` - 201 Created / 502)
- Vendor Create Re-Send (Idempotency Replay - 200 OK)
- SPK Duelist POST ke FTP SAP (Rincian Jasa & Parts dengan header `X-Validate-Total` - 201 Created / 502)
- SPK Duelist POST ke FTP SAP (Lengkap dengan data Invoice vendor dan Faktur Pajak - 201 Created / 502)
- SPK Duelist Re-Send (Idempotency Replay - 200 OK)
- Payments Create POST ke FTP SAP (Dokumen XML pembayaran format `PAYMENTS_<docNumber>_<companyCode>_<trxId>.xml` - 201 Created / 502)
- Payments Create POST ke FTP SAP (Format tanggal alternatif ISO YYYY-MM-DD - 201 Created / 502)
- Payments Create Re-Send / Idempotency Check (200 OK Replay)

### 6. Background Retry Worker (2 Endpoint)
- Trigger Background Retry Worker via GET: `GET /api/worker/retry` (200 OK)
- Trigger Background Retry Worker via POST: `POST /api/worker/retry` (200 OK)

