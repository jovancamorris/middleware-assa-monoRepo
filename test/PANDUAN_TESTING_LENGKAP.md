# 🚀 Panduan Lengkap Pengujian Manual ASSA Middleware (Step-by-Step)

Dokumen ini adalah panduan langkah demi langkah dari **paling awal (menjalankan server runtime)** hingga **menjalankan seluruh pengujian API via terminal cURL**.

---

> [!CAUTION]
> ### ⚠️ PENTING: Penyebab Error di Terminal PowerShell Windows!
> Jika Anda mengetik `curl`, Windows PowerShell akan menganggapnya sebagai alias dari `Invoke-WebRequest` bawaan Windows, sehingga muncul error:
> ```text
> Invoke-WebRequest : A positional parameter cannot be found that accepts argument ...
> ```
> **KUNCI SOLUSINYA:**
> Di PowerShell Windows, **SELALU KETIK `curl.exe`** (harus ada akhiran `.exe`), atau lebih praktis gunakan perintah asli PowerShell **`Invoke-RestMethod`** (seperti yang dicontohkan di bagian Pengujian Vendor Create).

---

## 📍 LANGKAH 1: Jalankan Server WSO2 MI (Run / Debug)

Server runtime WSO2 MI harus menyala di port `8290` sebelum bisa menerima request. Anda bisa menjalankannya via **Docker (Rekomendasi)** atau **Local Batch**:

### Opsi 1: Jalankan via Docker (Paling Praktis)
```bash
docker compose up -d
```
*(Menjalankan container WSO2 MI di port 8290 dan MariaDB di port 3308/3306)*

### Opsi 2: Jalankan Manual di Host Windows
```powershell
$env:JAVA_HOME = "C:\Users\eksad\tools\jdk-21.0.3+9"
& "C:\Users\eksad\.wso2-mi\micro-integrator\wso2mi-4.6.0\bin\micro-integrator.bat"
```
Tunggu sampai muncul log `Pass-through HTTP Listener started on 0.0.0.0:8290`. Biarkan terminal tetap berjalan.

---

## 📍 LANGKAH 2: Buka Terminal Baru untuk Testing

Buka tab terminal baru di VS Code:
- Klik tombol **`+`** di pojok kanan atas jendela terminal VS Code (pilih **PowerShell**), atau tekan `Ctrl + Shift + \``.
- Pastikan direktori terminal berada di folder project:
  ```powershell
  cd c:\Users\eksad\OneDrive\Documents\assa\code\middleware-assa-all\middleware-assa\middleware-assa\middleware-assa
  ```

---

## 📍 LANGKAH 3: Pilih Cara Menjalankan Tes

Anda memiliki 2 opsi yang sangat mudah:

### 🌟 OPSI A: Jalankan Semua Tes Otomatis (1-Klik)
1. **Pengujian Menyeluruh / All-in-One Master Suite (26 Test Lengkap):**
   ```powershell
   powershell -ExecutionPolicy Bypass -File "test\test_all.ps1"
   ```
2. **Pengujian Fungsional API & Auth Guard (11 Test):**
   ```powershell
   powershell -ExecutionPolicy Bypass -File "test\run_manual_tests.ps1"
   ```
3. **Pengujian Resiliency, 3x Retry, Idempotency & MariaDB (Port 3307/3308) (5 Test):**
   ```powershell
   powershell -ExecutionPolicy Bypass -File "test\run_resiliency_tests.ps1"
   ```
4. **Pengujian Vendor Create XML & Delivery ke FTP SAP (4 Test):**
   ```powershell
   powershell -ExecutionPolicy Bypass -File "test\test_vendor_create.ps1"
   ```
5. **Pengujian Service Request (SR) Fan-Out Paralel (6 Test):**
   ```powershell
   powershell -ExecutionPolicy Bypass -File "test\test_service_request.ps1"
   ```
