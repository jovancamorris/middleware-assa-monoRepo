# ASSA Middleware - Postman Collection & Test Suite

Koleksi Postman resmi untuk pengujian seluruh API ASSA Middleware WSO2 MI Monorepo & Nginx Gateway (Port 6031). Dilengkapi dengan **pre-request scripts dinamis** dan **automated test assertions** (`pm.test`) pada setiap request.

---

## 📁 Berkas yang Disediakan

| Berkas | Deskripsi |
|---|---|
| [`ASSA_Middleware_TestSuite.postman_collection.json`](./ASSA_Middleware_TestSuite.postman_collection.json) | Koleksi lengkap berisi **36 skenario pengujian API** terstruktur. |
| [`ASSA_Middleware_Local.postman_environment.json`](./ASSA_Middleware_Local.postman_environment.json) | Environment untuk pengujian di **Local Desktop** (`http://localhost:6031`). |
| [`ASSA_Middleware_ServerDev.postman_environment.json`](./ASSA_Middleware_ServerDev.postman_environment.json) | Environment untuk pengujian di **Server Dev** (`http://devmiddleware1.assa.id:6031`). |

---

## 🚀 Panduan Import ke Postman Desktop

1. Buka aplikasi **Postman**.
2. Klik tombol **Import** di pojok kiri atas (atau tekan shortcut `Cmd + O` di macOS / `Ctrl + O` di Windows).
3. Pilih / Drag & Drop 3 berkas di atas:
   - `ASSA_Middleware_TestSuite.postman_collection.json`
   - `ASSA_Middleware_Local.postman_environment.json`
   - `ASSA_Middleware_ServerDev.postman_environment.json`
4. Klik **Import**.

---

## ⚙️ Memilih Environment

Di pojok kanan atas aplikasi Postman, klik dropdown **Environment**:
- Pilih **`ASSA Middleware - Local Desktop (Port 6031)`** saat Docker local Anda sedang berjalan.
- Pilih **`ASSA Middleware - Server Dev (devmiddleware1.assa.id:6031)`** saat ingin menguji server dev.

---

## 🧪 Menjalankan Automated Test Runner

1. Pada sidebar kiri Postman, klik koleksi **`ASSA Middleware API Test Suite`**.
2. Klik tombol **Run** (atau klik titik tiga `...` pada nama koleksi -> pilih **Run collection**).
3. Pastikan urutan folder tercentang:
   - `1. Health & Readiness Probes` (12 request)
   - `2. Auth & Scope Security Guards` (7 request)
   - `3. Parameter Validation` (5 request)
   - `4. Inquiry & Pagination` (6 request)
   - `5. Transactional & Fan-Out Endpoints` (5 request)
   - `6. Background Retry Worker` (1 request)
4. Klik tombol biru **Run ASSA Middleware API Test Suite**.
5. Postman akan mengeksekusi seluruh 36 request secara otomatis dan menampilkan hasil verifikasi status code serta validasi payload.

---

## 📋 Cakupan 36 Skenario Pengujian

### 1. Health & Readiness Probes (12 Endpoint)
- Branch Service: `/health/branch` & `/readiness/branch`
- Customer Service: `/health/customer` & `/readiness/customer`
- Vehicle Service: `/health/vehicle` & `/readiness/vehicle`
- Vendor Service: `/health/vendor` & `/readiness/vendor`
- SPK Service: `/health/spk` & `/readiness/spk`
- Service Request Service: `/health/service-request` & `/readiness/service-request`

### 2. Auth & Scope Security Guards (7 Endpoint)
- Request tanpa header `Authorization` (401 Unauthorized)
- Request dengan token palsu / invalid (401 Unauthorized)
- Consumer App B (hanya scope vehicles) memanggil:
  - Branch Service (403 Forbidden)
  - Customer Service (403 Forbidden)
  - Vendor Create (403 Forbidden)
  - SPK Duelist (403 Forbidden)
  - Service Request (403 Forbidden)

### 3. Parameter Validation (5 Endpoint)
- Vehicle tanpa query param pencarian (400 Bad Request)
- Vendor Create dengan `companyTitle` tidak valid (400 Bad Request)
- SPK Duelist tanpa nomor `noSpk` (400 Bad Request)
- SPK Duelist dengan rincian total tidak cocok via header `X-Validate-Total` (400 Bad Request)
- Service Request tanpa field wajib `app_id` (400 Bad Request)

### 4. Inquiry & Pagination GET (6 Endpoint)
- Branch Inquiry GetByCreateDate (200 OK)
- Customer Inquiry GetByCreateDate (200 OK)
- Vehicle Inquiry `/getByLicensePlate` (200 OK / 403 jika API key upstream devfmsapi dibutuhkan)
- Vehicle Inquiry `/vehicleatlas` (200 OK / 403 jika API key upstream dibutuhkan)
- Service Request GET Inquiry paginated list (200 OK dengan JSON metadata `pagination`)
- Service Request Public Endpoint Barantum (200 OK)

### 5. Transactional & Parallel Fan-Out POST (5 Endpoint)
- Service Request Parallel Fan-Out:
  - Mengirim payload ke `/api/service-requests` dengan `X-Transaction-Id` dinamis (`TRX-SR-POSTMAN-<timestamp>`).
  - Menjalankan fan-out paralel ke ATLAS & ASSA ExtService.
  - Melakukan retry hingga 10x per target jika eksternal gagal.
  - Memverifikasi response code 200 (Success) atau 502 (Target gagal setelah 10x percobaan) beserta detail target.
- Service Request Re-Send / Re-Execution
- Service Request Public CRM Barantum POST
- Vendor Create POST ke FTP
- SPK Duelist POST ke FTP

### 6. Background Retry Worker (1 Endpoint)
- GET `/api/worker/retry` (200 OK)
