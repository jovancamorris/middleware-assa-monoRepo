# 🧱 KONSEP — Struktur Kode Monorepo per-Module (ASSA Middleware)

Dokumen ini menjelaskan **bagaimana seharusnya struktur kode** platform ASSA Middleware
ditata sebagai **monorepo dengan pendekatan per-module (per-domain)**. Fokusnya pada
tata letak folder/file, batas antar-module, komponen bersama, dan konvensi penamaan.

> Melengkapi: `CLEAN_ARCHITECTURE.md` (layer & tanggung jawab), `KONSEP.md` (auth),
> `KONSEP_MONITORING.md` (observability). Dokumen ini menjawab pertanyaan **"file-nya
> ditaruh di mana dan bagaimana modul dibagi"**.

---

## 1. Prinsip Struktur (Structure Principles)

1. **Monorepo, Multi-Module** — satu repositori, banyak module Maven independen.
2. **Batas per Domain Bisnis** — satu domain = satu module = satu CAR (deployable unit).
3. **Screaming Structure** — struktur folder "berteriak" tentang domain bisnis
   (Customer, Finance, Procurement), bukan tentang framework.
4. **Shared yang Jelas** — komponen lintas-domain punya tempat yang terdefinisi,
   bukan tersebar/duplikat tanpa aturan.
5. **Konsistensi Antar-Module** — semua module mengikuti tata letak identik agar mudah
   dipelajari dan di-onboard.
6. **Konfigurasi Terpisah dari Kode** — artifact (logika) terpisah dari config (nilai).

---

## 2. Peta Level Struktur (3 Level)

```
Level 1: MONOREPO ROOT      → orkestrasi build, dokumentasi, tooling bersama
Level 2: MODULE (per-domain)→ unit deployable independen (1 CAR)
Level 3: ARTIFACT (per-tipe)→ apis / endpoints / sequences / resources
```

Aturan dependensi antar level: Root **mengagregasi** Module; Module **berisi** Artifact.
Antar-module **tidak** saling impor kode secara langsung (loosely coupled) — berbagi
dilakukan lewat mekanisme shared yang eksplisit (lihat bagian 5).

---

## 3. Struktur Level 1 — Monorepo Root

```
assa_middleware/
├── pom.xml                          # Parent POM (packaging=pom, reactor semua module)
├── mvnw, mvnw.cmd, .mvn/            # Maven wrapper (build reproducible tanpa install Maven)
├── .gitignore
├── build-tools/                     # (disarankan) skrip build/test/deploy lintas module
│   └── run_tests.ps1
│
├── customer-integration/            # Module domain (Level 2)
├── finance-integration/             # Module domain (Level 2)
└── procurement-integration/         # Module domain (Level 2)
```

**Tanggung jawab Root:**
- Mendefinisikan versi & properti bersama (runtime version, plugin version) di parent POM.
- Mendaftarkan seluruh module di `<modules>`.
- Menyimpan dokumentasi & tooling lintas-module (bukan logika integrasi).
- **TIDAK** berisi artifact WSO2 langsung — semua artifact ada di dalam module.

> Catatan: saat ini dokumen `.md` tersebar di root. **Disarankan** dipindah ke `docs/`
> agar root bersih. Ini opsional dan tidak mengubah build.

---

## 4. Struktur Level 2 — Module (per-Domain)

Setiap module domain **identik** tata letaknya:

```
<domain>-integration/
├── pom.xml                          # Child POM (packaging=car, artifactId=<domain>-integration)
│
├── deployment/
│   ├── deployment.toml              # Config server WSO2 + [system.parameter] per-env
│   └── docker/
│       ├── Dockerfile               # Image runtime domain ini
│       └── resources/               # keystore/truststore (JANGAN commit secret nyata)
│
└── src/
    ├── main/wso2mi/
    │   ├── artifacts/               # ← Level 3 (lihat bagian 6)
    │   │   ├── apis/
    │   │   ├── endpoints/
    │   │   └── sequences/
    │   └── resources/conf/
    │       └── config.properties    # Default fallback + App Registry (hash token)
    │
    └── test/wso2mi/                 # Unit test synapse (mi test framework) — saat ini kosong
        └── .gitkeep
```

**Aturan Module:**
- Nama module = `<domain>-integration` (mis. `customer-integration`).
- Satu module = satu CAR = satu unit deploy. Bisa dirilis/di-scale terpisah.
- Module **tidak** mereferensi artifact module lain secara langsung.
- Semua nilai environment-specific ada di `deployment/` & `resources/conf/`, bukan di `artifacts/`.

---

## 5. Strategi Komponen Bersama (Shared Components) — Keputusan Kunci

