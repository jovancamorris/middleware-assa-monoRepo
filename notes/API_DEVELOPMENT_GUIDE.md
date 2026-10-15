# API Development Guide — Swagger / OpenAPI

Panduan ini menjelaskan cara membuat dan memelihara dokumentasi Swagger/OpenAPI untuk WSO2 Integrator: MI pada repository `wso2-mi-monorepo`.

> **Status saat ini:** repository belum memiliki file Swagger/OpenAPI formal (`.yaml`, `.yml`, atau `.json`). Kontrak runtime saat ini didefinisikan oleh API XML dan sequence WSO2 MI. Guide ini menetapkan cara mengubah kontrak tersebut menjadi OpenAPI secara konsisten.

## 1. Tujuan dan ruang lingkup

Swagger adalah tooling; format spesifikasi yang digunakan pada guide ini adalah **OpenAPI 3.0.3**. Dokumentasi OpenAPI harus membantu consumer API, developer middleware, serta QA/DevOps.

Dokumentasi publik hanya menjelaskan kontrak HTTP yang dipanggil client. Detail internal seperti password, token, API key, konfigurasi FTP, URL backend, dan nama database tidak boleh dimasukkan ke spesifikasi.

## 2. Source of truth

Gunakan urutan berikut ketika membuat atau memperbarui dokumentasi API:

| Prioritas | Sumber | Yang diverifikasi |
|---|---|---|
| 1 | `integrations/<service>/src/main/wso2mi/artifacts/apis/*.xml` | HTTP method, context, route, dan sequence |
| 2 | Domain sequence di folder `artifacts/sequences/` | Query parameter, body field, validasi, header, dan response |
| 3 | `shared/src/main/wso2mi/artifacts/sequences/` | Authentication, scope, idempotency, retry, error, correlation, health |
| 4 | `test_all.ps1` | Contoh request executable dan expected HTTP status |
| 5 | Dokumentasi arsitektur/feature guide | Konteks bisnis dan detail integrasi |

Jika dokumentasi berbeda dengan XML/sequence yang berjalan, tandai perbedaannya dan selaraskan implementasi atau dokumen. Jangan menyalin klaim dari feature guide ke OpenAPI sebelum diverifikasi terhadap runtime.

### Referensi repository

- `docs/SOFTWARE_ARCHITECTURE_DOCUMENT.md` — arsitektur dan alur request.
- `docs/STRUKTUR_ARSITEKTUR.md` — struktur API, sequence, dan endpoint.
- `test_all.ps1` — smoke test seluruh service.
- `shared/src/main/wso2mi/artifacts/sequences/AuthGuardSeq.xml` — Bearer token, scope, correlation ID.
- `shared/src/main/wso2mi/artifacts/sequences/ErrorResponseSeq.xml` — format error umum.
- `shared/src/main/wso2mi/artifacts/sequences/IdempotencyGuardSeq.xml` — idempotency dan replay.
- `shared/src/main/wso2mi/artifacts/sequences/SafeApiCallWithRetrySeq.xml` — panggilan backend dan retry.

## 3. Struktur file yang direkomendasikan

Gunakan satu spesifikasi per service karena setiap service memiliki port/deployment berbeda:

```text
wso2-mi-monorepo/
└── docs/
    ├── API_DEVELOPMENT_GUIDE.md
    └── openapi/
        ├── README.md
        ├── branch-service.yaml
        ├── customer-service.yaml
        ├── vehicle-service.yaml
        ├── vendor-service.yaml
        ├── spk-service.yaml
        └── service-request-service.yaml
```

Penamaan:

- File: `<service-name>.yaml`.
- `info.version`: versi kontrak API, bukan versi WSO2 MI.
- `operationId`: unik dan stabil, misalnya `getBranchByCreateDate`.
- Tag: nama domain, misalnya `Branch`, `Vehicle`, atau `Health`.
- Path ditulis tanpa trailing slash kecuali trailing slash memang bagian kontrak.

## 4. Inventaris endpoint saat ini

Port host Docker Compose dan endpoint yang terdeteksi dari API XML:

