# Security Remediation Guide — ASSA Middleware

> Panduan implementasi perbaikan atas temuan di `docs/SECURITY_REVIEW.md`. Dikerjakan **berurutan**: **High** dulu, lalu **Medium**.
> Setiap item berisi: masalah, bukti file, langkah implementasi, dan cara verifikasi.
> Perubahan menyentuh runtime/config/deployment — kerjakan di branch, uji di dev, lalu promote. Jangan commit nilai rahasia; gunakan nama variabel + secret manager.

## Cara pakai guide ini

- Kerjakan per item sebagai satu PR kecil agar mudah di-review & di-rollback.
- Tandai checkbox saat selesai; setiap item punya **Definition of Done (DoD)**.
- "Verifikasi" = cara membuktikan perbaikan benar-benar aktif, bukan sekadar diubah.

---

# BAGIAN A — SEVERITY HIGH (kerjakan lebih dulu)

Urutan disarankan: A1 → A2 → A3 → A4 → A5 → A6. A1 (auth) paling berdampak tapi paling besar; bila butuh quick win lebih dulu, A5 (SSRF) dan A6 (worker) adalah perubahan kecil berdampak tinggi.

---

## A1. Model autentikasi: static token → tervalidasi (JWT/OAuth2)

**Masalah:** auth memakai shared static token tanpa expiry/signature/revocation (`AuthGuardSeq.xml`). Token bocor = berlaku selamanya.

**Target:** validasi JWT (signature + `exp` + `aud`/`iss`) atau terminasi auth di WSO2 API Manager (sudah ada di `docker-compose.yml`).

### Opsi 1 (direkomendasikan) — Terminasi auth di WSO2 APIM
1. Daftarkan tiap API MI sebagai backend di APIM; aktifkan OAuth2/JWT di APIM.
2. APIM memvalidasi token & scope, lalu meneruskan JWT ke MI via header (mis. `X-JWT-Assertion`).
3. Di MI, ubah `AuthGuardSeq` agar **memverifikasi JWT** (bukan membandingkan string token):
   - Validasi signature pakai public key issuer (JWKS/truststore).
   - Validasi `exp` (tolak jika kedaluwarsa), `aud`, `iss`.
   - Ambil `scope`/`app` dari klaim JWT, bukan dari map token statis.
4. Pertahankan `requiredScope` + logika 403 yang sudah ada; hanya sumber identitas yang berubah.

### Opsi 2 (transisi, bila APIM belum siap) — Token dengan expiry + rotasi
1. Tambahkan metadata expiry pada token (mis. tabel `app_token` berisi `token_hash`, `expires_at`, `app_id`, `scopes`, `active`).
2. `AuthGuardSeq` melakukan `dblookup` hash token (jangan simpan token plaintext — simpan hash), cek `active` & `expires_at > NOW()`.
3. Terapkan jadwal rotasi token (mis. 90 hari) + prosedur revocation (set `active=0`).

**Langkah minimum yang bisa segera jalan (hardening sementara, bukan pengganti):**
- Pisahkan token per environment (dev/qa/prod) — jangan pakai nilai sama.
- Dokumentasikan prosedur rotasi manual + siapa pemiliknya.

**DoD:**
- [ ] Token kedaluwarsa ditolak `401`.
- [ ] Token dicabut (revoked) ditolak `401`.
- [ ] Scope diambil dari sumber tervalidasi (JWT claim / tabel), bukan string statis.

**Verifikasi:** kirim token kedaluwarsa → `401`; token dicabut → `401`; token valid dengan scope cukup → `200`; scope kurang → `403`.

---

## A2. TLS ke database (`useSSL=false`)

**Masalah:** `jdbc:mariadb://.../assa_middleware_db?useSSL=false&allowPublicKeyRetrieval=true` di `config.properties` & `deployment.toml.j2` — koneksi DB tanpa enkripsi.

**Langkah:**
1. Aktifkan TLS di MariaDB (sertifikat server dari CA internal).
2. Ubah JDBC URL (via env/`deployment.toml.j2`, bukan hardcode nilai berbeda per service):
   ```
   jdbc:mariadb://${DB_HOST}:${DB_PORT}/assa_middleware_db?useSSL=true&requireSSL=true&serverSslCert=/path/ca.pem&allowPublicKeyRetrieval=false
   ```
   (nama parameter TLS mengikuti versi driver `mariadb-java-client:3.3.3`; verifikasi di dokumentasi driver.)
3. Mount CA cert ke container (volume / Secret), bukan di-bake ke image.
4. Jika DB benar-benar di private network terisolasi dan TLS belum feasible, dokumentasikan sebagai **compensating control** (NetworkPolicy ketat) dan jadwalkan TLS.

