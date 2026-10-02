# ASSA Middleware - Postman Collection & Test Suite

Koleksi Postman resmi untuk pengujian seluruh API ASSA Middleware WSO2 MI Monorepo & Nginx Gateway (Port 6031). Dilengkapi dengan **pre-request scripts dinamis** dan **automated test assertions** (`pm.test`) pada setiap request.

---

## 📁 Berkas yang Disediakan

### 1. Dua Koleksi Siap Pakai (Stand-Alone Collection)
Langsung dapat diimpor dan dijalankan tanpa perlu setup environment:

| Berkas Koleksi | Target Host & Port | Deskripsi |
|---|---|---|
| [`ASSA_Middleware_ServerDev.postman_collection.json`](./ASSA_Middleware_ServerDev.postman_collection.json) | `http://devmiddleware1.assa.id:6031` | Koleksi pre-configured untuk pengujian langsung ke **Server Dev**. |
| [`ASSA_Middleware_Local.postman_collection.json`](./ASSA_Middleware_Local.postman_collection.json) | `http://localhost:6031` | Koleksi pre-configured untuk pengujian di **Local Desktop**. |

*Salinan berkas ini juga tersedia di direktori `middleware-assa/`:*
- [`ASSA Middleware Server Dev (devmiddleware1.assa.id-6031).postman_collection.json`](../middleware-assa/ASSA%20Middleware%20Server%20Dev%20%28devmiddleware1.assa.id-6031%29.postman_collection.json)
- [`ASSA Middleware Local Desktop (localhost-6031).postman_collection.json`](../middleware-assa/ASSA%20Middleware%20Local%20Desktop%20%28localhost-6031%29.postman_collection.json)

---

### 2. Opsi Environment Switcher (Opsional)
Jika Anda lebih suka menggunakan 1 koleksi tunggal dengan pergantian environment:

| Berkas | Deskripsi |
|---|---|
| [`ASSA_Middleware_TestSuite.postman_collection.json`](./ASSA_Middleware_TestSuite.postman_collection.json) | Koleksi umum (Generic Test Suite). |
| [`ASSA_Middleware_ServerDev.postman_environment.json`](./ASSA_Middleware_ServerDev.postman_environment.json) | Environment variable untuk **Server Dev**. |
| [`ASSA_Middleware_Local.postman_environment.json`](./ASSA_Middleware_Local.postman_environment.json) | Environment variable untuk **Local Desktop**. |

---

## 🚀 Panduan Import ke Postman Desktop

### Opsi A (Rekomendasi Cepat - Tanpa Perlu Environment)
1. Buka aplikasi **Postman**.
2. Klik tombol **Import** (atau `Cmd + O` di macOS / `Ctrl + O` di Windows).
3. Drag & drop kedua file koleksi:
   - `ASSA_Middleware_ServerDev.postman_collection.json`
   - `ASSA_Middleware_Local.postman_collection.json`
4. Kedua koleksi akan muncul di sidebar Postman:
   - **`ASSA Middleware - Server Dev (devmiddleware1.assa.id:6031)`**
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
   - `1. Health & Readiness Probes` (14 request)
   - `2. Auth & Scope Security Guards` (9 request)
   - `3. Parameter Validation` (7 request)
   - `4. Inquiry & Pagination` (9 request)
   - `5. Transactional & Fan-Out Endpoints` (7 request)
   - `6. Background Retry Worker` (2 request)
4. Klik tombol biru **Run ASSA Middleware API Test Suite**.
5. Postman akan mengeksekusi seluruh 48 request secara otomatis dan menampilkan hasil verifikasi status code serta validasi payload.

---

## 📋 Cakupan 48 Skenario Pengujian Lengkap

### 1. Health & Readiness Probes (14 Endpoint)
- General Liveness Probe: `GET /health` (200 OK)
- General Readiness Probe: `GET /readiness` (200 OK)
- Branch Service: `/health/branch` & `/readiness/branch` (200 OK)
- Customer Service: `/health/customer` & `/readiness/customer` (200 OK)
- Vehicle Service: `/health/vehicle` & `/readiness/vehicle` (200 OK)
- Vendor Service: `/health/vendor` & `/readiness/vendor` (200 OK)
- SPK Service: `/health/spk` & `/readiness/spk` (200 OK)
- Service Request Service: `/health/service-request` & `/readiness/service-request` (200 OK)