*Script ini akan otomatis memverifikasi liveness, pemanggilan backend, idempotency cache replay, pengiriman XML vendor ke FTP devqaxmlpool.assa.id, paralel fan-out Service Request ke external services & ATLAS, simulasi 3x retry kegagalan backend, audit tabel `api_transaction` dan `api_transaction_log`, serta background worker.*

---

## ⭐ PANDUAN KHUSUS SHOWCASE / DEMO KE LEAD (FITUR VENDOR & SERVICE REQUEST FROM ZERO)

Jika Anda ingin mendemonstrasikan 2 fitur utama terbaru ini (**Vendor Create XML FTP** & **Service Request Paralel Fan-Out**) kepada **Team Lead**, ikuti alur langkah demi langkah dari nol berikut:

### 1. Persiapan Awal (From Zero)
1. Buka aplikasi **Docker Desktop**, **WinSCP/FileZilla** (ke `devqaxmlpool.assa.id:/vmd`), dan **DBeaver** (ke `localhost:3308`).
2. Masuk ke terminal PowerShell:
   ```powershell
   cd c:\Users\eksad\OneDrive\Documents\assa\code\middleware-assa-all\middleware-assa\middleware-assa\middleware-assa
   ```
3. (Opsional jika ada build baru) Build paket CAR:
   ```powershell
   .\mvnw.cmd clean package -DskipTests
   ```
4. Nyalakan seluruh container:
   ```powershell
   docker compose up -d
   ```
5. Verifikasi server telah UP:
   ```powershell
   curl.exe -s http://localhost:8290/health
   ```

### 2. Live Demo Fitur 1: Vendor Create VMD ke SAP FTP (`POST /api/vendors/create`)
* **Cerita ke Lead**: *"Menerima JSON 17 field dari ATLAS, validasi data, Idempotency Guard, ubah menjadi XML resmi ATLAS VMD dengan pretty-print indentation rapi, dan kirim via FTP ke server SAP."*
* **Perintah Uji (PowerShell)**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File "test\test_vendor_create.ps1"
  ```
* **Bukti Fisik di Server FTP**: Buka WinSCP $\rightarrow$ folder `/vmd` $\rightarrow$ perlihatkan file baru `VMD_...xml` dengan struktur XML rapi berindentasi.
* **Uji Idempotency**: Jalankan lagi script yang sama $\rightarrow$ respons `200 OK` instan dari cache database **tanpa** mengirim file duplikat ke FTP.

### 3. Live Demo Fitur 2: Service Request Paralel Fan-Out (`POST /api/service-requests`)
* **Cerita ke Lead**: *"Menerima JSON 30 field dari consumer Omnichannel, validasi 6 field wajib, lalu via Clone mediator dipecah paralel simultan ke 2 target: Target 1 API ATLAS (toggle=false/SKIPPED) dan Target 2 ASSA External Services (POST form-urlencoded 30 field yang meneruskan ke SAP). Agregasi mengembalikan status gabungan 200 OK."*
* **Perintah Uji (PowerShell)**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File "test\test_service_request.ps1"
  ```
* **Uji Idempotency Replay**: Request kedua dengan transaction ID sama dibalas seketika dengan header `X-Idempotent-Replay: true`.

### 4. Bukti Audit Database MariaDB
Tunjukkan tabel di DBeaver atau jalankan query:
```sql
USE assa_middleware_db;
SELECT id, transaction_id, endpoint, status, attempt_count, created_at FROM api_transaction ORDER BY id DESC LIMIT 5;
SELECT id, transaction_id, attempt_number, endpoint, response_status, duration_ms, created_at FROM api_transaction_log ORDER BY id DESC LIMIT 5;
```
*Tunjukkan ke Lead bahwa kedua transaksi tercatat rapi dengan status `SUCCESS` dan latensi tercatat detail.*

*(Untuk panduan narasi lengkap beserta contoh curl manual per skenario, buka dokumen khusus: [TEST_SERVICE_REQUEST.md](TEST_SERVICE_REQUEST.md))*

---

### 🌟 OPSI B: Jalankan Manual Satu per Satu via `curl.exe`

