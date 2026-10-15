# Implementation Guide (Team Middleware) — Vendor Callback Inbound + Reprocess Failed

> **Jenis dokumen:** panduan **pembuatan/implementasi** untuk tim middleware. Turunan dari dokumen desain `.kiro/GUIDE_VENDOR_CALLBACK_INBOUND_REPROCESS.md` (baca itu dulu untuk konteks, diagram, dan keputusan desain).
> **Status fitur:** PROPOSED / TO BUILD. Endpoint & artefak di bawah **belum ada** di repo; dokumen ini memandu cara membuatnya. Semua kredensial via **nama variabel + placeholder**, jangan commit nilai rahasia.

Service target: `integrations/vendor-service`.
Scope keamanan vendor: `vendors` (sudah dipakai `VendorAPI.xml`).

---

## 0. Ringkasan yang akan dibangun

Melengkapi siklus vendor dengan jalur **inbound callback**:

1. SAP menaruh file XML balikan di FTP `/vmd/upload/` (banyak file `.xml`).
2. Middleware membaca tiap file, parse isinya (`Vendor_ID`, `Vendor_SAP`, `TransGuID`).
3. Middleware **push callback ke ATLAS**: lookup pakai `Vendor_ID`, update `vendor_code = Vendor_SAP`.
4. File diarsipkan ke `success/` atau `failed/`.
5. File di `failed/` diproses ulang oleh **worker reprocess** (terjadwal/manual) dengan batas attempt.

Idempotency berbasis **isi XML** (`Vendor_ID` + `TransGuID`), bukan nama file.

### Artefak yang akan dibuat/diubah

| # | Artefak | Aksi | Pola acuan (CURRENT di repo) |
|---|---|---|---|
| 1 | `endpoints/AtlasVendorCallbackEndpoint.xml` | BUAT | `service-request-service/.../endpoints/AtlasPostEndpoint.xml` |
| 2 | `sequences/VendorInboundCallbackSeq.xml` | BUAT | `SrToAtlasSeq.xml`, `IdempotencyGuardSeq.xml`, `ErrorResponseSeq.xml` |
| 3 | `sequences/VendorReprocessFailedSeq.xml` | BUAT | `shared/.../RetryWorkerSeq.xml` |
| 4 | `apis/VendorWorkerAPI.xml` | BUAT | `service-request-service/.../apis/WorkerAPI.xml` |
| 5 | Inbound VFS `VendorUploadInbound` (Opsi A) | BUAT (opsional) | — (belum ada di repo) |
| 6 | `resources/conf/config.properties` | UBAH | file per-service existing |
| 7 | `docker-compose.yml` (service `vendor-service`) | UBAH | blok env `FTP_SAP_*` existing |
| 8 | `platform/docker/deployment.toml.j2` | UBAH (bila Opsi A) | `[transport.vfs]` |
| 9 | `docs/openapi/vendor-service.yaml` | UBAH | spec existing |
| 10 | `test_all.ps1` | UBAH | pola `Run-Test` existing |

> Pilihan pola inbound (Opsi A VFS inbound vs Opsi B worker) dibahas di dokumen desain. Rekomendasi: **A untuk inbound rutin, B untuk reprocess failed**. Guide implementasi ini menuliskan **keduanya**; team boleh skip Opsi A bila VFS listener belum boleh diaktifkan.

---

## 1. Prasyarat

- Lingkungan build vendor-service jalan (`mvn -B validate` sukses di repo).
- Akses FTP ke `/vmd/upload` + subfolder `success`, `failed`, `processing` (dibuat bila belum ada).
- Endpoint penerima callback di ATLAS sudah diketahui (URL, method, auth, nama field body). Lihat bagian 9 (hal yang wajib dikonfirmasi sebelum mulai).
- Tabel `api_transaction` & `api_transaction_log` sudah ada (`scripts/db/init_mariadb_schema.sql`).

---

## 2. Urutan pengerjaan (disarankan)

Kerjakan bertahap agar mudah di-review dan diuji:

1. **Config & env** (bagian 3) — siapkan variabel folder & callback.
2. **Endpoint ATLAS** (bagian 4) — artefak #1.
3. **Sequence inbound callback** (bagian 5) — artefak #2, inti logika.
4. **Worker reprocess + API** (bagian 6) — artefak #3 & #4, fokus tugas.
5. **Inbound VFS** (bagian 7) — artefak #5, bila Opsi A.
6. **OpenAPI & test** (bagian 8) — artefak #9 & #10.
7. **Verifikasi** (bagian 10).

---