Masalah: `AuthGuardSeq`, `GenericPaginationSeq`, `ResolveBaseUrlSeq`, `LogRequestSeq`,
`ErrorResponseSeq`, `HealthCheckSeq`, dan `SapCoreDynamicEndpoint` dibutuhkan **semua module**.
Bagaimana membaginya tanpa copy-paste?

Ada tiga opsi. Pilih sesuai kematangan tim:

### Opsi A — Duplikasi Terkontrol (paling sederhana, kondisi saat ini)
Setiap module menyimpan salinan komponen shared-nya sendiri.
```
customer-integration/.../sequences/GenericPaginationSeq.xml
finance-integration/.../sequences/GenericPaginationSeq.xml   ← salinan identik
```
- ✅ Sederhana, tiap CAR self-contained, tidak ada dependency antar-module.
- ❌ Perubahan harus disalin ke semua module (rawan drift).
- **Cocok untuk:** tahap awal / jumlah module sedikit. **Wajib** ada aturan: file shared
  harus byte-identik antar module (bisa diverifikasi skrip di `build-tools/`).

### Opsi B — Module `common` sebagai Connector/Library (disarankan saat scale)
Buat satu module khusus berisi artifact bersama, di-package sebagai dependency.
```
assa_middleware/
├── common-integration/              # module shared (packaging=car atau connector)
│   └── src/main/wso2mi/artifacts/
│       ├── endpoints/SapCoreDynamicEndpoint.xml
│       └── sequences/  (AuthGuardSeq, GenericPaginationSeq, ResolveBaseUrlSeq,
│                        LogRequestSeq, ErrorResponseSeq, HealthCheckSeq)
├── customer-integration/            # depends-on common (deploy common CAR juga)
├── finance-integration/
└── procurement-integration/
```
- ✅ Satu sumber kebenaran untuk komponen shared (DRY nyata).
- ✅ Perubahan sekali, dipakai semua module.
- ❌ Menambah dependency deploy: CAR `common` harus ter-deploy sebelum module domain.
- **Cocok untuk:** saat module bertambah / komponen shared sering berubah.

### Opsi C — Registry/Governance Terpusat (paling matang)
Komponen shared dikelola sebagai artifact ter-versi di registry internal (mis. WSO2
registry / Git submodule / package internal), di-referensi lintas module dengan versi tetap.
- ✅ Versi terkontrol, auditable, bisa rollback per-versi.
- ❌ Overhead tooling & proses paling tinggi.
- **Cocok untuk:** organisasi besar, banyak tim, banyak domain.

> **Rekomendasi arah:** mulai dari **Opsi A** (sudah berjalan) dengan disiplin sinkronisasi,
> lalu **migrasi ke Opsi B** begitu finance & procurement mulai diisi dan komponen shared
> stabil. Dokumentasikan pilihan di `CLEAN_ARCHITECTURE.md` agar konsisten.

---

## 6. Struktur Level 3 — Artifact (per-Tipe)

Di dalam `src/main/wso2mi/artifacts/` komponen dikelompokkan per tipe WSO2:

```
artifacts/
├── apis/                            # Entry point (routing) — 1 file per domain-API
│   └── BranchAPI.xml                #   context /api/branches, delegasi ke sequence
│
├── endpoints/                       # Connectivity — endpoint dinamis tunggal
│   └── SapCoreDynamicEndpoint.xml
│
└── sequences/                       # Logika (dikelompokkan berdasar peran)
    │
    ├── ── SHARED (lintas operasi, kandidat pindah ke common-integration) ──
    ├── AuthGuardSeq.xml             # security: validasi token per-app
    ├── ResolveBaseUrlSeq.xml        # helper: resolusi base URL 4-layer
    ├── GenericPaginationSeq.xml     # helper: pagination + search + response
    ├── LogRequestSeq.xml            # observability: structured access log
    ├── HealthCheckSeq.xml           # observability: liveness/readiness
    ├── ErrorResponseSeq.xml         # error: format JSON error standar
    │
    └── ── OPERATION (spesifik domain, 1 per endpoint bisnis) ──
        ├── BranchByBranchCodeSeq.xml
        └── BranchByCreateDateSeq.xml
```

**Aturan penempatan sequence:**
- **Shared sequence**: bernama `<Fungsi>Seq.xml`, tidak mengandung logika domain spesifik.
- **Operation sequence**: bernama `<Domain><Operation>Seq.xml`, ramping — hanya merangkai
  parameter + memanggil komponen shared (lihat SOP di `CLEAN_ARCHITECTURE.md` §8).
- Satu file = satu artifact = satu tanggung jawab.

> Catatan: WSO2 MI mengelompokkan artifact **berdasarkan tipe** (apis/endpoints/sequences),
> bukan per-fitur. Pengelompokan per-peran (shared vs operation) dilakukan lewat **konvensi
> penamaan + komentar pemisah**, bukan sub-folder, agar tetap kompatibel dengan tooling MI.