Copy-paste perintah di bawah ini satu per satu ke terminal PowerShell:

#### 1. Cek Server Hidup (Liveness Probe - Tanpa Token)
```powershell
curl.exe -i "http://localhost:8290/health"
```
*Ekspektasi Hasil: `HTTP/1.1 200 OK`*
```json
{
  "status": "UP",
  "timestamp": "..."
}
```

---

#### 2. Cek Kesiapan Backend (Readiness Probe - Tanpa Token)
```powershell
curl.exe -i "http://localhost:8290/health/ready"
```
*Ekspektasi Hasil: `HTTP/1.1 200 OK`*
```json
{
  "status": "READY",
  "backend": "UP",
  "timestamp": "..."
}
```

---

#### 3. Tes Keamanan: Akses Tanpa Token (Harus Ditolak 401)
```powershell
curl.exe -i "http://localhost:8290/api/branches/getByCreateDate?companyCode=1000"
```
*Ekspektasi Hasil: `HTTP/1.1 401 Unauthorized`*
```json
{
  "error": true,
  "message": "Unauthorized",
  "detail": "Header Authorization wajib disertakan dengan format 'Bearer <token>'."
}
```

---

#### 4. Tes Keamanan: Akses dengan Token Palsu (Harus Ditolak 401)
```powershell
curl.exe -i "http://localhost:8290/api/branches/getByCreateDate?companyCode=1000" -H "Authorization: Bearer token-ngawur"
```
*Ekspektasi Hasil: `HTTP/1.1 401 Unauthorized`*
```json
{
  "error": true,
  "message": "Unauthorized",
  "detail": "Token tidak valid, tidak dikenal, atau telah dicabut."
}
```

---

#### 5. Tes Scope Guard: App B Akses Branch (Harus Ditolak 403)
*(App B hanya memiliki izin scope `vehicles`, dilarang mengakses `branches`)*
```powershell
curl.exe -i "http://localhost:8290/api/branches/getByCreateDate?companyCode=1000" -H "Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881"
```
*Ekspektasi Hasil: `HTTP/1.1 403 Forbidden`*
```json
{
  "error": true,
  "message": "Forbidden",
  "detail": "Aplikasi (app_b) tidak memiliki izin untuk scope: branches"
}
```

---

#### 6. Tes Scope Guard: App B Akses Customer (Harus Ditolak 403)
*(App B hanya memiliki izin scope `vehicles`, dilarang mengakses `customers`)*
```powershell
curl.exe -i "http://localhost:8290/api/customers/getByCreateDate?companyCode=1000" -H "Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881"
```
*Ekspektasi Hasil: `HTTP/1.1 403 Forbidden`*
```json
{
  "error": true,
  "message": "Forbidden",
  "detail": "Aplikasi (app_b) tidak memiliki izin untuk scope: customers"
}
```

---

#### 7. Tes Validasi Parameter: Vehicle tanpa Parameter Pencarian (Harus Ditolak 400)
```powershell
curl.exe -i "http://localhost:8290/api/vehicles/getByLicensePlate?companyCode=1000" -H "Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881"
```
*Ekspektasi Hasil: `HTTP/1.1 400 Bad Request`*
```json
{
  "error": true,
  "message": "Bad Request",
  "detail": "Query parameter 'plate_no' (atau 'licensePlate') wajib disertakan (contoh: DD-8112 atau B-9065-UCU)."
}
```

---

#### 8. Tes Sukses: Vehicle Atlas API ke Backend Live (Token App B)
Mengambil data armada dari server live `https://devfmsapi.assa.id/api/vehicleatlas` dengan pencarian sebagian (*partial match*) nomor polisi:
```powershell
curl.exe -i "http://localhost:8290/api/vehicles/vehicleatlas?plate_no=DD-8112" -H "Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881"
```
*(Atau via path backward compatibility: `/api/vehicles/getByLicensePlate?plate_no=DD-8112`)*