## 3. Config & environment (artefak #6, #7, #8)

### 3.1 `docker-compose.yml` — service `vendor-service`

Tambahkan variabel (nilai via `.env`, jangan hardcode rahasia). `FTP_SAP_*` sudah ada; tambahkan folder inbound & callback ATLAS:

```yaml
# CONTOH tambahan environment pada service vendor-service
FTP_SAP_UPLOAD_DIR:   ${FTP_SAP_UPLOAD_DIR:-/vmd/upload}
FTP_SAP_SUCCESS_DIR:  ${FTP_SAP_SUCCESS_DIR:-/vmd/upload/success}
FTP_SAP_FAILED_DIR:   ${FTP_SAP_FAILED_DIR:-/vmd/upload/failed}
FTP_SAP_PROCESSING_DIR: ${FTP_SAP_PROCESSING_DIR:-/vmd/upload/processing}
ATLAS_VENDOR_CALLBACK_URL:  ${ATLAS_VENDOR_CALLBACK_URL:-}
ATLAS_VENDOR_CALLBACK_PATH: ${ATLAS_VENDOR_CALLBACK_PATH:-/api/vendor/public/callback}
ATLAS_VENDOR_CALLBACK_APIKEY: "${ATLAS_VENDOR_CALLBACK_APIKEY:?set in .env}"
```

> Reuse `FTP_SAP_HOST`/`FTP_SAP_PORT`/`FTP_SAP_USERNAME`/`FTP_SAP_PASSWORD` yang sudah ada untuk koneksi FTP. Jangan buat kredensial FTP baru kecuali memang beda server.

### 3.2 `config.properties` vendor-service

```properties
# CONTOH
ftp.vendor.upload.remote.dir=/vmd/upload
ftp.vendor.success.remote.dir=/vmd/upload/success
ftp.vendor.failed.remote.dir=/vmd/upload/failed
ftp.vendor.processing.remote.dir=/vmd/upload/processing
atlas.vendor.callback.path=/api/vendor/public/callback
retry.max.attempts=3
retry.interval.seconds=60
```

### 3.3 `deployment.toml.j2` (hanya bila Opsi A)

Aktifkan VFS listener (`[transport.vfs]`). Ini keputusan deployment eksplisit — koordinasikan dengan tim ops.

---

## 4. Endpoint callback ATLAS (artefak #1)

File: `integrations/vendor-service/src/main/wso2mi/artifacts/endpoints/AtlasVendorCallbackEndpoint.xml`

Meniru `AtlasPostEndpoint.xml` (http dinamis via `uri.var`, timeout 30s, no auto-suspend):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<endpoint name="AtlasVendorCallbackEndpoint" xmlns="http://ws.apache.org/ns/synapse">
    <http method="POST" uri-template="{+uri.var.atlasVendorCallbackUrl}">
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

---

## 5. Sequence inbound callback (artefak #2)

File: `integrations/vendor-service/src/main/wso2mi/artifacts/sequences/VendorInboundCallbackSeq.xml`

Logika inti. Dipanggil per-file (dari VFS inbound atau worker). Langkah:

1. Terima isi XML sebagai message.
2. Ekstrak `Vendor_ID`, `Vendor_SAP`, `TransGuID`, `Key1`.
3. Validasi: `Vendor_ID` wajib, well-formed. Gagal &rarr; tandai `FAILED`.
4. Hitung `transactionId = Vendor_ID|TransGuID` (idempotency berbasis isi).
5. Cek `api_transaction`: kalau sudah `SUCCESS` &rarr; skip callback (replay), arsipkan.
6. Resolve URL ATLAS (env &rarr; system &rarr; file), bentuk `uri.var.atlasVendorCallbackUrl`.
7. Bentuk payload `{ vendor_id, vendor_code, trans_guid, status }` (`vendor_code = Vendor_SAP`).
8. Set header ATLAS (`X-API-Key`, `Origin`, `Content-Type`), `HTTP_METHOD=POST`.
9. Panggil `AtlasVendorCallbackEndpoint`, baca `HTTP_SC`.
10. 2xx &rarr; `SUCCESS` + arsip `success/`; selain itu &rarr; `FAILED` + `next_retry_at` + arsip `failed/`.
11. Catat ke `api_transaction`/`api_transaction_log`.

