# 📊 KONSEP — Monitoring & Observability (ASSA Middleware)

Dokumen ini menjelaskan **konsep monitoring** untuk ASSA Middleware: bagaimana kita
mengetahui platform sehat, siapa yang mengakses, seberapa cepat, dan kapan ada masalah.

> Tujuan monitoring: **tahu lebih dulu sebelum pengguna komplain.** Setiap request harus
> dapat dilihat, diukur, dan ditelusuri — termasuk **aplikasi mana** yang mengaksesnya
> (terhubung dengan konsep token per-aplikasi di `KONSEP.md`).

---

## 1. Tujuan Monitoring

1. **Ketersediaan (Availability)** — apakah middleware & backend hidup dan responsif.
2. **Kinerja (Performance)** — seberapa cepat request diproses (latency, throughput).
3. **Kebenaran (Correctness)** — berapa banyak error, jenis error, di endpoint mana.
4. **Akuntabilitas (Accountability)** — siapa (aplikasi mana) mengakses apa dan kapan.
5. **Kapasitas (Capacity)** — tren beban untuk perencanaan scaling.

---

## 2. Tiga Pilar Observability

Monitoring dibangun di atas tiga pilar standar:

```
┌───────────────────────────────────────────────────────────────┐
│                     OBSERVABILITY                               │
├─────────────────┬─────────────────┬───────────────────────────┤
│      LOGS        │     METRICS     │          TRACES           │
│  "apa yang       │  "berapa &      │  "perjalanan 1 request    │
│   terjadi"       │   seberapa"     │   dari awal → backend"    │
├─────────────────┼─────────────────┼───────────────────────────┤
│ Access log,      │ Jumlah request, │ Correlation ID melintasi  │
│ error log,       │ latency, error  │ API → Auth → Endpoint →    │
│ audit per appId  │ rate, uptime    │ Backend → response         │
└─────────────────┴─────────────────┴───────────────────────────┘
```

| Pilar | Menjawab pertanyaan | Contoh isi |
|---|---|---|
| **Logs** | Apa yang terjadi pada request ini? | `[2026-09-11 10:00:00] app=APP_A endpoint=/getByBranchCode status=200 durationMs=120` |
| **Metrics** | Berapa banyak & seberapa cepat? | `requests_total`, `latency_p95`, `error_rate`, `uptime` |
| **Traces** | Bagaimana alur satu request? | trace-id `abc123` melewati Auth → Endpoint → Backend |

---

## 3. Apa yang Dimonitor (What to Observe)

### 3.1 Level Request (per panggilan API)
- Timestamp masuk & selesai.
- **`appId`** pemilik token (siapa yang akses) — dari Auth Guard.
- Endpoint/domain yang diakses (mis. `/api/branches/getByBranchCode`).
- Parameter kunci (companyCode, branchCode, page, perPage, search).
- Status HTTP hasil (200 / 401 / 403 / 5xx).
- **Durasi (latency)** proses middleware.
- **Durasi backend** (waktu panggilan ke SAP Core).
- **Correlation ID** untuk tracing.

### 3.2 Level Sistem (kesehatan platform)
- Middleware hidup/tidak (health check).
- Konektivitas ke backend SAP Core (reachable/tidak).
- Penggunaan resource (CPU, memori, thread pool) — dari runtime WSO2 MI/JVM.
- Uptime & jumlah restart.

### 3.3 Level Keamanan (audit)
- Request ditolak (401/403) beserta `appId` (jika token dikenal) atau `unknown`.
- Percobaan akses tanpa token / token invalid — deteksi anomali/abuse.
- Aktivitas per aplikasi (volume per `appId`).

---

## 4. Metrik Kunci (Key Metrics / KPI)

| Metrik | Definisi | Kenapa penting |
|---|---|---|
| **Request rate** | Jumlah request per menit (per endpoint & per appId) | Beban & tren pemakaian |
| **Error rate** | % request dengan status ≥ 400 | Indikator kesehatan |
| **Latency p50/p95/p99** | Waktu proses (median & ekor) | Pengalaman pengguna |
| **Backend latency** | Waktu tunggu SAP Core | Isolasi: middleware vs backend |
| **Availability / Uptime** | % waktu middleware sehat | SLA |
| **Auth failure rate** | Jumlah 401/403 | Indikator keamanan/misconfig |
| **Top consumers** | appId dengan request terbanyak | Kapasitas & fair-use |