*Ekspektasi Hasil: `HTTP/1.1 200 OK` (Data nyata dari FMS Vehicle Atlas ASSA)*
```json
{
  "message": "success",
  "code": 200,
  "offset": 0,
  "limit": 10,
  "count": 2,
  "total": 2,
  "data": [
    {
      "equipment_no": "10027282",
      "plate_no": "DD-8112-YC",
      "branch_code": "1411",
      "branch_name": "Makassar",
      "tipe_kendaraan": "DAIHATSU GRAN MAX BV AC AB 1.3 M/T",
      "unit_allocation": "LT",
      "status_id": 11,
      "asset_status": "1",
      "responsible_area": "c",
      "booking_status": "0",
      "color": "WHITE DSO",
      "production_year": 2018
    },
    {
      "equipment_no": "10055490",
      "plate_no": "DD-8112-YV",
      "branch_code": "1411",
      "branch_name": "Makassar",
      "tipe_kendaraan": "DAIHATSU GRAN MAX BV AC PS ABS 1.5 M/T",
      "unit_allocation": "LT",
      "status_id": 11,
      "asset_status": "1",
      "responsible_area": "c",
      "booking_status": "0",
      "color": "PUTIH",
      "production_year": 2023
    }
  ]
}
```

---

#### 9. Tes Sukses: Vehicle Atlas API (Token QA)
```powershell
curl.exe -i "http://localhost:8290/api/vehicles/vehicleatlas?plate_no=DD-8112" -H "Authorization: Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d"
```
*Ekspektasi Hasil: `HTTP/1.1 200 OK`*

---

#### 10. Tes Branch Service (Token App A)
```powershell
curl.exe -i "http://localhost:8290/api/branches/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11&page=1&perPage=10" -H "Authorization: Bearer 3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013"
```

#### 11. Tes Customer Service (Token App A)
```powershell
curl.exe -i "http://localhost:8290/api/customers/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11&page=1&perPage=10" -H "Authorization: Bearer 3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013"
```

> [!NOTE]
> **Catatan Endpoint Branch & Customer (SAP Core):**
> Backend SAP Core (`devsapcoreapi.assa.id` dan `sapcoreapi.assa.id`) berada di jaringan internal korporat ASSA. Jika laptop Anda terhubung ke **VPN internal ASSA**, endpoint akan mengembalikan data cabang/customer (`200 OK`). Jika tidak terhubung ke VPN, middleware akan menangani kegagalan jaringan secara anggun (`500/502`) tanpa membuat server crash.

---

### 🌟 BAGIAN II: Pengujian Resiliency, 3x Retry, Idempotency & MariaDB (Port 3307 / 3308)

Bagian ini menguji fitur ketahanan backend, pencegahan request ganda (idempotency), dan logging audit ke **MariaDB database**.

#### 12. Tes Pemanggilan Sukses & Pencatatan MariaDB (Idempotency Key)
Mengirim request dengan `X-Transaction-Id` baru. Middleware akan memproses request, menyimpan status `SUCCESS` ke `api_transaction`, dan mencatat percobaan ke `api_transaction_log`.
```powershell
curl.exe -i "http://localhost:8290/api/vehicles/vehicleatlas?plate_no=DD-8112" `
  -H "Authorization: Bearer 3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013" `
  -H "X-Transaction-Id: TRX-MANUAL-001"
```
*Ekspektasi Hasil:*
- HTTP Status: `200 OK`
- Header Respons: `X-Transaction-Id: TRX-MANUAL-001`
- Database MariaDB:
  - `SELECT status, attempt_count FROM api_transaction WHERE transaction_id = 'TRX-MANUAL-001';` -> `status: SUCCESS`, `attempt_count: 1`
  - `SELECT attempt_number, response_status FROM api_transaction_log WHERE transaction_id = 'TRX-MANUAL-001';` -> `attempt_number: 1`, `response_status: 200`

---