### 2. Auth & Scope Security Guards (9 Endpoint)
- Request tanpa header `Authorization` (401 Unauthorized)
- Request dengan token palsu / invalid (401 Unauthorized)
- Consumer App B (hanya scope `vehicles`) memanggil:
  - Branch Service (403 Forbidden)
  - Customer Service (403 Forbidden)
  - Vendor Create (403 Forbidden)
  - SPK Duelist (403 Forbidden)
  - Service Request (403 Forbidden)
- Consumer App ATLAS (hanya scope `vendors`) memanggil:
  - SPK Duelist (403 Forbidden)
- Consumer App Omnichannel (hanya scope `service_requests`) memanggil:
  - Customer Service (403 Forbidden)

### 3. Parameter & Input Validation (7 Endpoint)
- Vehicle tanpa query param pencarian `plate_no`/`equipment_no`/`branchCode` (400 Bad Request)
- Vendor Create dengan `companyTitle` tidak valid (400 Bad Request)
- Vendor Create dengan `otv: "No"` tanpa kelengkapan rekening bank (400 Bad Request)
- SPK Duelist tanpa nomor `noSpk` (400 Bad Request)
- SPK Duelist dengan rincian total tidak cocok via header `X-Validate-Total` (400 Bad Request)
- SPK Duelist dengan data tagihan invoice parsial / tidak lengkap (400 Bad Request)
- Service Request tanpa field wajib `app_id` pada format legacy (400 Bad Request)

### 4. Inquiry & Pagination GET (9 Endpoint)
- Branch Inquiry GetByCreateDate (Page 1 via App A Token - 200 OK)
- Branch Inquiry GetByCreateDate (Page 2 via QA Token - 200 OK)
- Customer Inquiry GetByCreateDate (Page 1 via App A Token - 200 OK)
- Customer Inquiry GetByCreateDate (Page 2 via QA Token - 200 OK)
- Vehicle Inquiry `/getByLicensePlate` cari Plat Nomor (200 OK / 403 jika API key upstream devfmsapi dibutuhkan)
- Vehicle Inquiry `/vehicleatlas` cari Plat Nomor (200 OK / 403 jika API key upstream dibutuhkan)
- Vehicle Inquiry `/vehicleatlas` cari Equipment Number (200 OK / 403 jika API key upstream dibutuhkan)
- Service Request GET Inquiry paginated list (200 OK dengan JSON metadata `pagination`: `page`, `perPage`, `total`)
- Service Request Public Endpoint Barantum GET Inquiry (200 OK via `X-API-Key` & `Origin: https://barantum.internal`)

### 5. Transactional & Parallel Fan-Out POST (7 Endpoint)
- Service Request Parallel Fan-Out (Format Flat Legacy Omnichannel):
  - Mengirim payload 30 field ke `/api/service-requests` dengan `X-Transaction-Id` dinamis (`TRX-SR-POSTMAN-<timestamp>`).
  - Menjalankan fan-out paralel ke ATLAS & ASSA ExtService.
  - Melakukan retry hingga 10x per target jika eksternal gagal.
  - Memverifikasi response code 200 (Success) atau 502 (Target gagal setelah 10x percobaan) beserta detail target.
- Service Request Re-Send / Re-Execution (Idempotency Re-try)
- Service Request Public Gateway Barantum CRM (Format Baru: Nested `unit` { `licensePlate`, `brand`, `model`, `odometer` }, header `Origin` & `X-API-Key`)
- Vendor Create POST ke FTP SAP (Payload V2 ATLAS 17 field via QA Token - 201 Created / 502)
- Vendor Create POST ke FTP SAP (Payload V2 ATLAS via App ATLAS Token scope `vendors` - 201 Created / 502)
- SPK Duelist POST ke FTP SAP (Rincian Jasa & Parts dengan header `X-Validate-Total` - 201 Created / 502)
- SPK Duelist POST ke FTP SAP (Lengkap dengan data Invoice vendor dan Faktur Pajak - 201 Created / 502)

### 6. Background Retry Worker (2 Endpoint)
- Trigger Background Retry Worker via GET: `GET /api/worker/retry` (200 OK)
- Trigger Background Retry Worker via POST: `POST /api/worker/retry` (200 OK)

