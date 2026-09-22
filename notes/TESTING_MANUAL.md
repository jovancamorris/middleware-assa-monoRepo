# Panduan Pengujian Manual API (Manual Testing Guide)
## WSO2 MI Monorepo — ASSA Middleware

Dokumen ini berisi panduan lengkap pengujian manual untuk seluruh API endpoint middleware ASSA, diekstrak dan diselaraskan langsung dari test suite otomatis [`test_all.ps1`](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-monorepo/middleware-assa/wso2-mi-monorepo/test_all.ps1).

Panduan ini dapat digunakan untuk pengujian menggunakan **cURL**, **Postman**, **Thunder Client**, maupun tool HTTP client lainnya.

---

## 1. Konfigurasi Lingkungan (Environment)

### 1.1. Base URL Endpoint

Pengujian dapat diarahkan langsung ke port service internal (arsitektur microservice lokal/Docker terpisah) atau melalui **Nginx Reverse Proxy** (satu pintu):

| Komponen / Target | URL Direct Service (Lokal) | URL via Nginx Proxy (Server/Dev) |
|---|---|---|
| **Branch Service & Health** | `http://localhost:8290` | `http://localhost:6030` |
| **Customer Service** | `http://localhost:8291` | `http://localhost:6030` |
| **Vehicle Service** | `http://localhost:8292` | `http://localhost:6030` |
| **Vendor Service** | `http://localhost:8293` | `http://localhost:6030` |
| **SPK Service** | `http://localhost:8294` | `http://localhost:6030` |
| **Service Request & Worker** | `http://localhost:8295` | `http://localhost:6030` |

> [!NOTE]
> Contoh cURL di bawah menggunakan URL direct service (`localhost:8290` s/d `8295`). Bila menguji via **Nginx Reverse Proxy**, cukup ganti `http://localhost:829x` menjadi `http://localhost:6030` (atau port host Nginx yang aktif).

---

### 1.2. Daftar Token Otentikasi (Bearer Tokens)

Middleware menggunakan proteksi token berbasis registry aplikasi (`Auth Guard` dan `Scope Guard`):

| Nama Token | Nilai Token (Bearer) | Scope / Izin Akses |
|---|---|---|
| **Token App A** | `3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013` | `branches`, `customers` |
| **Token App B** | `988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881` | `vehicles` (Hanya kendaraan) |
| **Token QA** | `ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d` | `vehicles`, `vendors`, `spk`, testing scope |
| **Token Omnichannel** | `14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12` | `service_requests`, ticketing |
| *Token Palsu (Invalid)* | `token-palsu-ngawur` | Tidak memiliki akses (Untuk uji 401) |

---

### 1.3. Header Standar yang Digunakan

- `Authorization: Bearer <TOKEN>` (Wajib untuk endpoint yang dilindungi)
- `Content-Type: application/json` (Wajib untuk request body JSON)
- `X-Retry-Interval-Seconds: 1` (Opsional: kontrol interval retry)
- `X-Transaction-Id: <STRING_UNIK>` (Wajib untuk pengujian Idempotency pada Vendor, SPK, dan SR)
- `X-Validate-Total: true` (Header khusus validasi akumulasi total harga pada SPK Duelist)
- `X-Forwarded-For: 10.20.30.40` (Simulasi IP client)

---

## 2. Katalog 28 Skenario Pengujian

---

### Bagian A: Health Check & System Probes

#### [TEST 1] Health Check (Liveness)
- **Deskripsi**: Memeriksa apakah service WSO2 MI hidup dan merespons.
- **Method**: `GET`
- **URL**: `http://localhost:8290/health`
- **Auth**: Tidak perlu
- **Expected Status**: `200 OK`
```bash
curl -X GET "http://localhost:8290/health"
```

#### [TEST 2] Health Check (Readiness)
- **Deskripsi**: Memeriksa apakah service siap menerima traffic.
- **Method**: `GET`
- **URL**: `http://localhost:8290/health/ready`
- **Auth**: Tidak perlu
- **Expected Status**: `200 OK`
```bash
curl -X GET "http://localhost:8290/health/ready"
```

