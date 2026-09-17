# ⚙️ KONSEP — Auto-Build Endpoint (Metadata-Driven Endpoint Generation)

Dokumen ini menjawab pertanyaan: **"Kalau ada endpoint baru, bagaimana proses otomatisnya?"**

Idenya: developer **tidak menulis XML manual**. Developer cukup mendeklarasikan **spesifikasi
endpoint** (method, URL backend, token/app pemilik, module tujuan) di satu file metadata.
Sistem lalu **meng-generate artifact WSO2** dan **membangun (build)** endpoint yang siap dipakai.

> Ini adalah pendekatan **config-driven / metadata-driven**. Melengkapi `KONSEP_STRUKTUR_CODE.md`
> (tata letak) dengan **alur otomatisasi** pembuatan endpoint baru.

---

## 1. Masalah yang Diselesaikan

Tanpa otomatisasi, menambah endpoint (walau sudah pakai pola SOP) tetap berarti:
- Menulis file API resource XML.
- Menulis file sequence operasi XML.
- Menambah path & token di config.
- Rawan salah ketik, tidak konsisten antar developer, sulit di-review.

Dengan **auto-build**: developer mengisi **satu entri metadata**, sisanya digenerate & diverifikasi
otomatis. Konsisten, cepat, dan skala ke 200+ endpoint jadi mudah.

---

## 2. Input: Spesifikasi Endpoint (Contoh yang Kamu Maksud)

Setiap endpoint baru dideskripsikan sebagai entri metadata. Contoh format (YAML):

```yaml
# endpoints.yaml (per module, atau terpusat)
module: customer-integration          # untuk modul apa
endpoints:
  - id: getCustomerById                # id unik operasi
    method: GET                        # method apa: GET / POST / PUT / DELETE
    exposedPath: /getById              # path yang di-expose middleware
    backendPath: /api/Customers/GetById# URL (path) backend SAP yang dipanggil
    queryParams:                       # parameter yang diteruskan
      - name: id
        source: url                    # dari query string ?id=
        required: true
    pagination: true                   # pakai GenericPaginationSeq?
    auth:
      required: true                   # tokennya wajib?
      allowedApps: [app_a]             # token/app mana yang boleh (untuk modul ini)
```

Dari satu entri ini, sistem tahu:

| Pertanyaan | Sumber di metadata |
|---|---|
| **Method apa?** | `method: GET` |
| **URL-nya apa?** (backend) | `backendPath: /api/Customers/GetById` |
| **Token / app siapa?** | `auth.allowedApps: [app_a]` |
| **Untuk modul apa?** | `module: customer-integration` |
| **Menghasilkan endpoint apa?** | `exposedPath` → `/api/customers/getById` (lihat §4) |

---

## 3. Proses Auto-Build (Pipeline Konseptual)

```
┌─────────────────────┐
│ 1. DEKLARASI         │  developer menambah entri di endpoints.yaml
│    (endpoints.yaml)  │
└──────────┬──────────┘
           │  git commit / jalankan generator
           ▼
┌─────────────────────┐
│ 2. VALIDASI METADATA │  cek: field lengkap? method valid? appId terdaftar?
│    (schema check)    │       path tidak bentrok? module ada?
└──────────┬──────────┘   gagal → build STOP + pesan error
           │ valid
           ▼
┌─────────────────────┐
│ 3. GENERATE ARTIFACT │  dari template → hasilkan:
│    (code generator)  │   • resource di <Domain>API.xml
│                      │   • <Domain><Op>Seq.xml (rangkai AuthGuard→Log→URL→Endpoint→Pagination)
│                      │   • entri config (backendPath, allowedApps)
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ 4. BUILD (Maven/CAR) │  ./mvnw clean package → <module>_x.y.z.car
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ 5. DEPLOY            │  CAR di-deploy ke WSO2 MI
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ 6. OUTPUT: ENDPOINT  │  endpoint hidup & bisa dipanggil (lihat §4)
│    SIAP DIPANGGIL    │
└─────────────────────┘
```

Langkah 2–4 dapat dijalankan otomatis via **Hook** (mis. `PostFileSave` pada `endpoints.yaml`)
atau via CI/CD pipeline.

---

## 4. Output: Endpoint yang Dihasilkan

Dari contoh metadata di §2, sistem menghasilkan endpoint yang dapat dipanggil:

```
Method : GET
URL     : https://middleware.assa.id/api/customers/getById?id=12345
Header  : Authorization: Bearer <token milik app_a>
```

**Cara URL exposed terbentuk:**
```
context module (dari API domain)  +  exposedPath (dari metadata)
        /api/customers            +      /getById              = /api/customers/getById
```

**Perilaku runtime endpoint hasil generate:**
1. `AuthGuardSeq` — cek token; hanya `app_a` yang diizinkan (sesuai `allowedApps`).
2. Baca `id` dari query.
3. `LogRequestSeq` — catat akses (appId, correlationId).
4. `ResolveBaseUrlSeq` — dapatkan base URL SAP.
5. Susun URL backend: `baseUrl + /api/Customers/GetById?id=12345`.
6. Panggil `SapCoreDynamicEndpoint`.
7. `GenericPaginationSeq` — bentuk response standar.

**Response** mengikuti kontrak standar (`count`, `data`, `pagination`) atau error (401/403/5xx).

---

## 5. Contoh Kedua: Endpoint di Modul Berbeda dengan Token Berbeda

