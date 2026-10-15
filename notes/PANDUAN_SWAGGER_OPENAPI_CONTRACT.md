# Panduan Swagger / OpenAPI 3.0: Single Source of Truth Contract API
## WSO2 MI Monorepo — ASSA Middleware Gateway

Dokumen ini adalah panduan lengkap mengenai implementasi **OpenAPI Specification (OAS 3.0) / Swagger** untuk seluruh endpoint API di lingkungan **ASSA Middleware (WSO2 Micro Integrator)**.

Spesifikasi ini dirancang untuk menjawab arahan arsitektur dari **Pak Nobby**:
> *"Sebenarnya Swagger/OpenAPI menjadi single source of truth untuk contract API, bukan dokumentasi yang dibuat setelah coding selesai 😁"*

---

## 1. Lokasi File Kontrak OpenAPI Resmi

Seluruh berkas spesifikasi OpenAPI telah disiapkan secara modular per-service di folder resmi [`wso2-mi-monorepo/docs/openapi/`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo/docs/openapi/) sesuai standar [`API_DEVELOPMENT_GUIDE.md`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo/docs/API_DEVELOPMENT_GUIDE.md):

| Berkas | Service | Port | Tautan Akses |
|---|---|:---:|---|
| **`branch-service.yaml`** | Branch Service | `8290` | [`branch-service.yaml`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo/docs/openapi/branch-service.yaml) |
| **`customer-service.yaml`** | Customer Service | `8291` | [`customer-service.yaml`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo/docs/openapi/customer-service.yaml) |
| **`vehicle-service.yaml`** | Vehicle Service | `8292` | [`vehicle-service.yaml`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo/docs/openapi/vehicle-service.yaml) |
| **`vendor-service.yaml`** | Vendor Service | `8293` | [`vendor-service.yaml`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo/docs/openapi/vendor-service.yaml) |
| **`spk-service.yaml`** | SPK Service | `8294` | [`spk-service.yaml`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo/docs/openapi/spk-service.yaml) |
| **`service-request-service.yaml`** | Service Request & Worker | `8295` | [`service-request-service.yaml`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo/docs/openapi/service-request-service.yaml) |
| **`README.md`** | Index & Panduan Linter | - | [`README.md`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo/docs/openapi/README.md) |

---

## 2. Mengapa OpenAPI Menjadi "Single Source of Truth"?

Dalam rekayasa perangkat lunak modern (khususnya arsitektur microservices dan middleware integrasi perbankan/logistik seperti ASSA), terdapat perbedaan mendasar antara **"Dokumentasi Manual Pasca-Coding"** versus **"Contract-First / Single Source of Truth"**:

```
                              ┌──────────────────────────────────────────┐
                              │           KONTRAK RESMI API              │
                              │        OpenAPI Spec 3.0 (YAML)           │
                              │       "Single Source of Truth"           │
                              └────────────────────┬─────────────────────┘
                                                   │
         ┌─────────────────────────┬───────────────┴──────────────┬─────────────────────────┐
         ▼                         ▼                              ▼                         ▼
┌──────────────────┐     ┌──────────────────┐           ┌──────────────────┐     ┌──────────────────┐
│  Developer WSO2  │     │  Frontend ATLAS  │           │   QA Automation  │     │  Mitra & Vendor  │
│  (Implementasi)  │     │  (Integrasi UI)  │           │   (Postman/Test) │     │  (API Consumer)  │
└──────────────────┘     └──────────────────┘           └──────────────────┘     └──────────────────┘
```

1. **Satu Rujukan Resmi (*No Ambiguity*)**:
   Tidak ada lagi perdebatan field antara tim WSO2 vs tim frontend ATLAS/Omnichannel. Nama field, tipe data (contoh: 17 field Vendor Create, struktur detail SPK), parameter mandatory vs opsional, serta enum terdefinisi mutlak di file kontrak ini.
2. **Kesesuaian Kode Status HTTP**:
   Menetapkan kesepakatan status respon secara transparan:
   - `200 OK`: Transaksi sukses / Replay idempotency.
   - `201 Created`: Data baru berhasil dibuat dan dikirim ke server downstream/FTP.
   - `400 Bad Request`: Parameter kurang atau validasi total harga mismatch.
   - `401 Unauthorized`: Header Authorization tidak ada atau token tidak terdaftar.
   - `403 Forbidden`: Token valid namun melanggar batasan hak akses (*Scope Guard*).
3. **Otomasi Lanjutan**:
   File `openapi.yaml` ini dapat digunakan oleh tim frontend untuk men-generate TypeScript types/client SDK secara otomatis, serta oleh tim QA untuk automated contract testing di CI/CD.

---

## 3. Cakupan Endpoint yang Terdefinisi (15 Endpoint & 8 Tags)

Spesifikasi OpenAPI yang telah dibuat mencakup seluruh modul microservice di server dev ASSA:

### 3.1. Health & Readiness Probes
- `GET /health/branch`: Cek modul Branch Service.
- `GET /health/ready`: Cek kesiapan runtime WSO2 MI menerima traffic.
- `GET /health/customer`: Cek modul Customer Service.
- `GET /health/vehicle`: Cek modul Vehicle Service.
- `GET /health/vendor`: Cek modul Vendor Service & koneksi MariaDB/FTP.
- `GET /health/spk`: Cek modul SPK Duelist.
- `GET /health/service-request`: Cek modul Service Request & Worker.

