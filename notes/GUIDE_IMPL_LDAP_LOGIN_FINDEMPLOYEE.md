# Implementation Guide (Team Middleware) — LDAP Login + Find Employee

> **Status:** PROPOSED / TO BUILD. Endpoint & artefak di bawah **belum ada** di repo; dokumen ini memandu cara membuatnya.
> **Keamanan:** endpoint login menangani **kredensial**. Jangan pernah log `password`, jangan hardcode credential/URL rahasia, dan jangan commit nilai `.env`. Semua kredensial via nama variabel + placeholder.

Dua endpoint yang dibangun di middleware (service baru atau existing — lihat bagian 1):

1. **LDAP Login** — menerima `username` + `password`, mem-forward ke backend HC `/auth/login` (body `x-www-form-urlencoded`), mengembalikan hasilnya.
2. **Find Employee** — menerima `username`, mem-forward ke backend HC `/userldap/getbyusername` (query param), mengembalikan hasilnya.

Backend HC (contoh dev): `https://devhcbead.assa.id`.

---

## 1. Keputusan service & penempatan

Opsi penempatan (pilih, catat di PR):

- **Opsi 1 (disarankan): service baru `integrations/auth-service`** — login/identity adalah domain tersendiri, konsisten dengan pola "satu service per domain" di repo. Port host baru (mis. `8297`).
- **Opsi 2: tambah ke service existing** bila memang satu domain dengan service yang sudah ada. Hindari menaruh login di service yang scope-nya berbeda.

Guide ini memakai **Opsi 1** sebagai contoh (`auth-service`, context `/api/auth`). Sesuaikan bila tim memilih lain.

### Kontrak endpoint middleware yang diusulkan

| Endpoint middleware | Method | Body/Params | Backend yang di-hit |
|---|---|---|---|
| `/api/auth/login` | `POST` | `x-www-form-urlencoded`: `username`, `password` | `POST https://devhcbead.assa.id/auth/login` (form-urlencoded) |
| `/api/auth/findemployee` | `GET` | query: `username` | `GET https://devhcbead.assa.id/userldap/getbyusername?username=...` |

> Media type request ke middleware untuk login diasumsikan `application/x-www-form-urlencoded` (sama seperti ke backend). Bila tim ingin menerima JSON dari client lalu mengubah ke form-urlencoded saat forward, catat sebagai keputusan (bagian 9).

---

## 2. Artefak yang dibuat/diubah

| # | Artefak | Aksi | Pola acuan (CURRENT di repo) |
|---|---|---|---|
| 1 | `apis/AuthAPI.xml` | BUAT | `vehicle-service/.../apis/VehicleAPI.xml` |
| 2 | `sequences/AuthLoginSeq.xml` | BUAT | `VehicleGetByLicensePlateSeq.xml` + `SrToAtlasSeq.xml` (call eksternal) |
| 3 | `sequences/AuthFindEmployeeSeq.xml` | BUAT | `VehicleGetByLicensePlateSeq.xml` |
| 4 | `endpoints/HcLdapDynamicEndpoint.xml` | BUAT | `ExtServiceDynamicEndpoint.xml` |
| 5 | `resources/conf/config.properties` | BUAT/UBAH | file per-service existing |
| 6 | `docker-compose.yml` | UBAH | blok env service existing |
| 7 | `apis/HealthAPI.xml` + `apis/ReadinessAPI.xml` | BUAT | pola health existing |
| 8 | `docs/openapi/auth-service.yaml` | BUAT | spec existing |
| 9 | `test_all.ps1` | UBAH | pola `Run-Test` |

> Base URL backend HC **tidak di-hardcode**. Resolusi lewat `ResolveBaseUrlSeq` (shared) dengan key config + env var.

---

## 3. Config & environment (artefak #5, #6)

### 3.1 `docker-compose.yml`

```yaml
# CONTOH env pada service (mis. auth-service)
HC_BASE_URL:        ${HC_BASE_URL:-https://devhcbead.assa.id}
HC_AUTH_LOGIN_PATH: ${HC_AUTH_LOGIN_PATH:-/auth/login}
HC_FINDEMP_PATH:    ${HC_FINDEMP_PATH:-/userldap/getbyusername}
```

### 3.2 `config.properties`

```properties
# CONTOH
hc.base.url=https://devhcbead.assa.id
hc.auth.login.path=/auth/login
hc.findemp.path=/userldap/getbyusername
```

> Bila backend HC butuh API key/header auth tambahan, deklarasikan sebagai variabel (mis. `HC_API_KEY`) — nama variabel saja, isi dari `.env`.

---

## 4. Dynamic endpoint ke backend HC (artefak #4)

