# Assignment Guide — Vendor GET By Create Date (vendor_code filter + pagination)

> **Status dokumen:** PROPOSED / TO IMPLEMENT.
> Endpoint `GET /api/vendors/getByCreateDate` **belum ada** di repository. Yang sudah ada di `vendor-service` saat ini hanya `POST /api/vendors/create` (lihat `integrations/vendor-service/src/main/wso2mi/artifacts/apis/VendorAPI.xml`). Guide ini adalah tugas (assignment) untuk tim middleware ASSA agar menambahkan endpoint GET baru.
> Guide ini **dokumentasi saja**. Tidak ada perubahan runtime (API XML / sequence / `.env` / deployment) yang dilakukan oleh dokumen ini. Setiap skeleton XML di bawah ditandai sebagai **CONTOH** dan belum ada di repo.

---

## 1. Ringkasan tugas

Tambahkan endpoint GET pada `vendor-service` yang mengkonsumsi backend SAP Core:

```
GET https://sapcoreapi.assa.id/api/Vendor/GetByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-10-08
```

Saat di-expose melalui middleware, response wajib mendukung:
1. Filter tambahan berdasarkan `vendor_code` (menyaring hasil SAP berdasarkan kode vendor).
2. Pagination dengan field `total`, `page`, dan `perPage` pada envelope response.

Scope keamanan: `vendors` (sama seperti endpoint vendor yang sudah ada).

### Status CURRENT vs PROPOSED

| Item | Status | Bukti file |
|---|---|---|
| `POST /api/vendors/create` (FTP/XML VMD) | CURRENT (ada) | `integrations/vendor-service/src/main/wso2mi/artifacts/apis/VendorAPI.xml` |
| `GET /api/vendors/getByCreateDate` | PROPOSED (belum ada) | tidak ditemukan di `VendorAPI.xml` |
| Pola GetByCreateDate (Branch/Customer) | CURRENT (ada, acuan pola) | `BranchGetByCreateDateSeq.xml`, `CustomerGetByCreateDateSeq.xml` |
| Envelope `{success,total,page,perPage,data}` | CURRENT dibentuk `GenericPaginationSeq` | `shared/.../GenericPaginationSeq.xml` |
| Filter `vendor_code` di pagination | PROPOSED (belum ada) | `GenericPaginationSeq.xml` hanya punya filter customerCode/customerName/filterBy |
| Config SAP Core base URL untuk vendor | PROPOSED | `vendor-service` belum punya `config.properties` berisi key SAP (file kosong/absen) |

---

## 2. Tujuan bisnis

Tim middleware perlu mengekspos data vendor dari SAP Core (`/api/Vendor/GetByCreateDate`) ke konsumen internal, dengan nilai tambah di sisi middleware:

- **Filter `vendor_code`**: konsumen bisa menyaring hasil ke satu/sebagian kode vendor tanpa memanggil SAP berkali-kali.
- **Pagination konsisten**: response dibungkus envelope seragam `total` / `page` / `perPage` / `data[]`, sama seperti Branch/Customer GetByCreateDate yang sudah berjalan.

Catatan integrasi: filter dan pagination ini **berlapis di atas** data SAP; SAP tetap dipanggil dengan parameter aslinya.

---

## 3. Kontrak API middleware yang diusulkan

| Atribut | Nilai |
|---|---|
| Method | `GET` |
| Path | `/api/vendors/getByCreateDate` |
| Context API | `/api/vendors` (sudah dipakai `VendorAPI.xml`) |
| Scope | `vendors` |
| Auth | `Authorization: Bearer <TOKEN>` (atau `X-API-Key: <TOKEN>`) |

> Path mengikuti konvensi `BranchAPI.xml` (`/api/branches/getByCreateDate`) dan `CustomerAPI`. Context `/api/vendors` sudah ada; yang ditambahkan adalah resource GET baru `/getByCreateDate`.

### Query parameters