#### 13. Tes Idempotency Guard (Deteksi Request Duplikat)
Kirim kembali request yang sama persis dengan `X-Transaction-Id: TRX-MANUAL-001`. Middleware **tidak akan** memanggil backend eksternal lagi, melainkan langsung mengembalikan respons tersimpan dari cache database.
```powershell
curl.exe -i "http://localhost:8290/api/vehicles/vehicleatlas?plate_no=DD-8112" `
  -H "Authorization: Bearer 3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013" `
  -H "X-Transaction-Id: TRX-MANUAL-001"
```
*Ekspektasi Hasil:*
- HTTP Status: `200 OK`
- Header Respons: `X-Idempotent-Replay: true` *(Menandakan respons di-replay dari cache!)*
- Database MariaDB:
  - `SELECT COUNT(*) FROM api_transaction_log WHERE transaction_id = 'TRX-MANUAL-001';` -> **Tetap 1** *(Membuktikan backend tidak dipanggil ulang)*

---

#### 14. Tes 3x Retry Loop pada Backend Down & Alert Monitoring (Kegagalan yang Disengaja)
Mensimulasikan backend external mati (port 59999 tidak aktif). Middleware akan mencoba hingga **3x berturut-turut** dengan jeda waktu dinamis (`X-Retry-Interval-Seconds: 1`).

**Contoh A (Branch API):**
```powershell
curl.exe -i "http://localhost:8290/api/branches/getByCreateDate?companyCode=1000" `
  -H "Authorization: Bearer 3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013" `
  -H "X-Transaction-Id: TRX-FAIL-MANUAL-001" `
  -H "X-Retry-Interval-Seconds: 1" `
  -H "X-Target-Backend-Url: http://127.0.0.1:59999"
```

**Contoh B (Vehicle Atlas API):**
```powershell
curl.exe -i "http://localhost:8290/api/vehicles/vehicleatlas?plate_no=DD-8112" `
  -H "Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881" `
  -H "X-Transaction-Id: TRX-FAIL-VERIFY-001" `
  -H "X-Retry-Interval-Seconds: 1" `
  -H "X-Target-Backend-Url: http://127.0.0.1:59999"
```
*Ekspektasi Hasil:*
- Waktu eksekusi sekitar ~2–3 detik (mencoba Attempt 1 -> jeda 1s -> Attempt 2 -> jeda 1s -> Attempt 3).
- HTTP Status: `502 Bad Gateway`
```json
{
  "error": true,
  "message": "Bad Gateway - Max Retries Exhausted",
  "detail": "External API gagal diakses setelah 3x percobaan berturut-turut. Transaksi (ID: TRX-FAIL-MANUAL-001) telah dicatat dengan status FAILED dan masuk ke antrean retry asinkron."
}
```
- Server Console Log: Memicu log alert khusus `[ALERT MONITORING] Transaksi ID: TRX-FAIL-MANUAL-001 GAGAL setelah 3x percobaan. Status akhir: FAILED.`
- Database MariaDB:
  - `api_transaction`: `status = FAILED`, `attempt_count = 3`, `next_retry_at` dijadwalkan.
  - `api_transaction_log`: Tercatat lengkap **3 baris** (`attempt_number: 1, 2, 3`) dengan `response_status: 500`.

---

#### 15. Tes Asynchronous Background Worker (`/api/worker/retry`)
Memicu worker asinkron untuk memproses antrean transaksi yang berstatus `FAILED` / `RETRY` di database.
```powershell
curl.exe -i -X POST "http://localhost:8290/api/worker/retry"
```
*Ekspektasi Hasil:*
- HTTP Status: `200 OK`
```json
{
  "worker": "RetryWorker",
  "status": "COMPLETED",
  "timestamp": "2026-09-14T...",
  "message": "Background retry worker executed successfully."
}
```
- Database MariaDB: Transaksi `FAILED` diperbarui menjadi `RETRY` dengan exponential backoff 5 menit, dan tercatat aktivitas worker di `api_transaction_log` (`attempt_number: 0`, status `202 Accepted`).

---

---

