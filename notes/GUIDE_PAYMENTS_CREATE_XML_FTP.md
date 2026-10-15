# Guide Development: POST Payments → XML → FTP

> **STATUS: IMPLEMENTED — Fitur Payments Service telah diimplementasikan di repository (`integrations/payments-service`) dan didokumentasikan di Swagger UI (`docs/openapi/payments-service.yaml`).**
>
> Dokumen ini adalah panduan desain dan spesifikasi implementasi untuk API yang menerima JSON, membentuk XML, lalu mengirim XML ke folder remote `payments` melalui FTP/VFS.
>
> Naming convention file final yang disetujui:
> `PAYMENTS_<accountingDocumentNumber>_<companyCode>_<transactionId>.xml`
> Contoh: `PAYMENTS_9300051904_1000_TRX-PAYMENT-DUE-LIST-20260908-0001.xml`

## 1. Tujuan bisnis dan status repository

### 1.1 Tujuan bisnis

Fitur yang diminta adalah alur berikut:

1. Client terautentikasi mengirim request `POST` berisi data payment dalam JSON.
2. WSO2 Micro Integrator memvalidasi payload, correlation, dan idempotency.
3. Middleware memetakan JSON ke dokumen XML sesuai contoh/XSD resmi dari penerima.
4. XML dikirim sebagai file ke folder remote `payments` melalui koneksi FTP yang dikonfigurasi secara aman.
5. Client menerima hasil yang dapat dilacak melalui transaction ID, correlation ID, dan nama file tanpa menerima credential backend.

Keberhasilan HTTP sebaiknya berarti semantik delivery yang jelas: file sudah dipindahkan ke lokasi final, atau hanya diterima/staged. Arti `201` wajib disepakati sebelum kontrak publik dibuat.

### 1.2 CURRENT versus PROPOSED

| Area | CURRENT (terverifikasi di repository) | PROPOSED (panduan ini) |
|---|---|---|
| Payments | Tidak ditemukan API, sequence, endpoint, route, OpenAPI, atau konfigurasi bernama payments. | Service/domain baru untuk payments, pending approval. |
| Service | Root monorepo saat ini mendaftarkan enam module di `integrations/pom.xml`. | `integrations/payments-service` sebagai service terpisah, jika keputusan service-per-domain disetujui. |
| API FTP | `POST /api/vendors/create` memanggil `VendorCreateSeq`; `POST /api/spk/duelist` memanggil `SpkDuelistSeq`. | `POST /api/payments`, nama `PaymentsAPI`, scope `payments`; semuanya usulan. |
| FTP target | Vendor menggunakan `FTP_SAP_TARGET`/default domain `/vmd`; SPK menggunakan `FTP_SPK_TARGET`/default domain `/duelist`. | Target final harus dinormalisasi dan berakhir tepat pada `/payments`. |
| Shared flow | `AuthGuardSeq`, `LogRequestSeq`, `IdempotencyGuardSeq`, pencatatan DB, error handling, dan retry tersedia. | Reuse setelah code review dan penyesuaian payments. |
| Retry FTP | `SafeApiCallWithRetrySeq.xml` hanya mengenali `VendorFtpEndpoint` dan `SpkFtpEndpoint`. | Perlu perubahan runtime untuk `PaymentsFtpEndpoint`, atau flow khusus payments; bukan bagian task dokumentasi ini. |
| VFS | `platform/docker/deployment.toml.j2` memiliki `[transport.vfs]`, tetapi listener/sender default `false`; deployment service saat ini belum mengaktifkannya. | Aktivasi VFS harus menjadi keputusan deployment yang eksplisit. |
| Schema/OpenAPI | Tidak ada XSD payments dan tidak ada file OpenAPI formal saat inventaris dibuat. | Tambahkan XSD/OpenAPI hanya setelah kontrak dan runtime disetujui. |
| Config | `config.properties` Vendor dan SPK ada tetapi kosong pada inspeksi; template dan sequence memiliki mapping/fallback yang perlu diaudit. | Gunakan secret/config mechanism yang disetujui, tanpa credential di source. |

Referensi CURRENT yang mendasari tabel ini:

- `D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo\README.md`
- `D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo\docs\API_DEVELOPMENT_GUIDE.md`
- `D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo\docs\SOFTWARE_ARCHITECTURE_DOCUMENT.md`
- `D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo\docs\STRUKTUR_ARSITEKTUR.md`
- `D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo\integrations\vendor-service\src\main\wso2mi\artifacts\apis\VendorAPI.xml`
- `D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo\integrations\vendor-service\src\main\wso2mi\artifacts\sequences\VendorCreateSeq.xml`
- `D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo\integrations\spk-service\src\main\wso2mi\artifacts\apis\SpkAPI.xml`

Guide Vendor/SPK di luar folder `docs` hanya pola referensi assignment. Keberadaannya tidak membuktikan bahwa endpoint payments sudah berjalan dan mapping Vendor/SPK tidak boleh disalin sebagai kontrak payments.

## 2. Keputusan desain sementara dan asumsi

Keputusan berikut dipakai agar contoh guide konsisten, tetapi statusnya **pending approval**:

- **Service:** usulkan `integrations/payments-service`, bukan route tambahan pada `vendor-service`. Arsitektur repository memakai satu service/CAR per domain; memisahkan payments menjaga ownership, deployment, port, dan lifecycle Vendor tetap terpisah.
- **Route:** usulkan `POST /api/payments` dengan nama API `PaymentsAPI` dan scope `payments`. Final context, `uri-template`, operation name, dan scope harus disetujui.
- **Consumer:** gunakan aplikasi yang sudah terdaftar pada App Registry. Jangan menulis token baru di source, guide, OpenAPI, atau test fixture. App dan scope yang berhak menggunakan payments harus ditentukan oleh pemilik keamanan.
- **Envelope XML:** jangan mengklaim envelope VMD/SPK, namespace, konstanta header, atau `Key2` sebagai kontrak payments. Gunakan template usulan dengan `TBD` sampai SAP/ATLAS memberikan contoh XML dan XSD resmi.
- **Transport:** gunakan pola VFS yang sudah dipakai flow Vendor/SPK sebagai referensi teknis, tetapi konfirmasi FTP versus FTPS/SFTP, host, port, passive mode, parent directory, firewall/egress, serta permission.
- **Response:** gunakan guidance sementara `201` untuk hasil upload yang benar-benar selesai, `200` untuk replay sukses, dan status lain sesuai kondisi. Jangan mempublikasikannya sebagai kontrak sebelum disetujui.
- **Atomicity:** utamakan staging/temp lalu rename; kemampuan atomic rename WSO2 MI 4.6.0 dan server FTP belum terverifikasi pada repository.

