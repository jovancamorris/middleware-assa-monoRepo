# 🔐 KONSEP — Autentikasi Token per Aplikasi (ASSA Middleware)

Dokumen ini menjelaskan **konsep keamanan akses** ke ASSA Middleware. Aturan utamanya:

> **Setiap aplikasi yang mengakses ASSA Middleware WAJIB membawa token.**
> Setiap aplikasi memiliki **token sendiri yang berbeda** dari aplikasi lain.

Contoh:
- **Apps A** mengonsumsi middleware → punya **Token A** (unik milik A).
- **Apps B** mengonsumsi middleware → punya **Token B** (unik milik B, berbeda dari A).

Tidak ada akses tanpa token. Tidak ada token yang dipakai bersama antar aplikasi.

---

## 1. Prinsip Dasar

1. **Wajib Token (Mandatory Auth)** — semua request ke middleware harus menyertakan token.
   Request tanpa token / token tidak valid → **ditolak (401 Unauthorized)**.
2. **Satu Aplikasi, Satu Identitas (Per-App Credential)** — setiap aplikasi konsumen
   memiliki token unik. Token A ≠ Token B.
3. **Isolasi** — token satu aplikasi tidak bisa dipakai untuk "menyamar" jadi aplikasi lain.
4. **Dapat Dicabut (Revocable)** — bila token bocor atau aplikasi dinonaktifkan,
   token-nya bisa dicabut tanpa mengganggu aplikasi lain.
5. **Dapat Ditelusuri (Auditable)** — setiap request tercatat beserta identitas aplikasi
   pemilik token.

---

## 2. Kenapa Token per Aplikasi (Bukan Token Tunggal)

| Aspek | Token Bersama (❌) | Token per Aplikasi (✅) |
|---|---|---|
| **Identifikasi** | Tidak tahu siapa yang akses | Tahu persis aplikasi mana |
| **Pencabutan** | Cabut = semua aplikasi mati | Cabut satu, lainnya tetap jalan |
| **Kebocoran** | 1 bocor = semua terancam | Dampak terisolasi ke 1 aplikasi |
| **Audit** | Log tidak bisa dibedakan | Log per aplikasi jelas |
| **Kontrol akses** | Seragam untuk semua | Bisa beda hak akses per aplikasi |

---

## 3. Gambaran Alur (Conceptual Flow)

```
┌──────────┐   Authorization: Bearer <Token A>   ┌─────────────────────┐
│  Apps A  │ ───────────────────────────────────►│                     │
└──────────┘                                       │   ASSA MIDDLEWARE   │
                                                   │   (WSO2 MI)         │
┌──────────┐   Authorization: Bearer <Token B>   │                     │
│  Apps B  │ ───────────────────────────────────►│  ┌───────────────┐  │
└──────────┘                                       │  │ Auth Guard    │  │
                                                   │  │ 1. Ada token? │  │
┌──────────┐   (tanpa token)                       │  │ 2. Valid?     │  │
│  Apps C  │ ───────────────────────────────────►│  │ 3. Milik app? │  │
└──────────┘        │                              │  └──────┬────────┘  │
                    │                              │         │           │
                    ▼                              │    valid│ tidak     │
              ❌ 401 Unauthorized                  │         ▼    valid   │
                                                   │   proses request     │
                                                   │   + log identitas    │──► 401/403
                                                   └─────────────────────┘
                                                             │
                                                             ▼
                                                   Backend SAP Core API
```

Ringkas:
1. Aplikasi mengirim token di header setiap request.
2. Middleware memeriksa token pada **Auth Guard** (gerbang autentikasi) di depan.
3. Token valid → request diteruskan & dicatat dengan identitas aplikasi.
4. Token kosong/tidak valid → ditolak (401). Token valid tapi tak berhak → ditolak (403).

---

## 4. Cara Aplikasi Mengirim Token

Semua aplikasi mengirim token melalui HTTP header (standar `Bearer`):

```http
GET /api/branches/getByBranchCode?companyCode=1000&branchCode=1141 HTTP/1.1
Host: middleware.assa.id
Authorization: Bearer <TOKEN_MILIK_APLIKASI>
```

Contoh perbedaan token antar aplikasi:

```http
# Apps A
Authorization: Bearer APPA.a1b2c3d4-....-tokenA

# Apps B
Authorization: Bearer APPB.z9y8x7w6-....-tokenB
```

> Nilai token bersifat **rahasia**. Contoh di atas hanya ilustrasi format, bukan token nyata.

---

## 5. Konsep Identitas Aplikasi (App Registry)

Setiap aplikasi konsumen didaftarkan lebih dulu. Secara konsep, registry menyimpan:

