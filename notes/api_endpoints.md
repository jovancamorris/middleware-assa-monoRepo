# ASSA API Documentation

Dokumentasi endpoint API untuk integrasi Core SAP dan External Services.

---

## Daftar Endpoint

1. [Get Branches by Create Date](#1-get-branches-by-create-date)
2. [Get Customer by Create Date](#2-get-customer-by-create-date)
3. [Get Vehicle Service (Dev & QA)](#3-get-vehicle-service)

---

## 1. Get Branches by Create Date

Mengambil data cabang berdasarkan rentang tanggal pembuatan (*create date*).

- **Method**: `GET`
- **Base URL**: `https://devsapcoreapi.assa.id`
- **Path**: `/api/Branches/GetByCreateDate`

### Query Parameters

| Parameter | Tipe | Wajib | Contoh Nilai | Deskripsi |
| :--- | :--- | :--- | :--- | :--- |
| `companyCode` | string / int | Ya | `1000` | Kode perusahaan |
| `dateStart` | string (YYYY-MM-DD) | Ya | `2020-01-01` | Tanggal awal pencarian |
| `dateEnd` | string (YYYY-MM-DD) | Ya | `2026-09-11` | Tanggal akhir pencarian |
| `filterBy` | string | Tidak | `jakarta` | **Single-field search**: Mencakup `BranchCode` dan `BranchName` (case-insensitive substring) |
| `page` | int | Tidak (Default: `1`) | `1` | Nomor halaman data |
| `perPage` | int | Tidak (Default: `10`) | `10` | Jumlah data per halaman |

### Contoh Request URL

```text
https://devsapcoreapi.assa.id/api/Branches/GetByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11&filterBy=jakarta&page=1&perPage=5
```

### cURL

```bash
curl --location 'https://devsapcoreapi.assa.id/api/Branches/GetByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11&filterBy=jakarta&page=1&perPage=5'
```

---

## 2. Get Customer by Create Date

Mengambil data pelanggan berdasarkan rentang tanggal pembuatan (*create date*).

- **Method**: `GET`
- **Base URL**: `https://sapcoreapi.assa.id`
- **Path**: `/api/Customer/GetByCreateDate`

### Query Parameters

| Parameter | Tipe | Wajib | Contoh Nilai | Deskripsi |
| :--- | :--- | :--- | :--- | :--- |
| `companyCode` | string / int | Tidak (Default: `1000`) | `1000` | Kode entitas perusahaan |
| `dateStart` | string (YYYY-MM-DD) | Tidak (Default: `2025-01-01`) | `2025-01-01` | Tanggal awal pencarian |
| `dateEnd` | string (YYYY-MM-DD) | Tidak (Default: `2026-12-31`) | `2026-12-31` | Tanggal akhir pencarian |
| `filterBy` | string | Tidak | `1000025` / `ADI` | **Single-field search**: 1 field mencakup `CustomerCode` dan `CustomerName` (case-insensitive) |
| `CustomerCode` | string | Tidak | `1000025` | **Filter / search kode customer** (case-insensitive) |
| `CustomerName` | string | Tidak | `ADI SARANA` | **Filter / search nama customer** (case-insensitive substring) |
| `page` | int | Tidak (Default: `1`) | `1` | Nomor halaman |
| `perPage` | int | Tidak (Default: `10`) | `10` | Jumlah data per halaman |

### Contoh Request URL

```text
https://devmiddleware.assa.id/api/customers/getByCreateDate?companyCode=1000&dateStart=2025-01-01&dateEnd=2026-12-31&CustomerCode=1000025&CustomerName=ADI%20SARANA&page=1&perPage=5
```

### cURL

```bash
curl --location 'https://devmiddleware.assa.id/api/customers/getByCreateDate?companyCode=1000&dateStart=2025-01-01&dateEnd=2026-12-31&CustomerCode=1000025&CustomerName=ADI%20SARANA&page=1&perPage=5' \
  --header 'Authorization: Bearer <TOKEN>'
```

---

## 3. Get Vehicle Atlas Service

Mengambil data informasi kendaraan dari endpoint `getVehicleAtlas` berdasarkan nomor polisi (`plate_no`), `equipment_no`, atau filter lainnya.
Referensi detail: [panduan-get-vehicleatlas-ver1.md](./panduan-get-vehicleatlas-ver1.md).

- **Method**: `GET`
- **Path**: `/api/vehicleatlas`

### Environment & Base URL

| Environment | Base URL | URL Lengkap |
| :--- | :--- | :--- |
| **Local (dev server)** | `http://127.0.0.1:8899` | `http://127.0.0.1:8899/api/vehicleatlas` |
| **Dev / QA** | `https://<host-dev-fms-api>` | `https://<host-dev-fms-api>/api/vehicleatlas` |
| **Production** | `https://<host-prod-fms-api>` | `https://<host-prod-fms-api>/api/vehicleatlas` |

### Headers

| Header | Tipe | Wajib | Contoh Value | Catatan |
| :--- | :--- | :--- | :--- | :--- |
| `Key` | string | Ya | `<API_KEY>` | Wajib menggunakan header persis `Key` (huruf K kapital) |

### Query Parameters

| Parameter | Tipe | Wajib | Contoh Nilai | Deskripsi |
| :--- | :--- | :--- | :--- | :--- |
| `filterBy` | string | Opsional | `B-9065` / `10027282` / `Makassar` | **Single-field search**: 1 field mencakup nomor plat (`plat_no`), `equipment_no`, `branch_code`, `branch_name`, `tipe_kendaraan`, atau `color` |
| `plat_no` | string | Opsional | `B-9065` / `DD-8112` | Nomor plat kendaraan untuk filter / search (pencarian sebagian / LIKE, auto-normalisasi) |
| `page` | int | Opsional | `1` | Nomor halaman data (default: 1) |
| `perPage` | int | Opsional | `10` | Jumlah data per halaman (default: 10) |
| `plate_no` | string | Opsional | `DD-8112` | Alias untuk `plat_no` |
| `equipment_no` | string | Opsional | `10027282` | Nomor equipment (exact match) |
| `branch_code` | string | Opsional | `1411` | Filter per kode cabang (bisa juga via `branchCode`) |
| `status_id` | int | Opsional | `11` | Filter status unit |
| `color` | string | Opsional | `putih` | Filter warna unit |
| `limit` | int | Opsional | `10` | Alias limit data (ekuivalen `perPage`) |
| `offset` | int | Opsional | `0` | Alias offset pagination data |

*(Catatan: Mendukung auto-normalisasi plat nomor seperti `B 9065 UCU` atau `B9065UCU` menjadi `B-9065-UCU`).*

### Contoh Request

#### cURL (Cari Plat Nomor dengan Filter & Paginasi):
```bash
curl --location '{BASE_URL}/api/vehicles/getByLicensePlate?plat_no=B-9065&page=1&perPage=10' \
     --header 'Authorization: Bearer <TOKEN_APP_B_ATAU_QA>'
```

#### cURL (Paginasi Semua Kendaraan via /vehicleatlas):
```bash
curl --location '{BASE_URL}/api/vehicles/vehicleatlas?page=2&perPage=10' \
     --header 'Authorization: Bearer <TOKEN_APP_B_ATAU_QA>'
```

### Format Response Sukses (HTTP 200)

```json
{
    "success": true,
    "total": 30370,
    "page": 1,
    "perPage": 10,
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
        }
    ]
}
```

---

## 4. Vendor Create (XML → FTP Interface) — Version 2

Menerima payload data vendor (17 field V2 ATLAS), memvalidasi data master vendor, membentuk file XML resmi ATLAS/SAP (`Transaction` -> `Header` Key2=VMD + `TransactionDatas`), dan mengirimkannya ke server FTP inbound SAP (`devqaxmlpool.assa.id`) pada folder `/vmd`.
Referensi detail: [GUIDE_VENDOR_CREATE_XML_FTP_V2.md](./GUIDE_VENDOR_CREATE_XML_FTP_V2.md).

- **Method**: `POST`
- **Path**: `/api/vendors/create`
- **Auth**: Wajib Bearer Token dengan scope `vendors`

### Headers

| Header | Tipe | Wajib | Contoh Nilai | Deskripsi |
| :--- | :--- | :--- | :--- | :--- |
| `Authorization` | string | Ya | `Bearer <token>` | Token dari App Registry dengan scope `vendors` |
| `Content-Type` | string | Ya | `application/json` | Format request body |
| `X-Transaction-Id` | string | Opsional | `TRX-VENDOR-001` | UUID / ID Transaksi unik untuk Idempotency Guard |
| `X-Forwarded-For` | string | Opsional | `10.20.30.40` | IP Address pengirim untuk Header XML |
| `X-File-Name` | string | Opsional | `VMD_000001.xml` | Override nama file FTP target |

### Request Body (Contoh V2)

```json
{
  "company_code": "1000/2000/6000/7000",
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
}
```

### Response Sukses (HTTP 201 Created)

```json
{
  "success": true,
  "message": "Vendor (VMD) accepted and delivered to FTP",
  "transactionId": "TRX-VENDOR-001",
  "fileName": "VMD_20260917110339_TRX-VENDOR-001.xml",
  "documentNumber": "VENDOR-ATLAS-000123"
}
```

### Response Idempotency Replay (HTTP 200 OK)
Bila request dengan `X-Transaction-Id` yang sama dikirim ulang setelah transaksi sukses sebelumnya, middleware akan mengembalikan response dari cache replay dengan header `X-Idempotent-Replay: true`.

---

## 5. SPK Duelist (XML → FTP Interface)

Mengirim data Surat Perintah Kerja (SPK) Maintenance beserta rincian item pekerjaan (Jasa dan Parts) ke server FTP SAP inbound (`devqaxmlpool.assa.id`) pada folder `/spk`. Mendukung kelengkapan data tagihan invoice vendor dan faktur pajak.

- **Method**: `POST`
- **Path**: `/api/spk/duelist`
- **Auth**: Wajib Bearer Token dengan scope `spk`

### Headers

| Header | Tipe | Wajib | Contoh Nilai | Deskripsi |
| :--- | :--- | :--- | :--- | :--- |
| `Authorization` | string | Ya | `Bearer <token>` | Token dengan scope `spk` |
| `Content-Type` | string | Ya | `application/json` | Format request body |
| `X-Transaction-Id` | string | Opsional | `TRX-SPK-001` | ID Transaksi untuk Idempotency Guard |
| `X-Validate-Total` | string | Opsional | `true` | Validasi kecocokan totalPrice dengan jumlah rincian item |

### Request Body

```json
{
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
  "invoiceNumber": "INV-BKL-00001",
  "invoiceDate": "2026-09-17",
  "invoiceAmount": 1850000,
  "memo": "Perbaikan berkala kendaraan",
  "taxInvoiceNumber": "314650102340592",
  "taxInvoiceDate": "2026-09-17",
  "businessArea": "1101",
  "details": [
    {"jenis": "Jasa", "description": "Jasa Perbaikan AC", "qty": 1, "price": 150000},
    {"jenis": "Parts", "description": "Filter AC & Freon", "qty": 1, "price": 1700000}
  ]
}
```

---

## 6. Service Request (Paralel Fan-Out & Inquiry)

Mengelola pembuatan tiket Service Request perbaikan kendaraan dengan replikasi otomatis ke dua sistem tujuan sekaligus: ATLAS Service dan ASSA External Services. Dilengkapi background retry worker hingga 10x dan pencatatan audit log ke MariaDB.

- **Method**: `POST` (Create / Fan-Out), `GET` (Inquiry & Pagination)
- **Path**:
  - Internal / Partner: `/api/service-requests` (Scope: `service_requests`)
  - Barantum Public Gateway: `/api/vendor/public/service-requests` (Auth via header `X-API-Key`)

---

## 7. Payments Service (XML → FTP Interface) — Baru Dimuat (Merged)

Menerima dokumen transaksi akuntansi pembayaran hutang / due list pembayaran (JSON), memvalidasi kelayakan aturan bisnis SAP akuntansi, membentuk dokumen XML resmi `<PaymentAccountingDocument>`, dan mengunggahnya ke server FTP inbound SAP pada direktori remote `/payments`.

- **Method**: `POST`
- **Path**: `/api/payments`
- **Auth**: Wajib Bearer Token dengan scope `payments`

### Headers

| Header | Tipe | Wajib | Contoh Nilai | Deskripsi |
| :--- | :--- | :--- | :--- | :--- |
| `Authorization` | string | Ya | `Bearer <token>` | Token dengan scope `payments` (mis. Token QA) |
| `Content-Type` | string | Ya | `application/json` | Format request body |
| `X-Transaction-Id` | string | Opsional | `TRX-PAYMENT-20260908-0001` | ID Transaksi untuk Idempotency Guard |

### Request Body

```json
{
  "companyCodes": "1000/2000/6000/7000",
  "accountingDocumentNumber": "9300051904",
  "documentDate": "08.09.2026",
  "postingDate": "08.09.2026",
  "businessArea": "1100",
  "currency": "IDR",
  "glAccount": "1114000000",
  "text": "PBY BENGKEL REFF 3400082380 DLL",
  "assignment": "PT PRABU PENDAWA M"
}
```

### Konvensi Nama File FTP

File XML dibentuk secara deterministik sesuai standar penamaan:
`PAYMENTS_<accountingDocumentNumber>_<primaryCompanyCode>_<transactionId>.xml`
Contoh: `PAYMENTS_9300051904_1000_TRX-PAYMENT-DUE-LIST-20260908-0001.xml`

### Response Sukses (HTTP 201 Created)

```json
{
  "success": true,
  "message": "Payload accepted and delivered",
  "transactionId": "TRX-PAYMENT-DUE-LIST-20260908-0001",
  "fileName": "PAYMENTS_9300051904_1000_TRX-PAYMENT-DUE-LIST-20260908-0001.xml"
}
```

### Response Idempotency Replay (HTTP 200 OK)

Jika transaksi dengan `X-Transaction-Id` yang sama dikirim ulang dan berstatus sukses, middleware mengembalikan replay `200 OK` tanpa mengunggah ulang file ke FTP.


