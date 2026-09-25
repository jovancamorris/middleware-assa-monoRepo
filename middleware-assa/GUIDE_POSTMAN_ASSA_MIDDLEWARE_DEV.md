# Panduan Postman ASSA Middleware

Panduan ini menjelaskan cara menggunakan koleksi Postman untuk menguji kontrak HTTP ASSA Middleware pada lingkungan development. 

Koleksi yang dirujuk adalah:

```text
ASSA Middleware Server Dev.
postman_collection.json
```

Koleksi saat ini berisi 33 request dalam 9 folder. Koleksi adalah alat smoke test, bukan pengganti spesifikasi OpenAPI. Jika koleksi, API XML, sequence, dan dokumentasi berbeda, runtime pada API XML dan sequence adalah source of truth.

> [!WARNING]
> Jangan menaruh token, password, API key, URL backend internal, atau data pribadi nyata pada dokumentasi, collection file, atau repository. Gunakan Postman Environment lokal/secret variable dan data sintetis.

## Daftar Isi

1. [Ruang Lingkup dan Source of Truth](#1-ruang-lingkup-dan-source-of-truth)
2. [Base URL dan Environment](#2-base-url-dan-environment)
3. [Authentication, Scope, dan Header](#3-authentication-scope-dan-header)
4. [Inventaris Endpoint](#4-inventaris-endpoint)
5. [Skenario Request](#5-skenario-request)
6. [Menjalankan Postman dan Newman](#6-menjalankan-postman-dan-newman)
7. [Perbedaan Koleksi Saat Ini](#7-perbedaan-koleksi-saat-ini)
8. [Troubleshooting](#8-troubleshooting)
9. [Checklist Perubahan API](#9-checklist-perubahan-api)

## 1. Ruang Lingkup dan Source of Truth

Postman digunakan untuk memverifikasi:

- liveness dan readiness setiap service;
- authentication dan scope guard;
- query parameter dan validasi request body;
- idempotency dan replay response;
- fan-out Service Request;
- worker retry operasional;
- status HTTP pada happy path dan negative path.

Urutan verifikasi ketika endpoint berubah:

1. API XML pada `integrations/<service>/src/main/wso2mi/artifacts/apis/` untuk context, method, route, dan sequence.
2. Domain sequence untuk parameter, header, payload, validation, dan response.
3. Shared sequence untuk auth, scope, correlation, idempotency, retry, dan error.
4. `wso2-mi-monorepo/test_all.ps1` untuk contoh request yang dapat dieksekusi.
5. Feature guide untuk konteks bisnis setelah behavior runtime dikonfirmasi.

## 2. Base URL dan Environment

### 2.1 Deployment

Pada server development melalui reverse proxy, gunakan satu base URL untuk semua service:

```text
http://<DEV_HOST>:<PORT_HOST>
```

Nilai `baseUrl...` tidak boleh diakhiri `/`. URL request kemudian dibentuk, misalnya:

```text
{{baseUrlBranch}}/api/branches/getByCreateDate
```

### 2.2 Variable yang diperlukan

Buat Postman Environment lokal dengan variable berikut. Isi token dari secret manager atau administrator environment, bukan dari dokumen ini.

| Variable | Kegunaan |
|---|---|
| `baseUrlBranch` | Base URL Branch |
| `baseUrlCustomer` | Base URL Customer |
| `baseUrlVehicle` | Base URL Vehicle |
| `baseUrlVendor` | Base URL Vendor |
| `baseUrlSPK` | Base URL SPK |
| `baseUrlSR` | Base URL Service Request dan Worker |
| `token_app_a` | Token dengan scope Branch dan Customer |
| `token_app_b` | Token dengan scope Vehicle |
| `token_qa` | Token dengan scope yang disetujui untuk pengujian QA |
| `token_omnichannel` | Token dengan scope Service Request |
| `companyCode` | Contoh kode perusahaan sintetis |
| `vendor_trx_id` | Transaction ID Vendor, diisi script create |
| `spk_trx_id` | Transaction ID SPK, diisi script create |
| `sr_trx_id` | Transaction ID Service Request, diisi script create |

Nama variable pada tabel harus sama dengan nama yang dirujuk collection. Environment variable memiliki prioritas lebih tinggi daripada collection variable di Postman.

### 2.3 Keamanan collection

Export collection harus diperiksa sebelum commit atau dibagikan:

- hapus nilai token dari collection variable;
- ganti email, nomor telepon, alamat, nomor rekening, NPWP, nomor polisi, dan nama orang dengan data sintetis;
- gunakan `example.invalid` untuk domain email contoh;
- jangan masukkan credential FTP, password database, atau URL backend;
- gunakan Postman secret/environment variable untuk nilai sensitif.

## 3. Authentication, Scope, dan Header

### 3.1 Bearer token dan scope

Business API menggunakan header berikut:

```http
Authorization: Bearer <TOKEN_ENVIRONMENT>
```

| Scope | Endpoint |
|---|---|
| `branches` | Branch |
| `customers` | Customer |
| `vehicles` | Vehicle |
| `vendors` | Vendor |
| `spk` | SPK Duelist |
| `service_requests` | Service Request |

Health dan readiness tidak menggunakan token. Worker adalah endpoint operasional; security requirement-nya harus dipastikan pada deployment sebelum endpoint dipublikasikan atau dipanggil dari CI.

### 3.2 Header standar

| Header | Arah | Kegunaan |
|---|---|---|
| `Authorization` | Request | Bearer token untuk business API |
| `X-Correlation-Id` | Request/response | Tracing; middleware membuat nilai jika kosong |
| `X-Transaction-Id` | Request/response | Kunci transaction dan idempotency |
| `X-Idempotency-Key` | Request | Alias yang didukung untuk idempotency |
| `X-Idempotent-Replay` | Response | `true` jika response berasal dari replay cache |
| `X-Validate-Total` | Request SPK | Mengaktifkan validasi `qty * price` terhadap `totalPrice` |
| `X-Forwarded-For` | Request Vendor/SPK | Metadata asal request bila dibutuhkan deployment |
| `X-Retry-Interval-Seconds` | Request operasional/internal | Override interval retry jika sequence mendukung |

Untuk request create, gunakan `X-Transaction-Id` yang unik. Jika header kosong, sequence dapat membuat ID otomatis, tetapi pengujian replay harus memakai ID yang sama secara eksplisit.

### 3.3 Error response

Format error umum runtime adalah:

```json
{
  "error": true,
  "message": "Forbidden",
  "detail": "Application does not have the required scope."
}
```

Nilai `detail` bergantung pada error. Header `X-Correlation-Id` digunakan untuk tracing. Jangan menganggap field internal seperti `transactionId`, payload backend, atau detail credential selalu muncul di response; verifikasi terhadap `ErrorResponseSeq.xml`.

Status yang perlu diuji:

| Status | Arti |
|---:|---|
| `200` | Success atau idempotency replay |
| `201` | Request create berhasil diterima |
| `207` | Sebagian target fan-out berhasil |
| `400` | Parameter, payload, atau validasi gagal |
| `401` | Authorization tidak ada, format salah, atau token tidak dikenal |
| `403` | Token valid tetapi scope tidak cukup |
| `409` | Transaction dengan idempotency key masih diproses |
| `502` | Backend gagal setelah retry atau seluruh fan-out gagal |
| `504` | Timeout jika dikembalikan runtime |

## 4. Inventaris Endpoint

Path di bawah ini adalah kontrak client. Jangan membuat path berdasarkan nama sequence internal.

| Service | Port lokal | Method | Path | Auth/scope |
|---|---:|---|---|---|
| Branch | 8290 | GET | `/api/branches/getByCreateDate` | Bearer, `branches` |
| Customer | 8291 | GET | `/api/customers/getByCreateDate` | Bearer, `customers` |
| Vehicle | 8292 | GET | `/api/vehicles/getByLicensePlate` | Bearer, `vehicles` |
| Vehicle alias | 8292 | GET | `/api/vehicles/vehicleatlas` | Bearer, `vehicles` |
| Vendor | 8293 | POST | `/api/vendors/create` | Bearer, `vendors` |
| SPK | 8294 | POST | `/api/spk/duelist` | Bearer, `spk` |
| Service Request | 8295 | POST | `/api/service-requests` | Bearer, `service_requests` |
| Worker | 8295 | GET, POST | `/api/worker/retry` | Operasional; verifikasi deployment |
| Setiap service | service-specific | GET | `/health/<service>` | Tanpa token |
| Setiap service | service-specific | GET | `/readiness/<service>` | Tanpa token |

Nilai `<service>` untuk probe adalah `branch`, `customer`, `vehicle`, `vendor`, `spk`, dan `service-request`. Validasi trailing slash readiness tetap harus dilakukan terhadap API XML deployment karena resource XML menggunakan `/`.

`/api/vehicles/vehicleatlas` memakai sequence yang sama dengan pencarian kendaraan dan diperlakukan sebagai alias/legacy sampai keputusan kompatibilitas ditetapkan.

## 5. Skenario Request

Bagian ini menjelaskan request yang harus tersedia pada collection. Contoh menggunakan placeholder dan data sintetis.

### 5.1 Health dan readiness

Jalankan liveness terlebih dahulu, lalu readiness untuk setiap service:

```http
GET {{baseUrlBranch}}/health/branch
GET {{baseUrlBranch}}/readiness/branch
GET {{baseUrlCustomer}}/health/customer
GET {{baseUrlCustomer}}/readiness/customer
GET {{baseUrlVehicle}}/health/vehicle
GET {{baseUrlVehicle}}/readiness/vehicle
GET {{baseUrlVendor}}/health/vendor
GET {{baseUrlVendor}}/readiness/vendor
GET {{baseUrlSPK}}/health/spk
GET {{baseUrlSPK}}/readiness/spk
GET {{baseUrlSR}}/health/service-request
GET {{baseUrlSR}}/readiness/service-request
```

Ekspektasi umum adalah `200` dan JSON dengan `status: "UP"`. Readiness dapat memuat status backend tambahan.

Contoh cURL:

```bash
curl --fail "$BASE_URL/health/branch"
curl --fail "$BASE_URL/readiness/branch"
```

### 5.2 Branch dan Customer

Request GET menggunakan query berikut bila didukung sequence:

| Query | Keterangan |
|---|---|
| `companyCode` | Kode perusahaan |
| `dateStart` | Tanggal awal, format `YYYY-MM-DD` |
| `dateEnd` | Tanggal akhir, format `YYYY-MM-DD` |
| `page` | Nomor halaman jika pagination diproses runtime |
| `perPage` | Ukuran halaman jika pagination diproses runtime |

Branch:

```http
GET {{baseUrlBranch}}/api/branches/getByCreateDate?companyCode={{companyCode}}&dateStart=2020-01-01&dateEnd=2026-09-11&page=1&perPage=10
Authorization: Bearer {{token_app_a}}
X-Correlation-Id: corr-branch-example
```

Customer memakai pola yang sama dengan `{{baseUrlCustomer}}` dan scope `customers`:

```http
GET {{baseUrlCustomer}}/api/customers/getByCreateDate?companyCode={{companyCode}}&dateStart=2020-01-01&dateEnd=2026-09-11&page=1&perPage=10
Authorization: Bearer {{token_app_a}}
X-Correlation-Id: corr-customer-example
```

Ekspektasi happy path adalah `200`. Bentuk wrapper response seperti `count`, `data`, atau `pagination` harus diambil dari response runtime, bukan diasumsikan dari collection.

### 5.3 Vehicle

Path utama:

```http
GET {{baseUrlVehicle}}/api/vehicles/getByLicensePlate?plate_no=<PLATE_NUMBER>
Authorization: Bearer {{token_app_b}}
```

Parameter pencarian yang perlu diverifikasi terhadap sequence adalah:

- `plate_no` atau alias legacy `licensePlate`;
- `equipment_no`;
- `branch_code`;
- `limit`, `offset`, `status_id`, dan `color` bila diteruskan ke backend.

Request tanpa parameter pencarian harus diuji dan diharapkan menghasilkan `400`:

```bash
curl -i "$BASE_URL_VEHICLE/api/vehicles/getByLicensePlate?companyCode=$COMPANY_CODE" \
  -H "Authorization: Bearer $AUTH_APP_B_TOKEN"
```

Alias legacy:

```http
GET {{baseUrlVehicle}}/api/vehicles/vehicleatlas?plate_no=<PLATE_NUMBER>
Authorization: Bearer {{token_qa}}
```

Ekspektasi happy path adalah `200`; dokumentasikan perbedaan alias hanya setelah diverifikasi dari runtime.

### 5.4 Vendor

`POST /api/vendors/create` menerima JSON client. Detail internal seperti transformasi XML dan target transport bukan bagian dari request contract.

Header minimum:

```http
Authorization: Bearer {{token_qa}}
Content-Type: application/json
X-Transaction-Id: {{vendor_trx_id}}
```

Field yang perlu dipetakan dan divalidasi terhadap sequence meliputi:

```json
{
  "companyTitle": "PT",
  "companyName": "Example Company",
  "otv": "No",
  "paymentCycle": "Monthly",
  "accountNumber": "0000000000",
  "accountName": "Example Account",
  "bankName": "Example Bank",
  "hoEmail": "vendor@example.invalid",
  "hoPhone": "0000000000",
  "hoAddress": "Synthetic Address",
  "contactName": "Example Contact",
  "contactPhone": "0000000000",
  "npwp": "0000000000000000",
  "accountGroup": "V010",
  "top": "T014",
  "glAccount": "0000000000",
  "documentNumber": "VENDOR-EXAMPLE-001"
}
```

Skenario minimum:

| Skenario | Ekspektasi |
|---|---:|
| Payload valid dengan transaction ID baru | `201` |
| Payload sama dengan transaction ID yang sudah sukses | `200`, replay |
| Field wajib hilang atau enum invalid | `400` |
| Tanpa token | `401` |
| Token tanpa scope `vendors` | `403` |

Jalankan request create sebelum request replay agar `vendor_trx_id` tersedia dan payload replay identik.

### 5.5 SPK Duelist

Header yang relevan:

```http
Authorization: Bearer {{token_qa}}
Content-Type: application/json
X-Transaction-Id: {{spk_trx_id}}
X-Validate-Total: true
X-Forwarded-For: <SYNTHETIC_CLIENT_IP>
```

Body minimum dan detail minimum:

```json
{
  "noSpk": "SPK-EXAMPLE-001",
  "type": "Maintenance",
  "noPolisi": "B-0000-XXX",
  "category": "Maintenance",
  "subCategory": "Adhoc",
  "vendorReferensi": "VENDOR-001",
  "totalPrice": 1000,
  "createdAt": "2026-09-17 14:46:11",
  "createdBy": "synthetic-user",
  "details": [
    {
      "jenis": "Jasa",
      "description": "Example service",
      "qty": 1,
      "price": 1000
    }
  ]
}
```

Aturan yang harus diuji:

- `details` minimal satu item;
- `description` wajib;
- `qty > 0` dan `price > 0`;
- `jenis` adalah `Jasa` atau `Parts`;
- dengan `X-Validate-Total: true`, jumlah `qty * price` harus sama dengan `totalPrice`.

Skenario minimum:

| Skenario | Ekspektasi |
|---|---:|
| Payload valid dengan transaction ID baru | `201` |
| Request identik dengan transaction ID yang sudah sukses | `200`, replay |
| `noSpk` hilang atau detail tidak valid | `400` |
| Total detail berbeda dari `totalPrice` saat validasi aktif | `400` |
| Tanpa token | `401` |
| Token tanpa scope `spk` | `403` |

### 5.6 Service Request

`POST /api/service-requests` melakukan fan-out ke target integrasi. Consumer hanya mengirim JSON contract; target internal tidak ditulis pada collection atau dokumentasi publik.

Field minimum:

```json
{
  "app_id": "synthetic-app",
  "reff_number": "REF-EXAMPLE-001",
  "branch_code": "BR-001",
  "created_datetime": "17-09-2026",
  "created_by": "synthetic-user",
  "ticket_no": "TICKET-EXAMPLE-001"
}
```

Field tambahan dapat mencakup equipment/license plate, customer, contact person, jadwal, lokasi, incident, dan task. Gunakan format tanggal yang benar-benar diterima sequence; format pada collection bukan bukti bahwa format tersebut sudah formal.

Header:

```http
Authorization: Bearer {{token_omnichannel}}
Content-Type: application/json
X-Transaction-Id: {{sr_trx_id}}
```

Skenario minimum:

| Skenario | Ekspektasi |
|---|---:|
| Semua target fan-out berhasil | `200` |
| Sebagian target fan-out berhasil | `207` jika dikembalikan runtime |
| Semua target gagal setelah retry | `502` |
| Field minimum hilang | `400` |
| Request identik dengan transaction ID yang sudah sukses | `200`, replay |
| Tanpa token | `401` |
| Token tanpa scope `service_requests` | `403` |

### 5.7 Worker retry

Worker mendukung method berikut:

```http
GET  {{baseUrlSR}}/api/worker/retry
POST {{baseUrlSR}}/api/worker/retry
```

Response sukses berisi status worker dan diharapkan `200`. Endpoint ini bersifat operasional, bukan business API. Pastikan security deployment sudah ditetapkan sebelum menambahkan request worker ke smoke test publik.

Contoh cURL:

```bash
curl -i "$BASE_URL_SR/api/worker/retry"
curl -i -X POST "$BASE_URL_SR/api/worker/retry"
```

## 6. Menjalankan Postman dan Newman

### 6.1 Import dan konfigurasi

1. Buka Postman dan pilih **Import**.
2. Import `ASSA Middleware Server Dev.postman_collection.json`.
3. Buat atau pilih Environment lokal.
4. Isi semua `baseUrl...` dan token sesuai environment.
5. Pastikan tidak ada secret pada collection variable atau file yang akan di-commit.
6. Jalankan health dan readiness sebelum business request.

### 6.2 Urutan Collection Runner

Untuk rangkaian idempotency, jalankan berurutan:

1. Vendor create valid, lalu Vendor replay.
2. SPK create valid, lalu SPK replay.
3. Service Request valid, lalu Service Request replay.

Request replay harus memakai transaction ID dan body yang sama. Skenario negative dapat dijalankan terpisah agar tidak mengubah data uji create.

### 6.3 Newman

Gunakan environment file lokal yang tidak disimpan ke repository:

```bash
npm install -g newman
newman run "ASSA Middleware Server Dev.postman_collection.json" \
  --environment postman-dev.local.json \
  --reporters cli,junit \
  --reporter-junit-export report.xml
```

Sebelum CI dijalankan, pastikan environment file menyediakan token melalui secret store CI dan base URL yang benar. Jangan menaruh token pada command line, log pipeline, atau report artifact.

### 6.4 cURL smoke test

Contoh aman dengan token dari environment shell:

```bash
curl -i "$BASE_URL_BRANCH/api/branches/getByCreateDate?companyCode=<COMPANY_CODE>&dateStart=2020-01-01&dateEnd=2026-09-11&page=1&perPage=10" \
  -H "Authorization: Bearer $AUTH_APP_A_TOKEN" \
  -H "X-Correlation-Id: corr-local-001"
```

Untuk create request, buat transaction ID baru pada setiap percobaan dan simpan ID tersebut jika ingin menguji replay.

## 7. Perbedaan Koleksi Saat Ini

Koleksi yang ada perlu diselaraskan sebelum dianggap sebagai representasi penuh kontrak API:

| Temuan | Dampak | Tindakan |
|---|---|---|
| Request readiness Branch menggunakan `/health/ready` | Tidak sesuai inventaris endpoint `/readiness/branch` | Ubah URL dan test script setelah trailing slash dikonfirmasi pada runtime |
| Folder health hanya berisi satu request readiness dan tidak mencakup semua readiness service | Smoke test tidak mencakup 12 probe | Tambahkan readiness untuk `branch`, `customer`, `vehicle`, `vendor`, `spk`, dan `service-request` |
| Folder worker hanya memiliki `GET` | `POST /api/worker/retry` tidak diuji | Tambahkan request POST setelah security deployment ditetapkan |
| Vehicle `/vehicleatlas` belum ditandai legacy | Consumer dapat menganggapnya path utama | Tambahkan deskripsi alias/legacy |
| Collection berisi token dan data contoh yang harus dianggap sensitif | Risiko kebocoran credential atau PII | Sanitasi collection dan pindahkan nilai ke Environment secret |
| Test script terutama memeriksa status HTTP | Schema response dapat berubah tanpa terdeteksi | Tambahkan assertion schema setelah response runtime diverifikasi |
| Skenario `207`, `409`, `502`, dan `504` belum lengkap | Failure path tidak seluruhnya diuji | Tambahkan test berdasarkan behavior runtime yang sudah disepakati |

Perbedaan di atas adalah gap dokumentasi/test, bukan alasan untuk menebak behavior baru. Setiap perubahan harus diverifikasi terhadap API XML, sequence, dan service yang berjalan.

## 8. Troubleshooting

| Gejala | Kemungkinan penyebab | Tindakan |
|---|---|---|
| `Connection refused` | Host/port salah atau service belum berjalan | Cek base URL dan status deployment |
| `404` pada readiness | Collection masih memakai path lama atau trailing slash berbeda | Gunakan `/readiness/<service>` dan verifikasi API XML |
| `401` pada request positif | Token kosong, salah environment, atau token tidak dikenal | Pastikan `Authorization` memakai token environment yang benar |
| `403` pada request positif | Token tidak memiliki scope endpoint | Gunakan token dengan scope yang sesuai |
| `400` pada replay | Transaction ID atau payload tidak sama/bernilai kosong | Jalankan create lebih dahulu dan pertahankan ID serta body |
| `409` | Transaction masih berstatus `PROCESSING` | Tunggu proses selesai atau gunakan transaction ID baru |
| `502` atau `504` | Backend gagal atau timeout setelah retry | Korelasikan `X-Correlation-Id` dengan log runtime; jangan menaruh credential/log sensitif pada issue |
| Health `200` tetapi readiness gagal | Service hidup tetapi dependency belum siap | Tunggu dependency siap dan periksa deployment health |
| Newman gagal menemukan variable | Environment belum dipilih atau nama variable salah | Cocokkan nama variable dengan Section 2.2 |

## 9. Checklist Perubahan API

### Runtime

- [ ] API XML memiliki context, method, dan `uri-template` yang benar.
- [ ] Sequence memvalidasi parameter dan request body sesuai kontrak.
- [ ] Auth dan scope sudah diuji.
- [ ] Error path, idempotency, correlation, dan retry diuji jika relevan.
- [ ] Status aktual `200`, `201`, `207`, `400`, `401`, `403`, `409`, `502`, dan `504` tidak diklaim tanpa verifikasi.

### Collection dan guide

- [ ] URL Postman sama dengan route API XML.
- [ ] `Authorization`, scope, query, header, dan request body terdokumentasi.
- [ ] Create dan replay dijalankan dengan transaction ID yang konsisten.
- [ ] Alias/legacy route diberi label.
- [ ] Health dan readiness dibedakan.
- [ ] Worker method dan security requirement sudah jelas.
- [ ] Test response menggunakan schema aktual, bukan asumsi wrapper.
- [ ] Semua contoh memakai data sintetis.
- [ ] Tidak ada token, password, API key, URL sensitif, atau PII nyata.

### Validasi repository

Jalankan perintah berikut dari direktori `wso2-mi-monorepo`. Lint OpenAPI dijalankan setelah file spesifikasi tersedia.

```powershell
mvn -B validate
npx @redocly/cli@1.34.5 lint docs/openapi/branch-service.yaml
```

Perbarui file OpenAPI service yang sesuai di `wso2-mi-monorepo/docs/openapi/` bila spesifikasi formal sudah dibuat. Perbarui guide ini dan `test_all.ps1` jika behavior consumer berubah.