---

### Bagian B: Auth Guard & Scope Guard (Security Testing)

#### [TEST 3] Auth Guard: Tanpa Token
- **Deskripsi**: Memastikan request tanpa header Authorization ditolak.
- **Method**: `GET`
- **URL**: `http://localhost:8290/api/branches/getByCreateDate?companyCode=1000`
- **Auth**: *(Tanpa Token)*
- **Expected Status**: `401 Unauthorized`
```bash
curl -X GET "http://localhost:8290/api/branches/getByCreateDate?companyCode=1000"
```

#### [TEST 4] Auth Guard: Token Palsu / Tidak Terdaftar
- **Deskripsi**: Memastikan request dengan token sembarangan ditolak.
- **Method**: `GET`
- **URL**: `http://localhost:8290/api/branches/getByCreateDate?companyCode=1000`
- **Auth**: `Bearer token-palsu-ngawur`
- **Expected Status**: `401 Unauthorized`
```bash
curl -X GET "http://localhost:8290/api/branches/getByCreateDate?companyCode=1000" \
  -H "Authorization: Bearer token-palsu-ngawur"
```

#### [TEST 5] Scope Guard: App B Akses Branch Service
- **Deskripsi**: App B hanya berhak atas kendaraan; akses ke branch harus diblokir.
- **Method**: `GET`
- **URL**: `http://localhost:8290/api/branches/getByCreateDate?companyCode=1000`
- **Auth**: `Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881`
- **Expected Status**: `403 Forbidden`
```bash
curl -X GET "http://localhost:8290/api/branches/getByCreateDate?companyCode=1000" \
  -H "Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881"
```

#### [TEST 6] Scope Guard: App B Akses Customer Service
- **Deskripsi**: App B tidak memiliki scope `customers`.
- **Method**: `GET`
- **URL**: `http://localhost:8291/api/customers/getByCreateDate?companyCode=1000`
- **Auth**: `Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881`
- **Expected Status**: `403 Forbidden`
```bash
curl -X GET "http://localhost:8291/api/customers/getByCreateDate?companyCode=1000" \
  -H "Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881"
```

---

### Bagian C: Query API & Parameter Validation

#### [TEST 7] Vehicle: Validasi Parameter Kosong
- **Deskripsi**: Memanggil vehicle tanpa query parameter yang valid.
- **Method**: `GET`
- **URL**: `http://localhost:8292/api/vehicles/getByLicensePlate?companyCode=1000`
- **Auth**: `Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881`
- **Expected Status**: `400 Bad Request`
```bash
curl -X GET "http://localhost:8292/api/vehicles/getByLicensePlate?companyCode=1000" \
  -H "Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881"
```

#### [TEST 8] Vehicle: Get by License Plate (Atlas Endpoint)
- **Deskripsi**: Mengambil data kendaraan berdasarkan nomor plat dengan Token App B.
- **Method**: `GET`
- **URL**: `http://localhost:8292/api/vehicles/getByLicensePlate?plate_no=DD-8112`
- **Auth**: `Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881`
- **Expected Status**: `200 OK`
```bash
curl -X GET "http://localhost:8292/api/vehicles/getByLicensePlate?plate_no=DD-8112" \
  -H "Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881"
```

#### [TEST 9] Vehicle: Vehicle Atlas Endpoint (QA Token)
- **Deskripsi**: Mengambil spesifikasi kendaraan via route `/vehicleatlas` dengan Token QA.
- **Method**: `GET`
- **URL**: `http://localhost:8292/api/vehicles/vehicleatlas?plate_no=DD-8112`
- **Auth**: `Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d`
- **Expected Status**: `200 OK`
```bash
curl -X GET "http://localhost:8292/api/vehicles/vehicleatlas?plate_no=DD-8112" \
  -H "Authorization: Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d"
```