| Param | Wajib | Default | Diproses di | Keterangan |
|---|---|---|---|---|
| `companyCode` | tidak* | `1000` (pola Branch) | diteruskan ke SAP | *punya fallback default; samakan dengan pola Branch/Customer |
| `dateStart` | tidak* | pola Branch `2020-01-01` | diteruskan ke SAP | format `date` (`YYYY-MM-DD`) |
| `dateEnd` | tidak* | pola Branch `2026-09-11` | diteruskan ke SAP | format `date` (`YYYY-MM-DD`) |
| `filterBy` | tidak | — | **middleware** (bukan SAP) | filter universal substring case-insensitive (`VendorCode` atau `VendorName`). Mendukung juga alias `filteredBy` / `filterdby`. |
| `page` | tidak | `1` | middleware | halaman, mulai dari 1 |
| `perPage` | tidak | `10` | middleware | jumlah item per halaman |

> Catatan: pada pola Branch/Customer, `companyCode`/`dateStart`/`dateEnd` memiliki fallback default berlapis (`$url` → `file` → `system` → nilai hardcoded).

### Contoh request — curl

```bash
curl -s "http://localhost:8293/api/vendors/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-10-08&filterBy=ASTRA&page=1&perPage=10" \
  -H "Authorization: Bearer $AUTH_APP_QA_TOKEN" \
  -H "X-Correlation-Id: corr-vendor-001"
```

### Contoh request — PowerShell

```powershell
$headers = @{
  Authorization      = "Bearer $env:AUTH_APP_QA_TOKEN"
  "X-Correlation-Id" = "corr-vendor-001"
}

Invoke-RestMethod `
  -Uri "http://localhost:8293/api/vendors/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-10-08&filterBy=ASTRA&page=1&perPage=10" `
  -Headers $headers `
  -Method Get
```

> Port `8293` = vendor-service (lihat inventaris di `docs/API_DEVELOPMENT_GUIDE.md` dan `test_all.ps1`). Gunakan token dari environment; jangan menuliskan token nyata.

---

## 4. Mapping ke backend SAP Core

Backend: `GET /api/Vendor/GetByCreateDate` pada host SAP Core.

| Parameter middleware | Diteruskan ke SAP? | Catatan |
|---|---|---|
| `companyCode` | Ya | diteruskan apa adanya |
| `dateStart` | Ya | diteruskan apa adanya |
| `dateEnd` | Ya | diteruskan apa adanya |
| `vendor_code` | **Tidak** | diproses di middleware setelah response SAP diterima (kecuali terbukti SAP mendukung parameter ini) |
| `page` / `perPage` | **Tidak** (default) | pagination dilakukan middleware atas hasil SAP, mengikuti pola Branch |

> **Peringatan grounding:** pola Branch (`BranchGetByCreateDateSeq.xml`) **meneruskan** `page`/`perPage` ke SAP di URL backend sekaligus mengaktifkan `paginationEnabled=true`. Sebaliknya pola Customer (`CustomerGetByCreateDateSeq.xml`) meneruskan filter `CustomerCode`/`CustomerName` ke SAP **dan** menyaring ulang di middleware. Untuk `vendor_code`, karena SAP Vendor GetByCreateDate belum terbukti menerima parameter tersebut, defaultkan sebagai **pemrosesan middleware** sampai dikonfirmasi (keputusan terbuka di bagian 12).

### Base URL backend (jangan hardcode)

Base URL di-resolve lewat `ResolveBaseUrlSeq` (`shared/src/main/wso2mi/artifacts/sequences/ResolveBaseUrlSeq.xml`), resolusi 4-layer: header override → ENV → system → file → default.

Host contoh `https://sapcoreapi.assa.id` di repo saat ini dipetakan ke key:

- Config key (file/system): `sap.core.customer.base.url`
- Environment variable: `SAP_CORE_CUSTOMER_BASE_URL`