---

## 7. Aturan Ketergantungan (Dependency Rules)

```
Root POM  ──agregasi──►  Module (customer/finance/procurement) ──(opsional)──► common-integration
   │                          │
   │                          ▼
   │                    Artifact di dalam module (apis → sequences → endpoints)
   │
   └── docs/, build-tools/  (tidak ikut build artifact)
```

- ✅ **Boleh**: Module domain bergantung pada `common-integration` (Opsi B).
- ❌ **Dilarang**: Module domain bergantung pada module domain lain (customer ↔ finance).
- ❌ **Dilarang**: Artifact `apis` memanggil endpoint backend langsung (harus lewat sequence).
- ❌ **Dilarang**: nilai environment-specific di dalam `artifacts/` (harus di config layer).

---

## 8. Konvensi Penamaan Ringkas

| Elemen | Pola | Contoh |
|---|---|---|
| Module | `<domain>-integration` | `customer-integration` |
| API file | `<Domain>API.xml` | `BranchAPI.xml` |
| API context | `/api/<domain-plural>` | `/api/branches` |
| Operation sequence | `<Domain><Operation>Seq.xml` | `BranchByBranchCodeSeq.xml` |
| Shared sequence | `<Fungsi>Seq.xml` | `GenericPaginationSeq.xml` |
| Endpoint | `<Target>DynamicEndpoint.xml` | `SapCoreDynamicEndpoint.xml` |
| Config file | `config.properties` / `deployment.toml` | — |
| appId | `snake_case` huruf kecil | `app_a`, `app_b` |

---

## 9. Contoh Konkret: Menambah Domain Baru (mis. HR)

Menambah domain = menambah satu module yang mengikuti pola identik:

```
1. Buat folder module:      hr-integration/
2. Salin tata letak module: deployment/, src/main/wso2mi/{artifacts,resources}
3. Daftarkan di root pom.xml:  <module>hr-integration</module>
4. Buat API:                artifacts/apis/EmployeeAPI.xml  (context /api/employees)
5. Buat operation sequence: EmployeeGetByIdSeq.xml (rangkai AuthGuard→Log→ResolveUrl→...)
6. Shared components:
   - Opsi A: salin dari module lain (jaga byte-identik)
   - Opsi B: cukup depends-on common-integration
7. Config:                  resources/conf/config.properties (path & default HR)
8. Build:                   ./mvnw.cmd clean compile  →  hr-integration_1.0.0.car
```

Tidak ada perubahan pada module lain. Domain baru sepenuhnya aditif.

---

## 10. Gap Terhadap Kondisi Saat Ini

1. **Komponen shared masih Opsi A (duplikasi) tanpa alat verifikasi.** Belum ada skrip yang
   memastikan `GenericPaginationSeq.xml` dll byte-identik antar module. Tambahkan cek di
   `build-tools/` atau migrasi ke Opsi B.
2. **Dokumentasi tersebar di root.** Disarankan pindah ke `docs/` (opsional, kosmetik).
3. **Module finance & procurement belum lengkap.** Baru punya `endpoints/` + sebagian
   `sequences/`; belum ada `apis/`, operation sequence, dan `resources/conf/`.
4. **`test/wso2mi/` kosong.** Belum ada unit test synapse; struktur sudah disiapkan.
5. **Belum ada `common-integration`.** Bila memilih Opsi B, module ini perlu dibuat.
6. **Folder `test-api/` di root** belum jelas statusnya (legacy vs module) — rapikan.

---

## 11. Ringkasan

- Struktur = **monorepo (root) → module per-domain → artifact per-tipe**.
- Setiap domain adalah **module Maven independen** menghasilkan **satu CAR** yang deployable
  terpisah; antar-module **loosely coupled**.
- Komponen bersama dikelola dengan strategi eksplisit: **Opsi A (duplikasi terkontrol)**
  sekarang, **Opsi B (module `common`)** saat scale, **Opsi C (registry)** untuk skala besar.
- Pengelompokan artifact mengikuti tipe WSO2 (apis/endpoints/sequences) + konvensi penamaan
  untuk memisahkan **shared** vs **operation**.
- Menambah domain/API bersifat **aditif** — tidak menyentuh module lain.

---

## 12. Dokumen Terkait

- `KONSEP_BESAR.md` — visi & konsep besar platform.
- `KONSEP.md` — autentikasi token per aplikasi.
- `KONSEP_MONITORING.md` — monitoring & observability.
- `CLEAN_ARCHITECTURE.md` — arsitektur teknis (layer, tanggung jawab, runtime, SOP).
