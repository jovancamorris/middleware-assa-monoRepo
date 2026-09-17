# PANDUAN SETUP MARIADB & MEKANISME RESILIENCY ASSA MIDDLEWARE

Dokumen ini menjelaskan integrasi database **MariaDB Lokal (Port 3307)**, skema tabel transaksi & log, mekanisme ketahanan (resiliency) dengan **3x retry**, **idempotency guard**, dan **asynchronous background worker** pada ASSA Middleware (WSO2 Micro Integrator).

---

## 1. Spesifikasi Lingkungan Database

- **Database Engine**: MariaDB 10.x / 11.x
- **Host**: `localhost` (127.0.0.1)
- **Port**: `3307` *(Sesuai konfigurasi MariaDB lokal pengguna, terpisah dari MySQL standar 3306)*
- **Nama Database**: `assa_middleware_db`
- **User**: `root`
- **Password**: *(passwordless)*
- **JDBC Driver**: `org.mariadb.jdbc.Driver` (versi `3.3.3`)
- **JDBC Connection String**:
  ```properties
  jdbc:mariadb://localhost:3307/assa_middleware_db?useSSL=false&allowPublicKeyRetrieval=true
  ```

---

## 2. Struktur Skema Tabel

Script inisialisasi DDL tersimpan pada file: [init_mariadb.sql](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/scripts/init_mariadb.sql).

### 2.1. Tabel `api_transaction` (Transaksi Utama)
Mencatat transaksi utama tingkat aplikasi, memelihara status pemrosesan, mendukung proteksi idempotensi, dan mengantrekan transaksi yang gagal.

| Kolom | Tipe | Keterangan |
| :--- | :--- | :--- |
| `id` | `BIGINT AUTO_INCREMENT` | Primary Key unik internal |
| `transaction_id` | `VARCHAR(100) UNIQUE` | ID Transaksi unik (misal: `TRX-20260914...` atau dari header `X-Transaction-Id`) |
| `idempotency_key` | `VARCHAR(100)` | Kunci idempotensi (`X-Idempotency-Key`) untuk mendeteksi duplikasi |
| `endpoint` | `VARCHAR(255)` | Endpoint API yang dipanggil (misal: `/api/branches/getByCreateDate`) |
| `http_method` | `VARCHAR(10)` | HTTP Method (`GET`, `POST`, dll.) |
| `request_payload` | `MEDIUMTEXT` | Parameter query atau body request yang dikirim klien |
| `response_payload` | `MEDIUMTEXT` | Payload respons terakhir dari backend external |
| `status` | `ENUM(...)` | Status transaksi: `PENDING`, `PROCESSING`, `SUCCESS`, `RETRY`, `FAILED` |
| `attempt_count` | `INT` | Jumlah percobaan pemanggilan yang telah dilakukan (1, 2, 3) |
| `max_attempts` | `INT` | Batas maksimum percobaan (default: 3) |
| `next_retry_at` | `DATETIME` | Waktu jadwal percobaan berikutnya oleh Background Worker |
| `created_at` | `DATETIME` | Waktu transaksi dibuat pertama kali |
| `updated_at` | `DATETIME` | Waktu transaksi terakhir diperbarui |

### 2.2. Tabel `api_transaction_log` (Log Percobaan / Audit Trail)
Mencatat riwayat teknis setiap kali pemanggilan HTTP dilakukan ke backend external (percobaan 1, 2, dan 3).

| Kolom | Tipe | Keterangan |
| :--- | :--- | :--- |
| `id` | `BIGINT AUTO_INCREMENT` | Primary Key unik internal log |
| `transaction_id` | `VARCHAR(100)` | ID Transaksi (Foreign reference ke `api_transaction`) |
| `attempt_number` | `INT` | Nomor urut percobaan (`1`, `2`, `3`, atau `0` untuk worker) |
| `endpoint` | `VARCHAR(255)` | Path endpoint eksternal |
| `request_payload` | `MEDIUMTEXT` | Parameter / payload yang dikirim pada percobaan tersebut |
| `response_status` | `INT` | Status code HTTP yang diterima (`200`, `500`, `502`, dll.) |
| `response_body` | `MEDIUMTEXT` | Cuplikan pesan / payload respons |
| `error_message` | `TEXT` | Pesan galat jika pemanggilan gagal |
| `duration_ms` | `INT` | Latensi pemanggilan dalam milidetik (observabilitas) |
| `created_at` | `DATETIME` | Timestamp pencatatan percobaan |

---

## 3. Alur Ketahanan & Retry (Resiliency Pattern)

Sesuai permintaan operasional, middleware menerapkan pola:

```
Incoming Request -> IdempotencyGuardSeq -> SafeApiCallWithRetrySeq
                                                  |
                          +-----------------------+-----------------------+
                          |                                               |
                     [HTTP 2xx Success]                          [HTTP Fail / Error]
                          |                                               |
               Record 200 to Attempt Log                       Record Error to Attempt Log
               Update api_transaction: SUCCESS                            |
               Return Response to Client                       Check Attempt < 3?
                                                                 /             \
                                                           (YES)                (NO)
                                                             |                    |
                                                    Wait 60s (Non-hardcoded)  Set Status = FAILED
                                                    Increment Attempt         Send [ALERT MONITORING]
                                                    Retry SafeApiCall         Queue for Asynchronous Worker
                                                                              Return 502 Bad Gateway
```