(Lihat `docker-compose.yml`, `.env.example`, dan `platform/docker/deployment.toml.j2`: `SAP_CORE_CUSTOMER_BASE_URL` default `https://sapcoreapi.assa.id`, sedangkan `SAP_CORE_BASE_URL` default `https://devsapcoreapi.assa.id`.)

> **Rekomendasi:** gunakan `sap.core.customer.base.url` / `SAP_CORE_CUSTOMER_BASE_URL` bila target vendor adalah host `sapcoreapi.assa.id`. Alternatifnya, tim boleh menambahkan key khusus baru (mis. `sap.core.vendor.base.url` / `SAP_CORE_VENDOR_BASE_URL`) agar vendor punya endpoint terkonfigurasi sendiri. **Jangan menuliskan host backend secara hardcode di sequence.** Keputusan key mana yang dipakai adalah bagian dari assignment.

---

## 5. Validasi parameter

| Parameter | Aturan | Error |
|---|---|---|
| `dateStart`, `dateEnd` | format `YYYY-MM-DD`; `dateStart <= dateEnd` | `400` bila format salah |
| `companyCode` | string kode perusahaan (contoh `1000`, `2000`, `6000`, `7000`) | `400` bila divalidasi dan tidak valid |
| `vendor_code` | opsional; aturan match **harus diputuskan**: exact vs contains, case-sensitive vs insensitive | — |
| `page` | integer `>= 1`; bila `<1` fallback ke `1` (pola existing) | — |
| `perPage` | integer; default `10`; tetapkan batas min/maks (mis. 1..100) | `400` bila melebihi batas (bila divalidasi) |

> Pola existing (`GenericPaginationSeq.xml`) memperlakukan `page`/`perPage` yang tidak valid dengan fallback (`page=1`, `perPage=10`) alih-alih menolak. Keputusan apakah menolak `400` atau fallback adalah keputusan terbuka.

---

## 6. Pemrosesan middleware (urutan sequence)

Mengikuti pola `BranchGetByCreateDateSeq.xml` / `CustomerGetByCreateDateSeq.xml`:

1. **AuthGuard** — resource memasang `property requiredScope = vendors` lalu memanggil `AuthGuardSeq` (`shared/.../AuthGuardSeq.xml`). Guard ini juga menyusun `X-Correlation-Id` bila kosong, memvalidasi token, dan menolak `401`/`403`.
2. **Ekstraksi parameter + default** — baca `companyCode`, `dateStart`, `dateEnd`, `vendor_code`, `page`, `perPage` dari `$url:*` dengan fallback (ikuti pola Branch/Customer).
3. **Observability + idempotency** — set `api.endpoint` dan `api.params`, panggil `LogRequestSeq`, lalu `IdempotencyGuardSeq`.
   - Catatan GET: pola existing (Branch/Customer) **tetap** memanggil `IdempotencyGuardSeq` meski method GET. Pertahankan konsistensi pola kecuali tim memutuskan lain.
4. **Resolve base URL** — set `baseUrlConfigKey` + `envVarKey`, panggil `ResolveBaseUrlSeq`.
5. **Susun URL backend** — bentuk `uri.var.sapBackendUrl = resolvedBaseUrl + sapApiPath + ?companyCode=...&dateStart=...&dateEnd=...` (teruskan `page`/`perPage` bila mengikuti pola Branch).
6. **Panggil SAP** — set `targetEndpointKey = SapCoreDynamicEndpoint`, `paginationEnabled = true`, panggil `SafeApiCallWithRetrySeq` (`shared/.../SafeApiCallWithRetrySeq.xml`). Sequence ini melakukan retry (default 3x), mencatat attempt/transaksi ke DB, lalu memanggil `GenericPaginationSeq` dan `respond`.
7. **Filter `vendor_code` + paginate + format envelope** — dilakukan di `GenericPaginationSeq` (`shared/.../GenericPaginationSeq.xml`).
   - **PENTING:** `GenericPaginationSeq` saat ini **membentuk** envelope `{success,total,page,perPage,data}` dan sudah punya filter untuk `customerCode`, `customerName`, dan `filterBy` — tetapi **belum ada cabang filter untuk `vendor_code`**. Menambahkan filter `vendor_code` adalah **pekerjaan implementasi** (lihat bagian 7 & 9).