#### 16. Tes Vendor Create: Kirim Data Vendor ke SAP via FTP (`POST /api/vendors/create`)
Menguji penerimaan payload JSON 17-field data vendor (V2 ATLAS format), pembentukan format resmi XML ATLAS (`Transaction` -> `Header` Key2=VMD + `TransactionDatas`), validasi idempotency, serta pengiriman file XML via VFS FTP ke `devqaxmlpool.assa.id:/vmd`.
Referensi: [GUIDE_VENDOR_CREATE_XML_FTP_V2.md](../notes/GUIDE_VENDOR_CREATE_XML_FTP_V2.md).

##### A. Menggunakan PowerShell (Rekomendasi di Windows)
Copy-paste kode berikut langsung ke terminal PowerShell:
```powershell
$headers = @{
    "Authorization" = "Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d"
    "Content-Type" = "application/json"
    "X-Transaction-Id" = "TRX-MANUAL-" + (Get-Date -Format "yyyyMMddHHmmss")
    "X-Forwarded-For" = "10.20.30.40"
}

$body = @{
    companyTitle = "PT"
    companyName = "PT Adi Sarana Armada Tbk"
    otv = "No"
    paymentCycle = "Monthly"
    accountNumber = "1200010978489"
    accountName = "Robby Yulianto Setiawan"
    bankName = "Mandiri"
    hoEmail = "assa@assarent.co.id"
    hoPhone = "082246605199"
    hoAddress = "Jalan Nusa Indah 2 Block C.ext 8 no 7, Duri Kosambi, Jakarta Barat, DKI Jakarta, 11410"
    contactName = "Robby Contact"
    contactPhone = "08224660189"
    npwp = "3173080209920003"
    accountGroup = "V010"
    top = "T014"
    glAccount = "2121000000"
    documentNumber = "VENDOR-ATLAS-000123"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8290/api/vendors/create" -Method Post -Headers $headers -Body $body
```

*Ekspektasi Hasil:*
- HTTP Status: `201 Created`
```json
{
  "success": true,
  "message": "Vendor (VMD) accepted and delivered to FTP",
  "transactionId": "TRX-MANUAL-...",
  "fileName": "VMD_20260917..._TRX-MANUAL-....xml",
  "documentNumber": "VENDOR-ATLAS-000123"
}
```

##### B. Menguji Idempotency Replay (Re-send Transaksi yang Sama)
Jika Anda mengirim ulang request dengan nilai `X-Transaction-Id` yang sama persis:
- HTTP Status: `200 OK` (Replay terdeteksi)
- Middleware mengembalikan respon sukses sebelumnya dari database **tanpa** meng-upload ulang file duplikat ke FTP server.

##### C. Menguji Validasi Gagal (Harus 400 Bad Request)
Coba ganti `companyTitle` menjadi `"INVALID"` (bukan `PT` atau `CV`):
```powershell
$badHeaders = @{
    "Authorization" = "Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d"
    "Content-Type" = "application/json"
}
$badBody = '{"companyTitle":"INVALID","companyName":"PT Invalid","otv":"No"}'
Invoke-RestMethod -Uri "http://localhost:8290/api/vendors/create" -Method Post -Headers $badHeaders -Body $badBody
```
*Ekspektasi:* HTTP `400 Bad Request` dengan pesan detail: *"Field 'companyTitle' wajib diisi dengan nilai 'PT' atau 'CV'"*.

##### D. Menguji Scope Guard (Harus 403 Forbidden)
Gunakan token App B yang tidak memiliki scope `vendors`:
```powershell
$noScopeHeaders = @{
    "Authorization" = "Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881"
    "Content-Type" = "application/json"
}
Invoke-RestMethod -Uri "http://localhost:8290/api/vendors/create" -Method Post -Headers $noScopeHeaders -Body "{}"
```
*Ekspektasi:* HTTP `403 Forbidden` dengan pesan detail: *"Aplikasi (app_b) tidak memiliki izin untuk scope: vendors"*.