File: `endpoints/HcLdapDynamicEndpoint.xml`. Meniru `ExtServiceDynamicEndpoint.xml`, tetapi mendukung **GET dan POST** (login = POST form, findemployee = GET). Alternatif: buat dua endpoint terpisah (`HcLoginEndpoint` POST + `HcFindEmployeeEndpoint` GET) agar method tegas.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<endpoint name="HcLdapDynamicEndpoint" xmlns="http://ws.apache.org/ns/synapse">
    <!-- '+' mencegah double-encoding query param (RFC 6570) -->
    <http uri-template="{+uri.var.hcBackendUrl}">
        <timeout>
            <duration>30000</duration>
            <responseAction>fault</responseAction>
        </timeout>
        <suspendOnFailure>
            <initialDuration>0</initialDuration>
            <progressionFactor>1.0</progressionFactor>
            <maximumDuration>0</maximumDuration>
        </suspendOnFailure>
        <markForSuspension>
            <retriesBeforeSuspension>0</retriesBeforeSuspension>
            <retryDelay>0</retryDelay>
        </markForSuspension>
    </http>
</endpoint>
```

> `http` tanpa atribut `method` mengikuti `$axis2:HTTP_METHOD` yang di-set sequence. Set `POST` untuk login, `GET` untuk findemployee.

---

## 5. API routing (artefak #1)

File: `apis/AuthAPI.xml`, context `/api/auth`.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<api context="/api/auth" name="AuthAPI" xmlns="http://ws.apache.org/ns/synapse">
    <resource methods="POST" uri-template="/login">
        <inSequence>
            <sequence key="AuthLoginSeq"/>
        </inSequence>
        <faultSequence>
            <sequence key="ErrorResponseSeq"/>
        </faultSequence>
    </resource>
    <resource methods="GET" uri-template="/findemployee">
        <inSequence>
            <sequence key="AuthFindEmployeeSeq"/>
        </inSequence>
        <faultSequence>
            <sequence key="ErrorResponseSeq"/>
        </faultSequence>
    </resource>
</api>
```

> Scope/auth guard: tentukan apakah endpoint ini publik (login biasanya publik) atau butuh guard. Login umumnya **tidak** memakai `AuthGuardSeq` (karena ini yang menghasilkan sesi), tapi findemployee bisa diproteksi. Lihat keputusan bagian 9.

---

## 6. Login via LDAP (artefak #2)

File: `sequences/AuthLoginSeq.xml`.

Alur:
1. Ekstrak `username` + `password` dari body form-urlencoded (`$ctx:username` via `$url`/form, atau `get-property` sesuai cara MI membaca form).
2. Validasi: `username` & `password` wajib, tidak kosong.
3. Resolve base URL HC via `ResolveBaseUrlSeq` (key `hc.base.url`, env `HC_BASE_URL`).
4. Bentuk `uri.var.hcBackendUrl = baseUrl + /auth/login`.
5. Bentuk body **x-www-form-urlencoded** `username=...&password=...`.
6. Set `HTTP_METHOD=POST`, `messageType`/`ContentType=application/x-www-form-urlencoded`.
7. Call `HcLdapDynamicEndpoint`, teruskan response ke client.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<sequence name="AuthLoginSeq" onError="ErrorResponseSeq" xmlns="http://ws.apache.org/ns/synapse">
    <!-- 1. Ekstrak kredensial dari body form-urlencoded -->
    <property name="username" expression="$url:username" scope="default" type="STRING"/>
    <property name="password" expression="$url:password" scope="default" type="STRING"/>

    <!-- 2. Validasi (JANGAN log nilai password) -->
    <filter xpath="string-length($ctx:username) = 0 or string-length($ctx:password) = 0">
        <then>
            <property name="ERROR_CODE" value="400" scope="default" type="STRING"/>
            <property name="ERROR_MESSAGE" value="Bad Request" scope="default" type="STRING"/>
            <property name="ERROR_DETAIL" value="Field 'username' dan 'password' wajib diisi" scope="default" type="STRING"/>
            <sequence key="ErrorResponseSeq"/>
            <drop/>
        </then>
    </filter>

    <!-- 3. Resolve base URL HC -->
    <property name="baseUrlConfigKey" value="hc.base.url" scope="default" type="STRING"/>
    <property name="envVarKey" value="HC_BASE_URL" scope="default" type="STRING"/>
    <sequence key="ResolveBaseUrlSeq"/>

    <!-- 4. Path login (config -> fallback) -->
    <property name="hcLoginPath" expression="get-property('file', 'hc.auth.login.path')" scope="default" type="STRING"/>
    <filter xpath="string-length($ctx:hcLoginPath) = 0">
        <then><property name="hcLoginPath" value="/auth/login" scope="default" type="STRING"/></then>
    </filter>
    <property name="uri.var.hcBackendUrl" expression="fn:concat($ctx:resolvedBaseUrl, $ctx:hcLoginPath)" scope="default" type="STRING"/>

    <!-- 5. Body x-www-form-urlencoded -->
    <payloadFactory media-type="xml">
        <format>
            <soapenv:Body xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
                <root xmlns="">
                    <username>$1</username>
                    <password>$2</password>
                </root>
            </soapenv:Body>
        </format>
        <args>
            <arg evaluator="xml" expression="$ctx:username"/>
            <arg evaluator="xml" expression="$ctx:password"/>
        </args>
    </payloadFactory>

    <!-- 6. Set transport = form-urlencoded, method POST -->
    <property name="messageType" value="application/x-www-form-urlencoded" scope="axis2"/>
    <property name="ContentType" value="application/x-www-form-urlencoded" scope="axis2"/>
    <property name="DISABLE_CHUNKING" value="true" scope="axis2"/>
    <property name="HTTP_METHOD" value="POST" scope="axis2"/>
    <header name="Authorization" action="remove" scope="transport"/>

    <!-- 7. Call backend HC -->
    <call><endpoint key="HcLdapDynamicEndpoint"/></call>

    <!-- 8. Teruskan response apa adanya ke client -->
    <property name="messageType" value="application/json" scope="axis2"/>
    <property name="ContentType" value="application/json" scope="axis2"/>
    <respond/>