### 3.1. Kebijakan Percobaan 3x (Max Attempts)
- **Maksimum Percobaan**: Ditetapkan secara dinamis dari file konfigurasi:
  `retry.max.attempts=3` pada `config.properties`.
- **Jeda Waktu (Interval)**: Ditetapkan secara dinamis (tidak di-hardcode):
  - Default: `retry.interval.seconds=60` (1 menit).
  - Runtime Override (untuk testing otomatis): Header `X-Retry-Interval-Seconds: 1`.
- **Mekanisme Delay**: Menggunakan eksekusi jeda MariaDB native (`DO SLEEP(?)`) yang aman, akurat, dan independen dari runtime Java/JDK.

### 3.2. Pencatatan Log pada Setiap Kegagalan
- Setiap kali panggilan external API gagal (Connection Refused, 5xx, atau Timeout), sequence [DbRecordAttemptLogSeq.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/sequences/DbRecordAttemptLogSeq.xml) langsung menulis baris baru ke `api_transaction_log` dengan nomor percobaan (`attempt_number`), `response_status`, `error_message`, dan `duration_ms`.
- Jika mencapai percobaan ke-3 dan masih gagal:
  1. Status transaksi di `api_transaction` diubah menjadi `FAILED`.
  2. Kolom `next_retry_at` dijadwalkan untuk proses pemulihan.
  3. Mengirimkan log monitoring berkategori `[ALERT MONITORING]` ke konsol/log server.
  4. Transaksi dimasukkan ke **Retry Queue**.
  5. Mengembalikan HTTP 502 Bad Gateway terstandarisasi ke klien pemanggil.

---

## 4. Idempotency Guard (Pencegahan Duplikasi)

Sequence [IdempotencyGuardSeq.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/sequences/IdempotencyGuardSeq.xml) melindungi sistem dari pengulangan transaksi (contoh: pembuatan invoice atau order yang tidak boleh ganda):

1. **Duplicate Key (Status: SUCCESS)**:
   - Jika request datang dengan `X-Transaction-Id` atau `X-Idempotency-Key` yang sebelumnya sudah berstatus `SUCCESS`, middleware **TIDAK** memanggil backend eksternal lagi.
   - Respons sukses sebelumnya langsung di-replay dari kolom `response_payload` dengan header `X-Idempotent-Replay: true`.
2. **In-Flight Concurrency (Status: PROCESSING)**:
   - Jika request identik datang saat transaksi pertama masih diproses oleh worker lain, middleware merespons dengan **HTTP 409 Conflict** untuk mencegah race condition.
3. **Transaction Belum Ada**:
   - Dibuat record baru di `api_transaction` dengan status `PROCESSING`.

---

## 5. Asynchronous Background Worker

Worker diimplementasikan pada sequence [RetryWorkerSeq.xml](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/middleware-assa/middleware-assa/middleware-assa/src/main/wso2mi/artifacts/sequences/RetryWorkerSeq.xml) dan diakses melalui REST API:

- **Endpoint Worker**: `POST /api/worker/retry` (atau `GET /api/worker/retry`)
- **Fungsi**:
  1. Melakukan polling tabel `api_transaction` mencari transaksi berstatus `FAILED` atau `RETRY` yang jadwal `next_retry_at` nya telah tiba (`next_retry_at <= NOW()`).
  2. Memperbarui status transaksi menjadi `RETRY` dengan jadwal backoff 5 menit untuk mencegah duplikasi penarikan oleh worker lain.
  3. Mencatat aktivitas penanganan worker ke `api_transaction_log` dengan `attempt_number = 0` dan status `202 Accepted`.
  4. Memastikan request penting dari klien tidak hilang meskipun backend eksternal mengalami gangguan selama beberapa jam.

---

## 6. Verifikasi & Pengujian Otomatis

Seluruh skenario telah diuji secara otomatis melalui script: [run_resiliency_tests.ps1](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/test/run_resiliency_tests.ps1).

### Cara Menjalankan Test:
Buka PowerShell dan jalankan:
```powershell
cd c:\Users\eksad\OneDrive\Documents\assa\code\middleware-assa-all
powershell -ExecutionPolicy Bypass -File "test\run_resiliency_tests.ps1"
```

### Hasil Verifikasi (5/5 PASSED):
1. `[TEST 1]` Health Check Probe -> **PASSED** (HTTP 200 UP)
2. `[TEST 2]` External Call Sukses & DB Logging -> **PASSED** (`api_transaction` status SUCCESS, attempt 1 tercatat di `api_transaction_log`)
3. `[TEST 3]` Idempotency Duplicate Detection -> **PASSED** (`X-Idempotent-Replay: true`, hitungan attempt tetap 1 tanpa memanggil ulang backend)
4. `[TEST 4]` 3x Retry Loop pada Backend Down -> **PASSED** (Mencoba 3x berturut-turut, seluruh 3 percobaan tercatat lengkap di `api_transaction_log`, status akhir `FAILED`, alert terpicu, dan HTTP 502 dikembalikan)
5. `[TEST 5]` Background Worker Trigger -> **PASSED** (`/api/worker/retry` memproses transaksi tertunda di antrean secara asinkron)