#### [TEST 10] Customer: Get by Create Date
- **Deskripsi**: Mengambil daftar pelanggan dengan filter tanggal & pagination (Token App A).
- **Method**: `GET`
- **URL**: `http://localhost:8291/api/customers/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11&page=1&perPage=10`
- **Auth**: `Bearer 3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013`
- **Expected Status**: `200 OK`
```bash
curl -X GET "http://localhost:8291/api/customers/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11&page=1&perPage=10" \
  -H "Authorization: Bearer 3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013"
```

#### [TEST 11] Branch: Get by Create Date
- **Deskripsi**: Mengambil data cabang ASSA dengan filter tanggal & pagination (Token App A).
- **Method**: `GET`
- **URL**: `http://localhost:8290/api/branches/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11&page=1&perPage=10`
- **Auth**: `Bearer 3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013`
- **Expected Status**: `200 OK`
```bash
curl -X GET "http://localhost:8290/api/branches/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11&page=1&perPage=10" \
  -H "Authorization: Bearer 3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013"
```

---

### Bagian D: Vendor Create Service (XML & FTP Pool)

#### [TEST 12] Vendor Create: Tanpa Token
- **Deskripsi**: Request POST create vendor tanpa autentikasi.
- **Method**: `POST`
- **URL**: `http://localhost:8293/api/vendors/create`
- **Auth**: *(Tanpa Token)*
- **Body**: `{}`
- **Expected Status**: `401 Unauthorized`
```bash
curl -X POST "http://localhost:8293/api/vendors/create" \
  -H "Content-Type: application/json" \
  -d "{}"
```

#### [TEST 13] Vendor Create: Scope Guard (Token App B)
- **Deskripsi**: Token App B tidak berhak mengakses endpoint vendors.
- **Method**: `POST`
- **URL**: `http://localhost:8293/api/vendors/create`
- **Auth**: `Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881`
- **Body**: `{}`
- **Expected Status**: `403 Forbidden`
```bash
curl -X POST "http://localhost:8293/api/vendors/create" \
  -H "Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881" \
  -H "Content-Type: application/json" \
  -d "{}"
```

#### [TEST 14] Vendor Create: Validasi Field Gagal (`companyTitle` Invalid)
- **Deskripsi**: Payload berisi `companyTitle: "INVALID"` (harus PT, CV, UD, dll).
- **Method**: `POST`
- **URL**: `http://localhost:8293/api/vendors/create`
- **Auth**: `Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d`
- **Expected Status**: `400 Bad Request`
```bash
curl -X POST "http://localhost:8293/api/vendors/create" \
  -H "Authorization: Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d" \
  -H "Content-Type: application/json" \
  -d '{
    "companyTitle": "INVALID",
    "companyName": "PT Test",
    "otv": "No",
    "paymentCycle": "Monthly",
    "accountNumber": "123",
    "accountName": "Test",
    "bankName": "BCA",
    "hoEmail": "test@assa.id",
    "hoPhone": "08123",
    "hoAddress": "Jakarta",
    "npwp": "12345",
    "accountGroup": "V010",
    "top": "T014",
    "glAccount": "2121000000",
    "documentNumber": "DOC-01"
  }'
```

#### [TEST 15] Vendor Create: Payload Valid ke FTP SAP
- **Deskripsi**: Payload lengkap dan valid, menghasilkan file XML dan di-upload ke server FTP `devqaxmlpool.assa.id`.
- **Method**: `POST`
- **URL**: `http://localhost:8293/api/vendors/create`
- **Auth**: `Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d`
- **Headers**:
  - `X-Transaction-Id: TRX-VENDOR-001` *(Gunakan ID unik per transaksi)*
