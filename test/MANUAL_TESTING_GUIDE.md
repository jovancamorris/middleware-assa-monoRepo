# 🧪 Panduan Testing Manual — ASSA Middleware (WSO2 MI)

Dokumen ini berisi panduan lengkap langkah-demi-langkah (*step-by-step*) untuk melakukan **testing manual** terhadap seluruh endpoint dan mekanisme keamanan ASSA Middleware.

---

## 1. Persiapan Awal (Prerequisites)

### A. Pastikan File CAR Sudah Ter-build
Dari direktori project `middleware-assa/middleware-assa/middleware-assa`, pastikan CAR sudah terbuat:
```powershell
./mvnw.cmd clean compile
```
File CAR: `target/middleware-assa_1.0.0.car`

### B. Menjalankan WSO2 Micro Integrator (MI)
Ada 3 cara menjalankan WSO2 MI dengan CAR ini:

1. **Menggunakan VS Code WSO2 Extension (Paling Mudah):**
   - Buka VS Code.
   - Klik icon WSO2 MI di sidebar.
   - Klik **Run** atau **Debug** pada project `middleware-assa`.
2. **Menggunakan Standalone WSO2 MI Runtime:**
   - Copy file `middleware-assa_1.0.0.car` ke folder runtime:
     `<MI_HOME>/repository/deployment/server/carbonapps/`
   - Jalankan server MI:
     ```powershell
     <MI_HOME>\bin\micro-integrator.bat
     ```
3. **Menggunakan Docker:**
   - Build image dengan profile docker:
     ```powershell
     ./mvnw.cmd clean package -Pdocker
     ```

### C. Host & Port Default WSO2 MI
- **HTTP Port**: `8290` (PassThrough Transport HTTP)
- **HTTPS Port**: `8253` (PassThrough Transport HTTPS)
- **Base URL Lokal**: `http://localhost:8290`

---

## 2. Kredensial & Token Aplikasi (App Registry)

Berdasarkan konfigurasi `config.properties`, gunakan token berikut untuk pengujian:

| Aplikasi (`appId`) | Nama Aplikasi | Scopes yang Diizinkan | Token Bearer |
| :--- | :--- | :--- | :--- |
| `app_a` | Customer & Branch Consumer | `branches, customers, vehicles` | `Bearer token-assa-app-a-secret-12345` |
| `app_b` | Operations & Fleet Consumer | `vehicles` | `Bearer token-assa-app-b-secret-67890` |
| `app_qa` | QA Automation Consumer | `branches, customers, vehicles` | `Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d` |

---

## 3. Matriks Skenario Pengujian Manual

| No | Skenario | Endpoint | Token | Expected Status |
| :---: | :--- | :--- | :--- | :---: |
| **TC-01** | Liveness Probe | `GET /health` | *(Tanpa Token)* | `200 OK` |
| **TC-02** | Readiness Probe | `GET /health/ready` | *(Tanpa Token)* | `200 OK` |
| **TC-03** | Auth Guard: Tanpa Token | `GET /api/branches/getByCreateDate` | *(Tanpa Token)* | `401 Unauthorized` |
| **TC-04** | Auth Guard: Token Salah | `GET /api/branches/getByCreateDate` | `Bearer token-palsu-123` | `401 Unauthorized` |
| **TC-05** | Auth Guard: Scope Tak Berhak | `GET /api/branches/getByCreateDate` | `app_b` (hanya `vehicles`) | `403 Forbidden` |
| **TC-06** | Branch: Parameter Lengkap | `GET /api/branches/getByCreateDate` | `app_a` (berhak) | `200 OK` |
| **TC-07** | Branch: Parameter Default | `GET /api/branches/getByCreateDate` | `app_a` (berhak) | `200 OK` |
| **TC-08** | Customer: Get by Date | `GET /api/customers/getByCreateDate` | `app_a` (berhak) | `200 OK` |
| **TC-09** | Vehicle: Tanpa Plat Nomor | `GET /api/vehicles/getByLicensePlate` | `app_b` (berhak) | `400 Bad Request` |
| **TC-10** | Vehicle: Plat Nomor Valid | `GET /api/vehicles/getByLicensePlate` | `app_b` (berhak) | `200 OK` |
| **TC-11** | Tracing: Custom Correlation ID | Any Endpoint | Any Valid Token | `200 OK` (+ Header echo) |

