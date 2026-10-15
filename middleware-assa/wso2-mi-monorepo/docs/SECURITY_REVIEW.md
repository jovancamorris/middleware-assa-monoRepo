# Security Review — ASSA Middleware (WSO2 MI Monorepo)

> **Lingkup**: review keamanan berbasis kode terhadap artefak Synapse (API, sequence, endpoint), konfigurasi (`config.properties`, `deployment.toml.j2`), dan deployment (`docker-compose.yml`). Review ini **statis** (membaca kode), bukan penetration test. Temuan diberi severity dan rekomendasi tuning/enhancement.
> **Catatan**: review tidak menyertakan nilai rahasia apa pun. Referensi file memakai path relatif repo.
> **Tanggal**: lihat commit; **Reviewer**: audit otomatis berbantuan, perlu validasi tim security.

---

## Ringkasan Eksekutif

| Area | Status | Severity tertinggi |
|---|---|---|
| SQL injection (DB mediator) | ✅ Aman (parameterized) | — |
| XML injection (vendor/spk/payment) | ✅ Aman (payloadFactory `evaluator="xml"`) | — |
| Autentikasi (model token) | ⚠️ Perlu enhancement | **High** |
| Perbandingan token | ⚠️ Perlu tuning | Medium |
| Transport & TLS backend | ⚠️ Perlu tuning | **High** |
| Secret handling | ⚠️ Campuran | Medium–High |
| Logging & data sensitif | ⚠️ Perlu tuning | Medium |
| Rate limiting / brute force | ❌ Belum ada | **High** (khusus login) |
| Health/worker exposure | ⚠️ Perlu tuning | Medium |
| Dependency & build | ⚠️ Perlu tuning | Medium |

**Yang sudah baik:** semua SQL memakai `<parameter>` terparameterisasi (tidak ada konkatenasi), XML dibentuk via `payloadFactory` (bukan string mentah), auth **fail-closed** (menolak bila tidak ada token terkonfigurasi), base URL tidak hardcode, idempotency berbasis DB.

**Prioritas perbaikan (urut):**
1. Model autentikasi (static shared token → token tervalidasi/JWT atau gateway).
2. TLS/verifikasi sertifikat ke backend + `useSSL=false` pada DB.
3. Rate limiting & proteksi brute-force untuk `/api/auth/login`.
4. Secret management penuh (Secure Vault / Secret manager), hilangkan default plaintext.
5. Masking data sensitif di log.

---

## 1. Autentikasi & Otorisasi

Sumber: `shared/src/main/wso2mi/artifacts/sequences/AuthGuardSeq.xml`.

### 1.1 Model token statis bersama — **High (enhancement)**

Auth memakai **shared static token per aplikasi** (`AUTH_APP_*_TOKEN`) yang dibandingkan langsung dengan `Authorization: Bearer` atau `X-API-Key`. Tidak ada validasi signature, expiry, audience, atau issuer (bukan JWT/OAuth2 tervalidasi).

Risiko:
- Token tidak kedaluwarsa — bila bocor, berlaku selamanya sampai dirotasi manual.
- Tidak ada revocation granular; rotasi berarti mengganti token di semua konsumen.
- Satu token = satu aplikasi; tidak ada identitas user-level untuk audit.

Rekomendasi (enhancement):
- Idealnya terminasi auth di **WSO2 API Manager** (repo sudah menyertakan APIM 4.3.0 di compose) dengan OAuth2/JWT, lalu MI memvalidasi JWT (signature + exp + aud).
- Minimal: terapkan **rotasi token terjadwal** dan **expiry** di level gateway/proxy.
- Pisahkan token per environment (dev/qa/prod) secara tegas.

### 1.2 Perbandingan token non-constant-time — **Medium (tuning)**

Perbandingan `$ctx:bearerToken = $ctx:tokenAppX` adalah string-equality biasa. Secara teori rentan timing attack, meski di balik HTTPS + jaringan, eksploitasinya sulit.