```yaml
module: finance-integration
endpoints:
  - id: getInvoiceByNumber
    method: GET
    exposedPath: /getByNumber
    backendPath: /api/Invoices/GetByNumber
    queryParams:
      - name: invoiceNo
        source: url
        required: true
    pagination: true
    auth:
      required: true
      allowedApps: [app_b]          # token app_b, BUKAN app_a
```

Menghasilkan:
```
Method : GET
URL     : https://middleware.assa.id/api/invoices/getByNumber?invoiceNo=INV-001
Header  : Authorization: Bearer <token milik app_b>
Module  : finance-integration  →  finance-integration_x.y.z.car
```

Perhatikan: endpoint ini **hanya menerima token app_b**. Token app_a akan ditolak `403`
di modul finance ini. Isolasi token per-aplikasi (lihat `KONSEP.md`) tetap ditegakkan.

---

## 6. Tabel Ringkas: Input → Output

| Input (metadata) | Contoh nilai | Output yang dihasilkan |
|---|---|---|
| `method` | `GET` | Method resource di API XML |
| `exposedPath` | `/getById` | Bagian akhir URL exposed |
| `module` → context | `customer-integration` → `/api/customers` | Prefix URL exposed |
| `backendPath` | `/api/Customers/GetById` | URL backend yang dipanggil sequence |
| `auth.allowedApps` | `[app_a]` | Aturan validasi token di `AuthGuardSeq` |
| `queryParams` | `id (required)` | Pembacaan `$url:id` + penyusunan query backend |
| `pagination` | `true` | Pemanggilan `GenericPaginationSeq` |
| **Hasil akhir** | — | **`GET /api/customers/getById?id=...` + CAR ter-build** |

---

## 7. Komponen yang Dibutuhkan untuk Auto-Build

| Komponen | Peran | Status |
|---|---|---|
| `endpoints.yaml` (per module) | Sumber deklarasi endpoint | Belum ada (konsep) |
| Schema/validator metadata | Memastikan deklarasi valid sebelum generate | Belum ada |
| Template artifact (API + sequence) | Cetakan untuk generate XML | Belum ada |
| Generator (skrip/plugin) | Membaca metadata → menulis artifact + config | Belum ada |
| Hook / CI step | Memicu validate→generate→build otomatis | Belum ada |
| Shared sequences (AuthGuard, dll) | Dipakai artifact hasil generate | Sebagian ada |

Pilihan teknologi generator (konsep, dari sederhana → matang):
1. **Skrip (PowerShell/Node.js)** membaca YAML → tulis XML dari template string. Paling cepat dibuat.
2. **Maven plugin** (generate-sources) → integrasi mulus dengan build.
3. **Templating engine** (mis. Mustache/Freemarker) → template terpisah dari logika generator.

---

## 8. Keamanan & Guardrail Auto-Build

- **Validasi appId**: `allowedApps` harus merujuk app yang terdaftar di App Registry
  (`KONSEP.md`). Jika tidak, build gagal.
- **Cegah bentrok path**: dua endpoint dengan `module + exposedPath` sama → build gagal.
- **Tidak generate token**: metadata hanya menyebut `appId`, **bukan** nilai token.
  Token tetap rahasia dan tidak pernah masuk ke metadata/artifact.
- **Review tetap ada**: perubahan `endpoints.yaml` melewati code review (Git) sebelum di-generate.
- **Idempoten**: generate ulang menghasilkan artifact yang sama (tidak ada duplikasi).

---

## 9. Integrasi dengan Hook (Opsional)

Auto-build bisa dipicu otomatis di IDE via hook:

```
Trigger : PostFileSave  pada  **/endpoints.yaml
Action  : jalankan generator + validasi (command)
Efek    : setiap simpan endpoints.yaml → artifact ter-regenerate, siap build
```

Atau di CI/CD: langkah `validate → generate → mvn package` sebelum deploy.

---

## 10. Gap Terhadap Kondisi Saat Ini

1. **Belum ada mekanisme metadata-driven.** Endpoint saat ini ditulis manual (BranchAPI +
   sequence). Perlu `endpoints.yaml` + generator.
2. **Belum ada template artifact.** Pola sudah ada di SOP (`CLEAN_ARCHITECTURE.md §8`),
   tinggal dijadikan template generator.
3. **AuthGuardSeq & structured log belum diimplementasikan** — prasyarat agar output
   generator berfungsi penuh (lihat `KONSEP.md`, `KONSEP_MONITORING.md`).
4. **Belum ada validator & guardrail** (cek appId terdaftar, cegah bentrok path).

---

## 11. Ringkasan

- Auto-build = **deklarasi metadata → validasi → generate artifact → build CAR → deploy →
  endpoint siap**.
- Satu entri metadata menjawab: **method apa, URL backend apa, token/app siapa, untuk modul apa**,
  dan menentukan **endpoint exposed apa** yang dihasilkan.
- Contoh: `{GET, /getById, backend /api/Customers/GetById, app_a, customer}` →
  menghasilkan `GET /api/customers/getById` yang hanya menerima token `app_a`.
- Token **tidak pernah** ditulis di metadata — hanya `appId`; isolasi token per-aplikasi tetap terjaga.
- Diterapkan bertahap: mulai skrip generator sederhana, lalu Maven plugin / hook / CI.

---

## 12. Dokumen Terkait

- `KONSEP_STRUKTUR_CODE.md` — tata letak monorepo per-module (tempat artifact hasil generate).
- `KONSEP.md` — token per aplikasi (sumber aturan `allowedApps`).
- `KONSEP_MONITORING.md` — observability endpoint hasil generate.
- `CLEAN_ARCHITECTURE.md` — SOP & pola artifact (dasar template generator).