### Implikasi urutan filter vs pagination

Filter `vendor_code` dijalankan **setelah** data diterima dari SAP dan **sebelum** slicing halaman. Artinya:

- `total` dihitung dari jumlah record **setelah** filter `vendor_code` (lihat logika `filterApplied` di `GenericPaginationSeq`: bila filter diterapkan, `total = records.length`).
- Pagination memotong hasil yang sudah difilter. Konsekuensinya, pagination berlaku atas **full dataset yang dikembalikan SAP** untuk rentang tanggal tersebut, bukan atas paging native SAP (kecuali diputuskan meneruskan paging ke SAP). Bila SAP mengembalikan dataset besar, pertimbangkan dampak memori/performa (keputusan terbuka di bagian 12).

---

## 7. Response envelope dengan pagination

Target bentuk response (dibentuk `GenericPaginationSeq`):

```json
{
  "success": true,
  "total": 2,
  "page": 1,
  "perPage": 10,
  "data": [
    { "VendorCode": "82165871", "VendorName": "PT Contoh Satu" },
    { "VendorCode": "82165999", "VendorName": "PT Contoh Dua" }
  ]
}
```

> Nama field dalam `data[]` mengikuti bentuk asli response SAP Vendor dan **harus diverifikasi** saat implementasi (contoh di atas sintetis). `success`, `total`, `page`, `perPage`, `data` adalah bentuk yang **sudah** dihasilkan `GenericPaginationSeq.xml` hari ini.

### Status pembentukan envelope (grounding)

- **`GenericPaginationSeq.xml` SUDAH membentuk** wrapper `{success,total,page,perPage,data}` dan sudah melakukan slicing halaman. Ini bukan pekerjaan baru.
- **Yang BELUM ada**: cabang filter `vendor_code` di dalam `GenericPaginationSeq.xml`. Script JS di sana hanya menangani `customerCode`, `customerName`, dan `filterBy` (yang mencoba mencocokkan field customer/vehicle/branch). **Tidak ada** key atau field vendor. Menambahkan cabang untuk `vendor_code` adalah pekerjaan implementasi.

> Alternatif tanpa mengubah shared: pakai parameter `filterBy` yang sudah ada dan tambahkan field vendor ke script `filterBy`. Namun karena tugas secara eksplisit meminta parameter bernama `vendor_code`, menambahkan cabang `vendor_code` lebih sesuai. Keputusan ada pada tim (bagian 12).

---

## 8. Status code & error

| Status | Kondisi | Sumber |
|---|---|---|
| `200` | sukses (envelope pagination) | `SafeApiCallWithRetrySeq` → `respond` |
| `400` | parameter/tanggal invalid (bila divalidasi) | sequence domain → `ErrorResponseSeq` |
| `401` | tidak ada token / token tidak dikenal | `AuthGuardSeq` |
| `403` | token valid tapi tidak punya scope `vendors` | `AuthGuardSeq` |
| `502` | SAP gagal setelah retry | `ApiCallErrorHandlerSeq` / `ErrorResponseSeq` (mapping `101503/101505/101506/101507`) |
| `504` | timeout backend (bila dikembalikan runtime) | `ErrorResponseSeq` (mapping `101504/101508`) |

Format error mengikuti `ErrorResponseSeq.xml`:

```json
{
  "error": true,
  "message": "Forbidden",
  "detail": "Application (app_b) does not have scope: vendors"
}
```

> `ErrorResponseSeq` saat ini mem-build `{error, message, detail}`. Field `transactionId` muncul di contoh OpenAPI tetapi **tidak** ditambahkan oleh `ErrorResponseSeq.xml` versi sekarang; jangan klaim ada tanpa verifikasi.

