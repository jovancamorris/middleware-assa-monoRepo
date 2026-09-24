# WSO2 MI Monorepo — OpenAPI 3.0 Specifications

Katalog spesifikasi OpenAPI 3.0.3 resmi untuk seluruh microservice pada repository `wso2-mi-monorepo`.
Direktori dan struktur file ini disusun secara presisi mengikuti panduan arsitektur [`API_DEVELOPMENT_GUIDE.md`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo/docs/API_DEVELOPMENT_GUIDE.md).

---

## 1. Daftar Berkas Spesifikasi per Service

Setiap service memiliki file spesifikasinya masing-masing karena arsitektur microservice WSO2 MI memiliki port deployment dan konteks domain independen:

| Service | Port Lokal | File Spesifikasi | HTTP Method | Path Utama | Scope Token |
|---|---:|---|---|---|---|
| **Branch Service** | `8290` | [`branch-service.yaml`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo/docs/openapi/branch-service.yaml) | `GET` | `/api/branches/getByCreateDate` | `branches` |
| **Customer Service** | `8291` | [`customer-service.yaml`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo/docs/openapi/customer-service.yaml) | `GET` | `/api/customers/getByCreateDate` | `customers` |
| **Vehicle Service** | `8292` | [`vehicle-service.yaml`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo/docs/openapi/vehicle-service.yaml) | `GET` | `/api/vehicles/getByLicensePlate`<br>`/api/vehicles/vehicleatlas` | `vehicles` |
| **Vendor Service** | `8293` | [`vendor-service.yaml`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo/docs/openapi/vendor-service.yaml) | `POST` | `/api/vendors/create` | `vendors` |
| **SPK Service** | `8294` | [`spk-service.yaml`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo/docs/openapi/spk-service.yaml) | `POST` | `/api/spk/duelist` | `spk` |
| **Service Request** | `8295` | [`service-request-service.yaml`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo/docs/openapi/service-request-service.yaml) | `POST`<br>`GET/POST` | `/api/service-requests`<br>`/api/worker/retry` | `service_requests`<br>*(Operasional)* |

> Setiap file juga mendokumentasikan probe liveness `GET /health/<service>` dan readiness `GET /readiness/<service>` tanpa proteksi token (`security: []`).

---

## 2. Prinsip "Single Source of Truth" & Keamanan Data

Sesuai aturan Bab 1 & 2 pada `API_DEVELOPMENT_GUIDE.md`:
1. **Tidak Ada Secret di Dalam Spesifikasi**:
   Tidak ada password FTP, token asli, API key, atau URL koneksi database yang ditulis di file OpenAPI. Otentikasi menggunakan skema deklaratif `bearerAuth`.
2. **Runtime Verification**:
   Seluruh parameter query, header idempotency (`X-Transaction-Id`, `X-Idempotency-Key`, `X-Idempotent-Replay`), header kalkulasi total (`X-Validate-Total`), serta skema payload JSON telah diverifikasi langsung terhadap runtime source code Synapse XML di `integrations/<service>/src/main/wso2mi/` dan `shared/`.

---

## 3. Cara Membaca & Menguji Spesifikasi

### Opsi 1 — Menggunakan Ekstensi VSCode
- Pasang ekstensi **Swagger Viewer** atau **OpenAPI (Swagger) Editor**.
- Buka salah satu file `.yaml` di folder ini, lalu tekan **`Shift + Alt + P`** untuk melihat preview visual.

### Opsi 2 — Import ke Postman
1. Buka aplikasi **Postman**.
2. Klik **Import** -> pilih salah satu file `.yaml` di folder ini.
3. Postman akan mengonversi kontrak OpenAPI menjadi kumpulan request testing secara otomatis.

### Opsi 3 — Menjalankan Linter / Validator (CI Pipeline)
Sesuai Bab 12 `API_DEVELOPMENT_GUIDE.md`:
```bash
npx @redocly/cli@1.34.5 lint docs/openapi/branch-service.yaml
```