---

## 4. Langkah Pengujian Step-by-Step

### Kategori 1: Health & Observability (TC-01 & TC-02)

#### Skenario TC-01: Liveness Check
- **Tujuan**: Memastikan service middleware hidup.
- **cURL**:
  ```bash
  curl -i -X GET 'http://localhost:8290/health'
  ```
- **Expected Response**:
  - HTTP Status: `200 OK`
  - Response Body:
    ```json
    {
      "status": "UP",
      "timestamp": "2026-09-11T17:00:00.000+07:00"
    }
    ```

#### Skenario TC-02: Readiness Check
- **Tujuan**: Memastikan middleware siap melayani trafik ke backend.
- **cURL**:
  ```bash
  curl -i -X GET 'http://localhost:8290/health/ready'
  ```
- **Expected Response**:
  - HTTP Status: `200 OK`
  - Response Body:
    ```json
    {
      "status": "READY",
      "backend": "UP",
      "timestamp": "2026-09-11T17:00:00.000+07:00"
    }
    ```

---

### Kategori 2: Keamanan & Auth Guard (TC-03, TC-04, TC-05)

#### Skenario TC-03: Akses Tanpa Header Authorization
- **Tujuan**: Memastikan request tanpa token wajib ditolak (401).
- **cURL**:
  ```bash
  curl -i -X GET 'http://localhost:8290/api/branches/getByCreateDate'
  ```
- **Expected Response**:
  - HTTP Status: `401 Unauthorized`
  - Response Body:
    ```json
    {
      "error": true,
      "message": "Unauthorized",
      "detail": "Header Authorization wajib disertakan dengan format 'Bearer <token>'."
    }
    ```

#### Skenario TC-04: Akses dengan Token Tidak Terdaftar
- **Tujuan**: Memastikan token palsu/acak ditolak (401).
- **cURL**:
  ```bash
  curl -i -X GET 'http://localhost:8290/api/branches/getByCreateDate' \
    -H 'Authorization: Bearer token-acak-yang-salah'
  ```
- **Expected Response**:
  - HTTP Status: `401 Unauthorized`
  - Response Body:
    ```json
    {
      "error": true,
      "message": "Unauthorized",
      "detail": "Token tidak valid, tidak dikenal, atau telah dicabut."
    }
    ```

#### Skenario TC-05: Akses dengan Scope Tidak Sah
- **Tujuan**: `app_b` hanya memiliki scope `vehicles`. Jika mengakses endpoint `branches`, harus ditolak (403 Forbidden).
- **cURL**:
  ```bash
  curl -i -X GET 'http://localhost:8290/api/branches/getByCreateDate' \
    -H 'Authorization: Bearer token-assa-app-b-secret-67890'
  ```
- **Expected Response**:
  - HTTP Status: `403 Forbidden`
  - Response Body:
    ```json
    {
      "error": true,
      "message": "Forbidden",
      "detail": "Aplikasi (app_b) tidak memiliki izin untuk scope: branches"
    }
    ```

---

### Kategori 3: Domain Branches (TC-06 & TC-07)

#### Skenario TC-06: Get Branches dengan Query Parameters Lengkap
- **Tujuan**: Memanggil backend SAP Core Dev (`https://devsapcoreapi.assa.id`) via middleware.
- **cURL**:
  ```bash
  curl -i -X GET 'http://localhost:8290/api/branches/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11' \
    -H 'Authorization: Bearer token-assa-app-a-secret-12345'
  ```
- **Expected Response**:
  - HTTP Status: `200 OK`
  - Headers: Terdapat header `X-Correlation-Id: corr-...`
  - Response Body: Array data branch dari SAP Core atau format standar ASSA.

#### Skenario TC-07: Get Branches dengan Parameter Default (Query Kosong)
- **Tujuan**: Memastikan middleware secara otomatis mengisi default value dari `config.properties` jika caller tidak mengirim query params:
  - `companyCode = 1000`
  - `dateStart = 2020-01-01`
  - `dateEnd = 2026-09-11`
