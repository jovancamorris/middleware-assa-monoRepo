# 🎯 PANDUAN LENGKAP SHOWCASE KE LEAD: FITUR VENDOR CREATE & SERVICE REQUEST (FROM ZERO)

Dokumen ini disusun khusus sebagai **panduan presentasi / live demo langkah demi langkah dari nol (from zero)** untuk menunjukkan 2 fitur utama ASSA Middleware kepada **Team Lead**:
1. **Fitur 1: Vendor Create VMD ke SAP FTP (`POST /api/vendors/create`)** — *File-Based XML Interface*.
2. **Fitur 2: Service Request (SR) Fan-Out Paralel (`POST /api/service-requests`)** — *Pure HTTP REST Parallel Fan-Out*.

---

## 📋 DAFTAR ISI DEMO
1. [Tahap 0: Persiapan Tools & Akses](#tahap-0-persiapan-tools--akses)
2. [Tahap 1: Menjalankan Environment dari Nol (Docker & Runtime)](#tahap-1-menjalankan-environment-dari-nol-docker--runtime)
3. [Tahap 2: Demo Fitur 1 — Vendor Create (XML FTP ke SAP)](#tahap-2-demo-fitur-1--vendor-create-xml-ftp-ke-sap)
4. [Tahap 3: Demo Fitur 2 — Service Request (Fan-Out Paralel)](#tahap-3-demo-fitur-2--service-request-fan-out-paralel)
5. [Tahap 4: Demo Verifikasi Audit Database MariaDB](#tahap-4-demo-verifikasi-audit-database-mariadb)
6. [Tahap 5: Eksekusi Otomatis Sekali Klik (Script Test Runner)](#tahap-5-eksekusi-otomatis-sekali-klik-script-test-runner)
7. [Matriks Perbedaan Arsitektur untuk Penjelasan ke Lead](#matriks-perbedaan-arsitektur-untuk-penjelasan-ke-lead)

---

## 🛠️ TAHAP 0: Persiapan Tools & Akses

Sebelum demo dimulai di depan Lead, pastikan tools berikut sudah terbuka di laptop:
1. **Docker Desktop** dalam kondisi running.
2. **Terminal PowerShell** di VS Code.
3. **WinSCP atau FileZilla** untuk verifikasi file XML di server FTP SAP:
   * **Host:** `devqaxmlpool.assa.id` | **Port:** `21`
   * **Username:** `middlewaredev` | **Password:** `Gu34S5a#*232`
   * **Folder Tujuan:** `/vmd`
4. **DBeaver** (atau MySQL Client):
   * **Host:** `localhost` | **Port:** `3308` (Docker) atau `3307` (Local host)
   * **Database:** `assa_middleware_db` | **User:** `root` *(tanpa password)*

---

## 🚀 TAHAP 1: Menjalankan Environment dari Nol (Docker & Runtime)

### Langkah 1.1 — Buka Terminal & Pindah ke Direktori Project
```powershell
cd c:\Users\eksad\OneDrive\Documents\assa\code\middleware-assa-all\middleware-assa\middleware-assa\middleware-assa
```

### Langkah 1.2 — (Opsional) Build Ulang Package CAR
Jika ada perubahan source code, build package CAR:
```powershell
.\mvnw.cmd clean package -DskipTests
```
*Tunggu hingga muncul tulisan `BUILD SUCCESS` (sekitar 10-15 detik).*

### Langkah 1.3 — Jalankan Container Docker (WSO2 MI + MariaDB)
```powershell
docker compose up -d
```

### Langkah 1.4 — Verifikasi Container Berjalan Sehat
```powershell
docker ps
```
*Pastikan container `middleware-assa` dan `middleware-assa-mariadb` berstatus `Up` (healthy).*

### Langkah 1.5 — Uji Health Check Liveness Probe
Buktikan ke Lead bahwa server middleware sudah aktif dan siap melayani:
```powershell
curl.exe -s http://localhost:8290/health
```
**Ekspektasi Output:**
```json
{"status":"UP","services":{"sapCore":"UP","externalService":"UP","database":"UP"}}
```

---

## 🏢 TAHAP 2: Demo Fitur 1 — Vendor Create (XML FTP ke SAP)

> **Poin Penjelasan ke Lead:**  
> *"Fitur Vendor Create menerima payload JSON 17-field dari aplikasi internal (ATLAS), memvalidasi kelengkapan data, mencegah duplikasi transaksi dengan Idempotency Guard, mengonversi payload menjadi format resmi XML ATLAS VMD yang berindentasi rapi (pretty-print), dan mengirimkannya secara aman via protokol FTP ke server pool XML SAP (`devqaxmlpool.assa.id:/vmd`)."*

### Skenario 2.1: Eksekusi Request Sukses (HTTP 201 Created)
Jalankan script PowerShell berikut:
```powershell
$headers = @{
    "Authorization" = "Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d"
    "Content-Type" = "application/json"
    "X-Transaction-Id" = "TRX-VENDOR-" + (Get-Date -Format "yyyyMMddHHmmss")
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

**Ekspektasi Output ke Lead (HTTP 201 Created):**
```json
{
  "success": true,
  "message": "Vendor (VMD) accepted and delivered to FTP",
  "transactionId": "TRX-VENDOR-...",
  "fileName": "VMD_20260917..._TRX-VENDOR-....xml",
  "documentNumber": "VENDOR-ATLAS-000123"
}
```

### Skenario 2.2: Bukti Fisik di Server FTP SAP
1. Buka **WinSCP / FileZilla**.
2. Masuk ke folder `/vmd`.
3. Tunjukkan file baru bernama `VMD_...xml`.
4. Buka file tersebut dan perlihatkan ke Lead bahwa struktur XML-nya rapi, berindentasi, dan valid sesuai spesifikasi SAP VMD:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <Transaction>
       <Header>
           <Key1>ID01</Key1>
           <Key2>VMD</Key2>
           <DocumentNumber>VENDOR-ATLAS-000123</DocumentNumber>
           <CreationDate>20260917</CreationDate>
           <Status>NEW</Status>
       </Header>
       <TransactionDatas>
           <TransactionData>
               <CompanyTitle>PT</CompanyTitle>
               <CompanyName>PT Adi Sarana Armada Tbk</CompanyName>
               <OTV>No</OTV>
               ...
           </TransactionData>
       </TransactionDatas>
   </Transaction>
   ```

### Skenario 2.3: Uji Idempotency Replay (Pencegahan File Duplikat)
Kirim ulang request yang sama dengan `X-Transaction-Id` yang persis sama.
* **Hasil:** HTTP `200 OK`.
* **Poin ke Lead:** Middleware membalas langsung dari cache database **tanpa meng-upload ulang file duplikat ke server FTP SAP**, sehingga mencegah duplikasi data master vendor di SAP.

### Skenario 2.4: Uji Validasi Input (HTTP 400 Bad Request)
Ganti `companyTitle` dengan nilai yang salah (misal `"INVALID"`):
```powershell
curl.exe -i -s -X POST http://localhost:8290/api/vendors/create `
  -H "Authorization: Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d" `
  -H "Content-Type: application/json" `
  -d '{"companyTitle":"INVALID","companyName":"PT Maju","otv":"No"}'
```
* **Hasil:** HTTP `400 Bad Request`:
  `"Field 'companyTitle' wajib diisi dengan nilai 'PT' atau 'CV'"`

### Skenario 2.5: Uji Keamanan Token & Scope (HTTP 403 Forbidden)
Gunakan token App B yang hanya memiliki scope `vehicles`:
```powershell
curl.exe -i -s -X POST http://localhost:8290/api/vendors/create `
  -H "Authorization: Bearer token-assa-app-b-secret-67890" `
  -H "Content-Type: application/json" `
  -d "{}"
```
* **Hasil:** HTTP `403 Forbidden`:
  `"Aplikasi (app_b) tidak memiliki izin untuk scope: vendors"`

---

## ⚡ TAHAP 3: Demo Fitur 2 — Service Request (Fan-Out Paralel)

> **Poin Penjelasan ke Lead:**  
> *"Fitur Service Request (SR) dirancang untuk melayani aplikasi Omnichannel (portal customer/call center). Berbeda dengan Vendor yang menggunakan file XML, fitur ini adalah murni HTTP REST Fan-Out. Middleware menerima 1 panggilan JSON 30-field, lalu secara simultan (paralel via Clone mediator) meneruskannya ke:*  
> *1. **API ATLAS** (sistem operasional internal, saat ini toggle=false / SKIPPED karena masih dikembangkan).*  
> *2. **ASSA External Services** (`input_service_request`) yang diubah otomatis menjadi format form-urlencoded 30 field lengkap dengan `x-api-key`, dan backend inilah yang meneruskannya ke SAP.*  
> *Middleware kemudian mengagregasikan status kedua target dan membalasnya ke Omnichannel."*

### Skenario 3.1: Eksekusi Request Sukses (HTTP 200 OK)
Jalankan perintah berikut di PowerShell:
```powershell
$headers = @{
    "Authorization" = "Bearer token-assa-omnichannel-secret-99999"
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

**Ekspektasi Output ke Lead (HTTP 200 OK):**
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

### Skenario 3.2: Uji Idempotency Replay
Kirim ulang cURL dengan `X-Transaction-Id` yang sama:
```powershell
curl.exe -i -s -X POST http://localhost:8290/api/service-requests `
  -H "Authorization: Bearer token-assa-omnichannel-secret-99999" `
  -H "Content-Type: application/json" `
  -H "X-Transaction-Id: TRX-SR-MANUAL-001" `
  --data-binary "@test/payload_sr_test.json"
```
* **Hasil:** HTTP `200 OK` dengan header `X-Idempotent-Replay: true`.
* **Poin ke Lead:** Mencegah pelanggan yang melakukan *double-click submit* membuat tiket servis ganda di sistem backend ASSA.

### Skenario 3.3: Uji Validasi Fail-Fast Field Wajib (HTTP 400 Bad Request)
Hapus field `app_id` atau `ticket_no`:
```powershell
curl.exe -i -s -X POST http://localhost:8290/api/service-requests `
  -H "Authorization: Bearer token-assa-omnichannel-secret-99999" `
  -H "Content-Type: application/json" `
  -d '{"reff_number":"REF01","branch_code":"JKT01","created_datetime":"17-09-2026","created_by":"admin","ticket_no":"TCK01"}'
```
* **Hasil:** HTTP `400 Bad Request`:
  `{"error": true, "message": "Bad Request", "detail": "Field 'app_id' wajib diisi"}`

### Skenario 3.4: Uji Keamanan Token & Scope Guard (HTTP 403 Forbidden)
Gunakan token App B:
```powershell
curl.exe -i -s -X POST http://localhost:8290/api/service-requests `
  -H "Authorization: Bearer token-assa-app-b-secret-67890" `
  -H "Content-Type: application/json" `
  -d "{}"
```
* **Hasil:** HTTP `403 Forbidden`:
  `"Aplikasi (app_b) tidak memiliki izin untuk scope: service_requests"`

---

## 📊 TAHAP 4: Demo Verifikasi Audit Database MariaDB

Tunjukkan ke Lead bahwa seluruh aktivitas transaksi dan percobaan teknis tercatat rapi di **MariaDB Port 3308 / 3307** (`assa_middleware_db`).

Jalankan query ini di DBeaver atau terminal:
```sql
USE assa_middleware_db;

-- 1. Verifikasi Transaksi Utama (Tabel api_transaction)
SELECT id, transaction_id, endpoint, http_method, status, attempt_count, created_at 
FROM api_transaction 
ORDER BY id DESC LIMIT 5;

-- 2. Verifikasi Audit Log Percobaan Teknis (Tabel api_transaction_log)
SELECT id, transaction_id, attempt_number, endpoint, response_status, duration_ms, created_at 
FROM api_transaction_log 
ORDER BY id DESC LIMIT 5;
```

**Poin yang Ditonjolkan ke Lead:**
1. Setiap transaksi memiliki `transaction_id` unik untuk audit trail end-to-end.
2. Tercatat durasi latensi (`duration_ms`), status HTTP backend eksternal, dan jumlah percobaan (`attempt_count`).
3. Transaksi Vendor Create dan Service Request terpusat di skema audit yang sama.

---

## ⚡ TAHAP 5: Eksekusi Otomatis Sekali Klik (Script Test Runner)

Jika Lead ingin melihat seluruh tes berjalan otomatis dalam hitungan detik, Anda cukup mengeksekusi script yang sudah disiapkan:

1. **Uji Fitur Vendor Create Saja (4 Test):**
   ```powershell
   powershell -ExecutionPolicy Bypass -File "test\test_vendor_create.ps1"
   ```

2. **Uji Fitur Service Request Saja (6 Test):**
   ```powershell
   powershell -ExecutionPolicy Bypass -File "test\test_service_request.ps1"
   ```

3. **Uji Seluruh 26 Test Master Suite (All-In-One):**
   ```powershell
   powershell -ExecutionPolicy Bypass -File "test\test_all.ps1"
   ```

---

## 🎓 MATRIKS PERBEDAAN ARSITEKTUR UNTUK PENJELASAN KE LEAD

| Aspek Arsitektur | Fitur 1: Vendor Create (VMD) | Fitur 2: Service Request (SR) |
|---|---|---|
| **Consumer Utama** | ATLAS / Internal System | Omnichannel (Customer Care / Portal) |
| **Pola Integrasi** | **File-Based Interface (FTP)** | **HTTP REST Parallel Fan-Out** |
| **Format Input** | JSON (17 Field) | JSON (30 Field) |
| **Output / Protokol Tujuan** | File fisik XML (`VMD_...xml`) via **SFTP / VFS** | **HTTP POST** (`application/x-www-form-urlencoded`) |
| **Target Backend** | Server FTP SAP (`devqaxmlpool.assa.id:/vmd`) | **2 Target Simultan**: API ATLAS + External Services |
| **Penerusan ke SAP** | Middleware yang bertanggung jawab kirim XML ke FTP SAP | Ditangani langsung oleh backend `input_service_request` |
| **Idempotency** | Cache DB $\rightarrow$ cegah upload file XML ganda | Cache DB $\rightarrow$ cegah pembuatan tiket servis ganda |
| **Scope Keamanan** | `vendors` | `service_requests` |
| **Toleransi Kegagalan** | Retry 3x + DB Audit | Agregasi Partial Success (`207`) / Bad Gateway (`502`) |