Skeleton (lengkapi bagian yang ditandai TODO):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<sequence name="VendorInboundCallbackSeq" onError="ErrorResponseSeq" xmlns="http://ws.apache.org/ns/synapse">
    <!-- 1-2. Ekstrak dari ISI XML (lihat contoh file di dokumen desain 5.1) -->
    <property name="vendorId"  expression="//TransactionData/Vendor_ID"  scope="default" type="STRING"/>
    <property name="vendorSap" expression="//TransactionData/Vendor_SAP" scope="default" type="STRING"/>
    <property name="transGuId" expression="//Header/TransGuID"           scope="default" type="STRING"/>
    <property name="key1"      expression="//Header/Key1"                scope="default" type="STRING"/>

    <!-- 3. Validasi -->
    <filter xpath="string-length($ctx:vendorId) = 0">
        <then>
            <property name="ERROR_CODE" value="400" scope="default" type="STRING"/>
            <property name="ERROR_MESSAGE" value="Bad Request" scope="default" type="STRING"/>
            <property name="ERROR_DETAIL" value="Vendor_ID kosong pada file XML balikan SAP" scope="default" type="STRING"/>
            <!-- TODO: tandai FAILED + pindah file ke failed/ sebelum keluar -->
            <sequence key="ErrorResponseSeq"/>
            <drop/>
        </then>
    </filter>

    <!-- 4. transaction_id dari ISI XML (BUKAN nama file) -->
    <property name="transactionId" expression="fn:concat($ctx:vendorId, '|', $ctx:transGuId)" scope="default" type="STRING"/>

    <!-- 5. Idempotency: skip callback bila sudah SUCCESS (pola IdempotencyGuardSeq) -->
    <property name="existingStatus" value="" scope="default" type="STRING"/>
    <dblookup>
        <connection><pool>
            <driver key="conf:/repository/assa/db/driver"/>
            <url key="conf:/repository/assa/db/url"/>
            <user key="conf:/repository/assa/db/username"/>
            <password key="conf:/repository/assa/db/password"/>
        </pool></connection>
        <statement>
            <sql>SELECT status FROM api_transaction WHERE transaction_id = ?</sql>
            <parameter expression="$ctx:transactionId" type="VARCHAR"/>
            <result name="existingStatus" column="status"/>
        </statement>
    </dblookup>
    <filter xpath="$ctx:existingStatus = 'SUCCESS'">
        <then>
            <!-- TODO: replay — pindahkan file ke success/, jangan panggil ATLAS lagi -->
            <drop/>
        </then>
    </filter>

    <!-- 6. Resolve URL ATLAS (env -> system -> file), bentuk uri.var.atlasVendorCallbackUrl -->
    <property name="atlasBaseUrl" expression="get-property('env', 'ATLAS_VENDOR_CALLBACK_URL')" scope="default" type="STRING"/>
    <!-- TODO: fallback system/file bila kosong -->
    <property name="atlasPath" expression="get-property('env', 'ATLAS_VENDOR_CALLBACK_PATH')" scope="default" type="STRING"/>
    <filter xpath="string-length($ctx:atlasPath) = 0">
        <then><property name="atlasPath" expression="get-property('file', 'atlas.vendor.callback.path')" scope="default" type="STRING"/></then>
    </filter>
    <property name="uri.var.atlasVendorCallbackUrl" expression="fn:concat($ctx:atlasBaseUrl, $ctx:atlasPath)" scope="default" type="STRING"/>

    <!-- 7. Payload callback: vendor_code = Vendor_SAP -->
    <payloadFactory media-type="json">
        <format>{"vendor_id":"$1","vendor_code":"$2","trans_guid":"$3","status":"SUCCESS"}</format>
        <args>
            <arg evaluator="xml" expression="$ctx:vendorId"/>
            <arg evaluator="xml" expression="$ctx:vendorSap"/>
            <arg evaluator="xml" expression="$ctx:transGuId"/>
        </args>
    </payloadFactory>

    <!-- 8. Header ATLAS (pola SrToAtlasSeq) -->
    <header name="Authorization" action="remove" scope="transport"/>
    <property name="atlasApiKey" expression="get-property('env', 'ATLAS_VENDOR_CALLBACK_APIKEY')" scope="default" type="STRING"/>
    <filter xpath="string-length($ctx:atlasApiKey) &gt; 0">
        <then><header name="X-API-Key" expression="$ctx:atlasApiKey" scope="transport"/></then>
    </filter>
    <header name="Content-Type" value="application/json" scope="transport"/>
    <property name="messageType" value="application/json" scope="axis2"/>
    <property name="ContentType" value="application/json" scope="axis2"/>
    <property name="HTTP_METHOD" value="POST" scope="axis2"/>

    <!-- 9. Panggil ATLAS -->
    <call><endpoint key="AtlasVendorCallbackEndpoint"/></call>
    <property name="responseStatus" expression="$axis2:HTTP_SC" scope="default" type="STRING"/>

    <!-- 10-11. TODO: 2xx -> SUCCESS + success/ ; selain itu FAILED + next_retry_at + failed/ ;
         catat ke api_transaction / api_transaction_log (pola DbRecord*Seq) -->