- **Expected Status**: `201 Created`
```bash
curl -X POST "http://localhost:8293/api/vendors/create" \
  -H "Authorization: Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d" \
  -H "Content-Type: application/json" \
  -H "X-Transaction-Id: TRX-VENDOR-001" \
  -d '{
    "companyTitle": "PT",
    "companyName": "PT Adi Sarana Armada Tbk",
    "otv": "No",
    "paymentCycle": "Monthly",
    "accountNumber": "1200010978489",
    "accountName": "Robby Yulianto Setiawan",
    "bankName": "Mandiri",
    "hoEmail": "assa@assarent.co.id",
    "hoPhone": "082246605199",
    "hoAddress": "Jalan Nusa Indah 2 Block C.ext 8 no 7, Duri Kosambi, Jakarta Barat, DKI Jakarta, 11410",
    "contactName": "Robby Contact",
    "contactPhone": "08224660189",
    "npwp": "3173080209920003",
    "accountGroup": "V010",
    "top": "T014",
    "glAccount": "2121000000",
    "documentNumber": "VENDOR-ATLAS-000123"
  }'
```

#### [TEST 16] Vendor Create: Idempotency Replay
- **Deskripsi**: Mengirim ulang request yang sama dengan `X-Transaction-Id` yang sama persis seperti TEST 15. Server harus mendeteksi duplikat dan merespons tanpa membuat ulang file di FTP.
- **Method**: `POST`
- **URL**: `http://localhost:8293/api/vendors/create`
- **Auth**: `Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d`
- **Header**: `X-Transaction-Id: TRX-VENDOR-001`
- **Expected Status**: `200 OK` (Replay terdeteksi)
```bash
# Ulangi perintah TEST 15 dengan X-Transaction-Id yang sama:
curl -X POST "http://localhost:8293/api/vendors/create" \
  -H "Authorization: Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d" \
  -H "Content-Type: application/json" \
  -H "X-Transaction-Id: TRX-VENDOR-001" \
  -d '{
    "companyTitle": "PT",
    "companyName": "PT Adi Sarana Armada Tbk",
    "otv": "No",
    "paymentCycle": "Monthly",
    "accountNumber": "1200010978489",
    "accountName": "Robby Yulianto Setiawan",
    "bankName": "Mandiri",
    "hoEmail": "assa@assarent.co.id",
    "hoPhone": "082246605199",
    "hoAddress": "Jalan Nusa Indah 2 Block C.ext 8 no 7, Duri Kosambi, Jakarta Barat, DKI Jakarta, 11410",
    "contactName": "Robby Contact",
    "contactPhone": "08224660189",
    "npwp": "3173080209920003",
    "accountGroup": "V010",
    "top": "T014",
    "glAccount": "2121000000",
    "documentNumber": "VENDOR-ATLAS-000123"
  }'
```

---

### Bagian E: SPK Duelist Service (XML & FTP Pool)

#### [TEST 17] SPK Duelist: Tanpa Token
- **Deskripsi**: Request POST ke SPK Duelist tanpa otentikasi.
- **Method**: `POST`
- **URL**: `http://localhost:8294/api/spk/duelist`
- **Auth**: *(Tanpa Token)*
- **Body**: `{}`
- **Expected Status**: `401 Unauthorized`
```bash
curl -X POST "http://localhost:8294/api/spk/duelist" \
  -H "Content-Type: application/json" \
  -d "{}"
```

#### [TEST 18] SPK Duelist: Scope Guard (Token App B)
- **Deskripsi**: Token App B tidak berhak mengakses endpoint SPK.
- **Method**: `POST`
- **URL**: `http://localhost:8294/api/spk/duelist`
- **Auth**: `Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881`
- **Body**: `{}`
- **Expected Status**: `403 Forbidden`
```bash
curl -X POST "http://localhost:8294/api/spk/duelist" \
  -H "Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881" \
  -H "Content-Type: application/json" \
  -d "{}"
```

#### [TEST 19] SPK Duelist: Validasi Wajib `noSpk` Kosong
- **Deskripsi**: Payload tidak menyertakan parameter wajib `noSpk`.
- **Method**: `POST`
- **URL**: `http://localhost:8294/api/spk/duelist`
- **Auth**: `Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d`
- **Expected Status**: `400 Bad Request`
```bash
curl -X POST "http://localhost:8294/api/spk/duelist" \
  -H "Authorization: Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "Maintenance",
    "noPolisi": "B-2120-BKZ",
    "category": "Maintenance",
    "subCategory": "Adhoc",
    "vendorReferensi": "0001",
    "totalPrice": 1850000,
    "createdAt": "2026-09-17 14:46:11",
    "createdBy": "atlas.user",
    "details": [
      { "jenis": "Jasa", "description": "Jasa Perbaikan AC", "qty": 1, "price": 1850000 }
    ]
  }'
```