## 3. Endpoint dan method yang diusulkan

### 3.1 Kontrak HTTP sementara

```text
POST <PAYMENTS_SERVICE_BASE_URL>/api/payments
Content-Type: application/json
Authorization: Bearer <TOKEN>
X-Correlation-Id: corr-example-0001
X-Transaction-Id: trx-example-0001
```

`<PAYMENTS_SERVICE_BASE_URL>` adalah placeholder, bukan URL produksi. Route `POST /api/payments` bukan endpoint runtime saat ini.

Header yang diusulkan:

| Header | Wajib | Aturan |
|---|---:|---|
| `Authorization` | Ya | Format `Bearer <TOKEN>`; token harus berasal dari App Registry dan memiliki scope yang disetujui. |
| `Content-Type` | Ya | `application/json`; reject media type yang tidak didukung. |
| `X-Correlation-Id` | Disarankan | ID tracing dari caller; batasi panjang/karakter dan echo pada response. Jika kosong, middleware dapat membuat ID baru sesuai pola shared flow. |
| `X-Transaction-Id` | Disarankan/keputusan | Key idempotency utama yang stabil. Keputusan apakah wajib untuk payments harus ditutup sebelum implementasi. |
| `X-Idempotency-Key` | Alternatif | Fallback jika `X-Transaction-Id` tidak dikirim; jangan menerima dua nilai berbeda tanpa aturan conflict. |
| `X-Retry-Interval-Seconds` | Opsional terbatas | Hanya bila security/operation menyetujuinya; validasi range dan jangan biarkan client mengubah retry tanpa batas. |
| `X-Forwarded-For` | Bukan identity | Hanya boleh dipakai dari proxy/load balancer yang ada dalam allowlist. Jangan mempercayai nilai yang dikirim langsung client. |

### 3.2 Alur usulan

```text
Client
  → PaymentsAPI (POST)
  → AuthGuardSeq
  → PaymentsCreateSeq
       → validasi + idempotency fence
       → JSON → XML + schema gate
       → PaymentsFtpEndpoint (staging/temp)
       → rename ke file final di /payments
       → audit + response
  → Client
```

## 4. Request JSON sintetis dan validasi

### 4.1 Contoh request accounting usulan

Contoh berikut **bukan kontrak resmi**, memakai data sintetis/non-PII, dan menggunakan `companyCodes` sebagai **ARRAY string** agar beberapa Company Code dapat dikirim tanpa kehilangan leading zeroes bila suatu saat diperlukan:

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

Nilai tabel sumber untuk Company Code adalah `1000,2000,6000, 7000`; representasi JSON di atas memisahkannya menjadi empat item array. Semua nama JSON ini **PROPOSED**. SAP/ATLAS harus menetapkan daftar field, arti bisnis, format, dan klasifikasi data sebelum sequence ditulis. Field generik `paymentId`, `documentNumber`, `amount`, `paymentDate`, dan `description` tidak lagi menjadi model utama.

### 4.2 Required, optional, dan TBD

| Field usulan | Status sementara | Validasi yang harus disepakati |
|---|---|---|
| `companyCodes` | Candidate required; ARRAY string | Array tidak kosong, item unik dan tidak kosong; setiap Company Code harus berada dalam allowlist resmi. Tetapkan apakah seluruh item diproses bersama dan bagaimana urutan dinormalisasi. |
| `accountingDocumentNumber` | Candidate required; STRING | Perlakukan sebagai string, bukan numeric, agar leading zeroes bila ada tetap terjaga; trim, panjang/karakter, uniqueness bisnis, dan larangan path separator harus ditetapkan. |
| `documentDate` | Candidate required; STRING | Input mengikuti format sumber `DD.MM.YYYY` (`08.09.2026`); validasi kalender dan dokumentasikan normalisasi ke format XML. |
| `postingDate` | Candidate required; STRING | Input mengikuti format sumber `DD.MM.YYYY` (`08.09.2026`); validasi kalender dan aturan hubungan dengan Document Date harus disetujui. |
| `businessArea` | Candidate required; STRING | Validasi terhadap allowlist/panjang Business Area resmi; contoh `1100`. |
| `currency` | Candidate required; STRING | Kode ISO 4217 uppercase yang diizinkan domain; contoh `IDR`. |
| `glAccount` | Candidate required; STRING | Tepat 10 digit untuk GL BK (GL account); jangan mengonversi ke number. Contoh `1114000000`. |
| `text` | Candidate required/optional; TBD | Trim, batas panjang resmi, dan XML-escaping untuk `&`, `<`, `>` serta karakter khusus harus ditetapkan. |
| `assignment` | Candidate required/optional; TBD | Trim, batas panjang resmi, dan XML-escaping untuk `&`, `<`, `>` serta karakter khusus harus ditetapkan. |

Validasi umum yang perlu diterapkan:

- Body harus berupa JSON object, tidak kosong, dan memiliki batas ukuran request yang eksplisit.
- JSON malformed, `Content-Type` salah, null pada field wajib, tipe salah, string kosong setelah trim, atau field di luar kontrak diperlakukan sesuai kebijakan `additionalProperties` yang disetujui; rekomendasi awal adalah reject field ekstra agar typo tidak diam-diam hilang.
- `companyCodes` harus array string dan setiap nilai harus cocok dengan allowlist Company Code. Jika satu request memuat beberapa nilai, jangan menimpa nilai sebelumnya atau diam-diam hanya memilih item pertama.
- `accountingDocumentNumber` dan `glAccount` wajib diparse sebagai string; jangan memakai konversi numerik yang dapat menghapus leading zeroes pada nomor dokumen.
- `documentDate` dan `postingDate` diterima sebagai `DD.MM.YYYY`. Contoh `08.09.2026` dinormalisasi secara eksplisit menjadi `2026-09-08` pada XML contoh; implementasi tidak boleh melakukan konversi diam-diam dan format final harus mengikuti XSD resmi.
- `businessArea` harus mengikuti panjang dan allowlist domain yang disepakati; `currency` harus berupa kode ISO uppercase yang diizinkan, bukan string bebas.
- `text` dan `assignment` harus memiliki batas panjang resmi, di-escape saat dibentuk menjadi XML, dan tidak boleh mengandung markup mentah.
- Karakter `&`, `<`, `>`, quote, apostrophe, unicode, dan newline harus diuji sebagai data, bukan dihapus secara diam-diam.
- Batas panjang body, field, dan jumlah item `companyCodes` harus dikonfigurasi dan diuji.

## 5. Correlation, idempotency, dan duplicate handling