### 3.2. Branch Service (Port 8290 via Nginx 6031)
- `GET /api/branches/getByCreateDate`: Mengambil data kantor cabang dari SAP Core dengan parameter `companyCode`, `dateStart`, `dateEnd`, `page`, dan `perPage`. Memerlukan scope `branches`.

### 3.3. Customer Service (Port 8291 via Nginx 6031)
- `GET /api/customers/getByCreateDate`: Mengambil data master customer dari SAP Core dengan filter rentang tanggal. Memerlukan scope `customers`.

### 3.4. Vehicle Service (Port 8292 via Nginx 6031)
- `GET /api/vehicles/getByLicensePlate`: Pencarian kendaraan berdasarkan nomor polisi (`plate_no`). Memerlukan scope `vehicles`.
- `GET /api/vehicles/vehicleatlas`: Endpoint integrasi ATLAS FMS dengan filter nomor plat, equipment number, status unit, dan cabang.

### 3.5. Vendor Service (Port 8293 via Nginx 6031)
- `POST /api/vendors/create`: Registrasi master vendor V2 (17 field lengkap) yang dikonversi ke XML Key2=VMD dan diunggah ke FTP SAP `devqaxmlpool.assa.id:/vmd`.
  - Dilengkapi spesifikasi header **`X-Transaction-Id`** untuk proteksi **Idempotency Guard** (menghindari duplikasi pengiriman ke FTP).
  - Memerlukan scope `vendors`.

### 3.6. SPK Service (Port 8294 via Nginx 6031)
- `POST /api/spk/duelist`: Pembuatan dokumen SPK Duelist ke folder FTP `/spk`.
  - Dilengkapi spesifikasi header **`X-Validate-Total`**: Memvalidasi kalkulasi konsistensi `totalPrice` dengan rincian `details` (Jasa, Parts, Sublet).
  - Memerlukan scope `spk`.

### 3.7. Service Request Service (Port 8295 via Nginx 6031)
- `POST /api/service-requests`: Penerimaan tiket perawatan kendaraan dari kanal Omnichannel dan eksekusi **Fan-out Paralel** ke External Services dan ATLAS.
  - Memerlukan scope `service_requests`.

### 3.8. Background Retry Worker (Port 8295 via Nginx 6031)
- `GET /api/worker/retry`: Pemicu manual pemrosesan ulang transaksi yang tertunda (*PENDING/FAILED*) pada tabel retry MariaDB.

---

## 4. Cara Menggunakan Spesifikasi OpenAPI

### Opsi A — Membuka via Ekstensi VSCode
Jika Anda menggunakan VSCode, Anda dapat memasang ekstensi resmi:
- **Swagger Viewer** (oleh Arjun G) atau **OpenAPI (Swagger) Editor** (oleh 42Crunch).
- Buka salah satu file spesifikasi di [`wso2-mi-monorepo/docs/openapi/`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo/docs/openapi/) (misalnya `vendor-service.yaml`), lalu tekan **`Shift + Alt + P`** untuk melihat preview grafis Swagger secara realtime di panel samping.

### Opsi B — Membuka via Swagger Editor Online
1. Buka [editor.swagger.io](https://editor.swagger.io) di browser.
2. Salin isi salah satu file spesifikasi (misal `spk-service.yaml` atau `branch-service.yaml`) dan tempelkan ke editor.
3. Anda dapat langsung melihat visualisasi antarmuka Swagger resmi.

### Opsi C — Menjalankan Linter / Validator Otomatis (CI/CD Pipeline)
Sesuai Bab 12 `API_DEVELOPMENT_GUIDE.md`, jalankan linter untuk memastikan kepatuhan standar OpenAPI 3.0.3:
```bash
npx @redocly/cli@1.34.5 lint docs/openapi/branch-service.yaml
```

---

## 5. Hubungan Swagger dengan Postman Collection yang Sudah Ada

| Aspek | OpenAPI Specifications (`*.yaml`) | Postman Collection (`.json`) |
|---|---|---|
| **Fungsi Utama** | **Kontrak Resmi & Desain API** (*Contract & Schema Definition*). | **Tool Pengujian & Eksekusi** (*Manual & Automated Test Runner*). |
| **Status Hukum** | **Single Source of Truth** (kesepakatan antar tim). | Artefak pengujian turunan (*Implementation testing*). |
| **Lokasi Resmi** | [`wso2-mi-monorepo/docs/openapi/`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo/docs/openapi/) | `notes/` |
| **Interoperabilitas** | Dapat di-import ke Postman, Stoplight, SwaggerHub, generator SDK, mock server. | Terikat pada ekosistem Postman/Newman. |

> [!TIP]
> File-file spesifikasi di [`wso2-mi-monorepo/docs/openapi/`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo/docs/openapi/) dapat langsung di-import ke Postman melalui menu **Import** -> pilih file `.yaml` yang diinginkan. Postman akan otomatis membuatkan koleksi baru yang 100% selaras dengan kontrak OpenAPI tersebut!