---

## 5. Konsep Alur Monitoring (Conceptual Flow)

```
                    setiap request menghasilkan sinyal observability
                                        │
   ┌──────────────┐   logs+metrics   ┌──▼───────────────┐
   │  ASSA         │ ───────────────► │  COLLECTION LAYER │
   │  MIDDLEWARE   │   (structured)   │  (log file /      │
   │  (WSO2 MI)    │                  │   agent / metrics │
   └──────┬────────┘                  │   endpoint)       │
          │ health/metrics endpoint   └──────┬───────────┘
          ▼                                  │  kirim/scrape
   ┌───────────────┐                 ┌───────▼───────────┐
   │ Health Check   │                │  STORAGE &          │
   │ (liveness/     │                │  VISUALIZATION      │
   │  readiness)    │                │  (dashboard, grafik)│
   └───────────────┘                 └───────┬───────────┘
                                              │ ambang terlampaui
                                      ┌───────▼───────────┐
                                      │  ALERTING          │
                                      │ (email/Slack/WA)   │
                                      └───────────────────┘
```

1. **Middleware menghasilkan sinyal** (logs terstruktur + metrics) di setiap request.
2. **Collection layer** mengumpulkan (baca file log / agen / scrape metrics endpoint).
3. **Storage & visualization** menyimpan dan menampilkan dalam dashboard/grafik.
4. **Alerting** memberi notifikasi bila ambang batas terlampaui (mis. error rate tinggi).

---

## 6. Logging Terstruktur (Structured Logging)

Access log sebaiknya **terstruktur** (mudah diparse), bukan teks bebas. Contoh format:

```json
{
  "timestamp": "2026-09-11T10:00:00+07:00",
  "level": "ACCESS",
  "correlationId": "abc-123-def",
  "appId": "APP_A",
  "endpoint": "/api/branches/getByBranchCode",
  "params": { "companyCode": "1000", "branchCode": "1141", "page": 1, "perPage": 10 },
  "status": 200,
  "durationMs": 120,
  "backendMs": 85
}
```

Manfaat format terstruktur:
- Mudah difilter (mis. "semua error dari APP_A hari ini").
- Bisa diagregasi jadi metrics (hitung error rate per appId).
- Siap dikonsumsi tools log (ELK/Loki/CloudWatch) di tahap lanjut.

> Saat ini middleware sudah punya `LogRequestSeq` (menulis access log ke file & konsol).
> Konsep ini menyempurnakannya: tambahkan `appId`, `status`, `durationMs`, dan `correlationId`,
> serta format terstruktur.

---

## 7. Health Check

Sediakan endpoint kesehatan agar sistem luar (load balancer, K8s, uptime monitor) bisa cek:

| Jenis | Tujuan | Contoh hasil |
|---|---|---|
| **Liveness** | Middleware hidup? | `200 { "status": "UP" }` |
| **Readiness** | Siap menerima trafik & backend reachable? | `200 { "status": "READY", "backend": "UP" }` |

Konsep endpoint: `/health` (liveness) dan `/health/ready` (readiness). Tidak memerlukan
token agar bisa dipakai probe infrastruktur, tetapi tidak membocorkan data sensitif.

---

## 8. Tracing (Correlation ID)

Untuk menelusuri satu request lintas komponen:
- Middleware **membuat `correlationId`** di awal (atau memakai header `X-Correlation-Id`
  dari konsumen bila ada).
- ID ini disertakan di semua log terkait request tersebut dan diteruskan ke backend.
- Saat ada masalah, satu ID cukup untuk merekonstruksi seluruh perjalanan request:
  `Auth → Orchestration → Endpoint → Backend → Response`.

---

## 9. Alerting (Notifikasi Dini)

Contoh aturan alert (ambang batas bisa disesuaikan):