### 5.1 Perilaku CURRENT shared flow

`D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo\shared\src\main\wso2mi\artifacts\sequences\AuthGuardSeq.xml` saat ini membaca `X-Correlation-Id`; bila kosong, membuat ID berbasis waktu; lalu meneruskan `X-Correlation-Id` pada transport. Sequence tersebut juga memeriksa format Bearer, token yang dikonfigurasi, dan `requiredScope`.

`D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo\shared\src\main\wso2mi\artifacts\sequences\IdempotencyGuardSeq.xml` saat ini:

1. memprioritaskan `X-Transaction-Id`;
2. fallback ke `X-Idempotency-Key`;
3. membuat ID berbasis timestamp jika keduanya kosong;
4. membaca `api_transaction`;
5. mengembalikan replay untuk status `SUCCESS` tanpa upload ulang;
6. mengembalikan `409` untuk status `PROCESSING`;
7. menandai request baru sebagai `PROCESSING`;
8. mengatur default maksimum 3 attempt dan interval 60 detik, yang dapat berasal dari konfigurasi.

Pencatatan ini didukung oleh tabel pada `D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo\scripts\db\init_mariadb_schema.sql`. Status, response payload, attempt, dan retry schedule harus diperlakukan sebagai audit data yang dilindungi.

### 5.2 Policy PROPOSED untuk payments

- Gunakan `X-Transaction-Id` sebagai key utama; fallback ke `X-Idempotency-Key` hanya bila kebijakan menyetujuinya.
- Normalisasi/validasi key sebelum menyimpannya. Batasi panjang, karakter kontrol, delimiter berbahaya, dan perbedaan case sesuai keputusan.
- Derive nama file secara deterministik dari transaction ID yang sudah disanitasi. Jangan memberi client kontrol bebas melalui `X-File-Name` tanpa allowlist dan validasi path traversal.
- Untuk key sama dan request sama, hasil sukses harus replay tanpa upload kedua. Response replay usulan adalah `200` dengan `X-Idempotent-Replay: true`.
- Untuk key yang sedang `PROCESSING`, kembalikan `409` atau policy polling yang disepakati; jangan memulai upload paralel.
- Jika key sama digunakan untuk payload berbeda, deteksi fingerprint/payload conflict dan tetapkan response (disarankan `409`), bukan menganggapnya replay.
- Putuskan apakah key wajib untuk payments. Timestamp fallback CURRENT tidak menjamin stabilitas lintas retry/client dan dapat menyulitkan recovery.
- Tetapkan retention replay, lease/expiry status `PROCESSING`, recovery untuk process crash, serta siapa yang boleh melakukan manual replay.

## 6. JSON → XML: mapping, naming, encoding, escaping, schema

### 6.1 Mapping accounting usulan dengan status PROPOSED/TBD

Mapping berikut adalah template diskusi. Nama JSON dan tag XML semuanya **PROPOSED**; nama tag final wajib mengikuti kontrak XML/XSD resmi SAP/ATLAS.

| Nama semantic tabel | JSON usulan (PROPOSED) | XML tag usulan (PROPOSED/TBD) | Aturan sementara |
|---|---|---|---|
| Company Code | `companyCodes` (ARRAY string) | `<CompanyCode>` berulang | Satu item array menjadi satu elemen. Allowlist dan cardinality final harus disetujui. |
| Nomor acc document | `accountingDocumentNumber` | `<AccountingDocumentNumber>` | String; pertahankan leading zeroes bila ada. |
| Document Date | `documentDate` | `<DocumentDate>` | Input `DD.MM.YYYY`; normalisasi XML terdokumentasi sesuai XSD. |
| Posting Date | `postingDate` | `<PostingDate>` | Input `DD.MM.YYYY`; normalisasi XML terdokumentasi sesuai XSD. |
| Business Area | `businessArea` | `<BusinessArea>` | Validasi terhadap aturan domain resmi. |
| Currency | `currency` | `<Currency>` | Kode ISO 4217 uppercase. |
| GL BK (GL account) | `glAccount` | `<GLBK>` | String tepat 10 digit. |
| Text | `text` | `<Text>` | Escape XML dan patuhi batas panjang. |
| Assignment | `assignment` | `<Assignment>` | Escape XML dan patuhi batas panjang. |

Final XML tag names must follow the official SAP/ATLAS XML/XSD contract. Jangan mengambil mapping Vendor atau SPK sebagai mapping payments. `VendorCreateSeq.xml` dan `SpkDuelistXmlXslt.xml` hanya menunjukkan pola teknis yang dapat dipelajari.

Dua opsi envelope yang harus diputuskan SAP/ATLAS:

1. envelope bergaya ATLAS seperti `Transaction/Header/TransactionDatas`; atau
2. schema payments yang berbeda dengan root, namespace, cardinality, ordering, dan nama tag sendiri.

### 6.2 Contoh XML accounting usulan

Contoh berikut menunjukkan **satu XML dengan elemen `<CompanyCode>` berulang** untuk empat company code. Root, namespace, `schemaVersion`, dan semua tag adalah **PROPOSED/TBD** sampai schema resmi supplied oleh SAP/ATLAS:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<PaymentAccountingDocument xmlns="urn:example:payments:TBD" schemaVersion="TBD">
  <CompanyCode>1000/2000/6000/7000</CompanyCode>
  <AccountingDocumentNumber>9300051904</AccountingDocumentNumber>
  <DocumentDate>2026-09-08</DocumentDate>
  <PostingDate>2026-09-08</PostingDate>
  <BusinessArea>1100</BusinessArea>
  <Currency>IDR</Currency>
  <GLBK>1114000000</GLBK>
  <Text>PBY BENGKEL REFF 3400082380 DLL</Text>
  <Assignment>PT PRABU PENDAWA M</Assignment>