#### [TEST 20] SPK Duelist: Validasi Total Harga Gagal (`X-Validate-Total`)
- **Deskripsi**: Header `X-Validate-Total: true` mendeteksi ketidakcocokan antara `totalPrice` (1.850.001) dengan akumulasi item detail (1.850.000).
- **Method**: `POST`
- **URL**: `http://localhost:8294/api/spk/duelist`
- **Auth**: `Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d`
- **Headers**:
  - `X-Validate-Total: true`
- **Expected Status**: `400 Bad Request`
```bash
curl -X POST "http://localhost:8294/api/spk/duelist" \
  -H "Authorization: Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d" \
  -H "Content-Type: application/json" \
  -H "X-Validate-Total: true" \
  -d '{
    "noSpk": "SPK/2026/09/00002",
    "type": "Maintenance",
    "noPolisi": "B-2120-BKZ",
    "category": "Maintenance",
    "subCategory": "Adhoc",
    "vendorReferensi": "0001",
    "totalPrice": 1850001,
    "createdAt": "2026-09-17 14:46:11",
    "createdBy": "atlas.user",
    "details": [
      { "jenis": "Jasa", "description": "Jasa Perbaikan AC", "qty": 1, "price": 1850000 }
    ]
  }'
```

#### [TEST 21] SPK Duelist: Payload Valid + Akumulasi Total Valid ke FTP
- **Deskripsi**: Mengirim data SPK yang valid (150.000 + 1.700.000 = 1.850.000) dengan header validasi total dan generate XML ke folder FTP `/duelist`.
- **Method**: `POST`
- **URL**: `http://localhost:8294/api/spk/duelist`
- **Auth**: `Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d`
- **Headers**:
  - `X-Transaction-Id: SPK-TRX-001` *(ID unik)*
  - `X-Validate-Total: true`
  - `X-Forwarded-For: 10.20.30.40`
- **Expected Status**: `201 Created`
```bash
curl -X POST "http://localhost:8294/api/spk/duelist" \
  -H "Authorization: Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d" \
  -H "Content-Type: application/json" \
  -H "X-Transaction-Id: SPK-TRX-001" \
  -H "X-Validate-Total: true" \
  -H "X-Forwarded-For: 10.20.30.40" \
  -d '{
    "noSpk": "SPK/2026/09/00003",
    "type": "Maintenance",
    "noPolisi": "B-2120-BKZ",
    "noSr": "SR-000123",
    "category": "Maintenance",
    "subCategory": "Adhoc",
    "vendorReferensi": "0001",
    "namaVendor": "Bengkel Jaya Motor",
    "picService": "PIC-001",
    "namaPicService": "Andi Wijaya",
    "spkRework": "No",
    "totalPrice": 1850000,
    "createdAt": "2026-09-17 14:46:11",
    "createdBy": "atlas.user",
    "poSpkNumber": "PO-4500012345",
    "invoiceNumber": "INV_BKL_00001",
    "invoiceDate": "2026-09-17",
    "invoiceAmount": 1850000,
    "memo": "Perbaikan kendaraan",
    "taxInvoiceNumber": "314650102340592",
    "taxInvoiceDate": "2026-09-17",
    "businessArea": "1101",
    "details": [
      { "jenis": "Jasa", "description": "Jasa Perbaikan AC", "qty": 1, "price": 150000 },
      { "jenis": "Parts", "description": "Filter AC", "qty": 1, "price": 1700000 }
    ]
  }'
```