##### E. Cara Verifikasi File XML di Server FTP
* **Host FTP:** `devqaxmlpool.assa.id` | **Port:** `21`
* **Username:** `middlewaredev` | **Password:** `Gu34S5a#*232`
* **Folder Tujuan:** `/vmd`
* Buka FileZilla / WinSCP, masuk ke `/vmd`, file XML `VMD_...xml` akan tersimpan dengan struktur format resmi ATLAS (`<Transaction><Header><Key2>VMD</Key2>...</Header><TransactionDatas><TransactionData>...</TransactionData></TransactionDatas></Transaction>`).

---

#### 17. Tes Service Request (SR): Fan-Out Paralel ke ATLAS & ASSA External Services (`POST /api/service-requests`)
Menguji penerimaan payload JSON 30-field dari consumer **Omnichannel**, validasi fail-fast 6-field wajib, pencatatan idempotency, serta eksekusi **paralel fan-out** ke dua backend via `Clone` mediator:
1. **Target 1 (ATLAS)**: `POST API ATLAS` (saat ini toggle `sr.target.atlas.enabled=false`, menghasilkan status `SKIPPED`).
2. **Target 2 (External Services)**: `POST https://assa-ext-services.assa.id/dev/service/input_service_request` (Body: `x-www-form-urlencoded` 30 field, Header: `x-api-key: DDtCZNeoPN27TWpHJdk9zaFwivxXrqQs2r1hbiKs`).

Referensi: [GUIDE_SR.md](../notes/GUIDE_SR.md) & [TEST_SERVICE_REQUEST.md](TEST_SERVICE_REQUEST.md).

##### A. Menggunakan PowerShell (Rekomendasi di Windows)
Copy-paste kode berikut langsung ke terminal PowerShell Anda:
```powershell
$headers = @{
    "Authorization" = "Bearer 14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12"
    "Content-Type" = "application/json"
    "X-Transaction-Id" = "TRX-SR-" + (Get-Date -Format "yyyyMMddHHmmss")
}

$body = @{
    app_id = "sr_app_omnichannel"
    reff_number = "REF-SR-20260917-001"
    branch_code = "JKT01"
    equipment_number = "EQ-998877"
    license_plate = "B-1234-SSA"
    customer_code = "CUST-00123"
    customer_name = "PT Maju Bersama ASSA"
    channel = "Omnichannel-Web"
    cp_title = "Bpk"
    cp_name = "Ahmad Fauzi"
    cp_phone = "081234567890"
    cp_email = "ahmad.fauzi@example.com"
    cp_address = "Jl. Gatot Subroto No. 45 Jakarta"
    km = "25000"
    description = "Perawatan berkala 25.000 KM dan pengecekan rem"
    service_datetime = "2026-09-20 10:00:00"
    service_location = "Bengkel Resmi ASSA Sunter"
    jenis_permintaan = "Service Berkala"
    incident_datetime = "2026-09-17 09:00:00"
    tipe_tiket = "Regular"
    judul = "Service Berkala Kendaraan Operasional"
    nama_kunjungan = "Ahmad Fauzi"
    telepon_kunjungan = "081234567890"
    alamat_kunjungan = "Jl. Danau Sunter Barat Blok A"
    pool_name = "Pool Sunter"
    area_bengkel = "Jakarta Utara"
    task = "Ganti Oli Mesin dan Filter Oli"
    created_datetime = "17-09-2026"
    created_by = "omnichannel_agent"
    ticket_no = "TICKET-SR-99901"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8290/api/service-requests" -Method Post -Headers $headers -Body $body
```

*Ekspektasi Hasil (HTTP 200 OK):*
```json
{
  "success": true,
  "message": "Service request diteruskan ke semua target",
  "transactionId": "TRX-SR-...",
  "ticket_no": "TICKET-SR-99901",
  "targets": {
    "atlas": {
      "status": "SKIPPED",
      "httpStatus": 200,
      "detail": "API ATLAS disabled or no response"
    },
    "extService": {
      "status": "SUCCESS",
      "httpStatus": 200,
      "detail": "Success forwarded to ASSA External Services"
    }
  }
}
```