</PaymentAccountingDocument>
```

Rekomendasi sementara adalah **satu XML dengan repeated elements `<CompanyCode>`**, bukan satu XML per Company Code, karena satu accounting document dapat dilacak sebagai satu payload. Namun cardinality dan arti bisnis beberapa Company Code belum diverifikasi; keputusan “multiple XML versus repeated element” tetap **unresolved business decision** yang harus diputuskan oleh SAP/ATLAS/pemilik domain. Jika kontrak resmi memilih satu dokumen per Company Code, idempotency dan filename harus diubah agar setiap dokumen memiliki key deterministik.

`08.09.2026` pada input tidak disalin mentah ke contoh XML: secara eksplisit dinormalisasi menjadi `2026-09-08`. Jangan menerapkan konversi selain yang disepakati XSD.

### 6.3 Aturan output

- Sertakan XML declaration dengan encoding UTF-8 sesuai kontrak.
- Hasil harus well-formed, tanpa BOM atau encoding campuran yang tidak disepakati.
- Pertahankan casing tag, namespace, urutan elemen, cardinality, decimal format, dan date format sesuai XSD resmi.
- Escape nilai text: `&` menjadi `&amp;`, `<` menjadi `&lt;`, `>` menjadi `&gt;`; quote/apostrophe juga harus di-escape bila berada dalam attribute.
- Jangan melakukan string concatenation mentah dari input client. Gunakan `payloadFactory` berparameter, XML builder, atau XSLT terparameterisasi. Pola yang dapat ditinjau ada pada `D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo\integrations\vendor-service\src\main\wso2mi\artifacts\sequences\VendorCreateSeq.xml`, `D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo\integrations\spk-service\src\main\wso2mi\artifacts\local-entries\SpkDuelistXmlXslt.xml`, dan `D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo\shared\src\main\wso2mi\artifacts\local-entries\XmlPrettyPrintXslt.xml`.
- Jangan membentuk XML dari input yang mengandung markup tanpa escaping dan validation; cegah XML injection.
- XSD payments belum ada. Sebelum XSD resmi tersedia, hanya business validation dan well-formedness yang boleh diklaim. Setelah XSD tersedia, schema validation harus menjadi gate sebelum upload.

## 7. Filename dan aturan naming idempotency

Usulan dan format yang disetujui:

```text
PAYMENTS_<accountingDocumentNumber>_<companyCode>_<transactionId>.xml
```

Contoh: `PAYMENTS_9300051904_1000_TRX-PAYMENT-DUE-LIST-20260908-0001.xml`.

Komponen format penamaan:
1. `PAYMENTS_` : Prefix domain service payments.
2. `<accountingDocumentNumber>` : Nomor dokumen accounting yang diekstrak dari payload JSON (mis. `9300051904`).
3. `<companyCode>` : Kode perusahaan pengirim yang diekstrak dari `companyCode` atau elemen pertama/utama dari `companyCodes` (mis. `1000` dari `1000/2000/6000/7000`).
4. `<transactionId>` : Identifier transaksi/idempotency yang unik (mis. `TRX-PAYMENT-DUE-LIST-20260908-0001`).
5. `.xml` : Ekstensi file format XML.

Nama tersebut memungkinkan penelusuran accounting document number, company code, dan transaction ID secara deterministik tanpa menaruh secret.

Aturan yang harus ditetapkan:

- Hanya gunakan karakter allowlist, misalnya huruf, angka, titik, underscore, dan hyphen; exact allowlist, case, panjang maksimum, serta normalisasi Unicode harus disetujui.
- Tolak atau encode path separator, `..`, control character, wildcard, dan nama reserved platform.
- Jangan menerima nama file bebas dari client sebagai default. Jika SAP mewajibkan accounting document number/company code, tetapkan transformasi dan collision policy secara resmi.
- Nama harus deterministik untuk key idempotency yang sama dan konsisten di semua instance/node.
- Retry dengan key yang sama harus memakai nama final yang sama dan melakukan existence check sebelum membuat file baru.
- Jika file final sudah ada, bandingkan transaction ID/fingerprint bila metadata tersedia. Jangan menimpa file yang berbeda tanpa kebijakan eksplisit.
- Putuskan apakah nama memakai accounting document number, company code, transaction ID, timestamp, sequence counter, atau kombinasi. Pola `VMD_*` dan `SPK_Duelist_*` adalah contoh existing, bukan kontrak payments.
- Tentukan panjang maksimum path dan filename yang didukung FTP server, serta cleanup untuk file temp/orphan.

## 8. Koneksi FTP dan komposisi remote path

### 8.1 Placeholder dan variable names

Format konseptual VFS dengan placeholder:

```text
vfs:ftp://<FTP_USERNAME>:<FTP_PASSWORD>@<FTP_HOST>:<FTP_PORT>/<normalized-remote-path>
```

Ini hanya ilustrasi format, bukan anjuran menaruh credential literal di URI. Credential harus diambil dari secret mechanism dan tidak boleh muncul di log, source, OpenAPI, exception, atau response.

Nama environment payments yang diusulkan dan **belum ada** pada `.env` saat inspeksi:

```text
FTP_PAYMENTS_HOST
FTP_PAYMENTS_PORT
FTP_PAYMENTS_TARGET
FTP_PAYMENTS_USERNAME
FTP_PAYMENTS_PASSWORD
```

`FTP_SAP_*` dan `FTP_SPK_*` adalah nama CURRENT untuk domain existing; jangan menggunakannya diam-diam untuk payments. Source yang menunjukkan mapping current adalah `D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo\platform\docker\deployment.toml.j2` dan `D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo\docker-compose.yml`.

Precedence yang diusulkan: environment/secret → system parameter/deployment → `config.properties`, dengan validasi bahwa secret wajib tersedia dan tidak menggunakan fallback credential produksi. Nama payments perlu dipetakan secara eksplisit pada deployment yang disetujui.

### 8.2 Path final wajib `payments`

Komposisi yang diharapkan:

```text
<REMOTE_BASE>/payments/<FILE_NAME>
```

Normalisasi harus:

1. menghapus slash ganda yang tidak diperlukan;
2. menggabungkan parent dengan satu separator;
3. menolak `..`, path traversal, absolute path tak terduga, null byte, dan override URL dari client;
4. memastikan segment terakhir folder adalah tepat `payments` sebelum filename;
5. memastikan hasil tidak menjadi `/payments/payments` karena konfigurasi ganda;
6. mencatat remote path yang sudah disanitasi tanpa username/password.

Contoh expected berbasis konfigurasi: `<REMOTE_BASE>/payments/PAYMENTS_9300051904_1000_TRX-PAYMENT-DUE-LIST-20260908-0001.xml`. Path Vendor `/vmd` dan SPK `/duelist` yang ada saat ini bukan target payments.

Konfirmasi operasional yang wajib:

- FTP, FTPS, atau SFTP; preferensi produksi adalah SFTP/FTPS bila didukung organisasi.
- Host/port, passive mode, connect/read/upload/rename timeout, firewall, egress allowlist, certificate/host-key verification, directory existence, dan write/rename permission.
- Apakah server membuat subdirectory otomatis atau operator harus membuat `payments` terlebih dahulu.
- Apakah `PaymentsFtpEndpoint` mendukung destination dinamis, staging, dan rename pada WSO2 MI 4.6.0.

## 9. Atomic upload dan temporary-file strategy

### 9.1 Strategi utama usulan

Untuk mencegah consumer membaca file parsial:

1. Bentuk XML lengkap di memory/temp lokal dengan batas ukuran yang aman.
2. Upload ke `payments/.staging/<filename>.tmp` atau suffix temp yang disepakati.
3. Verifikasi transfer selesai dan ukuran/checksum bila server mendukung.
4. Rename/move ke `payments/<filename>`.
5. Update status transaksi menjadi `SUCCESS` hanya setelah langkah final yang didefinisikan sebagai delivery selesai.

Repository saat ini tidak menunjukkan staging/rename Vendor atau SPK. Karena itu, atomicity di atas **belum terverifikasi** untuk WSO2 MI 4.6.0 dan FTP server yang akan dipakai.

### 9.2 Jika rename tidak didukung

Jika VFS/FTP server tidak menjamin rename atomic:

- Jangan menjanjikan atomic delivery pada response atau OpenAPI.
- Gunakan suffix `.tmp`/directory `.staging` dan minta consumer SAP mengabaikannya sampai file final tersedia; ini perlu persetujuan consumer.
- Alternatif operasional, seperti upload langsung final name, harus mendokumentasikan risiko partial read dan retry duplicate.
- Uji behavior rename lintas server, permission, dan koneksi yang terputus sebelum memilih strategi.

Recovery dan cleanup:

- Hapus temp setelah rename berhasil.
- Catat dan bersihkan orphan temp berdasarkan age/transaction policy; jangan menghapus file final tanpa ownership.
- Retry rename terpisah dari retry upload, dengan idempotency fence.
- Tangani final file sudah ada, permission denied, folder staging hilang, disconnect setelah upload, dan crash di antara upload dan database update.
- Metrics/log minimum: staging started/completed, rename started/completed/failed, orphan cleanup, byte count, checksum bila tersedia, dan correlation/transaction ID.

## 10. Success/error response dan HTTP status guidance

Semua response di bagian ini **PROPOSED**, bukan runtime contract.

### 10.1 Sukses

Jika definisi sukses adalah file final telah tersedia di remote folder:

```http
HTTP/1.1 201 Created
X-Correlation-Id: corr-example-0001
Content-Type: application/json
```

```json
{
  "success": true,
  "message": "Payload accepted and delivered",
  "transactionId": "TRX-PAYMENT-DUE-LIST-20260908-0001",
  "fileName": "PAYMENTS_9300051904_1000_TRX-PAYMENT-DUE-LIST-20260908-0001.xml"
}
```

Nilai di atas mencerminkan response sukses standar WSO2 MI Shared `SafeApiCallWithRetrySeq.xml` (HTTP 201 Created). Idempotency replay mengembalikan HTTP 200 dengan payload yang sama.

### 10.2 Status yang diusulkan

| Status | Kondisi |
|---:|---|
| `201` | XML berhasil di-upload dan mencapai semantik delivery yang disepakati. |
| `200` | Replay idempotency sukses; sertakan `X-Idempotent-Replay: true`. |
| `400` | JSON malformed, content type/field/type/range/date invalid, XML tidak valid, schema gagal, filename/path invalid, atau field ekstra ditolak. |
| `401` | Authorization tidak ada, format bukan Bearer, atau token invalid. |
| `403` | Token valid tetapi tidak memiliki scope `payments`. |
| `409` | Transaction sedang diproses, payload berbeda memakai key sama, atau duplicate final file tidak dapat diputuskan otomatis. |
| `502` | FTP/backend gagal setelah retry atau koneksi/permission menandakan bad gateway sesuai policy. |
| `504` | Connect/read/upload/rename timeout setelah policy retry. |
| `500` | Error internal, konfigurasi tidak lengkap, atau kondisi yang tidak terklasifikasi. |

Format error mengikuti bentuk CURRENT `D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo\shared\src\main\wso2mi\artifacts\sequences\ErrorResponseSeq.xml`:

```json
{
  "error": true,
  "message": "Bad Request",
  "detail": "Deskripsi aman tanpa credential atau payload sensitif"
}
```

Jangan menambahkan `accountingDocumentNumber`, `companyCodes`, `fileName`, atau detail backend sebagai fakta kontrak publik sebelum disetujui. Error detail harus aman untuk client dan tidak membocorkan host, credential, token, stack trace, atau konfigurasi internal.

## 11. Retry, timeout, duplicate, dan failure recovery

### 11.1 CURRENT yang perlu dipahami

`IdempotencyGuardSeq.xml` dan schema DB memperlihatkan default maksimum 3 attempt dan interval 60 detik. Tabel `api_transaction` memiliki status `PENDING`, `PROCESSING`, `SUCCESS`, `RETRY`, dan `FAILED`, serta `next_retry_at`; `api_transaction_log` menyimpan attempt, status response, error, dan duration. Endpoint `VendorFtpEndpoint.xml` dan `SpkFtpEndpoint.xml` saat ini memiliki timeout 30.000 ms, tetapi angka ini **bukan otomatis policy payments**.

`SafeApiCallWithRetrySeq.xml` menerima `X-Retry-Interval-Seconds` dan saat ini hanya memiliki branch endpoint Vendor/SPK untuk FTP. Jangan menyatakan payments sudah memakai flow tersebut tanpa perubahan dan test runtime.

### 11.2 Policy yang harus diimplementasikan setelah disetujui

Bedakan error berikut:

- **Retryable:** connection timeout/reset, transient network failure, temporary FTP 5xx/service unavailable, dan rename timeout yang aman diulang.
- **Non-retryable:** JSON/business/schema invalid, credential/authentication failed, permission denied, invalid remote path, unsupported protocol, certificate/host-key failure, dan filename policy violation.

Sebelum upload:

1. Validasi request dan schema.
2. Buat idempotency fence di DB.
3. Periksa apakah final file sudah ada dan cocok dengan transaction/fingerprint.
4. Upload dengan attempt dan timeout yang tercatat.
5. Rename sesuai strategi atomik.
6. Update audit transaction setelah outcome yang didefinisikan.

Tetapkan secara eksplisit:

- connect, read, upload, dan rename timeout;
- maximum attempts, backoff/jitter, interval, serta apakah client boleh memberi interval terbatas;
- retry hanya pada tahap yang aman dan tidak menyebabkan duplicate final file;
- status setelah process crash antara transfer, rename, dan update database;
- cara recovery `PROCESSING` stale, orphan temp, dan transaction `FAILED`/`RETRY`;
- manual replay/dead-letter ownership, approval, dan evidence yang harus dicatat.

`SafeApiCallWithRetrySeq.xml` harus diperluas untuk mengenali `PaymentsFtpEndpoint`, atau dibuat flow payments khusus. Itu adalah perubahan runtime masa depan yang harus direncanakan, direview, dan diuji; task ini tidak mengubahnya.

## 12. Observability dan audit

### 12.1 Shared flow dan data yang ada

- `D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo\shared\src\main\wso2mi\artifacts\sequences\LogRequestSeq.xml` membuat structured log berisi timestamp, correlation ID, app ID, endpoint, dan params. Untuk payments, mask atau hilangkan password, bearer token, payload sensitif, rekening, PII, dan field yang tidak diperlukan.
- `DbRecordAttemptLogSeq.xml` dan `DbRecordTransactionSeq.xml` adalah pola pencatatan attempt/status yang perlu direview untuk payments.
- `D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo\scripts\db\init_mariadb_schema.sql` mendefinisikan `api_transaction` dan `api_transaction_log`, termasuk transaction ID, request/response payload, status, attempt, retry schedule, HTTP status, error, dan duration.
- `AuthGuardSeq.xml` menyediakan correlation/app context; `ErrorResponseSeq.xml` meneruskan correlation ID pada error.

### 12.2 Minimum observability yang diusulkan

Event/metric terstruktur:

- request received;
- authentication/scope passed or rejected;
- validation passed/failed;
- XML built, byte count, well-formed/schema validation result;
- idempotency new, replay, payload conflict, in-flight conflict;
- FTP staging started/completed;
- final rename started/completed;
- delivered, retry scheduled, retry attempted, timeout, FTP failure, final failure;
- latency per tahap, total duration, attempt count, dan cleanup outcome.

Label yang boleh digunakan: correlation ID, transaction/idempotency key, sanitized filename, endpoint, status, attempt, dan payment/document ID hanya jika klasifikasi data mengizinkan. Remote path harus disanitasi dan tidak mengandung credential.

Tentukan retention log/audit, access control, masking, encryption at rest/in transit, alert threshold, dashboard, correlation dengan FTP server, dan prosedur audit. Payload penuh sebaiknya tidak disimpan/log bila tidak dibutuhkan; gunakan hash/fingerprint untuk duplicate comparison bila memadai.

## 13. Security dan secret handling

### 13.1 Aturan secret

Jangan pernah menyalin atau menulis nilai dari `.env`. Gunakan nama variabel saja dan placeholder berikut dalam source contoh:

```text
<FTP_HOST>
<FTP_PORT>
<FTP_USERNAME>
<FTP_PASSWORD>
<TOKEN>
<PAYMENTS_SERVICE_BASE_URL>
```

Tidak ada nilai credential nyata dalam guide ini. Sebelum merge, scan file ini dan diff untuk secret-like value, URL credential, token, password, API key, atau PII.

### 13.2 Kontrol yang diperlukan

- Gunakan WSO2 Secure Vault, Kubernetes Secret, atau secret manager organisasi; jangan menyimpan secret pada API XML, sequence, POM, OpenAPI example, test output, log, atau VFS URI literal.
- Gunakan FTP account least privilege yang hanya dapat menulis/rename pada area yang diperlukan; pisahkan account per environment dan rotation policy.
- Pilih SFTP/FTPS untuk produksi bila disetujui, verifikasi host key/certificate, dan batasi egress ke host/port yang di-allowlist.
- Hindari fallback credential/default credential sebagai pola produksi. `config.properties` Vendor/SPK kosong pada inspeksi, tetapi template/sequence memiliki fallback dan mapping yang harus diaudit sebelum dijadikan pola baru.
- Validasi `X-Forwarded-For` hanya dari trusted proxy; jangan jadikan header client sebagai identity.
- Terapkan bearer scope `payments`, replay protection, body-size limit, XML escaping/schema validation, dan path traversal prevention.
- Jangan izinkan client memasukkan URL FTP, host, port, atau remote path arbitrer; cegah SSRF dan override destination.
- Batasi permission file/temp lokal dan remote; jangan menulis payload sensitif pada exception.
- `[transport.vfs]` pada `D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo\platform\docker\deployment.toml.j2` default sender/listener-nya `false`; mengaktifkannya adalah keputusan deployment eksplisit, bukan asumsi dari guide.

## 14. Local testing dan negative tests

### 14.1 Build dan runtime yang tersedia

Dari root `D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo`:

```powershell
mvn clean install
```

Pola targeted build yang tercantum di README:

```powershell
mvn -pl shared -am install
mvn -pl integrations/<service> -am package
```

Runtime local existing:

```powershell
docker compose up --build
```

Payments service, port Compose, environment mapping, dan image belum ada. Perintah di atas tidak membuktikan payments berjalan sampai implementasi future menambah wiring secara terpisah. `test_all.ps1` saat ini menguji Vendor/SPK dan service lain, bukan payments.

Untuk task ini tidak ada payments runtime yang dapat diuji. Setelah implementasi tersedia, gunakan FTP test double/sandbox yang dikontrol, bukan FTP produksi.

### 14.2 Contoh request PowerShell sintetis

```powershell
$headers = @{
    Authorization = 'Bearer <TOKEN>'
    'Content-Type' = 'application/json'
    'X-Correlation-Id' = 'corr-example-0001'
    'X-Idempotency-Key' = 'trx-example-0001'
}