</sequence>
```

> **Catatan form-urlencoded di WSO2 MI:** MI men-serialize map `x-www-form-urlencoded` dari struktur XML `<root><username/><password/></root>` ketika `messageType=application/x-www-form-urlencoded`. Verifikasi bentuk persis saat implementasi (bisa juga memakai pola yang di-build via `<property name="HTTP_METHOD"/>` + payload). Pastikan hasil kirim benar `username=...&password=...`.

**Keamanan login — wajib:**
- Jangan pernah menaruh `$ctx:password` ke `log` atau ke `api.params`/DB. Bila service ini memakai `LogRequestSeq`/pencatatan transaksi, **mask** atau **exclude** field password.
- Gunakan HTTPS ke backend HC.
- Pertimbangkan rate-limit / lockout bila endpoint login publik (keputusan bagian 9).

### Contoh request login

```bash
curl -X POST "http://localhost:8297/api/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "username=admindev" \
  --data-urlencode "password=<PASSWORD>"
```

### Contoh hasil (dari backend HC)

```json
{
  "message": "Success",
  "count": 1,
  "data": [
    {
      "ldap_id": "admindev",
      "empl_no": null,
      "firstname": "Administrator",
      "lastname": null,
      "company_code": null,
      "personnel_area_code": null,
      "personnel_area_name": null,
      "personnel_subarea_code": null,
      "personnel_subarea_name": null,
      "isActive": 1,
      "organization_unit": null
    }
  ]
}
```

---

## 7. Find Employee (artefak #3)

File: `sequences/AuthFindEmployeeSeq.xml`.

Alur:
1. Ekstrak `username` dari query param.
2. Validasi `username` wajib.
3. Resolve base URL HC.
4. Bentuk `uri.var.hcBackendUrl = baseUrl + /userldap/getbyusername?username=...` (URL-encode nilai username).
5. `HTTP_METHOD=GET`, call `HcLdapDynamicEndpoint`, teruskan response.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<sequence name="AuthFindEmployeeSeq" onError="ErrorResponseSeq" xmlns="http://ws.apache.org/ns/synapse">
    <!-- 1. Query param -->
    <property name="username" expression="$url:username" scope="default" type="STRING"/>

    <!-- 2. Validasi -->
    <filter xpath="string-length($ctx:username) = 0">
        <then>
            <property name="ERROR_CODE" value="400" scope="default" type="STRING"/>
            <property name="ERROR_MESSAGE" value="Bad Request" scope="default" type="STRING"/>
            <property name="ERROR_DETAIL" value="Query param 'username' wajib diisi" scope="default" type="STRING"/>
            <sequence key="ErrorResponseSeq"/>
            <drop/>
        </then>
    </filter>

    <!-- 3. Resolve base URL HC -->
    <property name="baseUrlConfigKey" value="hc.base.url" scope="default" type="STRING"/>
    <property name="envVarKey" value="HC_BASE_URL" scope="default" type="STRING"/>
    <sequence key="ResolveBaseUrlSeq"/>

    <!-- 4. Path + query -->
    <property name="hcFindPath" expression="get-property('file', 'hc.findemp.path')" scope="default" type="STRING"/>
    <filter xpath="string-length($ctx:hcFindPath) = 0">
        <then><property name="hcFindPath" value="/userldap/getbyusername" scope="default" type="STRING"/></then>
    </filter>
    <property name="uri.var.hcBackendUrl" expression="fn:concat($ctx:resolvedBaseUrl, $ctx:hcFindPath, '?username=', $ctx:username)" scope="default" type="STRING"/>

    <!-- 5. GET + call -->
    <property name="HTTP_METHOD" value="GET" scope="axis2"/>
    <header name="To" action="remove"/>
    <property name="REST_URL_POSTFIX" action="remove" scope="axis2"/>
    <call><endpoint key="HcLdapDynamicEndpoint"/></call>

    <property name="messageType" value="application/json" scope="axis2"/>
    <property name="ContentType" value="application/json" scope="axis2"/>
    <respond/>
</sequence>
```