| Service | Port | Method | Path | Scope |
|---|---:|---|---|---|
| branch-service | 8290 | GET | `/api/branches/getByCreateDate` | `branches` |
| customer-service | 8291 | GET | `/api/customers/getByCreateDate` | `customers` |
| vehicle-service | 8292 | GET | `/api/vehicles/getByLicensePlate` | `vehicles` |
| vehicle-service | 8292 | GET | `/api/vehicles/vehicleatlas` | `vehicles` |
| vendor-service | 8293 | POST | `/api/vendors/create` | `vendors` |
| spk-service | 8294 | POST | `/api/spk/duelist` | `spk` |
| service-request-service | 8295 | POST | `/api/service-requests` | `service_requests` |
| service-request-service | 8295 | GET | `/api/worker/retry` | operasional |
| service-request-service | 8295 | POST | `/api/worker/retry` | operasional |
| setiap service | service-specific | GET | `/health/<service>` | tanpa token |
| setiap service | service-specific | GET | `/readiness/<service>` | tanpa token |

Nama health endpoint saat ini: `branch`, `customer`, `vehicle`, `vendor`, `spk`, dan `service-request`. Validasi final harus tetap dilakukan terhadap `HealthAPI.xml` dan `ReadinessAPI.xml` masing-masing service.

`/api/vehicles/vehicleatlas` diperlakukan sebagai alias/legacy sampai keputusan kompatibilitas ditetapkan.

## 5. Pemetaan API XML WSO2 ke OpenAPI

```xml
<api context="/api/vehicles" name="VehicleAPI">
    <resource methods="GET" uri-template="/getByLicensePlate">
        <inSequence>
            <property name="requiredScope" value="vehicles"/>
            <sequence key="AuthGuardSeq"/>
            <sequence key="VehicleGetByLicensePlateSeq"/>
        </inSequence>
        <faultSequence>
            <sequence key="ErrorResponseSeq"/>
        </faultSequence>
    </resource>
</api>
```

| WSO2 MI | OpenAPI |
|---|---|
| `api context` + `uri-template` | `paths` key |
| `resource methods` | `get`, `post`, `put`, `patch`, atau `delete` |
| `requiredScope` | `security` dengan Bearer scope |
| property dari `$url:<name>` | `parameters` dengan `in: query` |
| payload JSON yang dibaca sequence | `requestBody` |
| `faultSequence` / `ErrorResponseSeq` | response error |
| header transport | parameter/request header atau response header |
| sequence domain | behavior, schema, dan validation |

Jangan membuat path berdasarkan nama sequence. Path harus mengikuti API XML yang menerima request.

## 6. Template OpenAPI minimum

```yaml
openapi: 3.0.3
info:
  title: Branch Service API
  description: API integrasi branch melalui WSO2 Integrator: MI.
  version: 1.0.0
servers:
  - url: http://localhost:8290
    description: Local Docker Compose

tags:
  - name: Branch
  - name: Health

paths:
  /api/branches/getByCreateDate:
    get:
      tags: [Branch]
      operationId: getBranchByCreateDate
      summary: Mengambil data branch berdasarkan rentang tanggal pembuatan
      security:
        - bearerAuth: [branches]
      parameters:
        - $ref: '#/components/parameters/CorrelationId'
        - $ref: '#/components/parameters/CompanyCode'
        - $ref: '#/components/parameters/DateStart'
        - $ref: '#/components/parameters/DateEnd'
      responses:
        '200':
          description: Request berhasil
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/SuccessResponse'
        '400':
          $ref: '#/components/responses/BadRequest'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '403':
          $ref: '#/components/responses/Forbidden'
        '502':
          $ref: '#/components/responses/BadGateway'

  /health/branch:
    get:
      tags: [Health]
      operationId: getBranchHealth
      security: []
      responses:
        '200':
          description: Service hidup
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/HealthResponse'

components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
      description: Gunakan token environment; jangan menaruh token nyata.

  parameters:
    CorrelationId:
      name: X-Correlation-Id
      in: header
      required: false
      schema:
        type: string
        maxLength: 128
    CompanyCode:
      name: companyCode
      in: query
      required: false
      schema:
        type: string
        example: '1000'
    DateStart:
      name: dateStart
      in: query
      required: false
      schema:
        type: string
        format: date
        example: '2020-01-01'
    DateEnd:
      name: dateEnd
      in: query
      required: false
      schema:
        type: string
        format: date
        example: '2026-09-11'

  schemas:
    SuccessResponse:
      type: object
      additionalProperties: true
      description: Ganti dengan response aktual setelah runtime diverifikasi.
    HealthResponse:
      type: object
      required: [status, timestamp]
      properties:
        status:
          type: string
          example: UP
        timestamp:
          type: string
          format: date-time
    ErrorResponse:
      type: object
      required: [error, message]
      properties:
        error:
          type: boolean
          example: true
        message:
          type: string
          example: Unauthorized
        detail:
          type: string
        transactionId:
          type: string
          nullable: true

  responses:
    BadRequest:
      description: Request atau payload tidak valid
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/ErrorResponse'
    Unauthorized:
      description: Token tidak ada, format salah, atau tidak dikenal
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/ErrorResponse'
    Forbidden:
      description: Token valid tetapi scope tidak cukup
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/ErrorResponse'
    BadGateway:
      description: Backend gagal setelah proses retry
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/ErrorResponse'
```