Rekomendasi: pindahkan validasi ke komponen yang mendukung constant-time compare (gateway/custom class mediator), atau terima risiko ini sebagai rendah bila auth dipindah ke JWT (poin 1.1 menihilkan isu ini).

### 1.3 Urutan match token & potensi ambiguitas — **Medium (tuning)**

`AuthGuardSeq` mencocokkan token secara berurutan (barantum/atlas-apikey → app_a → app_b → ...). `tokenAtlasApiKey` (SR_TARGET_ATLAS_APIKEY, kredensial **outbound** ke ATLAS) ikut diperlakukan sebagai kredensial **inbound** yang valid untuk `app_barantum`. Mencampur kredensial outbound sebagai identitas inbound memperluas attack surface dan membingungkan audit.

Rekomendasi:
- Pisahkan kredensial outbound (dipakai middleware memanggil ATLAS) dari kredensial inbound (dipakai klien memanggil middleware). Jangan pakai satu nilai untuk dua arah.
- Bila dua token berbeda app kebetulan bernilai sama, match pertama menang — pastikan keunikan token antar-app.

### 1.4 Scope guard — ✅ baik, dengan catatan

Scope dicek via `fn:contains($ctx:appScopes, $ctx:requiredScope)`. **Risiko substring**: `fn:contains` mencocokkan substring, jadi scope `employee` akan **match** terhadap `employees`, atau scope `vendor` match `vendors`. Saat ini nilai scope relatif aman, tapi penamaan rentan.

Rekomendasi (tuning): gunakan pencocokan berbasis daftar token yang tepat (mis. bungkus dengan delimiter: cek `fn:contains(fn:concat(',',$scopes,','), fn:concat(',',$required,','))`) agar `vendor` tidak match `vendors`.

### 1.5 Wildcard scope `*` — catatan

Scope `*` memberi akses semua. Pastikan `*` hanya untuk app internal/QA, tidak untuk konsumen produksi.

---

## 2. Injection

### 2.1 SQL Injection — ✅ Aman

Seluruh `dblookup`/`dbreport` memakai `<sql>...?...</sql>` dengan `<parameter expression=... type=.../>` (prepared statement). Tidak ditemukan konkatenasi nilai ke dalam string SQL. Contoh: `IdempotencyGuardSeq`, `DbRecordAttemptLogSeq`, `VendorInboundCallbackSeq`, `RetryWorkerSeq`.

Catatan: `DO SLEEP(?)` pada `ApiCallErrorHandlerSeq` juga parameterized. Pertahankan pola ini — jangan pernah membangun SQL via `fn:concat`.

### 2.2 XML Injection — ✅ Aman

Pembentukan XML (vendor VMD, spk, payment) memakai `payloadFactory` dengan `<arg evaluator="xml" .../>`, yang meng-escape entity XML. Tidak ada konkatenasi string XML mentah dari input user.

Catatan tuning: tetap tambahkan validasi panjang/charset input sebelum masuk XML (sebagian sudah ada di `VendorCreateSeq`, mis. batas panjang field) untuk mencegah payload abnormal, dan pertimbangkan validasi skema (XSD) bila kontrak backend mendukung.

### 2.3 XXE (XML External Entity) — perlu dikonfirmasi

Sequence inbound (`VendorInboundCallbackSeq`, `VendorReprocessFailedSeq`) mem-parse XML balikan SAP via `payloadFactory`/`//xpath`. Perlu dipastikan parser Synapse menolak DOCTYPE/entity eksternal (default MI biasanya aman, tapi konfirmasi untuk file dari FTP yang kurang tepercaya).

Rekomendasi: pastikan XXE dinonaktifkan pada pemrosesan file inbound; perlakukan file dari `/vmd/upload` sebagai untrusted.

---

## 3. Transport, TLS, dan Koneksi Backend

### 3.1 DB connection `useSSL=false` — **High (tuning)**