#### [TEST 22] SPK Duelist: Idempotency Replay
- **Deskripsi**: Replay request yang sama dengan `X-Transaction-Id: SPK-TRX-001`.
- **Method**: `POST`
- **URL**: `http://localhost:8294/api/spk/duelist`
- **Auth**: `Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d`
- **Header**: `X-Transaction-Id: SPK-TRX-001`
- **Expected Status**: `200 OK` (Replay terdeteksi)
```bash
# Ulangi perintah TEST 21 dengan X-Transaction-Id yang sama:
curl -X POST "http://localhost:8294/api/spk/duelist" \
  -H "Authorization: Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d" \
  -H "Content-Type: application/json" \
  -H "X-Transaction-Id: SPK-TRX-001" \
  -H "X-Validate-Total: true" \
  -H "X-Forwarded-For: 10.20.30.40" \
  -d '{
    "noSpk": "SPK/2026/09/00003",
    "type": "Maintenance",
    "noPolisi": "B-2120-BKZ",
    "noSr": "SR-000123",
    "category": "Maintenance",
    "subCategory": "Adhoc",
    "vendorReferensi": "0001",
    "namaVendor": "Bengkel Jaya Motor",
    "picService": "PIC-001",
    "namaPicService": "Andi Wijaya",
    "spkRework": "No",
    "totalPrice": 1850000,
    "createdAt": "2026-09-17 14:46:11",
    "createdBy": "atlas.user",
    "poSpkNumber": "PO-4500012345",
    "invoiceNumber": "INV_BKL_00001",
    "invoiceDate": "2026-09-17",
    "invoiceAmount": 1850000,
    "memo": "Perbaikan kendaraan",
    "taxInvoiceNumber": "314650102340592",
    "taxInvoiceDate": "2026-09-17",
    "businessArea": "1101",
    "details": [
      { "jenis": "Jasa", "description": "Jasa Perbaikan AC", "qty": 1, "price": 150000 },
      { "jenis": "Parts", "description": "Filter AC", "qty": 1, "price": 1700000 }
    ]
  }'
```

---

### Bagian F: Service Request (SR) & Fan-Out Paralel

#### [TEST 23] Service Request: Tanpa Token
- **Deskripsi**: Request POST tanpa otentikasi.
- **Method**: `POST`
- **URL**: `http://localhost:8295/api/service-requests`
- **Auth**: *(Tanpa Token)*
- **Body**: `{}`
- **Expected Status**: `401 Unauthorized`
```bash
curl -X POST "http://localhost:8295/api/service-requests" \
  -H "Content-Type: application/json" \
  -d "{}"
```

#### [TEST 24] Service Request: Scope Guard (Token App B)
- **Deskripsi**: Token App B tidak berhak mengakses endpoint Service Request.
- **Method**: `POST`
- **URL**: `http://localhost:8295/api/service-requests`
- **Auth**: `Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881`
- **Body**: `{}`
- **Expected Status**: `403 Forbidden`
```bash
curl -X POST "http://localhost:8295/api/service-requests" \
  -H "Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881" \
  -H "Content-Type: application/json" \
  -d "{}"
```

#### [TEST 25] Service Request: Validasi `app_id` Wajib
- **Deskripsi**: Request tidak menyertakan atribut mandatory `app_id`.
- **Method**: `POST`
- **URL**: `http://localhost:8295/api/service-requests`
- **Auth**: `Bearer 14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12`
- **Expected Status**: `400 Bad Request`
```bash
curl -X POST "http://localhost:8295/api/service-requests" \
  -H "Authorization: Bearer 14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12" \
  -H "Content-Type: application/json" \
  -d '{
    "reff_number": "REF01",
    "branch_code": "JKT01",
    "created_datetime": "17-09-2026",
    "created_by": "admin",
    "ticket_no": "TCK01"
  }'
```

#### [TEST 26] Service Request: Fan-Out Paralel Valid (Omnichannel)
- **Deskripsi**: Mengirim tiket perbaikan dari kanal Omnichannel ke backend ASSA External Services dan ATLAS (bila toggle aktif).
- **Method**: `POST`
- **URL**: `http://localhost:8295/api/service-requests`
- **Auth**: `Bearer 14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12`
- **Headers**:
  - `X-Transaction-Id: TRX-SR-001` *(ID unik)*
