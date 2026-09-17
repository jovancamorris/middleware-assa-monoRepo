# Panduan: Cara Get Data dari Vehicle Atlas

Panduan praktis langkah demi langkah untuk mengambil data kendaraan dari endpoint `getVehicleAtlas`.

> Dokumen ini fokus pada **cara pakai (how-to)**. Untuk referensi lengkap field & aturan, lihat [api-vehicleatlas.md](./api-vehicleatlas.md).

---

## Ringkas

| Item | Nilai |
|------|-------|
| Method | `GET` |
| URL | `{BASE_URL}/api/vehicleatlas` |
| Header wajib | `Key: <API_KEY>` |
| Parameter | Dikirim sebagai **query string** (opsional) |

---

## Langkah 1 — Siapkan Base URL

Pilih sesuai environment:

| Environment | Base URL |
|-------------|----------|
| Local (dev server) | `http://127.0.0.1:8899` |
| Dev | `https://devfmsapi.assa.id` |
| Production | `https://<host-prod-fms-api>` |

URL akhir menjadi: `{BASE_URL}/api/vehicleatlas`

---

## Langkah 2 — Siapkan API Key

- Ambil API Key dari environment variable `SECRET_KEY` (server bisa punya beberapa key, dipisah koma — pakai salah satu).
- Kirim di HTTP header bernama persis **`Key`** (huruf `K` kapital).

```
Key: <API_KEY>
```

> Tanpa header `Key` yang benar, request akan ditolak dengan HTTP `403`.

---

## Langkah 3 — Kirim Request GET

### Tanpa filter (ambil semua, pagination default 20)

```
GET {BASE_URL}/api/vehicleatlas
Header: Key: <API_KEY>
```

### Dengan filter (query string)

```
GET {BASE_URL}/api/vehicleatlas?plate_no=DD-8112&limit=50
Header: Key: <API_KEY>
```

> Penting: parameter dikirim di **URL (query string)**, bukan di body. Method-nya `GET`.

---

## Langkah 4 — Baca Response

Response sukses (HTTP 200):

```json
{
    "message": "success",
    "code": 200,
    "offset": 0,
    "limit": 20,
    "count": 2,
    "total": 39018,
    "data": [
        {
            "equipment_no": "10027282",
            "plate_no": "DD-8112-YC",
            "branch_code": "1411",
            "branch_name": "Makassar",
            "tipe_kendaraan": "DAIHATSU GRAN MAX BV AC AB 1.3 M/T",
            "unit_allocation": "LT",
            "status_id": 11,
            "asset_status": "1",
            "responsible_area": "c",
            "booking_status": "0",
            "color": "WHITE DSO",
            "production_year": 2018
        }
    ]
}
```

Yang perlu diperhatikan:
- `data` → array unit kendaraan.
- `total` → total data yang cocok filter (dipakai untuk pagination).
- `count` → jumlah data pada halaman ini.

---

## Cara Get Berdasarkan Kebutuhan

### 1. Get semua data (paginated)

```bash
curl --location "{BASE_URL}/api/vehicleatlas?limit=100&offset=0" \
     --header "Key: <API_KEY>"
```

### 2. Cari berdasarkan nomor polisi (partial)

`plate_no` memakai pencarian sebagian (LIKE), jadi fragmen pun cocok.

```bash
curl --location "{BASE_URL}/api/vehicleatlas?plate_no=DD-8112" \
     --header "Key: <API_KEY>"
```

### 3. Cari berdasarkan equipment_no (satu / banyak)

`equipment_no` exact match, hanya angka. Multi-nilai dipisah koma.

```bash
# satu
curl --location "{BASE_URL}/api/vehicleatlas?equipment_no=10027282" \
     --header "Key: <API_KEY>"

# banyak
curl --location "{BASE_URL}/api/vehicleatlas?equipment_no=10027282,10034434" \
     --header "Key: <API_KEY>"
```

### 4. Filter per cabang

```bash
curl --location "{BASE_URL}/api/vehicleatlas?branch_code=1411&limit=50" \
     --header "Key: <API_KEY>"
```

### 5. Kombinasi filter

```bash
curl --location "{BASE_URL}/api/vehicleatlas?branch_code=1411&status_id=11&color=putih&limit=50" \
     --header "Key: <API_KEY>"
```

---

---

## Menangani Response Error

| HTTP | Arti | Yang harus dilakukan |
|------|------|----------------------|
| `200` | Sukses | Proses `data`. Gunakan `total` untuk pagination |
| `400` | Parameter tidak valid | Periksa nilai parameter (lihat aturan validasi di referensi) |
| `403` | API Key salah/tidak ada | Pastikan header `Key` dikirim & nilainya benar |

Contoh body `403`:

```json
{ "error": "API Key is Missing" }
```

---