---

## 9. Peta artefak WSO2 MI yang harus dibuat/diubah (vendor-service)

Semua di bawah ini adalah **pekerjaan assignment** (belum ada di repo kecuali disebut CURRENT).

### 9.1 Tambah resource GET di `VendorAPI.xml` (UBAH)

File: `integrations/vendor-service/src/main/wso2mi/artifacts/apis/VendorAPI.xml` (CURRENT hanya punya resource POST `/create`).

**CONTOH skeleton** (tambahkan resource baru, jangan hapus POST yang ada):

```xml
<!-- CONTOH — belum ada di repo -->
<resource methods="GET" uri-template="/getByCreateDate">
    <inSequence>
        <property name="requiredScope" value="vendors" scope="default" type="STRING"/>
        <sequence key="AuthGuardSeq"/>
        <sequence key="VendorGetByCreateDateSeq"/>
    </inSequence>
    <faultSequence>
        <sequence key="ErrorResponseSeq"/>
    </faultSequence>
</resource>
```

### 9.2 Buat domain sequence `VendorGetByCreateDateSeq.xml` (BARU)

File: `integrations/vendor-service/src/main/wso2mi/artifacts/sequences/VendorGetByCreateDateSeq.xml`

**CONTOH skeleton** (mengikuti `BranchGetByCreateDateSeq.xml`, disederhanakan — lengkapi fallback & validasi sesuai keputusan tim):

```xml
<!-- CONTOH — belum ada di repo -->
<?xml version="1.0" encoding="UTF-8"?>
<sequence name="VendorGetByCreateDateSeq" trace="disable" xmlns="http://ws.apache.org/ns/synapse">
    <!-- 1. Ekstraksi parameter + fallback (ikuti pola Branch/Customer) -->
    <property name="companyCode" expression="$url:companyCode" scope="default" type="STRING"/>
    <!-- ... fallback file/system/default seperti pola Branch ... -->
    <property name="dateStart" expression="$url:dateStart" scope="default" type="STRING"/>
    <property name="dateEnd" expression="$url:dateEnd" scope="default" type="STRING"/>

    <!-- Parameter khusus middleware -->
    <property name="vendorCode" expression="$url:vendor_code" scope="default" type="STRING"/>
    <property name="page" expression="$url:page" scope="default" type="STRING"/>
    <filter xpath="string-length($ctx:page) = 0"><then><property name="page" value="1" scope="default" type="STRING"/></then></filter>
    <property name="perPage" expression="$url:perPage" scope="default" type="STRING"/>
    <filter xpath="string-length($ctx:perPage) = 0"><then><property name="perPage" value="10" scope="default" type="STRING"/></then></filter>

    <!-- 2. Observability + idempotency -->
    <property name="api.endpoint" value="/api/vendors/getByCreateDate" scope="default" type="STRING"/>
    <property name="api.params" expression="fn:concat('companyCode=', $ctx:companyCode, '&amp;dateStart=', $ctx:dateStart, '&amp;dateEnd=', $ctx:dateEnd, '&amp;vendor_code=', $ctx:vendorCode, '&amp;page=', $ctx:page, '&amp;perPage=', $ctx:perPage)" scope="default" type="STRING"/>
    <sequence key="LogRequestSeq"/>
    <sequence key="IdempotencyGuardSeq"/>

    <!-- 3. Resolve base URL (gunakan key SAP Core yang menuju sapcoreapi.assa.id) -->
    <property name="baseUrlConfigKey" value="sap.core.customer.base.url" scope="default" type="STRING"/>
    <property name="envVarKey" value="SAP_CORE_CUSTOMER_BASE_URL" scope="default" type="STRING"/>
    <sequence key="ResolveBaseUrlSeq"/>

    <!-- 4. Path SAP (dari config, dengan fallback) -->
    <property name="sapApiPath" expression="get-property('file', 'sap.api.path.vendor.getByCreateDate')" scope="default" type="STRING"/>
    <filter xpath="string-length($ctx:sapApiPath) = 0">
        <then><property name="sapApiPath" value="/api/Vendor/GetByCreateDate" scope="default" type="STRING"/></then>
    </filter>

    <!-- 5. Susun URL backend (vendor_code TIDAK diteruskan ke SAP by default) -->
    <property name="uri.var.sapBackendUrl" expression="fn:concat($ctx:resolvedBaseUrl, $ctx:sapApiPath, '?companyCode=', $ctx:companyCode, '&amp;dateStart=', $ctx:dateStart, '&amp;dateEnd=', $ctx:dateEnd)" scope="default" type="STRING"/>

    <!-- 6. Panggil SAP + pagination + filter -->
    <property name="paginationEnabled" value="true" scope="default" type="STRING"/>
    <property name="targetEndpointKey" value="SapCoreDynamicEndpoint" scope="default" type="STRING"/>
    <sequence key="SafeApiCallWithRetrySeq"/>
</sequence>
```