**DoD:**
- [ ] Koneksi DB produksi memakai TLS (`useSSL=true` + verifikasi cert).
- [ ] `allowPublicKeyRetrieval=false` di non-lokal.

**Verifikasi:** cek log/handshake koneksi DB; coba koneksi tanpa TLS harus gagal.

---

## A3. FTP plain (port 21) → SFTP/FTPS

**Masalah:** `deployment.toml.j2` memakai `ftp.spk.protocol="ftp"`, port 21, untuk file berisi rekening/NPWP (vendor/spk/payment) — kredensial & data tanpa enkripsi.

**Langkah:**
1. Konfirmasi dukungan SAP: **SFTP** (disarankan) atau **FTPS**.
2. Ubah VFS URI builder di sequence terkait (`VendorCreateSeq`, `SpkDuelistSeq`, `PaymentsCreateSeq`) dari `vfs:ftp://...` ke `vfs:sftp://...` (atau FTPS), dan sesuaikan parameter koneksi di `deployment.toml.j2` (`ftp.*.protocol`, port, host key).
3. Untuk SFTP: kelola **known_hosts / host key verification** (jangan auto-accept), simpan private key/credential di secret manager.
4. Jika SAP hanya mendukung plain FTP, jadikan jalur **private link/VPN** + egress allowlist sebagai compensating control, dan dokumentasikan risikonya.

**DoD:**
- [ ] File dikirim via SFTP/FTPS (bukan plain FTP), atau jalur FTP sepenuhnya privat + terdokumentasi.
- [ ] Host key/sertifikat server diverifikasi.

**Verifikasi:** capture jaringan menunjukkan koneksi terenkripsi; file sampai di folder tujuan; koneksi ke host key tak dikenal ditolak.

---

## A4. Rate limiting & proteksi brute-force (khusus `/api/auth/login`)

**Masalah:** tidak ada throttling; `/api/auth/login` (LDAP) rentan brute-force.

**Langkah:**
1. Terapkan rate limiting di **edge** (WSO2 APIM throttling policy atau nginx `limit_req`) — paling bersih di luar MI.
   - Contoh nginx (reverse proxy di depan auth-service):
     ```nginx
     limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
     location /api/auth/login {
         limit_req zone=login burst=5 nodelay;
         proxy_pass http://auth-service:8290;
     }
     ```
2. Tambahkan **lockout** berbasis username (mis. tabel `login_attempt`: hitung gagal per username/IP, blokir sementara setelah N gagal).
3. Jangan bedakan pesan error "user tidak ada" vs "password salah" (hindari user enumeration) — kembalikan `401` generik.
4. Pastikan `password` tetap tidak di-log (sudah benar di `AuthLoginSeq`).

**DoD:**
- [ ] Percobaan login berlebih dari satu IP/username di-throttle/lockout.
- [ ] Pesan gagal login generik (tidak membocorkan keberadaan user).

**Verifikasi:** script 20 login gagal berturut → sebagian ditolak `429`/lockout.

---

## A5. SSRF via header `X-Target-Backend-Url` (quick win)

**Masalah:** `ResolveBaseUrlSeq.xml` menghormati header `X-Target-Backend-Url` untuk override base URL — klien bisa mengarahkan panggilan ke host arbitrer.

**Langkah:**
1. **Nonaktifkan di produksi.** Jadikan override hanya aktif bila flag konfigurasi `allow.backend.override=true` (default `false`), dibaca dari config/env — bukan selalu aktif.
2. Jika override tetap dibutuhkan (chaos testing di non-prod), batasi ke **allowlist host** `.assa.id`:
   - Validasi `X-Target-Backend-Url` harus `fn:starts-with(...,'https://')` dan host berakhiran `.assa.id` sebelum dipakai; jika tidak, abaikan (fallback ke config).
3. Tambahkan log bila override dipakai (audit).

**Contoh guard (konsep) di `ResolveBaseUrlSeq`:**
```xml
<property name="allowOverride" expression="get-property('file','allow.backend.override')" scope="default" type="STRING"/>
<filter xpath="$ctx:allowOverride = 'true' and string-length($ctx:backendOverrideHeader) &gt; 0 and fn:starts-with($ctx:backendOverrideHeader,'https://') and fn:ends-with($ctx:backendOverrideHeader,'.assa.id')">
    <then><property name="resolvedBaseUrl" expression="$ctx:backendOverrideHeader" scope="default" type="STRING"/></then>
</filter>
```
> `fn:ends-with` memeriksa host; untuk URL dengan path, ekstrak host dulu. Sesuaikan agar yang dicek adalah **host**, bukan seluruh URL (hindari bypass `https://evil.com/?x=.assa.id`).