- **Expected Status**: `200 OK`
```bash
curl -X POST "http://localhost:8295/api/service-requests" \
  -H "Authorization: Bearer 14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12" \
  -H "Content-Type: application/json" \
  -H "X-Transaction-Id: TRX-SR-001" \
  -d '{
    "app_id": "sr_app_omnichannel",
    "reff_number": "REF-SR-20260917-001",
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
    "service_datetime": "2026-09-20 10:00:00",
    "service_location": "Bengkel Resmi ASSA Sunter",
    "jenis_permintaan": "Service Berkala",
    "incident_datetime": "2026-09-17 09:00:00",
    "tipe_tiket": "Regular",
    "judul": "Service Berkala Kendaraan Operasional",
    "nama_kunjungan": "Ahmad Fauzi",
    "telepon_kunjungan": "081234567890",
    "alamat_kunjungan": "Jl. Danau Sunter Barat Blok A",
    "pool_name": "Pool Sunter",
    "area_bengkel": "Jakarta Utara",
    "task": "Ganti Oli Mesin dan Filter Oli",
    "created_datetime": "17-09-2026",
    "created_by": "omnichannel_agent",
    "ticket_no": "TICKET-SR-99901"
  }'
```

#### [TEST 27] Service Request: Idempotency Replay
- **Deskripsi**: Replay request yang sama dengan `X-Transaction-Id: TRX-SR-001`.
- **Method**: `POST`
- **URL**: `http://localhost:8295/api/service-requests`
- **Auth**: `Bearer 14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12`
- **Header**: `X-Transaction-Id: TRX-SR-001`
- **Expected Status**: `200 OK` (Replay terdeteksi)
```bash
# Ulangi perintah TEST 26 dengan X-Transaction-Id yang sama persis:
curl -X POST "http://localhost:8295/api/service-requests" \
  -H "Authorization: Bearer 14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12" \
  -H "Content-Type: application/json" \
  -H "X-Transaction-Id: TRX-SR-001" \
  -d '{
    "app_id": "sr_app_omnichannel",
    "reff_number": "REF-SR-20260917-001",
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
    "service_datetime": "2026-09-20 10:00:00",
    "service_location": "Bengkel Resmi ASSA Sunter",
    "jenis_permintaan": "Service Berkala",
    "incident_datetime": "2026-09-17 09:00:00",
    "tipe_tiket": "Regular",
    "judul": "Service Berkala Kendaraan Operasional",
    "nama_kunjungan": "Ahmad Fauzi",
    "telepon_kunjungan": "081234567890",
    "alamat_kunjungan": "Jl. Danau Sunter Barat Blok A",
    "pool_name": "Pool Sunter",
    "area_bengkel": "Jakarta Utara",
    "task": "Ganti Oli Mesin dan Filter Oli",
    "created_datetime": "17-09-2026",
    "created_by": "omnichannel_agent",
    "ticket_no": "TICKET-SR-99901"
  }'
```

---

### Bagian G: Background Worker

#### [TEST 28] Background Worker: Manual Trigger Retry Worker
- **Deskripsi**: Menjalankan trigger manual untuk background retry worker yang memproses pesan pending / gagal.
- **Method**: `GET`
- **URL**: `http://localhost:8295/api/worker/retry`
- **Auth**: Tidak perlu
- **Expected Status**: `200 OK`
```bash
curl -X GET "http://localhost:8295/api/worker/retry"
```

---

## 3. Ringkasan Matriks Pengujian (Quick Reference Sheet)