### 9.3 Tambahkan filter `vendor_code` di `GenericPaginationSeq.xml` (UBAH — shared)

File: `shared/src/main/wso2mi/artifacts/sequences/GenericPaginationSeq.xml`

Saat ini script JS membaca `customerCode`, `customerName`, dan `filterBy`. Tambahkan cabang membaca property `vendorCode` dan mencocokkan field vendor (mis. `VendorCode`/`vendorCode`/`vendor_code`, dan opsional `VendorName`).

**CONTOH potongan** (sisipkan di dalam blok `if (records !== null)`, sebelum slicing halaman):

```javascript
// CONTOH — belum ada di GenericPaginationSeq.xml
var filterVendorCode = mc.getProperty("vendorCode");
if (filterVendorCode && String(filterVendorCode).trim().length > 0) {
    filterApplied = true;
    var vNeedle = String(filterVendorCode).trim().toLowerCase();
    var filteredVendors = [];
    for (var v = 0; v < records.length; v++) {
        var it = records[v];
        if (!it) continue;
        var vc = it.VendorCode || it.vendorCode || it.vendor_code || it.vendorcode || "";
        if (String(vc).toLowerCase().indexOf(vNeedle) !== -1) {
            filteredVendors.push(it);
        }
    }
    records = filteredVendors;
}
```

> Perubahan ini **shared** dan memengaruhi semua service yang memakai `GenericPaginationSeq`. Karena hanya menambah cabang untuk property baru `vendorCode` (yang tidak di-set service lain), dampak regresi minimal — tetap uji ulang Branch/Customer/Vehicle. Aturan match (exact vs contains, case-insensitive) di contoh ini = **contains, case-insensitive**, konsisten dengan filter existing; konfirmasikan dengan tim (bagian 12).

### 9.4 Konfigurasi base URL vendor (UBAH/BUAT)

File per-service: `integrations/vendor-service/src/main/wso2mi/resources/conf/config.properties` (CURRENT: kosong/absen).

Tambahkan (contoh) agar resolusi base URL & path konsisten:

```properties
# CONTOH
sap.core.customer.base.url=https://sapcoreapi.assa.id
sap.api.path.vendor.getByCreateDate=/api/Vendor/GetByCreateDate
```

Dan pastikan `SAP_CORE_CUSTOMER_BASE_URL` tersedia di environment (lihat `docker-compose.yml`, `.env.example`, `platform/docker/deployment.toml.j2`). **Jangan commit nilai rahasia; gunakan placeholder dan mekanisme env.**

---

## 10. Testing lokal

### Happy path

```powershell
$headers = @{ Authorization = "Bearer $env:AUTH_APP_QA_TOKEN"; "X-Correlation-Id" = "corr-vendor-200" }
Invoke-RestMethod -Method Get -Headers $headers `
  -Uri "http://localhost:8293/api/vendors/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-10-08&page=1&perPage=10"