</sequence>
```

> Yang perlu dilengkapi team (TODO): operasi pindah file FTP (`success`/`failed`/`processing`), penulisan `api_transaction` baru/update, dan mapping error ATLAS &rarr; status. Pola move file: lihat Opsi A (VFS `Move*`) atau implement via VFS outbound bila worker.

---

## 6. Worker reprocess failed + API (artefak #3, #4) — FOKUS TUGAS

### 6.1 Sequence `VendorReprocessFailedSeq.xml`

File: `integrations/vendor-service/src/main/wso2mi/artifacts/sequences/VendorReprocessFailedSeq.xml`
Meniru `RetryWorkerSeq.xml` (DB-driven):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<sequence name="VendorReprocessFailedSeq" xmlns="http://ws.apache.org/ns/synapse">
    <property name="reTrxId" value="" scope="default" type="STRING"/>
    <property name="reFile"  value="" scope="default" type="STRING"/>
    <dblookup>
        <connection><pool>
            <driver key="conf:/repository/assa/db/driver"/>
            <url key="conf:/repository/assa/db/url"/>
            <user key="conf:/repository/assa/db/username"/>
            <password key="conf:/repository/assa/db/password"/>
        </pool></connection>
        <statement>
            <sql>SELECT transaction_id, request_payload FROM api_transaction
                 WHERE endpoint = '/callback/vendor'
                   AND status IN ('FAILED','RETRY')
                   AND attempt_count &lt; max_attempts
                   AND (next_retry_at IS NULL OR next_retry_at &lt;= NOW())
                 ORDER BY updated_at ASC LIMIT 1</sql>
            <result name="reTrxId" column="transaction_id"/>
            <result name="reFile" column="request_payload"/>
        </statement>
    </dblookup>
    <filter xpath="string-length($ctx:reTrxId) &gt; 0">
        <then>
            <!-- set RETRY + next_retry_at (+300s, pola RetryWorkerSeq) -->
            <dbreport>
                <connection><pool>
                    <driver key="conf:/repository/assa/db/driver"/>
                    <url key="conf:/repository/assa/db/url"/>
                    <user key="conf:/repository/assa/db/username"/>
                    <password key="conf:/repository/assa/db/password"/>
                </pool></connection>
                <statement>
                    <sql>UPDATE api_transaction SET status='RETRY', next_retry_at=DATE_ADD(NOW(), INTERVAL 300 SECOND), updated_at=NOW() WHERE transaction_id = ?</sql>
                    <parameter expression="$ctx:reTrxId" type="VARCHAR"/>
                </statement>
            </dbreport>
            <!-- TODO: baca ulang isi XML dari failed/ (request_payload simpan ISI XML),
                 panggil VendorInboundCallbackSeq ulang, update SUCCESS/attempt_count,
                 pindah file success/ atau tetap failed/ (dead-letter bila habis) -->
        </then>
    </filter>
</sequence>
```

> Penting: simpan **isi XML** di `request_payload` saat inbound mencatat transaksi, supaya reprocess tidak bergantung pada nama file (nama file bisa duplikat).

### 6.2 API `VendorWorkerAPI.xml`

File: `integrations/vendor-service/src/main/wso2mi/artifacts/apis/VendorWorkerAPI.xml`
Meniru `WorkerAPI.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<api context="/api/vendors/worker" name="VendorWorkerAPI" xmlns="http://ws.apache.org/ns/synapse">
    <resource methods="POST GET" uri-template="/reprocess-failed">
        <inSequence>
            <sequence key="VendorReprocessFailedSeq"/>
            <property name="HTTP_SC" value="200" scope="axis2" type="STRING"/>
            <property name="messageType" value="application/json" scope="axis2"/>
            <property name="ContentType" value="application/json" scope="axis2"/>
            <payloadFactory media-type="json">
                <format>{"worker":"VendorReprocessFailed","status":"COMPLETED","timestamp":"$1"}</format>
                <args><arg evaluator="xml" expression="get-property('SYSTEM_DATE','yyyy-MM-dd HH:mm:ss')"/></args>
            </payloadFactory>
            <respond/>
        </inSequence>
        <faultSequence><sequence key="ErrorResponseSeq"/></faultSequence>
    </resource>
</api>
```

