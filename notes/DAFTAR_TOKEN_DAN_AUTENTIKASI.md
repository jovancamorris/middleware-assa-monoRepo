# Daftar Token & Panduan Autentikasi API
## ASSA Middleware — WSO2 Micro Integrator Monorepo

Dokumen ini berisi daftar lengkap kredensial token autentikasi yang digunakan di seluruh layanan ASSA Middleware. 

> [!IMPORTANT]
> **Keamanan Kredensial**:
> Seluruh token ini **sengaja tidak dicantumkan di Swagger / OpenAPI UI** agar tidak terekspos secara publik. Gunakan dokumen ini sebagai referensi internal tim pengembang.

---

## 1. Mekanisme Autentikasi Middleware

Setiap request yang masuk ke API Middleware divalidasi oleh sequence terpusat [`AuthGuardSeq.xml`](file:///Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo/shared/src/main/wso2mi/artifacts/sequences/AuthGuardSeq.xml).

### Header yang Didukung:
1. **`Authorization: Bearer <token>`** (Standar HTTP Bearer Authentication)
2. **`X-API-Key: <token>`** atau `x-api-key: <token>` (Untuk kemudahan integrasi vendor seperti Barantum CRM)

### Hierarki Resolusi Token di WSO2 MI:
1. `get-property('env', '<ENV_VAR_NAME>')` — Environment variable server / docker container (Prioritas Tertinggi)
2. `get-property('system', '<config.key>')` — Java system property
3. `get-property('file', '<config.key>')` — File `config.properties`
4. Hardcoded Fallback di `AuthGuardSeq.xml` — Nilai default jika env belum diset

---

## 2. Matriks Token, Scope & Izin Akses

| Client / Aplikasi | Variabel Environment | Scope Izin | Format Header | Nilai Token |
|---|---|---|---|---|
| **Barantum CRM** | `AUTH_APP_BARANTUM_TOKEN` | `service_requests` | `X-API-Key` atau `Bearer` | `umk_2d35d5538f25624fc716958934d1751889cb7f6a0b0f1df18667032272eb86fd` |
| **Omnichannel** | `AUTH_APP_OMNICHANNEL_TOKEN` | `service_requests` | `Bearer` | `14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12` |
| **App QA** | `AUTH_APP_QA_TOKEN` | `branches, customers, vehicles, vendors, service_requests, spk` | `Bearer` | `e20b33b006bc229d49dd701c385f8abfbe6a24726fb51db11624bce3766627be` |
| **App A** | `AUTH_APP_A_TOKEN` | `branches, customers, vehicles, vendors, service_requests, spk` | `Bearer` | `c220fbfbc7e4c925eb662d85be47ee5ab017d23d9b04f7c22df6cb7efb6dfdbd` |
| **App B** | `AUTH_APP_B_TOKEN` | `vehicles` | `Bearer` | `988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881` |
| **App ATLAS** | `AUTH_APP_ATLAS_TOKEN` | `vendors` | `Bearer` | `ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d` |

---

## 3. Rincian Token Siap Copas

### 1. Barantum CRM (Public Gateway Service Request)
- **Kegunaan**: Submit Service Request (SR) tiket baru & tracking status SR untuk vendor publik Barantum CRM.
- **Scope**: `service_requests`
- **Nilai Token**:
  ```text
  umk_2d35d5538f25624fc716958934d1751889cb7f6a0b0f1df18667032272eb86fd
  ```
- **Contoh Header**:
  ```http
  X-API-Key: umk_2d35d5538f25624fc716958934d1751889cb7f6a0b0f1df18667032272eb86fd
  ```
- **Endpoint**:
  - `POST /api/service-requests`
  - `POST /api/v1/service-requests`
  - `GET /api/service-requests/{sr_id}`

---

### 2. App Omnichannel (Internal ASSA SR)
- **Kegunaan**: Integrasi submit tiket Service Request dari sistem internal Omnichannel ASSA.
- **Scope**: `service_requests`
- **Nilai Token**:
  ```text
  14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12
  ```
- **Contoh Header**:
  ```http
  Authorization: Bearer 14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12
  ```
- **Endpoint**:
  - `POST /api/service-requests`
  - `GET /api/service-requests/{sr_id}`

---

### 3. App QA (Testing All Services)
- **Kegunaan**: Testing otomatis Postman Test Suite & manual testing seluruh modul integrasi.
- **Scope**: `branches, customers, vehicles, vendors, service_requests, spk` (Full Scopes)
- **Nilai Token**:
  ```text
  e20b33b006bc229d49dd701c385f8abfbe6a24726fb51db11624bce3766627be
  ```
- **Contoh Header**:
  ```http
  Authorization: Bearer e20b33b006bc229d49dd701c385f8abfbe6a24726fb51db11624bce3766627be
  ```
- **Endpoint**: Seluruh endpoint API Middleware.

---

### 4. App A (Super Client Internal)
- **Kegunaan**: Aplikasi internal ASSA tingkat tinggi dengan hak akses menyeluruh ke semua modul.
- **Scope**: `branches, customers, vehicles, vendors, service_requests, spk` (Full Scopes)
- **Nilai Token**:
  ```text
  c220fbfbc7e4c925eb662d85be47ee5ab017d23d9b04f7c22df6cb7efb6dfdbd
  ```
- **Contoh Header**:
  ```http
  Authorization: Bearer c220fbfbc7e4c925eb662d85be47ee5ab017d23d9b04f7c22df6cb7efb6dfdbd
  ```
- **Endpoint**: Seluruh endpoint API Middleware.

---

### 5. App B (Vehicle Service Only)
- **Kegunaan**: Khusus modul data kendaraan, inquiry plat nomor, dan spesifikasi unit ASSA.
- **Scope**: `vehicles`
- **Nilai Token**:
  ```text
  988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881
  ```
- **Contoh Header**:
  ```http
  Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881
  ```
- **Endpoint**: `/api/vehicles/*`

---

### 6. App ATLAS (Vendor Service Only)
- **Kegunaan**: Akses data master vendor bengkel & rekanan ASSA untuk sistem ATLAS.
- **Scope**: `vendors`
- **Nilai Token**:
  ```text
  ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d
  ```
- **Contoh Header**:
  ```http
  Authorization: Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d
  ```
- **Endpoint**: `/api/vendors/*`

---

## 4. Token Egress (Outbound Middleware ke Backend / Pihak Ketiga)

Saat Middleware meneruskan request ke backend hilir (misalnya pada Service Request fan-out):

| Variabel Environment | Default Value | Target Backend |
|---|---|---|
| `SR_EXT_API_KEY` | `umk_2d35d5538f25624fc716958934d1751889cb7f6a0b0f1df18667032272eb86fd` | AWS Lambda ASSA Ext Service (`assa-ext-services.assa.id`) |
| `SR_TARGET_ATLAS_API_KEY` | `umk_2d35d5538f25624fc716958934d1751889cb7f6a0b0f1df18667032272eb86fd` | API ATLAS (`atlas-api.assa.id`) — *Jika diaktifkan* |

---

## 5. Snippet Konfigurasi `.env` Server Dev

Salin blok berikut langsung ke file `.env` di server dev (`/var/www/devmiddleware/.env`):

```bash
# ==============================================================================
# ASSA MIDDLEWARE TOKENS CONFIGURATION
# ==============================================================================

# 1. Ingress Tokens (Kredensial Client Pemanggil API Middleware)
AUTH_APP_BARANTUM_TOKEN=umk_2d35d5538f25624fc716958934d1751889cb7f6a0b0f1df18667032272eb86fd
AUTH_APP_OMNICHANNEL_TOKEN=14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12
AUTH_APP_QA_TOKEN=e20b33b006bc229d49dd701c385f8abfbe6a24726fb51db11624bce3766627be
AUTH_APP_A_TOKEN=c220fbfbc7e4c925eb662d85be47ee5ab017d23d9b04f7c22df6cb7efb6dfdbd
AUTH_APP_B_TOKEN=988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881
AUTH_APP_ATLAS_TOKEN=ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d

# 2. Outbound Egress API Keys (Middleware memanggil downstream)
SR_EXT_API_KEY=umk_2d35d5538f25624fc716958934d1751889cb7f6a0b0f1df18667032272eb86fd
SR_TARGET_ATLAS_API_KEY=umk_2d35d5538f25624fc716958934d1751889cb7f6a0b0f1df18667032272eb86fd
```

---

## 6. Contoh Perintah cURL untuk Testing

### Test 1: Service Request dengan Barantum CRM (X-API-Key)
```bash
curl -X POST "http://localhost:8290/api/service-requests" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: umk_2d35d5538f25624fc716958934d1751889cb7f6a0b0f1df18667032272eb86fd" \
  -d '{
    "customer_code": "0000000001",
    "customer_name": "PT ABC TEST",
    "contact_person": "Budi",
    "contact_person_phone": "08123456789",
    "contact_person_address": "Jl. Sudirman No 1",
    "branch_code": "0101",
    "police_number": "B 1234 CD",
    "vehicle_category": "Passenger",
    "service_type": "Berkala",
    "service_location": "Pool ASSA",
    "service_date": "2026-10-01",
    "service_time": "09:00",
    "notes": "Testing SR Barantum"
  }'
```

### Test 2: Inquery Vehicle dengan App B (Bearer Token)
```bash
curl -X GET "http://localhost:8290/api/vehicles/B1234CD" \
  -H "Authorization: Bearer 988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881"
```

### Test 3: Akses Semua Service dengan App QA
```bash
curl -X GET "http://localhost:8290/api/branches" \
  -H "Authorization: Bearer e20b33b006bc229d49dd701c385f8abfbe6a24726fb51db11624bce3766627be"
```