```

### Negative tests

| Kasus | Request | Expected |
|---|---|---|
| Tanpa token | GET tanpa header Authorization | `401` |
| Scope salah | token App B (tanpa scope `vendors`) | `403` |
| Tanggal invalid | `dateStart=2026-13-40` (bila divalidasi) | `400` |
| `vendor_code` tidak ketemu | `vendor_code=XXXXNOTFOUND` | `200`, `data: []`, `total: 0` |

### Saran entri untuk `test_all.ps1` (JANGAN diubah tanpa diminta)

Pola existing memakai helper `Run-Test` dan `Run-Pagination-Test`. Saran tambahan (contoh, selaraskan penomoran):

```powershell
# SARAN — tambahkan saat endpoint sudah dibuat
Run-Test -TestName "Vendor GetByCreateDate: Tanpa Token (401)" -Url "$baseUrlVendor/api/vendors/getByCreateDate?companyCode=1000" -ExpectedStatus 401
Run-Test -TestName "Vendor GetByCreateDate: App B tanpa scope vendors (403)" -Url "$baseUrlVendor/api/vendors/getByCreateDate?companyCode=1000" -Token $tokenAppB -ExpectedStatus 403
Run-Test -TestName "Vendor GetByCreateDate: Happy path (200)" -Url "$baseUrlVendor/api/vendors/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-10-08&page=1&perPage=10" -Token $tokenQA -ExpectedStatus 200
Run-Test -TestName "Vendor GetByCreateDate: vendor_code tidak ketemu (200, data kosong)" -Url "$baseUrlVendor/api/vendors/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-10-08&vendor_code=XXXXNOTFOUND" -Token $tokenQA -ExpectedStatus 200
Run-Pagination-Test -TestName "Vendor pagination (page/perPage)" -BaseUrl $baseUrlVendor -Token $tokenQA -Path "/api/vendors/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-10-08"
```

> `$baseUrlVendor` dan `$tokenQA`/`$tokenAppB` sudah didefinisikan di `test_all.ps1`.

---

## 11. Dokumentasi OpenAPI

File: `docs/openapi/vendor-service.yaml` (CURRENT: hanya mendokumentasikan `POST /api/vendors/create`, `/health/vendor`, `/readiness/vendor`).

Saat endpoint dibuat, tambahkan operation `getVendorByCreateDate` dengan:

- `parameters`: `companyCode`, `dateStart` (format `date`), `dateEnd` (format `date`), `vendor_code`, `page`, `perPage`, plus header `X-Correlation-Id`.
- `security: [{ bearerAuth: [vendors] }]`.
- Response `200` dengan schema envelope pagination; `400/401/403/502` reuse `#/components/responses/*` yang sudah ada.

**CONTOH schema envelope** (tambahkan ke `components.schemas`):

```yaml
# CONTOH
VendorPageResponse:
  type: object
  properties:
    success: { type: boolean, example: true }
    total:   { type: integer, example: 2 }
    page:    { type: integer, example: 1 }
    perPage: { type: integer, example: 10 }
    data:
      type: array
      items:
        type: object
        additionalProperties: true
        description: Bentuk item vendor mengikuti response SAP; verifikasi saat implementasi.
```

Patuhi `API_DEVELOPMENT_GUIDE.md`: jangan klaim wrapper pagination di OpenAPI melebihi apa yang benar-benar dihasilkan runtime.

---

## 12. Checklist assignment & keputusan terbuka

### Checklist

**Runtime**
- [ ] Tambah resource GET `/getByCreateDate` di `VendorAPI.xml` (scope `vendors`).
- [ ] Buat `VendorGetByCreateDateSeq.xml` mengikuti pola Branch/Customer.
- [ ] Set `baseUrlConfigKey`/`envVarKey` yang benar; tidak hardcode host.
- [ ] Lengkapi `config.properties` vendor-service (base URL + `sap.api.path.vendor.getByCreateDate`).