> Trigger: manual via `POST /api/vendors/worker/reprocess-failed`, dan/atau MI Scheduled Task yang memanggil `VendorReprocessFailedSeq` tiap interval.

---

## 7. (Opsi A) Inbound VFS `VendorUploadInbound` (artefak #5)

Hanya bila VFS listener diaktifkan. Polling `/vmd/upload`, auto-move ke `success`/`failed`:

```xml
<inboundEndpoint name="VendorUploadInbound" protocol="file"
                 sequence="VendorInboundCallbackSeq" onError="ErrorResponseSeq"
                 suspend="false" xmlns="http://ws.apache.org/ns/synapse">
    <parameters>
        <parameter name="interval">60000</parameter>
        <parameter name="transport.vfs.FileURI">vfs:ftp://.../vmd/upload?vfs.passive=true</parameter>
        <parameter name="transport.vfs.ContentType">application/xml</parameter>
        <parameter name="transport.vfs.FileNamePattern">.*\.xml</parameter>
        <parameter name="transport.vfs.ActionAfterProcess">MOVE</parameter>
        <parameter name="transport.vfs.MoveAfterProcess">vfs:ftp://.../vmd/upload/success</parameter>
        <parameter name="transport.vfs.ActionAfterFailure">MOVE</parameter>
        <parameter name="transport.vfs.MoveAfterFailure">vfs:ftp://.../vmd/upload/failed</parameter>
    </parameters>
</inboundEndpoint>
```

> Karena nama file bisa duplikat, saat move ke arsip tambahkan `TransGuID`/timestamp atau subfolder per tanggal agar tidak menimpa. Idempotency bisnis tetap di `VendorInboundCallbackSeq` (isi XML), bukan nama file.

---

## 8. OpenAPI & test (artefak #9, #10)

### 8.1 OpenAPI `docs/openapi/vendor-service.yaml`

Tambahkan operation worker reprocess (endpoint operasional). Callback ke ATLAS **outbound**, jadi tidak jadi path yang di-expose; cukup didokumentasikan sebagai integrasi internal. Patuhi `docs/API_DEVELOPMENT_GUIDE.md`.

### 8.2 `test_all.ps1`

```powershell
# SARAN — tambahkan saat endpoint sudah dibuat
Run-Test -TestNumber "VND-RP-1" -TestName "Vendor reprocess-failed trigger (200)" -Url "$baseUrlVendor/api/vendors/worker/reprocess-failed" -Method "POST" -ExpectedStatus 200
```

Skenario fungsional yang harus diuji:
- Banyak file valid di `/vmd/upload` &rarr; tiap file callback ATLAS sukses &rarr; `success/`, `status=SUCCESS`.
- File tanpa `Vendor_ID` &rarr; `failed/`, `FAILED`.
- ATLAS error/timeout &rarr; `failed/`, `next_retry_at` terisi.
- Reprocess: file `failed/` dicoba lagi, sukses &rarr; `success/`; habis `max_attempts` &rarr; dead-letter.
- Idempotency isi: dua file isi sama (`Vendor_ID`+`TransGuID`) &rarr; callback sekali. Dua file nama sama tapi `TransGuID` beda &rarr; dua transaksi.

---

## 9. Wajib dikonfirmasi sebelum coding (ke tim SAP/ATLAS/Ops)

Mapping yang **sudah tetap**: lookup = `Vendor_ID`, `vendor_code` = `Vendor_SAP`.

Yang masih harus dikonfirmasi:

1. **Endpoint ATLAS**: URL, path, method (`POST`/`PUT`/`PATCH`), auth (`X-API-Key`?), nama field body (`vendor_code`/`vendorCode`?), apakah butuh `trans_guid`/`status`.
2. **Response ATLAS**: bentuk sukses (2xx) & error, agar middleware memutuskan `SUCCESS`/`FAILED`.
3. **Nama & lokasi folder**: `/vmd/upload`, `success`, `failed`, `processing` (relatif `/vmd/upload` atau `/vmd`).
4. **Siapa yang memindahkan file** ke `success`/`failed` (asumsi: middleware).
5. **Opsi inbound**: boleh aktifkan VFS listener (Opsi A)? Jika tidak, pakai Opsi B + verifikasi listing direktori FTP di MI 4.6.0.
6. **Kecukupan kunci idempotency** `Vendor_ID|TransGuID` (tambah `Vendor_SAP`/hash bila perlu).
7. **Field status di XML balikan**: contoh tidak memuat status; sukses/gagal ditentukan dari callback ATLAS.

---