**DoD:**
- [ ] Di prod, header override diabaikan (flag `false`).
- [ ] Di non-prod, hanya host `.assa.id` diterima; selain itu fallback config.

**Verifikasi:** kirim `X-Target-Backend-Url: https://evil.example.com` → middleware tetap memanggil backend resmi (bukan evil).

---

## A6. Proteksi endpoint worker (quick win)

**Masalah:** `/api/worker/retry` (`WorkerAPI.xml`) dan `/api/vendors/worker/reprocess-failed` (`VendorWorkerAPI.xml`) memicu proses background **tanpa `requiredScope`/AuthGuard**.

**Langkah (pilih sesuai kebutuhan):**
1. **Tambah auth + scope operasional** pada resource worker:
   ```xml
   <resource methods="POST GET" uri-template="/retry">
       <inSequence>
           <property name="requiredScope" value="operations" scope="default" type="STRING"/>
           <sequence key="AuthGuardSeq"/>
           <sequence key="RetryWorkerSeq"/>
           ...
       </inSequence>
       <faultSequence><sequence key="ErrorResponseSeq"/></faultSequence>
   </resource>
   ```
   Tambahkan scope `operations` ke app internal/scheduler saja (bukan ATLAS/klien bisnis).
2. **Atau** batasi akses hanya dari jaringan internal / cron (NetworkPolicy / nginx allow internal IP), jangan ekspos publik.

**DoD:**
- [ ] Endpoint worker menolak akses tanpa kredensial operasional, atau tidak terjangkau publik.

**Verifikasi:** panggil worker tanpa token dari luar → `401`/`403` atau unreachable; dari scheduler sah → `200`.

---

# BAGIAN B — SEVERITY MEDIUM (setelah High beres)

---

## B1. Scope match berbasis delimiter (hindari substring)

**Masalah:** `AuthGuardSeq` memakai `fn:contains($appScopes,$requiredScope)` → `vendor` bisa match `vendors`, `employee` match `employees`.

**Langkah:** bungkus dengan delimiter koma di kedua sisi:
```xml
<filter xpath="not(fn:contains(fn:concat(',',$ctx:appScopes,','), fn:concat(',',$ctx:requiredScope,','))) and not(fn:contains($ctx:appScopes,'*'))">
    <then> ...403... </then>
</filter>
```
Pastikan `appScopes` tidak mengandung spasi (atau normalisasi dulu).

**DoD:** [ ] scope `vendor` tidak lagi lolos untuk `vendors`.
**Verifikasi:** app dengan scope `vendors` diminta `requiredScope=vendor` → `403`.

---

## B2. Masking PII/data finansial di logging

**Masalah:** `LogRequestSeq` menulis `api.params`; di `VendorCreateSeq` `api.params = originalPayload` (berisi rekening, NPWP, email, telepon). Juga `response_payload`/`response_body` di DB.

**Langkah:**
1. Jangan set `api.params = originalPayload` penuh untuk domain sensitif. Set hanya metadata (mis. `vendorId`, jumlah field) atau versi ter-mask.
2. Di `LogRequestSeq`, log hanya `endpoint`, `correlationId`, `appId`, `transactionId` — hindari payload penuh.
3. Untuk kolom DB `request_payload`/`response_payload`: pertimbangkan mask field sensitif sebelum simpan, atau terapkan enkripsi at-rest + akses terbatas + retensi.

**DoD:** [ ] log & DB tidak memuat nomor rekening/NPWP/password dalam bentuk plaintext.
**Verifikasi:** jalankan vendor create, cek log & tabel `api_transaction*` tidak ada data sensitif plaintext.

---

## B3. Pisahkan kredensial inbound vs outbound

**Masalah:** `AuthGuardSeq` memperlakukan `SR_TARGET_ATLAS_APIKEY` (kredensial **outbound** ke ATLAS) sebagai token **inbound** valid untuk `app_barantum`.

**Langkah:**
1. Hentikan penggunaan `tokenAtlasApiKey` sebagai identitas inbound di `AuthGuardSeq`.
2. Buat token inbound khusus untuk Barantum (`AUTH_APP_BARANTUM_TOKEN`) yang terpisah dari apikey outbound ATLAS.
3. Pastikan tidak ada dua app berbeda memakai nilai token sama.