`config.properties` dan `deployment.toml.j2`:
```
jdbc:mariadb://.../assa_middleware_db?useSSL=false&allowPublicKeyRetrieval=true
```
`useSSL=false` + `allowPublicKeyRetrieval=true` berarti koneksi DB tanpa enkripsi dan menerima public key dari server tanpa verifikasi. Aman hanya bila DB di jaringan privat terisolasi penuh.

Rekomendasi: untuk non-lokal, aktifkan TLS ke MariaDB (`useSSL=true` + verifikasi sertifikat), atau pastikan trafik DB benar-benar di private network + NetworkPolicy.

### 3.2 Verifikasi sertifikat backend — **High (konfirmasi/tuning)**

Panggilan keluar (SAP Core, ASSA Ext, ATLAS, HC LDAP, FTP) memakai HTTPS/FTP. `client-truststore.jks` default WSO2 (`wso2carbon`) dipakai. Perlu dipastikan sertifikat backend ter-import ke truststore dan verifikasi hostname aktif (bukan trust-all).

Rekomendasi: kelola truststore khusus berisi CA backend ASSA; jangan nonaktifkan verifikasi hostname. Ganti password keystore/truststore default `wso2carbon`.

### 3.3 FTP memakai plain FTP port 21 — **High (tuning)**

`deployment.toml.j2`: `ftp.spk.protocol = "ftp"`, `ftp.vendor.port = 21`, `vfs.passive=true`. Plain FTP mengirim kredensial & data **tanpa enkripsi**. File vendor/spk/payment berisi data bisnis (rekening bank, NPWP, dll).

Rekomendasi: migrasi ke **SFTP** atau **FTPS**. Bila SAP hanya mendukung FTP, pastikan jalur sepenuhnya privat (VPN/private link) dan batasi egress.

### 3.4 Keystore/truststore password default — **Medium–High (tuning)**

`deployment.toml.j2` memakai default `wso2carbon` untuk keystore & truststore (ada penanda `secret-detector:ignore`). Default ini publik diketahui.

Rekomendasi: wajib override `KEYSTORE_PASSWORD`/`TRUSTSTORE_PASSWORD`/`KEYSTORE_KEY_PASSWORD` di produksi, dan ganti keystore `wso2carbon.jks` bawaan dengan milik ASSA.

---

## 4. Secret Management

### 4.1 Token/API key default & kosong di config — **Medium–High**

- `config.properties` per service menaruh `auth.app.*.token=` kosong dan `db.password=` kosong (baik: tidak ada secret nyata di-commit).
- `docker-compose.yml` memakai `${VAR:?set VAR in .env}` untuk token wajib (fail-fast, baik) tetapi beberapa punya **default plaintext** untuk kredensial infrastruktur: `FTP_SAP_USERNAME:-middlewaredev`, `FTP_SAP_HOST:-devqaxmlpool.assa.id`, `DB_USERNAME` default `root`.
- `deployment.toml.j2` memakai `$env{...}` untuk API key/FTP password (baik) tetapi `db.password` default kosong dan DB user default `root`.

Risiko: nilai di `.env` adalah satu-satunya pelindung; bila `.env` bocor/ter-commit, semua terbuka. Username FTP & host default tertanam di compose.

Rekomendasi:
- Gunakan **WSO2 Secure Vault** (cipher-tool) untuk secret di `deployment.toml`, atau **Kubernetes Secret**/secret manager (Vault/AWS Secrets Manager) saat deploy.
- Hilangkan default kredensial infrastruktur dari `docker-compose.yml`; jadikan wajib via `.env`.
- Pastikan `.env` ada di `.gitignore` dan tidak pernah ter-commit (verifikasi history).
- DB jangan pakai `root`; buat user khusus dengan hak terbatas (hanya DB `assa_middleware_db`).

### 4.2 Token tidak expiry/rotasi — lihat 1.1.

---

## 5. Logging & Data Sensitif