- **cURL**:
  ```bash
  curl -i -X GET 'http://localhost:8290/api/branches/getByCreateDate' \
    -H 'Authorization: Bearer token-assa-app-a-secret-12345'
  ```
- **Expected Response**:
  - HTTP Status: `200 OK` (Request berhasil diproses menggunakan nilai default).

---

### Kategori 4: Domain Customers (TC-08)

#### Skenario TC-08: Get Customers by Create Date
- **Tujuan**: Memanggil backend SAP Core Customer (`https://sapcoreapi.assa.id`) via middleware.
- **cURL**:
  ```bash
  curl -i -X GET 'http://localhost:8290/api/customers/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11' \
    -H 'Authorization: Bearer token-assa-app-a-secret-12345'
  ```
- **Expected Response**:
  - HTTP Status: `200 OK`
  - Headers: Terdapat `X-Correlation-Id`
  - Response Body: Data list customer dari backend SAP Core.

---

### Kategori 5: Domain Vehicles & External Service (TC-09 & TC-10)

#### Skenario TC-09: Validasi Query Wajib `licensePlate`
- **Tujuan**: Memastikan jika parameter `licensePlate` kosong, ditolak dengan 400 Bad Request.
- **cURL**:
  ```bash
  curl -i -X GET 'http://localhost:8290/api/vehicles/getByLicensePlate?companyCode=1000' \
    -H 'Authorization: Bearer token-assa-app-b-secret-67890'
  ```
- **Expected Response**:
  - HTTP Status: `400 Bad Request`
  - Response Body:
    ```json
    {
      "error": true,
      "message": "Bad Request",
      "detail": "Query parameter 'licensePlate' wajib disertakan (contoh: B-9065-UCU)."
    }
    ```

#### Skenario TC-10: Get Vehicle dengan Plat Nomor Valid
- **Tujuan**: Memanggil External Service ASSA (`https://assa-ext-services.assa.id/qa/service/vehicle`) dengan header `x-api-key` yang diinjeksi otomatis oleh middleware.
- **cURL**:
  ```bash
  curl -i -X GET 'http://localhost:8290/api/vehicles/getByLicensePlate?companyCode=1000&licensePlate=B-9065-UCU' \
    -H 'Authorization: Bearer token-assa-app-b-secret-67890'
  ```
- **Expected Response**:
  - HTTP Status: `200 OK`
  - Headers: Terdapat `X-Correlation-Id`
  - Response Body: Informasi data kendaraan untuk plat nomor `B-9065-UCU`.

---

### Kategori 6: Tracing & Observability Log (TC-11)

#### Skenario TC-11: Custom Correlation ID Tracing
- **Tujuan**: Mengirim header kustom `X-Correlation-Id` dari client dan memastikan middleware merekam serta mengembalikan ID yang sama di response header.
- **cURL**:
  ```bash
  curl -i -X GET 'http://localhost:8290/api/branches/getByCreateDate?companyCode=1000' \
    -H 'Authorization: Bearer token-assa-app-a-secret-12345' \
    -H 'X-Correlation-Id: TRACE-AUDIT-TEST-9999'
  ```
- **Expected Response Headers**:
  - `X-Correlation-Id: TRACE-AUDIT-TEST-9999`
- **Pengecekan Log Konsol / WSO2 Log**:
  Pada log console server MI, amati output JSON structured log:
  ```json
  {
    "timestamp": "2026-09-11T17:05:00.123+07:00",
    "correlationId": "TRACE-AUDIT-TEST-9999",
    "appId": "app_a",
    "endpoint": "/api/branches/getByCreateDate",
    "params": "companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11"
  }
  ```

---

## 5. Cara Cepat Eksekusi Script Otomatis

Selain manual cURL satu per satu, Anda dapat menjalankan script pengujian otomatis yang ada di folder ini:

```powershell
cd notes/test
.\run_manual_tests.ps1
```

Script tersebut akan mengeksekusi ke-11 skenario secara berurutan dan menampilkan indikator warna **[PASSED]** atau **[FAILED]** beserta detail responnya.