**Response / pagination**
- [ ] Tambah cabang filter `vendor_code` di `GenericPaginationSeq.xml`.
- [ ] Pastikan envelope `total/page/perPage/data` benar setelah filter diterapkan.
- [ ] `total` merefleksikan jumlah setelah filter.

**Security**
- [ ] `requiredScope = vendors` terpasang & 401/403 teruji.
- [ ] Tidak ada token/credential/host rahasia yang di-commit.

**Test**
- [ ] Negative tests (401/403/400/`vendor_code` kosong) ditambahkan ke `test_all.ps1`.
- [ ] Pagination test ditambahkan.
- [ ] `mvn -B validate` + regresi Branch/Customer/Vehicle (karena shared diubah).

**Docs**
- [ ] Tambah operation + schema pagination ke `docs/openapi/vendor-service.yaml`.
- [ ] Perbarui inventaris endpoint di `API_DEVELOPMENT_GUIDE.md`.

### Keputusan terbuka

1. **Match `vendor_code`**: exact vs contains? case-sensitive vs insensitive? (contoh di guide = contains, case-insensitive).
2. **Paging native SAP**: apakah SAP Vendor GetByCreateDate mendukung `page`/`perPage` dan/atau filter `vendor_code` sendiri? Bila ya, apakah diteruskan ke SAP (pola Branch) atau tetap diproses middleware (pola Customer)?
3. **Pagination atas full result SAP**: apakah aman memuat seluruh hasil SAP ke memori lalu slicing? Perlu batas `perPage` maksimum (mis. 100).
4. **Validasi vs fallback**: apakah `dateStart/dateEnd/companyCode` kosong harus `400` atau pakai fallback default seperti pola existing?
5. **Idempotency pada GET**: pertahankan `IdempotencyGuardSeq` (konsisten dengan Branch/Customer) atau lewati untuk GET?
6. **Config key base URL**: pakai `sap.core.customer.base.url`/`SAP_CORE_CUSTOMER_BASE_URL` (menuju `sapcoreapi.assa.id`) atau buat key vendor baru?

---

## Lampiran — File repository yang dibaca untuk menyusun guide ini

CURRENT (dibaca & diverifikasi):
- `docs/API_DEVELOPMENT_GUIDE.md`
- `integrations/vendor-service/src/main/wso2mi/artifacts/apis/VendorAPI.xml`
- `integrations/branch-service/src/main/wso2mi/artifacts/apis/BranchAPI.xml`
- `integrations/branch-service/src/main/wso2mi/artifacts/sequences/BranchGetByCreateDateSeq.xml`
- `integrations/customer-service/src/main/wso2mi/artifacts/sequences/CustomerGetByCreateDateSeq.xml`
- `shared/src/main/wso2mi/artifacts/sequences/AuthGuardSeq.xml`
- `shared/src/main/wso2mi/artifacts/sequences/ResolveBaseUrlSeq.xml`
- `shared/src/main/wso2mi/artifacts/sequences/SafeApiCallWithRetrySeq.xml`
- `shared/src/main/wso2mi/artifacts/sequences/GenericPaginationSeq.xml`
- `shared/src/main/wso2mi/artifacts/sequences/ErrorResponseSeq.xml`
- `docs/openapi/vendor-service.yaml`
- `docker-compose.yml`, `.env.example`, `platform/docker/deployment.toml.j2`
- `test_all.ps1`
- `integrations/vendor-service/src/main/wso2mi/resources/conf/config.properties` (kosong/absen)

PROPOSED (ditandai belum ada di repo):
- `integrations/vendor-service/src/main/wso2mi/artifacts/sequences/VendorGetByCreateDateSeq.xml`
- resource GET `/getByCreateDate` di `VendorAPI.xml`
- cabang filter `vendor_code` di `GenericPaginationSeq.xml`
- operation `getVendorByCreateDate` di `docs/openapi/vendor-service.yaml`
