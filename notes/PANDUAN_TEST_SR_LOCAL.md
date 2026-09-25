# Panduan Lengkap Testing Fitur Service Request (SR) di Local Docker Desktop

Panduan ini disusun langkah-demi-langkah **dari nol (0)** agar Anda dapat menguji fitur Service Request (SR) baik format baru **Barantum CRM** maupun format **Omnichannel**, lengkap dengan pengujian **GET Pagination**, **Idempotency Replay**, pengujian via **Terminal (cURL)**, dan via **Postman**.

---

## Daftar Isi
1. [Prasyarat & Arsitektur Port Local](#1-prasyarat--arsitektur-port-local)
2. [Langkah 0: Memastikan Docker Container Aktif](#2-langkah-0-memastikan-docker-container-aktif)
3. [Langkah Cepat: Deploy Update Kode ke Container (Hot-Deploy)](#3-langkah-cepat-deploy-update-kode-ke-container-hot-deploy)
4. [Skenario Pengujian 1: POST Service Request (Format Barantum)](#4-skenario-pengujian-1-post-service-request-format-barantum)
5. [Skenario Pengujian 2: GET Service Request dengan Pagination](#5-skenario-pengujian-2-get-service-request-dengan-pagination)
6. [Skenario Pengujian 3: Idempotency Replay (Pencegahan Duplikasi)](#6-skenario-pengujian-3-idempotency-replay-pencegahan-duplikasi)
7. [Skenario Pengujian 4: Negative Test (Keamanan & Validasi)](#7-skenario-pengujian-4-negative-test-keamanan--validasi)
8. [Skenario Pengujian 5: POST Service Request (Format Legacy Omnichannel)](#8-skenario-pengujian-5-post-service-request-format-legacy-omnichannel)
9. [Panduan Pengujian via Postman](#9-panduan-pengujian-via-postman)
10. [Troubleshooting & Solusi Error](#10-troubleshooting--solusi-error)

---

## 1. Prasyarat & Arsitektur Port Local

Saat menjalankan docker di local machine Anda, ada 2 cara mengakses endpoint:
1. **Melalui Gateway Nginx (Port `6031`)**: Mensimulasikan pemanggilan klien sungguhan seperti di server dev.
2. **Langsung ke WSO2 MI Service Request (Port `8295`)**: Direct call ke microservice WSO2 tanpa perantara Nginx.

```
+-------------------------------------------------------------------------------+
|                             LOCAL DOCKER ENVIRONMENT                         |
|                                                                               |
|  [Client: Postman / cURL]                                                     |
|         │                                                                     |
|         ├───► Port 6031 (Nginx Reverse Proxy: middleware-wso2-nginx)          |
|         │            │                                                        |
|         │            └───► Port 8295 (WSO2 MI: service-request-service)       |
|         │                        │                                            |
|         └────────────────────────┤                                            |
|                                  ├───► MariaDB (Port 3308 / mi-mariadb)       |
|                                  │     (Cek & simpan transaksi api_transaction)
|                                  │                                            |
|                                  └───► ASSA Ext Services (Backend Dev SAP)     |
|                                        (POST input_service_request)           |
+-------------------------------------------------------------------------------+
```

### Informasi Kredensial Pengujian:
- **Kredensial Barantum (Public Gateway)**:
  - Header: `X-API-Key: umk_da295902028f5804c4f0e9d9fd81fa07a2a0e1152d6171e30f387416fbfe5680`
  - Header: `Origin: https://barantum.internal`
- **Kredensial Omnichannel**:
  - Header: `Authorization: Bearer 14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12`

---

## 2. Langkah 0: Memastikan Docker Container Aktif

1. Buka aplikasi **Docker Desktop** di komputer Anda dan pastikan daemon Docker telah berjalan (`Docker Engine running`).
2. Buka Terminal / iTerm / Command Prompt, lalu arahkan ke folder monorepo:
   ```bash
   cd /Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo
   ```
3. Cek status container yang berjalan:
   ```bash
   docker ps
   ```
   Pastikan minimal 3 container berikut berstatus **Up**:
   - `middleware-wso2-nginx` (Port `0.0.0.0:6031->80/tcp`)
   - `service-request-service` (Port `0.0.0.0:8295->8290/tcp`)
   - `mi-mariadb` (Port `0.0.0.0:3308->3306/tcp`)

*Catatan: Jika container belum menyala sama sekali, jalankan:*
```bash
docker compose up -d mariadb service-request-service nginx
```

---

## 3. Langkah Cepat: Deploy Update Kode ke Container (Hot-Deploy)

Setiap kali Anda mengubah file XML sequence, API, atau properties di dalam folder `src/main/wso2mi/`, **Anda tidak perlu menunggu build maven Dockerfile yang memakan waktu belasan menit**.

Gunakan script python hot-deploy instan yang sudah kami sediakan:
```bash
cd /Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo

# 1. Jalankan script packaging CAR otomatis (< 1 detik)
python3 scripts/package_cars.py

# 2. Salin library JDBC MariaDB & CAR hasil update ke container
docker cp /tmp/mariadb-java-client-3.3.3.jar service-request-service:/home/wso2carbon/wso2mi-4.6.0/lib/
docker cp /tmp/shared-artifacts_1.0.0.car service-request-service:/home/wso2carbon/wso2mi-4.6.0/repository/deployment/server/carbonapps/
docker cp /tmp/service-request-service_1.0.0.car service-request-service:/home/wso2carbon/wso2mi-4.6.0/repository/deployment/server/carbonapps/

# 3. Reload Nginx & restart container WSO2
docker exec middleware-wso2-nginx nginx -s reload
docker restart service-request-service
```

Tunggu 3-5 detik, lalu cek log container:
```bash
docker logs --tail 25 service-request-service
```
Jika muncul pesan:
```
INFO {API} - {api:PublicServiceRequestAPI} Initializing API: PublicServiceRequestAPI
INFO {CappDeployer} - Successfully Deployed Carbon Application : service-request-service_1.0.0
INFO {StartupFinalizer} - WSO2 Micro Integrator started in 3.xx seconds
```
Maka microservice sudah **100% siap diuji!**

---

## 4. Skenario Pengujian 1: POST Service Request (Format Barantum)

Skenario ini menguji pengiriman data Service Request baru dari CRM Barantum dengan struktur JSON bertingkat (nested object `unit`).

Jalankan perintah cURL berikut di terminal:

```bash
curl -i -X POST "http://localhost:6031/api/vendor/public/service-requests" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: umk_da295902028f5804c4f0e9d9fd81fa07a2a0e1152d6171e30f387416fbfe5680" \
  -H "Origin: https://barantum.internal" \
  -d '{
    "customerName": "Budi Santoso",
    "requestorName": "Budi Santoso",
    "requestorPhone": "081234567890",
    "branch": "Jakarta Pusat",
    "referenceNumber": "BRT-2026-000999",
    "unit": {
      "licensePlate": "B 1234 XYZ",
      "brand": "Toyota",
      "model": "Avanza",
      "odometer": 25000
    }
  }'
```

*(Catatan: Anda juga bisa mengetes langsung ke port `8295` dengan mengganti URL menjadi `http://localhost:8295/api/vendor/public/service-requests`)*

### Ekspektasi Respon:
- **HTTP Status**: `200 OK` (atau `207 Multi-Status` jika backend dev ASSA eksternal mengembalikan error non-200).
- **Body JSON**:
```json
{
  "success": true,
  "message": "Service request diteruskan ke semua target",
  "transactionId": "BRT-2026-000999",
  "referenceNumber": "BRT-2026-000999",
  "ticket_no": "BRT-2026-000999",
  "targets": {
    "atlas": {
      "status": "SKIPPED",
      "httpStatus": 200,
      "detail": "API ATLAS disabled or no response"
    },
    "extService": {
      "status": "SUCCESS",
      "httpStatus": 200
    }
  }
}
```

---

## 5. Skenario Pengujian 2: GET Service Request dengan Pagination

Skenario ini digunakan untuk mengecek riwayat data transaksi yang tersimpan di database MariaDB dengan format **pagination lengkap**.

### A. Query Semua Data (Halaman 1, 5 Data Per Halaman)
```bash
curl -i -X GET "http://localhost:6031/api/vendor/public/service-requests?page=1&perPage=5" \
  -H "X-API-Key: umk_da295902028f5804c4f0e9d9fd81fa07a2a0e1152d6171e30f387416fbfe5680"
```

### Ekspektasi Respon (HTTP 200 OK):
```json
{
  "count": 1,
  "pagination": {
    "page": 1,
    "perPage": 5,
    "total": 3
  },
  "data": [
    {
      "transactionId": "BRT-2026-000999",
      "status": "SUCCESS",
      "createdAt": "2026-09-25 05:15:30.0"
    }
  ]
}
```

### B. Query Spesifik Berdasarkan `referenceNumber`
```bash
curl -i -X GET "http://localhost:6031/api/vendor/public/service-requests?referenceNumber=BRT-2026-000999" \
  -H "X-API-Key: umk_da295902028f5804c4f0e9d9fd81fa07a2a0e1152d6171e30f387416fbfe5680"
```

---

## 6. Skenario Pengujian 3: Idempotency Replay (Pencegahan Duplikasi)

Fitur Idempotency memastikan klien Barantum yang tidak sengaja mengirim ulang nomor referensi yang sama **tidak akan membuat tiket ganda di backend SAP**.

### Langkah Tes:
Kirimkan kembali payload persis sama dengan nomor referensi yang sudah pernah dikirim sebelumnya (`BRT-2026-000999`):

```bash
curl -i -X POST "http://localhost:6031/api/vendor/public/service-requests" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: umk_da295902028f5804c4f0e9d9fd81fa07a2a0e1152d6171e30f387416fbfe5680" \
  -H "Origin: https://barantum.internal" \
  -d '{
    "customerName": "Budi Santoso",
    "requestorName": "Budi Santoso",
    "requestorPhone": "081234567890",
    "branch": "Jakarta Pusat",
    "referenceNumber": "BRT-2026-000999",
    "unit": {
      "licensePlate": "B 1234 XYZ",
      "brand": "Toyota",
      "model": "Avanza",
      "odometer": 25000
    }
  }'
```

### Ekspektasi Respon:
- Sistem langsung membalas respon cache tanpa melakukan call ulang ke backend downstream.
- Status transaksi tetap terjaga konsistensinya.

---

## 7. Skenario Pengujian 4: Negative Test (Keamanan & Validasi)

### A. Uji Coba Tanpa Token (Harus Gagal 401 Unauthorized)
```bash
curl -i -X POST "http://localhost:6031/api/vendor/public/service-requests" \
  -H "Content-Type: application/json" \
  -d '{"customerName": "Test"}'
```
**Respon**:
```json
{
  "error": true,
  "message": "Unauthorized",
  "detail": "Authentication required. Please provide 'Authorization: Bearer <token>' or 'X-API-Key: <token>'."
}
```

### B. Uji Coba Field Wajib Kurang (Harus Gagal 400 Bad Request)
Kirim request tanpa menyertakan `referenceNumber`:
```bash
curl -i -X POST "http://localhost:6031/api/vendor/public/service-requests" \
  -H "X-API-Key: umk_da295902028f5804c4f0e9d9fd81fa07a2a0e1152d6171e30f387416fbfe5680" \
  -H "Content-Type: application/json" \
  -d '{"customerName": "Budi Santoso"}'
```
**Respon**:
```json
{
  "error": true,
  "message": "Bad Request",
  "detail": "Field 'referenceNumber' (atau 'reff_number') wajib diisi"
}
```

---

## 8. Skenario Pengujian 5: POST Service Request (Format Legacy Omnichannel)

Untuk memastikan format lama dari Omnichannel tetap berfungsi normal:

```bash
curl -i -X POST "http://localhost:6031/api/service-requests" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer 14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12" \
  -H "X-Transaction-Id: SR-OMNI-20260925-001" \
  -d '{
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
  }'
```

---

## 9. Panduan Pengujian via Postman

Koleksi Postman monorepo telah disiapkan dengan otomatisasi script pre-request (generate transaction ID otomatis) dan test assertions.

### Langkah-langkah:
1. **Buka Aplikasi Postman**.
2. Klik tombol **Import** (di pojok kiri atas).
3. Pilih file koleksi berikut dari workspace project Anda:  
   `middleware-assa/ASSA Middleware Server Dev (devmiddleware1.assa.id-6031).postman_collection.json`
4. **Cek / Atur Collection Variables**:
   - Klik nama koleksi di sidebar kiri -> tab **Variables**.
   - Pastikan variable berikut terisi:
     - `baseUrl`: `http://localhost:6031` (via Nginx)
     - `baseUrlSR`: `http://localhost:8295` (Direct MI)
     - `token_barantum`: `umk_da295902028f5804c4f0e9d9fd81fa07a2a0e1152d6171e30f387416fbfe5680`
     - `token_omnichannel`: `14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12`
   - Klik **Save** (`Ctrl+S` / `Cmd+S`).

5. **Buka Folder `7. Service Request Service (Port 8295)`**:
   Telah tersedia 5 request siap pakai:
   - **`Service Request (Barantum) - Public Endpoint POST (200 OK)`**:
     - *Method*: `POST`
     - *URL*: `{{baseUrlSR}}/api/vendor/public/service-requests` *(bisa diganti ke `{{baseUrl}}` untuk lewat port 6031)*
     - *Headers*: `X-API-Key: {{token_barantum}}`, `Origin: https://barantum.internal`
     - *Action*: Klik **Send**. Status `200 OK` / `207` akan otomatis lolos test validation.
   - **`Service Request - Get Paginated List (200 OK)`**:
     - *Method*: `GET`
     - *URL*: `{{baseUrlSR}}/api/vendor/public/service-requests?page=1&perPage=10`
     - *Headers*: `X-API-Key: {{token_barantum}}`
     - *Action*: Klik **Send**. Postman akan memverifikasi field `pagination.page`, `pagination.perPage`, dan array `data`.
   - **`Service Request - Valid Fan-out Paralel (200 OK)`**:
     - *Method*: `POST`
     - *URL*: `{{baseUrlSR}}/api/service-requests`
     - *Auth*: Bearer Token `{{token_omnichannel}}`
   - **`Service Request - Idempotency Replay (200 Replay)`**:
     - Menguji pengiriman ulang ID transaksi yang sama.
   - **`Service Request - Missing app_id (400 Bad Request)`**:
     - Menguji respon validasi error 400.

---

## 10. Troubleshooting & Solusi Error

| Masalah / Error | Penyebab | Solusi |
|---|---|---|
| `Connection refused` (Port 6031 atau 8295) | Container Docker belum menyala | Jalankan `docker compose up -d mariadb service-request-service nginx` di folder `wso2-mi-monorepo`. |
| `HTTP 401 Unauthorized` | Header `X-API-Key` atau `Authorization` salah / tidak dikirim | Pastikan header `X-API-Key: umk_da295902028f5804c4f0e9d9fd81fa07a2a0e1152d6171e30f387416fbfe5680` telah disertakan. |
| `Cannot load JDBC driver class 'org.mariadb.jdbc.Driver'` | Driver MariaDB belum ada di direktori runtime WSO2 | Salin file JAR dengan perintah: `docker cp /tmp/mariadb-java-client-3.3.3.jar service-request-service:/home/wso2carbon/wso2mi-4.6.0/lib/` lalu restart container. |
| `UnknownHostException: mariadb` | Container WSO2 tidak dapat menemukan host mariadb | Pastikan container berada dalam satu docker network (jalankan via `docker compose`). |
| Ingin mereset data pengujian database | Tabel `api_transaction` ingin dikosongkan | Jalankan di terminal: `docker exec mi-mariadb mariadb -u root assa_middleware_db -e "DELETE FROM api_transaction;"` |