### Contoh request & hasil

```bash
curl "http://localhost:8297/api/auth/findemployee?username=nobi.sumariga"
```

```json
{
  "message": "Success",
  "count": 1,
  "data": [
    { "id": 445, "ldap_id": "nobi.sumariga", "fullname": "Nobi Sumariga", "email": "nobi.sumariga@assarent.co.id", "emplno": "1605287", "isActive": 1 }
  ]
}
```

> Nilai contoh di atas dari deskripsi tugas (data pegawai nyata). Untuk fixture test, pertimbangkan pakai data sintetis bila dokumen akan dibagikan luas.

---

## 8. Health, OpenAPI, test (artefak #7, #8, #9)

- **Health/Readiness**: ikuti pola `HealthAPI.xml`/`ReadinessAPI.xml` service lain (`/health/auth`, `/readiness/auth`).
- **OpenAPI** `docs/openapi/auth-service.yaml`: dokumentasikan `POST /api/auth/login` (requestBody `application/x-www-form-urlencoded` dengan `username`+`password`) dan `GET /api/auth/findemployee` (query `username`). **Jangan** menaruh contoh password nyata; pakai placeholder. Patuhi `docs/API_DEVELOPMENT_GUIDE.md`.
- **test_all.ps1** (saran):

```powershell
# SARAN
Run-Test -TestNumber "AUTH-1" -TestName "Login: field kosong (400)" -Url "$baseUrlAuth/api/auth/login" -Method "POST" -Body "" -ExpectedStatus 400
Run-Test -TestNumber "AUTH-2" -TestName "Find employee: tanpa username (400)" -Url "$baseUrlAuth/api/auth/findemployee" -ExpectedStatus 400
Run-Test -TestNumber "AUTH-3" -TestName "Find employee: happy path (200)" -Url "$baseUrlAuth/api/auth/findemployee?username=nobi.sumariga" -ExpectedStatus 200
```

> Untuk uji login sukses, jangan tulis password nyata di `test_all.ps1`. Ambil dari env (mis. `$env:HC_TEST_PASSWORD`).

---

## 9. Status code & wajib dikonfirmasi

### Status code yang diusulkan

| Status | Kondisi |
|---|---|
| `200` | Login/find sukses (backend 2xx, teruskan body HC) |
| `400` | `username`/`password` kosong atau request tidak valid |
| `401` | Kredensial salah — bila backend HC membedakan; petakan dari response HC |
| `502` | Backend HC gagal/error setelah panggilan |
| `504` | Timeout ke backend HC |

> Bagaimana membedakan "login gagal (kredensial salah)" vs "sukses" dari response HC **harus diverifikasi** — contoh sukses memberi `message: "Success"` + `count: 1`. Perlu tahu bentuk response HC saat kredensial salah agar middleware memetakan `401` dengan benar.

### Wajib dikonfirmasi sebelum coding

1. **Autentikasi ke backend HC**: apakah `/auth/login` & `/userldap/getbyusername` butuh API key/header tambahan, atau cukup kredensial di body?
2. **Media type request ke middleware**: client kirim `x-www-form-urlencoded` (seperti backend) atau JSON yang middleware ubah ke form?
3. **Serialisasi form-urlencoded di MI 4.6.0**: verifikasi payload terkirim persis `username=...&password=...` (uji nyata, bukan asumsi).
4. **Response gagal login HC**: bentuk & status saat kredensial salah, untuk mapping `401`.
5. **Proteksi endpoint**: login publik atau butuh guard; apakah findemployee butuh scope. Rate-limit/lockout?
6. **Placement service**: `auth-service` baru (port `8297`?) atau tambah ke service existing. Daftarkan module di `integrations/pom.xml` + `docker-compose.yml` + `Dockerfile` bila service baru.
7. **Session/token**: apakah middleware perlu menghasilkan token/sesi setelah login, atau cukup meneruskan hasil HC.
8. **PII/logging**: field apa yang boleh dilog; pastikan `password` di-exclude total.

---