$body = @{
    companyCodes = @('1000', '2000', '6000', '7000')
    accountingDocumentNumber = '9300051904'
    documentDate = '08.09.2026'
    postingDate = '08.09.2026'
    businessArea = '1100'
    currency = 'IDR'
    glAccount = '1114000000'
    text = 'PBY BENGKEL REFF 3400082380 DLL'
    assignment = 'PT PRABU PENDAWA M'
} | ConvertTo-Json

Invoke-RestMethod `
  -Uri '<PAYMENTS_SERVICE_BASE_URL>/api/payments' `
  -Method Post `
  -Headers $headers `
  -Body $body
```

Expected status `201` hanya **proposed** untuk upload final yang sukses. Uji juga replay dengan key sama (proposed `200`), bukan hanya response pertama.

### 14.3 Verifikasi happy path

Dengan sandbox FTP terkontrol, buktikan:

- auth dan scope benar;
- JSON tervalidasi;
- XML well-formed dan UTF-8;
- XSD valid bila XSD resmi sudah tersedia;
- remote path final berakhir `payments`;
- file temp/staging berpindah ke final sesuai semantics;
- filename deterministic;
- request replay tidak membuat file kedua;
- audit DB memiliki transaction/attempt/status/duration;
- log tidak membocorkan secret/PII;
- orphan temp dan cleanup dapat diverifikasi.

### 14.4 Negative test matrix

| Skenario | Expected guidance |
|---|---|
| Authorization hilang/salah format/token invalid | `401`; tidak ada upload. |
| Token valid tanpa scope `payments` | `403`; tidak ada upload. |
| Body kosong atau JSON malformed | `400`; tidak ada XML/file. |
| Field wajib hilang/null atau tipe salah | `400`. |
| `accountingDocumentNumber` kosong, numeric, atau formatnya tidak valid | `400`. |
| Company Code kosong, duplikat, atau di luar allowlist | `400`. |
| `documentDate`/`postingDate` bukan `DD.MM.YYYY` atau tanggal kalender tidak valid | `400`. |
| Currency tidak dikenal atau `glAccount` bukan 10 digit | `400`. |
| Field ekstra atau body terlalu besar | `400`/status policy yang disetujui. |
| XML special characters (`&`, `<`, `>`, quote) | XML tetap well-formed dan escaped; reject bila mapping/schema gagal. |
| XML mapping/schema invalid | `400`; tidak ada upload. |
| FTP config missing | `500`/`502` sesuai klasifikasi; secret tidak tampil. |
| Credential salah atau permission denied | non-retryable `502`/status policy; retry terbatas/tidak ada. |
| Host tidak reachable atau network timeout | retry sampai policy; final `502`/`504`. |
| Remote folder `payments` tidak ada | gagal aman atau create sesuai policy; jangan upload ke folder lain. |
| Rename gagal | status failure/retry rename; temp cleanup dan audit wajib. |
| Duplicate in-flight | `409`; satu upload maksimum. |
| Replay key sukses | `200`, replay header, tidak ada upload ulang. |
| Payload berbeda dengan key sama | `409`/policy conflict; tidak menimpa file. |
| Retry exhaustion | status `FAILED`, audit lengkap, manual recovery. |
| Crash/restart setelah upload sebelum DB update | recovery check final file + idempotency fence; tidak membuat duplicate. |
| Secret leakage scan | build/CI gagal bila token/password/API key muncul pada source/log/example. |

## 15. Struktur artefak WSO2 MI dan step-by-step implementation mapping

Bagian ini adalah **rencana implementasi masa depan**, bukan instruksi untuk mengubah runtime dalam task dokumentasi ini.

### Langkah 1 — Service dan build

Buat `D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo\integrations\payments-service\` mengikuti pola `vendor-service`/`spk-service`: POM, source WSO2 MI, CAR, Dockerfile, deployment, resources, dan port unik. Tambahkan module ke `D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo\integrations\pom.xml` hanya setelah keputusan service baru disetujui. Tambahkan service pada `docker-compose.yml` dan matrix CI/CD jika memang dipilih.

### Langkah 2 — API XML

Buat file future:

```text
integrations/payments-service/src/main/wso2mi/artifacts/apis/PaymentsAPI.xml
```

Isinya kelak harus memetakan context/URI yang disetujui, `POST`, property `requiredScope=payments`, `AuthGuardSeq`, `PaymentsCreateSeq`, dan `ErrorResponseSeq` pada fault path. Jangan menganggap route ini current.

### Langkah 3 — Domain sequence

Buat:

```text
integrations/payments-service/src/main/wso2mi/artifacts/sequences/PaymentsCreateSeq.xml
```

Sequence masa depan harus memiliki urutan yang dapat direview: capture JSON secukupnya, validate content/fields, set API endpoint, correlation/idempotency/log, deterministic filename, JSON→XML, well-formed/schema validation, staging upload, final rename, response, dan update transaction status. Payload sensitif tidak boleh disalin ke log tanpa masking.

### Langkah 4 — Shared sequences

Review dan reuse:

```text
shared/src/main/wso2mi/artifacts/sequences/AuthGuardSeq.xml
shared/src/main/wso2mi/artifacts/sequences/LogRequestSeq.xml
shared/src/main/wso2mi/artifacts/sequences/IdempotencyGuardSeq.xml
shared/src/main/wso2mi/artifacts/sequences/DbRecordAttemptLogSeq.xml
shared/src/main/wso2mi/artifacts/sequences/DbRecordTransactionSeq.xml
shared/src/main/wso2mi/artifacts/sequences/ErrorResponseSeq.xml
shared/src/main/wso2mi/artifacts/sequences/SafeApiCallWithRetrySeq.xml
shared/src/main/wso2mi/artifacts/sequences/ApiCallErrorHandlerSeq.xml
```

`SafeApiCallWithRetrySeq.xml` harus diubah atau digantikan agar mengenali `PaymentsFtpEndpoint`; perubahan ini adalah runtime change terpisah, dengan code review dan test.

### Langkah 5 — XML transform dan resource

Tambahkan local entry/XSLT/payloadFactory berdasarkan XSD resmi, mengikuti pola teknis yang dapat ditinjau pada `SpkDuelistXmlXslt.xml` dan `XmlPrettyPrintXslt.xml`. Tambahkan validator XSD hanya setelah file XSD payments resmi tersedia dan lifecycle-nya disetujui.

### Langkah 6 — FTP endpoint

Buat:

```text
integrations/payments-service/src/main/wso2mi/artifacts/endpoints/PaymentsFtpEndpoint.xml
```

Ikuti pola timeout/fault existing sebagai baseline, tetapi verifikasi cara VFS melakukan upload, temp destination, dan rename pada MI 4.6.0 serta FTP server target. Jangan menyalin timeout 30 detik sebagai keputusan tanpa uji beban/operasional.

### Langkah 7 — Config dan endpoint destination

Petakan nama usulan berikut melalui deployment/system parameter atau secret mechanism:

```text
FTP_PAYMENTS_HOST
FTP_PAYMENTS_PORT
FTP_PAYMENTS_TARGET
FTP_PAYMENTS_USERNAME
FTP_PAYMENTS_PASSWORD
```

Pastikan final URI tersusun ke remote folder `/payments`, tidak menerima URL/path override client, dan tidak mengandung secret di source. Mapping perlu ditambahkan ke template/deployment yang benar setelah keputusan transport dan secret selesai.

### Langkah 8 — Deployment

Aktifkan VFS sender pada deployment yang benar secara eksplisit, deploy CAR payments bersama `shared-artifacts` CAR, atur egress, Secret, FTP permission, certificate/host key, dan bedakan Docker local dengan Kubernetes. Verifikasi port service, health/readiness, rollout, dan config render tanpa mencetak secret.

### Langkah 9 — Tests dan docs

Tambahkan unit, integration dengan FTP test double, smoke, negative, replay, crash-recovery, XML well-formed/XSD, path, dan secret scan. Perbarui OpenAPI, README/reference link, serta evidence PR hanya pada implementation PR mendatang. `test_all.ps1` tidak boleh disebut lulus untuk payments sebelum scenario payments benar-benar ditambahkan dan dijalankan.

## 16. Guidance pembaruan OpenAPI/Swagger

Ikuti source-of-truth pada `D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo\docs\API_DEVELOPMENT_GUIDE.md`: API XML → domain sequence → shared sequence → test script → feature documentation. OpenAPI tidak boleh mendahului kontrak runtime yang disetujui.

File yang diusulkan setelah runtime siap:

```text
D:\ASSA\Development\Middleware\middleware\wso2-mi-monorepo\docs\openapi\payments-service.yaml
```

Jangan membuat file tersebut dalam task ini. Saat nanti dibuat, request schema harus merepresentasikan model accounting berikut sebagai model utama (semua nama **PROPOSED** sampai kontrak disetujui): `companyCodes` sebagai array string untuk Company Code multipel, `accountingDocumentNumber` sebagai string, `documentDate` dan `postingDate` sebagai string sumber `DD.MM.YYYY` dengan aturan normalisasi XML terdokumentasi, `businessArea`, `currency`, `glAccount` string 10 digit, `text`, dan `assignment`. Field generik `paymentId`, `documentNumber`, `amount`, `paymentDate`, dan `description` tidak boleh dipakai sebagai primary schema. Final JSON/XML names dan tag wajib mengikuti kontrak resmi SAP/ATLAS/XML/XSD.

Saat nanti dibuat:
- pakai `operationId` stabil, misalnya `createPayment` setelah disetujui;
- dokumentasikan `POST /api/payments`, requestBody JSON dengan `companyCodes` array, `accountingDocumentNumber` string, `documentDate`/`postingDate` sumber `DD.MM.YYYY`, `businessArea`, `currency`, `glAccount` string 10 digit, `text`, dan `assignment`; sertakan required/optional constraints, enum, max size, serta synthetic examples;
- gunakan bearer security dengan scope `payments`;
- dokumentasikan `X-Correlation-Id`, `X-Transaction-Id`/`X-Idempotency-Key`, replay header, serta response `201/200/400/401/403/409/502/504` yang benar-benar diverifikasi;
- gunakan error schema `error`, `message`, `detail` sesuai runtime setelah diverifikasi;
- jelaskan side effect file delivery dan delivery semantics yang sebenarnya, tanpa menjanjikan atomicity yang belum dibuktikan;
- jangan dokumentasikan credential FTP, bearer token, URL internal, nama secret, password, atau detail backend yang tidak publik;
- validasi repository dengan `mvn -B validate` dan gunakan linter OpenAPI yang pinned sesuai keputusan CI setelah file tersedia.

OpenAPI tidak menjadi source of truth untuk XML internal atau credential FTP; source of truth route/method tetap API XML dan behavior sequence yang berjalan.

## 17. PR checklist

- [ ] Banner CURRENT/PROPOSED dan status belum implemented tetap jelas.
- [ ] Service, route, scope, payload, XML, response, dan delivery semantics ditandai proposed sampai sign-off.
- [ ] Semua contoh data sintetis; tidak ada secret, token, password, API key, URL credential, atau PII nyata.
- [ ] Nama variable current dan proposed dipisahkan; `FTP_PAYMENTS_*` tidak diklaim sudah ada.
- [ ] Komposisi remote path tervalidasi dan hasil final berakhir `/payments`; traversal ditolak.
- [ ] XML declaration, UTF-8, escaping, well-formedness, dan status XSD dijelaskan.
- [ ] Temp/staging/rename, keterbatasan non-atomic, cleanup, retry, duplicate, dan recovery diuji.
- [ ] Auth, scope, correlation, idempotency, replay, audit, log masking, metric, timeout, error status, dan security covered.
- [ ] Artifact path API XML, domain sequence, shared sequence, transform, endpoint, config, deployment, dan CI lengkap.
- [ ] Happy path dan seluruh negative test matrix memiliki expected outcome.
- [ ] OpenAPI guidance tidak mengklaim file yang belum ada dan tidak memuat credential.
- [ ] Future implementation memverifikasi `mvn clean install`, targeted Maven package/test, `docker compose config`, runtime smoke, dan XML/FTP evidence.
- [ ] Tidak ada API XML, sequence, endpoint, `.env`, config runtime, deployment, POM, Compose, atau source runtime yang berubah dalam documentation-only task.

## 18. Unresolved decisions sebelum implementable

1. Apakah service baru benar-benar `payments-service`, atau payments harus menjadi resource di `vendor-service`?
2. Apakah route final `POST /api/payments`, atau path/nama domain lain?
3. Scope dan consumer/App Registry mana yang berhak; apakah default scope pada `AuthGuardSeq` perlu diperbarui?
4. Apa payload JSON resmi: field, required/optional, enum, precision, timezone, max size, dan PII classification?
5. Apa XML root/envelope, namespace, tag casing, header constants, `Key2`, cardinality, ordering, dan XSD/example resmi?
6. Bagaimana mapping setiap field JSON ke XML dan bagaimana field yang tidak dikirim ke SAP diperlakukan?
7. Apakah transport final FTP, FTPS, atau SFTP; host/port, parent directory, exact final path ending `payments`, passive mode, permission, dan egress allowlist-nya apa?
8. Apa nama key/config payments dan precedence environment/system/config; apakah VFS sender aktif pada deployment target?
9. Apakah MI 4.6.0 dan FTP server mendukung atomic rename; apa temp directory/suffix, cleanup, dan perilaku consumer terhadap `.tmp`/`.staging`?
10. Apa filename convention, uniqueness lintas node, max length/character rule, serta hubungan filename dengan payment/document/transaction ID?
11. Apakah idempotency key wajib; berapa retention replay; bagaimana stale `PROCESSING`, payload conflict, dan duplicate final ditangani?
12. Apakah `201` berarti uploaded, renamed, staged, atau accepted; response field publik apa yang disetujui; apakah replay `200`?
13. Error FTP mana yang retryable/non-retryable; berapa attempts/backoff; timeout connect/read/upload/rename; siapa owner manual replay/FAILED?
14. Apakah `SafeApiCallWithRetrySeq.xml` diperluas untuk `PaymentsFtpEndpoint` atau payments memakai flow khusus?
15. Siapa owner OpenAPI, versioning, operationId, security scheme, dan versi linter CI?
16. Apa FTP test double/sandbox, port local, fixture XML, tool validasi XSD, dan evidence PR yang diterima?

Dokumen ini dianggap sebagai guide desain yang siap diturunkan menjadi implementation plan setelah keputusan di atas ditutup; belum merupakan bukti bahwa flow payments tersedia di WSO2 Integrator: MI.
