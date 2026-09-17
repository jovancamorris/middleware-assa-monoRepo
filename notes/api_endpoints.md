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

### Contoh Request URL

```text
https://devsapcoreapi.assa.id/api/Branches/GetByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11
```

### cURL

```bash
curl --location 'https://devsapcoreapi.assa.id/api/Branches/GetByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11'
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
| `companyCode` | string / int | Ya | `1000` | Kode perusahaan |
| `dateStart` | string (YYYY-MM-DD) | Ya | `2020-01-01` | Tanggal awal pencarian |
| `dateEnd` | string (YYYY-MM-DD) | Ya | `2026-09-11` | Tanggal akhir pencarian |

### Contoh Request URL

```text
https://sapcoreapi.assa.id/api/Customer/GetByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11
```

### cURL

```bash
curl --location 'https://sapcoreapi.assa.id/api/Customer/GetByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11'
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
| `plate_no` | string | Opsional | `DD-8112` / `B-9065-UCU` | Nomor plat (pencarian sebagian / LIKE) |
| `equipment_no` | string | Opsional | `10027282` | Nomor equipment (exact match, bisa multi dipisah koma) |
| `branch_code` | string | Opsional | `1411` | Filter per cabang |
| `status_id` | int | Opsional | `11` | Filter status unit |
| `color` | string | Opsional | `putih` | Filter warna unit |
| `limit` | int | Opsional | `50` | Batas jumlah data (default: 20) |
| `offset` | int | Opsional | `0` | Offset pagination (default: 0) |

*(Catatan kompatibilitas: Middleware ASSA juga tetap menerima parameter legacy `licensePlate` dan otomatis memetakannya ke `plate_no`).*

### Contoh Request

#### cURL (Cari Plat Nomor):
```bash
curl --location '{BASE_URL}/api/vehicleatlas?plate_no=DD-8112&limit=50' \
     --header 'Key: <API_KEY>'
```

#### cURL (Cari Equipment No):
```bash
curl --location '{BASE_URL}/api/vehicleatlas?equipment_no=10027282' \
     --header 'Key: <API_KEY>'
```

### Format Response Sukses (HTTP 200)

```json
{
    "message": "success",
    "code": 200,
    "offset": 0,
    "limit": 20,
    "count": 2,
    "total": 39018,
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