##### B. Menggunakan cURL Terminal (`curl.exe`)
```powershell
curl.exe -i -s -X POST http://localhost:8290/api/service-requests `
  -H "Authorization: Bearer 14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12" `
  -H "Content-Type: application/json" `
  -H "X-Transaction-Id: TRX-SR-MANUAL-001" `
  --data-binary "@test/payload_sr_test.json"
```

##### C. Menguji Idempotency Replay (Re-send Transaksi yang Sama)
Jika Anda mengeksekusi ulang perintah cURL di atas dengan `X-Transaction-Id: TRX-SR-MANUAL-001` yang sama:
* Middleware mendeteksi status transaksi `SUCCESS` sebelumnya di MariaDB.
* Respons dikembalikan seketika dari cache database (`X-Idempotent-Replay: true`) **tanpa** memanggil ulang backend eksternal.

##### D. Menguji Validasi Fail-Fast (Harus 400 Bad Request)
Jika ada field wajib (`app_id`, `reff_number`, `branch_code`, `created_datetime`, `created_by`, `ticket_no`) yang tidak disertakan:
```powershell
curl.exe -i -s -X POST http://localhost:8290/api/service-requests `
  -H "Authorization: Bearer 14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12" `
  -H "Content-Type: application/json" `
  -d '{"reff_number":"REF01","branch_code":"JKT01","created_datetime":"17-09-2026","created_by":"admin","ticket_no":"TCK01"}'
```
*Ekspektasi Hasil:* HTTP `400 Bad Request`
```json
{
  "error": true,
  "message": "Bad Request",
  "detail": "Field 'app_id' wajib diisi"
}
```

##### E. Menguji Scope Guard (Harus 403 Forbidden)
Gunakan token App B yang hanya berhak untuk scope `vehicles`:
```powershell
curl.exe -i -s -X POST http://localhost:8290/api/service-requests `
  -H "Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881" `
  -H "Content-Type: application/json" `
  -d "{}"
```
*Ekspektasi Hasil:* HTTP `403 Forbidden`
```json
{
  "error": true,
  "message": "Forbidden",
  "detail": "Aplikasi (app_b) tidak memiliki izin untuk scope: service_requests"
}
```

---

#### 18. Cara Verifikasi Langsung di Database MariaDB (Port 3308 Docker / Port 3307 Local)
Anda bisa mengecek data transaksi langsung melalui **DBeaver** (Host: `localhost`, Port: `3308` jika Docker atau `3307` jika local host, Database: `assa_middleware_db`, User: `root`, Password kosong) atau via command terminal:

```sql
USE assa_middleware_db;

-- 1. Cek transaksi utama & statusnya (termasuk /api/vendors/create dan /api/service-requests)
SELECT id, transaction_id, endpoint, status, attempt_count, next_retry_at, created_at 
FROM api_transaction 
ORDER BY id DESC LIMIT 5;

-- 2. Cek riwayat log percobaan & endpoint tujuan (attempt 1, 2, 3)
SELECT id, transaction_id, attempt_number, endpoint, response_status, error_message, duration_ms, created_at 
FROM api_transaction_log 
ORDER BY id DESC LIMIT 10;
```

---

## 📍 DAFTAR TOKEN LENGKAP (App Registry)

| Token ID | Scopes | Bearer Token Header |
| :--- | :--- | :--- |
| **App A** | `branches, customers, vehicles, vendors, service_requests` | `Authorization: Bearer 3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013` |
| **App B** | `vehicles` | `Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881` |
| **App QA** | `branches, customers, vehicles, vendors, service_requests` | `Authorization: Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d` |
| **App ATLAS** | `vendors` | `Authorization: Bearer 513736d17f45657e2e448779cbc89320691f0fc246728f34250c0abf166f494a` |
| **App Omnichannel** | `service_requests` | `Authorization: Bearer 14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12` |