| Kondisi | Ambang contoh | Tindakan |
|---|---|---|
| Error rate melonjak | > 5% selama 5 menit | Notifikasi tim integrasi |
| Latency p95 tinggi | > 2 detik selama 5 menit | Investigasi backend/beban |
| Backend tidak reachable | gagal health readiness | Alert kritikal |
| Lonjakan 401/403 | > N per menit dari satu IP/appId | Indikasi abuse → tinjau keamanan |
| Middleware down | liveness gagal | Alert kritikal + auto-restart |

### 9.1. Alerting Resiliency & MariaDB Transaction Audit Trail (Port 3307)
Ketika pemanggilan external API gagal 3x berturut-turut:
1. **Audit Trail Otomatis**: Setiap percobaan (attempt 1, 2, 3) dicatat ke MariaDB lokal (Port 3307) pada tabel `api_transaction_log` lengkap dengan HTTP status code, pesan galat, dan latensi (`duration_ms`).
2. **Alert Monitoring**: Sistem memicu log berkategori khusus:
   ```text
   [ALERT MONITORING] Transaksi ID: <trxId> GAGAL setelah 3x percobaan. Status akhir: FAILED. Dimasukkan ke Asynchronous Retry Queue (MariaDB).
   ```
3. **Asynchronous Retry Queue**: Transaksi berstatus `FAILED` dijadwalkan ulang melalui kolom `next_retry_at` dan dipantau oleh Background Worker (`POST /api/worker/retry`) agar request penting tidak hilang.
4. Panduan teknis lengkap tersedia pada [DATABASE_SETUP_GUIDE.md](file:///c:/Users/eksad/OneDrive/Documents/assa/code/middleware-assa-all/notes/DATABASE_SETUP_GUIDE.md).

---

## 10. Tingkat Kematangan Monitoring (Maturity Levels)

Diterapkan bertahap agar tidak over-engineering di awal:

| Level | Kemampuan | Alat (contoh) | Status target |
|---|---|---|---|
| **L1 — Dasar** | Access log & error log ke file + konsol | `LogRequestSeq`, konsol WSO2 MI | Sebagian sudah ada |
| **L2 — Terstruktur** | Log JSON + appId + durasi + correlationId | Penyempurnaan sequence | Berikutnya |
| **L3 — Terpusat** | Kirim log ke sistem terpusat + dashboard | ELK / Grafana Loki / CloudWatch | Menengah |
| **L4 — Metrics & Alert** | Metrics endpoint + dashboard + alerting | Prometheus + Grafana + Alertmanager | Lanjut |
| **L5 — Full Observability** | Metrics + logs + distributed tracing | + OpenTelemetry / Jaeger | Matang |

---

## 11. Integrasi dengan Konsep Lain

- **Dengan `KONSEP.md` (Auth Token)**: setiap log & metrik dilabeli `appId` dari Auth Guard,
  sehingga monitoring bisa menjawab "aplikasi mana yang error/lambat/paling sering akses".
- **Dengan `CLEAN_ARCHITECTURE.md`**: monitoring memanfaatkan shared sequence
  (`LogRequestSeq`, dan nanti `AuthGuardSeq`) sebagai titik pengumpulan sinyal, konsisten
  dengan prinsip komponen reusable.
- **Dengan `KONSEP_BESAR.md`**: mewujudkan prinsip "Observability by Default".

---

## 12. Ringkasan

- Monitoring bertumpu pada tiga pilar: **Logs, Metrics, Traces**, ditambah **Health Check**
  dan **Alerting**.
- Setiap request diukur: siapa (`appId`), apa (endpoint), hasil (status), seberapa cepat
  (latency), dan bisa ditelusuri (correlationId).
- Diterapkan **bertahap** (L1 → L5) mulai dari access log yang sudah ada hingga observability
  penuh dengan dashboard & alert.
- Terhubung erat dengan konsep token per-aplikasi: monitoring bukan cuma tahu "ada error",
  tapi tahu **aplikasi mana** dan **kenapa**.

---

## 13. Dokumen Terkait

- `KONSEP.md` — visi & konsep besar platform.
- `KONSEP.md` — autentikasi token per aplikasi (sumber `appId` untuk monitoring).
- `CLEAN_ARCHITECTURE.md` — arsitektur teknis target (tempat komponen monitoring didetailkan).