Sumber: `shared/.../LogRequestSeq.xml`, berbagai `<log>`.

### 5.1 `api.params` dilog apa adanya — **Medium (tuning)**

`LogRequestSeq` menulis `params` (= `api.params`) ke log terstruktur. Pada beberapa domain `api.params` berisi payload asli (mis. `VendorCreateSeq` men-set `api.params = originalPayload`). Payload vendor memuat **data sensitif** (nomor rekening, NPWP, email, telepon). Ini berpotensi menulis PII/data finansial ke log.

Rekomendasi: mask/redaksi field sensitif sebelum logging (rekening, NPWP, email), atau log hanya metadata (endpoint, correlationId) tanpa payload penuh.

### 5.2 Login — password sudah ditangani benar — ✅

`AuthLoginSeq` punya komentar eksplisit dan **tidak** me-log `password`. Pertahankan. Pastikan `password` juga tidak masuk `api.params`/DB bila sequence login kelak memanggil `LogRequestSeq`/pencatatan transaksi.

### 5.3 Response body dilog/disimpan — **Medium (tuning)**

Beberapa sequence menyimpan `responseBody` ke `api_transaction.response_payload` dan `api_transaction_log.response_body`. Bila response backend memuat data sensitif, DB jadi tempat penyimpanan PII. Terapkan retensi & akses terbatas pada tabel ini, pertimbangkan masking.

---

## 6. Endpoint Exposure & Abuse

### 6.1 Tidak ada rate limiting / brute-force protection — **High (khusus login)**

Tidak ditemukan rate limiting di middleware. Untuk `/api/auth/login` (LDAP), ini berarti **tidak ada proteksi brute-force** terhadap kredensial user. Endpoint bisnis lain juga tanpa throttling (risiko DoS/abuse).

Rekomendasi:
- Terapkan rate limiting/throttling (idealnya di WSO2 APIM atau reverse proxy/nginx) khususnya untuk login — batasi percobaan per IP/username, dan lockout sementara.
- Pertimbangkan WAF/throttle global di gateway.

### 6.2 Health/readiness tanpa token — ✅ wajar, dengan catatan

`/health/*` & `/readiness/*` sengaja tanpa token (untuk probe). Wajar. Pastikan endpoint ini **tidak membocorkan detail internal** (versi, konfigurasi, koneksi DB string) di response.

### 6.3 Worker endpoint operasional — **Medium (tuning)**

`/api/worker/retry` dan `/api/vendors/worker/reprocess-failed` memicu proses background **tanpa `requiredScope`/AuthGuard** (berdasarkan API XML). Siapa pun yang bisa menjangkau endpoint dapat memicu worker (potensi abuse/DoS atau memaksa reprocess).

Rekomendasi: proteksi endpoint worker dengan auth (scope operasional khusus) atau batasi hanya dari jaringan internal/cron, jangan ekspos publik.

### 6.4 Backend override header — **Medium (tuning)**

`ResolveBaseUrlSeq` menghormati header `X-Target-Backend-Url` untuk override base URL ("chaos testing"). Jika aktif di produksi, **klien bisa mengarahkan panggilan middleware ke host arbitrer** (SSRF). 

Rekomendasi: nonaktifkan override header di produksi, atau batasi ke allowlist host `.assa.id`. Ini risiko SSRF yang nyata bila dibiarkan.

---

## 7. Konfigurasi Build & Dependency

### 7.1 `checksumPolicy=ignore` pada repository Maven — **Medium (tuning)**

Beberapa `pom.xml` memakai `<checksumPolicy>ignore</checksumPolicy>`. Mengabaikan checksum artefak melemahkan jaminan integritas supply-chain.

Rekomendasi: ubah ke `warn`/`fail` bila feasible, dan pin versi dependency.

### 7.2 Versi dependency — tuning

Pastikan `mariadb-java-client`, connector HTTP, dan base image `wso2/wso2mi:4.6.0` dipantau untuk CVE. Terapkan dependency scanning (mis. OWASP Dependency-Check / Trivy image scan) di CI.