`SuccessResponse` sengaja placeholder. Ganti dengan schema aktual setelah bentuk response sequence dan backend dipastikan. Jangan mengklaim wrapper `count/data/pagination` jika runtime belum benar-benar menghasilkannya.

## 7. Security dan header standar

### 7.1 Bearer token dan scope

Business API wajib menggunakan:

```http
Authorization: Bearer <TOKEN_ENVIRONMENT>
```

| Scope | API |
|---|---|
| `branches` | Branch |
| `customers` | Customer |
| `vehicles` | Vehicle |
| `vendors` | Vendor |
| `spk` | SPK Duelist |
| `service_requests` | Service Request |

Health/readiness tidak menggunakan token. Worker adalah endpoint operasional dan harus diberi security requirement sesuai keputusan keamanan deployment.

Security scheme hanya mendokumentasikan bentuk token. Token dibaca dari environment/secret lokal, bukan ditulis ke file OpenAPI.

### 7.2 Header request/response

| Header | Arah | Kegunaan |
|---|---|---|
| `Authorization` | request | Bearer token |
| `X-Correlation-Id` | request/response | tracing; dibuat middleware jika kosong |
| `X-Transaction-Id` | request/response | idempotency transaction key |
| `X-Idempotency-Key` | request | alias yang didukung sequence idempotency |
| `X-Idempotent-Replay` | response | `true` jika response berasal dari replay cache |
| `X-Validate-Total` | request SPK | validasi `qty * price` terhadap `totalPrice` |
| `X-Forwarded-For` | request Vendor/SPK | metadata asal request |
| `X-Retry-Interval-Seconds` | request internal/operasional | override interval retry jika didukung |

Jangan menaruh `x-api-key`, username FTP, password FTP, atau backend credential sebagai default value. Jika API key memang dikirim client, deklarasikan sebagai `apiKey` security scheme tanpa nilai rahasia.

## 8. Aturan dokumentasi per endpoint

Setiap operation minimal harus memiliki:

- `tags` dan `operationId` unik.
- `summary` dan `description` yang menjelaskan behavior, default, alias, serta efek samping.
- `security` yang tepat, atau `security: []` untuk health/readiness.
- Semua query/path/header parameter.
- `requestBody` untuk POST/PUT/PATCH.
- Response sukses dan seluruh error yang dapat terjadi.
- Header correlation/idempotency yang relevan.
- Contoh request/response tanpa secret atau PII nyata.

Contoh PowerShell:

```powershell
$headers = @{
  Authorization = "Bearer $env:AUTH_APP_A_TOKEN"
  "X-Correlation-Id" = "corr-local-001"
}

Invoke-RestMethod `
  -Uri "http://localhost:8290/api/branches/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11" `
  -Headers $headers `
  -Method Get