| Field | Keterangan |
|---|---|
| `appId` | Identitas unik aplikasi (mis. `APP_A`, `APP_B`) |
| `appName` | Nama aplikasi konsumen |
| `token` | Token unik milik aplikasi (disimpan sebagai hash/rahasia, bukan plain) |
| `status` | `active` / `revoked` |
| `scopes` (opsional) | Daftar domain/endpoint yang boleh diakses aplikasi ini |
| `createdAt` / `expiresAt` | Masa berlaku token |

Prinsip penyimpanan:
- Token **tidak** disimpan sebagai teks polos; simpan sebagai hash atau di secret store.
- Satu `appId` memetakan ke tepat satu token aktif (rotasi menghasilkan token baru).

---

## 6. Perbedaan Token: Apps A vs Apps B (Contoh)

| | **Apps A** | **Apps B** |
|---|---|---|
| appId | `APP_A` | `APP_B` |
| Token | `Token A` (unik) | `Token B` (unik, ≠ Token A) |
| Akses | mis. domain Customer | mis. domain Finance |
| Jika Token A bocor | hanya Apps A dicabut/rotasi | Apps B **tidak terpengaruh** |
| Log | tercatat sebagai `APP_A` | tercatat sebagai `APP_B` |

Poin kunci: **token bersifat per-aplikasi dan saling terisolasi.** Masalah pada satu
aplikasi tidak merembet ke aplikasi lain.

---

## 7. Skenario Response

| Kondisi | Hasil | HTTP Status |
|---|---|---|
| Token ada & valid & berhak | Request diproses | `200 OK` |
| Tidak ada header `Authorization` | Ditolak | `401 Unauthorized` |
| Token tidak dikenal / kedaluwarsa / dicabut | Ditolak | `401 Unauthorized` |
| Token valid tapi tidak berhak ke endpoint/domain itu | Ditolak | `403 Forbidden` |

Contoh bentuk response penolakan (konsisten dengan kontrak error middleware):

```json
{
  "error": true,
  "message": "Unauthorized",
  "detail": "Token tidak ditemukan atau tidak valid"
}
```

---

## 8. Konsep Penerapan di WSO2 MI (High-Level)

Autentikasi diterapkan sebagai **gerbang di depan** sebelum logika bisnis, sehingga
seluruh domain (Customer/Finance/Procurement) terlindungi secara seragam.

```
API Layer (BranchAPI, dll)
   │
   ▼
AuthGuardSeq   ◄── shared sequence baru (reusable)
   │  • baca header Authorization
   │  • validasi token → App Registry
   │  • set properti appId untuk logging
   │  • jika gagal → ErrorResponseSeq (401/403) + hentikan alur
   ▼
Orchestration Seq (business) → Endpoint → Pagination → Response
```

Konsep komponen yang perlu ditambahkan:
- **`AuthGuardSeq`** — sequence reusable yang dipanggil paling awal di setiap resource.
- **Sumber validasi token** — pilihan konsep (dari sederhana → matang):
  1. Daftar token statis di konfigurasi (paling sederhana, untuk awal).
  2. Datasource / DB registry aplikasi (lebih fleksibel & revocable).
  3. OAuth2 / JWT via identity provider (paling matang, tervalidasi & ber-scope).
- **`appId` dicatat di access log** (integrasi dengan `LogRequestSeq`) agar audit jelas.

> Detail teknis implementasi (XML sequence, skema tabel, mekanisme hashing) akan
> dijabarkan pada dokumen arsitektur teknis, bukan di dokumen konsep ini.

---

## 9. Praktik Keamanan Token (Guidelines)

1. **Rahasia** — token diperlakukan seperti password; jangan pernah di-commit ke repo.
2. **HTTPS wajib** — token hanya dikirim melalui koneksi terenkripsi.
3. **Rotasi berkala** — token diganti secara periodik atau saat dicurigai bocor.
4. **Least privilege** — aplikasi hanya diberi akses domain/endpoint yang benar-benar dibutuhkan.
5. **Simpan sebagai hash** — di sisi middleware, simpan hash token, bukan teks polos.
6. **Audit** — setiap akses tercatat dengan `appId`, waktu, dan endpoint.

---

## 10. Ringkasan

- Setiap aplikasi **wajib** membawa token untuk mengakses ASSA Middleware.
- **Apps A punya Token A**, **Apps B punya Token B** — token **berbeda dan terisolasi**.
- Tanpa token / token tidak valid → **401**. Valid tapi tak berhak → **403**.
- Token per-aplikasi memberi **identifikasi, pencabutan selektif, isolasi kebocoran,
  dan audit** yang jelas.
- Diterapkan sebagai **Auth Guard reusable** di depan seluruh domain di WSO2 MI.

---

## 11. Dokumen Terkait

- `KONSEP_BESAR.md` — visi & konsep besar platform.
- `CLEAN_ARCHITECTURE.md` — arsitektur teknis target (tempat `AuthGuardSeq` akan didetailkan).