### 7.3 Base image & non-root — konfirmasi

Pastikan container berjalan sebagai **non-root** dan image di-scan. Verifikasi `Dockerfile` tiap service.

---

## 8. CORS & Header Keamanan — perlu dikonfirmasi

`SrToAtlasSeq` memanipulasi header `Origin`. Perlu dipastikan kebijakan CORS di gateway/nginx tidak terlalu permisif (`*`), dan response middleware menyertakan header keamanan (HSTS, X-Content-Type-Options) di layer edge.

---

## 9. Ringkasan Rekomendasi (Backlog)

### Prioritas Tinggi (High)
- [ ] **Auth model**: pindah ke JWT/OAuth2 tervalidasi (via APIM) atau minimal token expiry + rotasi.
- [ ] **TLS DB**: aktifkan `useSSL=true` + verifikasi, atau isolasi private network penuh.
- [ ] **FTP → SFTP/FTPS**: hentikan plain FTP port 21 untuk data sensitif.
- [ ] **Rate limiting login**: proteksi brute-force `/api/auth/login`.
- [ ] **SSRF**: nonaktifkan/allowlist `X-Target-Backend-Url` di produksi.
- [ ] **Proteksi worker endpoint**: tambahkan auth/scope operasional.

### Prioritas Menengah (Medium)
- [ ] Scope match berbasis delimiter (hindari substring `vendor` vs `vendors`).
- [ ] Masking PII/data finansial di `LogRequestSeq` & kolom DB.
- [ ] Pisahkan kredensial inbound vs outbound (hentikan reuse ATLAS apikey sebagai identitas inbound).
- [ ] Ganti password keystore/truststore default `wso2carbon`.
- [ ] DB user non-root dengan hak terbatas.
- [ ] `checksumPolicy` → `warn`/`fail`, dependency scanning di CI.
- [ ] Constant-time token compare (jika auth tetap token-based).

### Prioritas Rendah / Housekeeping
- [ ] Pastikan `.env` di `.gitignore` & bersih dari history.
- [ ] XXE hardening pada parsing file inbound FTP.
- [ ] Health endpoint tidak membocorkan detail internal.
- [ ] Retensi & akses terbatas pada `api_transaction*`.

---

## 10. Catatan Metodologi & Batasan

- Review ini **statis** atas kode & konfigurasi yang ada di repo saat audit. Tidak mencakup pengujian runtime, fuzzing, atau pentest.
- Beberapa poin ditandai **"perlu dikonfirmasi"** karena bergantung pada konfigurasi deployment aktual (truststore, network policy, gateway) yang tidak sepenuhnya terlihat dari repo.
- Severity bersifat indikatif; prioritaskan sesuai paparan nyata (apakah endpoint publik, apakah data benar-benar sensitif, environment prod vs dev).
- Tidak ada nilai rahasia yang direproduksi dalam dokumen ini.

---

## Lampiran — File yang ditinjau

- `shared/.../AuthGuardSeq.xml`, `LogRequestSeq.xml`, `ErrorResponseSeq.xml`, `IdempotencyGuardSeq.xml`, `ApiCallErrorHandlerSeq.xml`, `DbRecordAttemptLogSeq.xml`, `RetryWorkerSeq.xml`, `ResolveBaseUrlSeq.xml`, `SafeApiCallWithRetrySeq.xml`
- `integrations/vendor-service/.../VendorCreateSeq.xml`, `VendorInboundCallbackSeq.xml`, `VendorReprocessFailedSeq.xml`, `apis/VendorWorkerAPI.xml`
- `integrations/auth-service/.../AuthLoginSeq.xml`
- `integrations/*/resources/conf/config.properties`
- `platform/docker/deployment.toml.j2`
- `docker-compose.yml`
- `integrations/*/pom.xml`, `shared/pom.xml`
