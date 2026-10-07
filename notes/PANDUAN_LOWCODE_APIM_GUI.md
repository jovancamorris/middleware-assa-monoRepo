# Panduan Pembuatan API Low-Code via WSO2 APIM Publisher GUI
## ASSA Middleware — Portal Manajemen API

> **Tujuan Dokumen**: Panduan praktis bagi Developer, Tech Lead, dan Administrator untuk membuat, mengonfigurasi, mengamankan, dan mempublikasikan API baru **secara visual (Low-Code / No-Code via Web GUI)** tanpa perlu memodifikasi kode XML, Maven, atau me-restart container WSO2 Micro Integrator (MI).

---

## 1. URL Akses & Kredensial Portal

| Portal | URL Akses | Fungsi | Kredensial Default |
|---|---|---|---|
| **Publisher Portal** | `https://devmiddleware.assa.id:9443/publisher`<br>*(atau `https://devmiddleware.assa.id/publisher`)* | Tempat membuat API, mengatur endpoint backend, pasang policy security & rate limit, serta publish API. | `admin` / `admin` |
| **Developer Portal** *(DevPortal)* | `https://devmiddleware.assa.id:9443/devportal`<br>*(atau `https://devmiddleware.assa.id/devportal`)* | Tempat katalog API untuk klien (ATLAS, Omnichannel, vendor), generate API Key, dan uji coba (*Try Out*). | User terdaftar / `admin` |
| **Admin Portal** | `https://devmiddleware.assa.id:9443/admin`<br>*(atau `https://devmiddleware.assa.id/admin`)* | Pengaturan tingkat lanjut (Throttling Tier, Application Policy, Key Manager). | `admin` / `admin` |

---

## 2. Cara Membuat API Baru via GUI (Tanpa Koding)

### Skenario A: Membuat API Baru dari Nol (Design New REST API)

Gunakan cara ini jika Anda memiliki backend REST API baru (misal layanan microservice Golang/NodeJS internal atau third-party API) dan ingin mengeksposnya ke ekosistem ASSA:

1. **Login ke Publisher Portal**:
   - Buka `https://devmiddleware.assa.id:9443/publisher`.
   - Masukkan username `admin` dan password `admin`.
2. **Klik Tombol "Create API"**:
   - Pilih opsi **"Design a New REST API"**.
3. **Isi Metadata Dasar**:
   - **Name**: `Customer Loyalty Service` (contoh nama API).
   - **Context**: `/api/v1/loyalty` (URL path yang akan dipanggil oleh klien).
   - **Version**: `1.0.0`.
   - **Endpoint**: Masukkan URL backend target, contoh: `http://internal-loyalty-app.assa.id:8080/api`.
4. **Tentukan Sumber Daya (Resources / Paths)**:
   - Tambahkan path seperti:
     - `GET /points`
     - `POST /redeem`
5. **Klik "Create"**.

---

### Skenario B: Import dari Spesifikasi OpenAPI / Swagger

Jika Anda sudah memiliki file OpenAPI YAML atau JSON:

1. Di menu **Create API**, pilih **"I Have an Existing REST API"**.
2. Pilih opsi **OpenAPI URL** (misal masukkan URL docs yang sudah ada: `https://devmiddleware.assa.id/docs/openapi/branch-service.yaml`) atau pilih **OpenAPI File / Archive** untuk mengunggah file `.yaml`.
3. Isi context path dan endpoint backend.
4. Klik **Create**. Seluruh path, parameter, dan schema request otomatis terisi di GUI!

---

### Skenario C: Menampilkan & Mempublish Service dari WSO2 MI (Service Catalog)

WSO2 Micro Integrator (MI) secara otomatis mendaftarkan semua service integrasinya (`branch-service`, `vendor-service`, `spk-service`, dll.) ke APIM:

1. Di bilah menu kiri Publisher Portal, klik menu **"Service Catalog"**.
2. Anda akan melihat daftar service WSO2 MI yang aktif beserta statusnya.
3. Klik tombol **"Create API"** di sebelah service yang diinginkan (misal `vendor-service`).
4. GUI akan otomatis membuat proxy API di gateway yang langsung terhubung ke WSO2 MI (`http://middleware-wso2-api:8290`).

---

## 3. Menambahkan Kebijakan (Policy) & Keamanan via GUI

Tanpa menulis konfigurasi XML, Anda bisa memasang fitur enterprise cukup dengan mencentang opsi di GUI:

### A. Pengaturan Keamanan (Security)
1. Buka API yang sudah dibuat → Masuk ke menu **API Configurations** → **Runtime**.
2. Di bagian **Application Level Security**, centang opsi yang diinginkan:
   - **OAuth2**: Klien harus menggunakan token Bearer OAuth2.
   - **API Key**: Klien cukup mengirimkan header `apikey: <token>`.
   - **Mutual SSL**: Untuk komunikasi antar-server sertifikat terpercaya.

### B. Pembatasan Trafik (Rate Limiting / Throttling)
1. Di menu **Runtime**, pilih **Rate Limiting Policies**:
   - `Unlimited`
   - `50KPerMin` (50.000 request per menit)
   - `Gold` / `Silver` / `Bronze` tier sesuai kapasitas server backend.

### C. CORS Configuration
1. Di menu **Runtime** → **CORS Configuration**:
   - Aktifkan tombol toggle **Enable CORS**.
   - Masukkan domain frontend yang diizinkan (misal: `https://atlas.assa.id`, `https://fms.assa.id`).

---

## 4. Deploy & Publish API ke Publik

Setelah konfigurasi selesai:

1. Klik menu **Deployments** di bilah kiri.
2. Klik tombol **"Deploy"** untuk mendistribusikan API ke API Gateway.
3. Masuk ke menu **Lifecycle**:
   - Status awal adalah `Created`.
   - Klik tombol **"Publish"**.
4. **Selesai!** Status API berubah menjadi `Published` dan langsung bisa diakses oleh klien di URL Gateway:
   👉 `https://devmiddleware.assa.id:8243/<context>/<version>/<path>`

---

## 5. Pengujian Langsung di Browser (Try Out)

Developer dan QA tidak perlu membuka Postman untuk mencoba API:

1. Buka Developer Portal: `https://devmiddleware.assa.id:9443/devportal`.
2. Klik API yang baru dipublish.
3. Masuk ke tab **"Try Out"**.
4. Klik tombol **"Generate Key"** atau masukkan token.
5. Pilih method (`GET`/`POST`), isi parameter atau body, lalu klik **"Execute"**.
6. Response dari backend langsung tampil di layar browser beserta response code, headers, dan latency time.

---

## 6. Ringkasan Perbedaan Alur Kerja

| Aktivitas | Cara Lama (Manual Code) | Cara Baru (WSO2 APIM GUI) |
|---|---|---|
| Buat API Proxy baru | Buat file XML API, buat sequence, update pom.xml, compile Maven, repack CAR, restart container | Login browser, klik "Create API", isi endpoint, klik "Publish" (3 menit) |
| Pasang Rate Limiting | Koding sequence custom filter atau mediator throttling XML | Checklist tier rate limiting di GUI |
| Dokumentasi API | Tulis manual OpenAPI YAML di text editor | Otomatis dibuatkan Swagger/OpenAPI interaktif oleh GUI APIM |
| Orkestrasi Kompleks (SAP XML FTP) | Tetap gunakan WSO2 MI (Synapse XML) | Tetap gunakan WSO2 MI (Synapse XML) |