**DoD:** [ ] kredensial outbound tidak bisa dipakai untuk otentikasi inbound.
**Verifikasi:** nilai `SR_TARGET_ATLAS_APIKEY` dikirim sebagai Bearer inbound → `401`.

---

## B4. Ganti password keystore/truststore default `wso2carbon`

**Masalah:** `deployment.toml.j2` default `wso2carbon` (publik diketahui) untuk keystore & truststore.

**Langkah:**
1. Generate keystore/truststore baru milik ASSA (jangan pakai `wso2carbon.jks` bawaan).
2. Set `KEYSTORE_PASSWORD`, `KEYSTORE_KEY_PASSWORD`, `TRUSTSTORE_PASSWORD` via secret (wajib di prod), hapus ketergantungan default.
3. Simpan JKS via Secret/volume, bukan di-commit ke repo.

**DoD:** [ ] tidak ada password keystore `wso2carbon` di environment manapun selain lokal.
**Verifikasi:** server start dengan keystore baru; cek tidak ada fallback ke default.

---

## B5. DB user non-root + hak terbatas

**Masalah:** `db.username=root` (default) di config & compose.

**Langkah:**
1. Buat user DB khusus (mis. `mw_app`) dengan privilege terbatas hanya ke `assa_middleware_db` (`SELECT, INSERT, UPDATE` pada tabel yang diperlukan; hindari `DROP`/`GRANT`).
2. Set `DB_USERNAME`/`DB_PASSWORD` via secret; hapus default `root`.

**DoD:** [ ] aplikasi konek sebagai user non-root berhak terbatas.
**Verifikasi:** user app tidak bisa `DROP TABLE`; operasi normal tetap jalan.

---

## B6. Supply chain: `checksumPolicy` & dependency scanning

**Masalah:** beberapa `pom.xml` memakai `<checksumPolicy>ignore</checksumPolicy>`.

**Langkah:**
1. Ubah `ignore` → `warn` (atau `fail` bila feasible) di repository config pom.
2. Pin versi dependency; tambahkan **dependency/image scanning** di CI (OWASP Dependency-Check / Trivy image scan).
3. Pantau CVE untuk `mariadb-java-client`, connector HTTP, base image `wso2/wso2mi:4.6.0`.

**DoD:** [ ] CI gagal/warning bila artefak checksum invalid atau CVE kritikal.
**Verifikasi:** jalankan scan di CI; lihat laporan.

---

## B7. Constant-time token compare (bila auth tetap token-based)

**Masalah:** perbandingan token `=` bukan constant-time.

**Langkah:** bila A1 belum pindah ke JWT, implementasikan compare via custom class mediator yang memakai perbandingan constant-time. Bila A1 (JWT) sudah jalan, item ini gugur.

**DoD:** [ ] perbandingan rahasia tidak bergantung panjang/isi (atau sudah pindah ke JWT).

---

# Lampiran — Peta temuan → file yang disentuh

| Item | File utama |
|---|---|
| A1 Auth | `shared/.../AuthGuardSeq.xml`, APIM config |
| A2 TLS DB | `platform/docker/deployment.toml.j2`, `integrations/*/.../config.properties` |
| A3 FTP | `platform/docker/deployment.toml.j2`, `VendorCreateSeq.xml`, `SpkDuelistSeq.xml`, `PaymentsCreateSeq.xml`, endpoint FTP |
| A4 Rate limit login | nginx / APIM, `auth-service` |
| A5 SSRF | `shared/.../ResolveBaseUrlSeq.xml` |
| A6 Worker auth | `service-request-service/.../apis/WorkerAPI.xml`, `vendor-service/.../apis/VendorWorkerAPI.xml` |
| B1 Scope match | `shared/.../AuthGuardSeq.xml` |
| B2 Masking log | `shared/.../LogRequestSeq.xml`, `VendorCreateSeq.xml`, skema DB |
| B3 Inbound/outbound creds | `shared/.../AuthGuardSeq.xml` |
| B4 Keystore | `platform/docker/deployment.toml.j2`, resources security |
| B5 DB user | `platform/docker/deployment.toml.j2`, `config.properties`, `docker-compose.yml` |
| B6 Supply chain | `pom.xml` (root + per service), CI workflow |
| B7 Token compare | `shared/.../AuthGuardSeq.xml` (gugur bila A1 JWT) |

> **Catatan:** contoh kode XML/nginx di atas adalah **ilustrasi pola** dan harus diverifikasi terhadap versi WSO2 MI 4.6.0 / driver / gateway yang dipakai sebelum dipakai di produksi. Uji di dev lebih dulu. Jangan commit nilai rahasia; semua kredensial via secret manager/env.