| # | Skenario Pengujian | Port / Path | Method | Auth / Token | Expected |
|:---:|---|---|:---:|---|:---:|
| **1** | Health Check (Liveness) | `:8290/health` | `GET` | *(None)* | **200** |
| **2** | Health Check (Readiness) | `:8290/health/ready` | `GET` | *(None)* | **200** |
| **3** | Auth Guard: Tanpa Token | `:8290/api/branches/getByCreateDate` | `GET` | *(None)* | **401** |
| **4** | Auth Guard: Token Palsu | `:8290/api/branches/getByCreateDate` | `GET` | `token-palsu-ngawur` | **401** |
| **5** | Scope Guard: App B panggil Branch | `:8290/api/branches/getByCreateDate` | `GET` | `tokenAppB` | **403** |
| **6** | Scope Guard: App B panggil Customer | `:8291/api/customers/getByCreateDate` | `GET` | `tokenAppB` | **403** |
| **7** | Validasi Parameter: Vehicle tanpa query | `:8292/api/vehicles/getByLicensePlate` | `GET` | `tokenAppB` | **400** |
| **8** | Vehicle: Get by Plate (`/getByLicensePlate`) | `:8292/api/vehicles/getByLicensePlate` | `GET` | `tokenAppB` | **200** |
| **9** | Vehicle: Get by Plate (`/vehicleatlas`) | `:8292/api/vehicles/vehicleatlas` | `GET` | `tokenQA` | **200** |
| **10** | Customer: Get by Create Date | `:8291/api/customers/getByCreateDate` | `GET` | `tokenAppA` | **200** |
| **11** | Branch: Get by Create Date | `:8290/api/branches/getByCreateDate` | `GET` | `tokenAppA` | **200** |
| **12** | Vendor Create: Tanpa Token | `:8293/api/vendors/create` | `POST` | *(None)* | **401** |
| **13** | Vendor Create: Scope Guard (App B) | `:8293/api/vendors/create` | `POST` | `tokenAppB` | **403** |
| **14** | Vendor Create: Validasi `companyTitle` | `:8293/api/vendors/create` | `POST` | `tokenQA` | **400** |
| **15** | Vendor Create: Valid Payload ke FTP | `:8293/api/vendors/create` | `POST` | `tokenQA` | **201** |
| **16** | Vendor Create: Idempotency Replay | `:8293/api/vendors/create` | `POST` | `tokenQA` | **200** |
| **17** | SPK Duelist: Tanpa Token | `:8294/api/spk/duelist` | `POST` | *(None)* | **401** |
| **18** | SPK Duelist: Scope Guard (App B) | `:8294/api/spk/duelist` | `POST` | `tokenAppB` | **403** |
| **19** | SPK Duelist: Validasi Wajib `noSpk` | `:8294/api/spk/duelist` | `POST` | `tokenQA` | **400** |
| **20** | SPK Duelist: Validasi Akumulasi Total | `:8294/api/spk/duelist` | `POST` | `tokenQA` | **400** |
| **21** | SPK Duelist: Valid Payload ke FTP | `:8294/api/spk/duelist` | `POST` | `tokenQA` | **201** |
| **22** | SPK Duelist: Idempotency Replay | `:8294/api/spk/duelist` | `POST` | `tokenQA` | **200** |
| **23** | Service Request: Tanpa Token | `:8295/api/service-requests` | `POST` | *(None)* | **401** |
| **24** | Service Request: Scope Guard (App B) | `:8295/api/service-requests` | `POST` | `tokenAppB` | **403** |
| **25** | Service Request: Validasi `app_id` | `:8295/api/service-requests` | `POST` | `tokenOmnichannel` | **400** |
| **26** | Service Request: Valid Fan-out Paralel | `:8295/api/service-requests` | `POST` | `tokenOmnichannel` | **200** |
| **27** | Service Request: Idempotency Replay | `:8295/api/service-requests` | `POST` | `tokenOmnichannel` | **200** |
| **28** | Background Worker: Trigger Retry | `:8295/api/worker/retry` | `GET` | *(None)* | **200** |

---

## 4. Cara Pengujian Otomatis via PowerShell

Bila ingin menjalankan seluruh 28 skenario di atas secara otomatis dan berurutan:

```powershell
cd c:\Users\eksad\OneDrive\Documents\assa\code\middleware-assa-monorepo\middleware-assa\wso2-mi-monorepo
.\test_all.ps1
```
