# Standar Kredensial, Keamanan, dan Konfigurasi Repository (Strict Rule)

Aturan ini WAJIB dipatuhi tanpa pengecualian di seluruh kode dan artefak WSO2 MI / Docker pada repository ini:

## 1. DILARANG KERAS Menuliskan Hardcode Kredensial, Password, dan Endpoint
- **Password DB & FTP**: Jangan pernah menuliskan string password riil (seperti password DB atau FTP) di dalam berkas XML sequence, endpoint, inbound endpoint, atau berkas `config.properties`.
- **Nilai di `config.properties`**: Parameter password (`db.password=`, `ftp.apduelist.password=`, dll) WAJIB selalu dikosongkan (`=`).
- **Secret & Token**: Token aplikasi dan API key tidak boleh di-hardcode ke dalam kode XML sebagai fallback.

## 2. Pola Resolusi Konfigurasi Dinamis (Dynamic Hierarchy)
Semua konfigurasi kredensial dan endpoint harus di-resolve secara dinamis dengan urutan hierarki:
1. **Environment Variables**: `get-property('env', 'VAR_NAME')` (disediakan via `.env` / `docker-compose.yml` / K8s Secret).
2. **System Properties**: `get-property('system', 'prop.name')`
3. **File Properties**: `get-property('file', 'prop.name')`
4. **WSO2 Registry Resources**: Untuk koneksi MariaDB (`driver`, `url`, `user`, `password`), gunakan `conf:/repository/assa/db/*` yang dirender otomatis oleh `render-registry-secrets.sh` saat container startup.

## 3. Prinsip Fail-Closed (Gagal Tertutup)
- Jika kredensial (host, username, password, token) bernilai kosong / tidak ditemukan di env, system, maupun file:
  - **DILARANG** menambahkan `<property name="..." value="hardcoded_fallback" />`.
  - **WAJIB** mengeksekusi filter validasi dan menolak transaksi dengan `500 Internal Server Error` (fail-closed).

## 4. Scope Autentikasi (`AuthGuardSeq`)
- Scope hak akses aplikasi pada `AuthGuardSeq.xml` murni diambil dari:
  - `AUTH_APP_<APP>_SCOPES` di environment variable / `.env`
  - Konfigurasi system / file properties.
- Dilarang keras menyisipkan fallback scope yang di-hardcode di dalam `AuthGuardSeq.xml`.