```

## 9. Panduan schema domain

### 9.1 Branch dan Customer

Dokumentasikan query berikut setelah diverifikasi pada sequence:

- `companyCode` — kode perusahaan.
- `dateStart` — tanggal awal, format `date`.
- `dateEnd` — tanggal akhir, format `date`.
- `page` dan `perPage` jika pagination diproses runtime.

Sequence memiliki fallback konfigurasi untuk sebagian parameter. Fallback ditulis sebagai default publik hanya jika nilainya stabil dan sudah disetujui.

### 9.2 Vehicle

Dua path memakai sequence yang sama: `/api/vehicles/getByLicensePlate` dan `/api/vehicles/vehicleatlas` sebagai alias/legacy.

Dokumentasikan parameter pencarian yang benar-benar didukung sequence:

- `plate_no` atau alias legacy `licensePlate`.
- `equipment_no`.
- `branch_code`.
- `limit`, `offset`, `status_id`, dan `color` bila diteruskan ke backend.

Request tanpa parameter pencarian menghasilkan `400`. Jika alias memiliki prioritas berbeda, jelaskan pada `description` atau gunakan schema `oneOf` yang sesuai.

### 9.3 Vendor

`POST /api/vendors/create` menerima JSON dan mengubahnya menjadi XML VMD sebelum dikirim melalui FTP. OpenAPI mendokumentasikan JSON client, bukan XML internal.

Field yang perlu dipetakan dari sequence/feature guide meliputi `companyTitle`, `companyName`, `otv`, `paymentCycle`, data bank, kontak, `npwp`, `accountGroup`, `top`, `glAccount`, dan `documentNumber`. Dokumentasikan enum, panjang maksimum, email, dan conditional rule hanya berdasarkan validasi aktual.

### 9.4 SPK Duelist

`POST /api/spk/duelist` menerima object header dengan array `details`.

- Header minimum: `noSpk`, `type`, `noPolisi`, `category`, `subCategory`, `vendorReferensi`, `totalPrice`, `createdAt`, `createdBy`.
- `details` minimal satu item.
- Detail wajib memiliki `description`, `qty > 0`, `price > 0`, dan `jenis` bernilai `Jasa` atau `Parts`.
- Jika `X-Validate-Total: true`, jumlah `qty * price` dibandingkan dengan `totalPrice`.

Field tambahan harus ditambahkan setelah mapping sequence dikonfirmasi. Bedakan `required` dan optional field.

### 9.5 Service Request

`POST /api/service-requests` melakukan fan-out ke target ATLAS dan ASSA External Service. Field minimum:

- `app_id`
- `reff_number`
- `branch_code`
- `created_datetime`
- `created_by`
- `ticket_no`

Field integrasi tambahan dapat mencakup equipment/license plate, customer, contact person, jadwal, lokasi, incident, ticket, dan task. Gunakan format tanggal yang sama dengan sequence.

Dokumentasikan hasil fan-out jika sudah diverifikasi: `200` semua target berhasil, `207` sebagian berhasil, dan `502` seluruh target gagal.

### 9.6 Health, readiness, dan worker

Health/readiness adalah endpoint probe, bukan business API. Dokumentasikan `security: []`, response JSON, dan path per service. Contoh liveness:

```json
{
  "status": "UP",
  "timestamp": "2026-09-24T10:15:30Z"
}
```

Readiness dapat memuat `backend: UP`. Worker retry adalah endpoint operasional; dokumentasikan method yang tersedia dan tambahkan security requirement sebelum dipublikasikan.

## 10. Status code dan response

Gunakan status code yang benar-benar dikembalikan implementasi:

| Status | Makna |
|---:|---|
| 200 | Success atau idempotency replay |
| 201 | Request berhasil dibuat/diterima sesuai kontrak service |
| 207 | Sebagian target fan-out berhasil |
| 400 | Payload/parameter/validasi gagal |
| 401 | Authorization tidak ada, salah format, atau token tidak dikenal |
| 403 | Token valid tetapi scope tidak cukup |
| 409 | Transaksi dengan idempotency key masih diproses |
| 502 | Backend gagal setelah retry atau seluruh fan-out gagal |
| 504 | Timeout jika memang dikembalikan runtime |

Format error umum:

```json
{
  "error": true,
  "message": "Forbidden",
  "detail": "Application does not have the required scope.",
  "transactionId": "TRX-EXAMPLE-001"
}
```

Nama field response harus diverifikasi dari `ErrorResponseSeq.xml` dan `SafeApiCallWithRetrySeq.xml`. Jangan menambahkan field bisnis ke schema sukses jika field tersebut hanya property internal dan tidak terlihat pada response HTTP.

## 11. Workflow membuat atau mengubah Swagger

1. Ubah API XML/sequence WSO2 MI terlebih dahulu.
2. Identifikasi route, method, scope, header, parameter, body, validation, dan status dari source runtime.
3. Tambahkan/ubah operation pada `docs/openapi/<service>.yaml`.
4. Tambahkan schema dan response reusable di `components`.
5. Tambahkan contoh aman ke OpenAPI dan `test_all.ps1`.
6. Jalankan validasi XML/build:

   ```powershell
   mvn -B validate
   ```

7. Jalankan service lokal dan uji happy path serta negative path.
8. Pastikan response aktual sesuai schema.
9. Perbarui README/feature guide bila behavior consumer berubah.
10. Review keamanan: tidak ada token, password, API key, URL sensitif, atau PII nyata.

## 12. Validasi OpenAPI

Setelah file spesifikasi dibuat, tambahkan validator ke CI. Contoh dengan versi CLI yang dipin:

```powershell
npx @redocly/cli@1.34.5 lint docs/openapi/branch-service.yaml
```

Validasi minimal harus memastikan:

- YAML dapat diparse dan `openapi` bernilai `3.0.3`.
- Semua `$ref` valid.
- `operationId` unik.
- Setiap route di API XML memiliki operation OpenAPI.
- Tidak ada operation OpenAPI tanpa route runtime.
- Contoh request tidak mengandung secret atau data pribadi.

## 13. Checklist pull request

### Runtime

- [ ] API XML memiliki context, method, dan uri-template yang benar.
- [ ] Sequence memvalidasi parameter/body sesuai kontrak.
- [ ] Fault/error path sudah diuji.
- [ ] Scope dan authentication benar.
- [ ] Idempotency/correlation/retry diuji jika relevan.

### OpenAPI

- [ ] File service yang benar diperbarui.
- [ ] `operationId` unik dan stabil.
- [ ] Semua parameter/header/request body terdokumentasi.
- [ ] `required`, `type`, `format`, enum, dan constraint sesuai sequence.
- [ ] Response sukses, error, dan headers terdokumentasi.
- [ ] Contoh menggunakan data sintetis.
- [ ] Secret dan credential tidak masuk spec.
- [ ] Alias/legacy route diberi label.

### Test dan dokumen

- [ ] `test_all.ps1` atau test otomatis mencakup perubahan.
- [ ] `mvn -B validate` berhasil.
- [ ] Spec OpenAPI lolos parser/linter.
- [ ] README/feature guide diperbarui bila behavior berubah.
- [ ] Perbedaan kontrak lama dan baru dijelaskan pada release note.

## 14. Gap sebelum OpenAPI dipublikasikan

1. Pastikan response sukses Vendor/SPK benar-benar mengembalikan `documentNumber` bila feature guide menjanjikannya.
2. Pastikan apakah `GenericPaginationSeq` menghasilkan wrapper `count/data/pagination` atau hanya meneruskan payload backend.
3. Tetapkan apakah status create adalah `201` dan status replay tetap `200`.
4. Tetapkan kontrak trailing slash untuk health/readiness.
5. Tetapkan method dan security worker retry.
6. Tetapkan format tanggal Service Request yang resmi.
7. Tandai `/api/vehicles/vehicleatlas` sebagai alias yang dipertahankan atau route legacy.
8. Selaraskan lokasi feature guide dengan link di README.

Setelah gap tersebut diputuskan, buat file spesifikasi di `docs/openapi/` dan jadikan file tersebut kontrak formal untuk consumer API.
