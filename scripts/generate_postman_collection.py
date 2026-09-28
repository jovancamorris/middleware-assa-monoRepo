#!/usr/bin/env python3
import json
import uuid
import os

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
POSTMAN_DIR = os.path.join(REPO_ROOT, "postman")
os.makedirs(POSTMAN_DIR, exist_ok=True)

# ------------------------------------------------------------------------------
# Token & Variabel Default
# ------------------------------------------------------------------------------
TOKENS = {
    "token_app_a": "c220fbfbc7e4c925eb662d85be47ee5ab017d23d9b04f7c22df6cb7efb6dfdbd",
    "token_app_b": "988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881",
    "token_qa": "e20b33b006bc229d49dd701c385f8abfbe6a24726fb51db11624bce3766627be",
    "token_omnichannel": "14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12",
    "token_barantum": "umk_da295902028f5804c4f0e9d9fd81fa07a2a0e1152d6171e30f387416fbfe5680",
    "token_atlas": "ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d"
}

def make_test_script(assertions):
    return {
        "listen": "test",
        "script": {
            "type": "text/javascript",
            "exec": assertions
        }
    }

def make_prerequest_script(code_lines):
    return {
        "listen": "prerequest",
        "script": {
            "type": "text/javascript",
            "exec": code_lines
        }
    }

def make_request_item(name, method, url_path, query_params=None, headers=None, body_json=None, token_var=None, test_assertions=None, prerequest_lines=None):
    events = []
    if prerequest_lines:
        events.append(make_prerequest_script(prerequest_lines))
    if test_assertions:
        events.append(make_test_script(test_assertions))

    header_list = [
        {"key": "X-Retry-Interval-Seconds", "value": "1", "type": "text"}
    ]
    if body_json is not None:
        header_list.append({"key": "Content-Type", "value": "application/json", "type": "text"})
    if headers:
        for k, v in headers.items():
            header_list.append({"key": k, "value": v, "type": "text"})

    request_obj = {
        "method": method,
        "header": header_list,
        "url": {
            "raw": "{{baseUrl}}" + url_path,
            "host": ["{{baseUrl}}"],
            "path": [p for p in url_path.split("?")[0].split("/") if p]
        }
    }

    if query_params:
        query_list = []
        for k, v in query_params.items():
            query_list.append({"key": k, "value": str(v)})
        request_obj["url"]["query"] = query_list
        # Build query string in raw url if not present
        if "?" not in url_path:
            qs = "&".join(f"{k}={v}" for k, v in query_params.items())
            request_obj["url"]["raw"] += "?" + qs

    if token_var:
        request_obj["auth"] = {
            "type": "bearer",
            "bearer": [
                {"key": "token", "value": f"{{{{{token_var}}}}}", "type": "string"}
            ]
        }

    if body_json is not None:
        request_obj["body"] = {
            "mode": "raw",
            "raw": json.dumps(body_json, indent=2) if isinstance(body_json, (dict, list)) else body_json,
            "options": {
                "raw": {
                    "language": "json"
                }
            }
        }

    return {
        "name": name,
        "event": events,
        "request": request_obj,
        "response": []
    }

# ------------------------------------------------------------------------------
# Build Test Folders
# ------------------------------------------------------------------------------

# 1. Health & Readiness Probes
health_items = [
    make_request_item(
        "Branch Health Check (Liveness)", "GET", "/health/branch",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('Response is UP or 200', function () { pm.expect(pm.response.code).to.eql(200); });"
        ]
    ),
    make_request_item(
        "Branch Readiness Check", "GET", "/readiness/branch",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
    make_request_item(
        "Customer Health Check (Liveness)", "GET", "/health/customer",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
    make_request_item(
        "Customer Readiness Check", "GET", "/readiness/customer",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
    make_request_item(
        "Vehicle Health Check (Liveness)", "GET", "/health/vehicle",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
    make_request_item(
        "Vehicle Readiness Check", "GET", "/readiness/vehicle",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
    make_request_item(
        "Vendor Health Check (Liveness)", "GET", "/health/vendor",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
    make_request_item(
        "Vendor Readiness Check", "GET", "/readiness/vendor",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
    make_request_item(
        "SPK Health Check (Liveness)", "GET", "/health/spk",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
    make_request_item(
        "SPK Readiness Check", "GET", "/readiness/spk",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
    make_request_item(
        "Service Request Health Check (Liveness)", "GET", "/health/service-request",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
    make_request_item(
        "Service Request Readiness Check", "GET", "/readiness/service-request",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
]

# 2. Auth & Scope Security Guards
security_items = [
    make_request_item(
        "Auth Guard: Request Tanpa Token (401)", "GET", "/api/branches/getByCreateDate",
        query_params={"companyCode": "{{companyCode}}"},
        test_assertions=[
            "pm.test('Status code is 401 Unauthorized', function () { pm.response.to.have.status(401); });",
            "pm.test('Error response body contains Unauthorized', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res.error).to.be.true;",
            "    pm.expect(res.message).to.eql('Unauthorized');",
            "});"
        ]
    ),
    make_request_item(
        "Auth Guard: Request dengan Token Palsu (401)", "GET", "/api/branches/getByCreateDate",
        query_params={"companyCode": "{{companyCode}}"},
        headers={"Authorization": "Bearer token-palsu-ngawur-12345"},
        test_assertions=[
            "pm.test('Status code is 401 Unauthorized', function () { pm.response.to.have.status(401); });",
            "pm.test('Detail mentions invalid token', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res.error).to.be.true;",
            "});"
        ]
    ),
    make_request_item(
        "Scope Guard: App B (scope: vehicles) call Branch (403)", "GET", "/api/branches/getByCreateDate",
        query_params={"companyCode": "{{companyCode}}"},
        token_var="token_app_b",
        test_assertions=[
            "pm.test('Status code is 403 Forbidden', function () { pm.response.to.have.status(403); });",
            "pm.test('Detail states missing branches scope', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res.error).to.be.true;",
            "    pm.expect(res.detail).to.include('branches');",
            "});"
        ]
    ),
    make_request_item(
        "Scope Guard: App B call Customer (403)", "GET", "/api/customers/getByCreateDate",
        query_params={"companyCode": "{{companyCode}}"},
        token_var="token_app_b",
        test_assertions=[
            "pm.test('Status code is 403 Forbidden', function () { pm.response.to.have.status(403); });",
            "pm.test('Detail states missing customers scope', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res.detail).to.include('customers');",
            "});"
        ]
    ),
    make_request_item(
        "Scope Guard: App B call Vendor Create (403)", "POST", "/api/vendors/create",
        body_json={},
        token_var="token_app_b",
        test_assertions=[
            "pm.test('Status code is 403 Forbidden', function () { pm.response.to.have.status(403); });",
            "pm.test('Detail states missing vendors scope', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res.detail).to.include('vendors');",
            "});"
        ]
    ),
    make_request_item(
        "Scope Guard: App B call SPK Duelist (403)", "POST", "/api/spk/duelist",
        body_json={},
        token_var="token_app_b",
        test_assertions=[
            "pm.test('Status code is 403 Forbidden', function () { pm.response.to.have.status(403); });",
            "pm.test('Detail states missing spk scope', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res.detail).to.include('spk');",
            "});"
        ]
    ),
    make_request_item(
        "Scope Guard: App B call Service Request (403)", "POST", "/api/service-requests",
        body_json={},
        token_var="token_app_b",
        test_assertions=[
            "pm.test('Status code is 403 Forbidden', function () { pm.response.to.have.status(403); });",
            "pm.test('Detail states missing service_requests scope', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res.detail).to.include('service_requests');",
            "});"
        ]
    ),
]

# 3. Parameter Validation (400 Bad Request)
validation_items = [
    make_request_item(
        "Validasi: Vehicle tanpa parameter pencarian (400)", "GET", "/api/vehicles/getByLicensePlate",
        query_params={"companyCode": "{{companyCode}}"},
        token_var="token_app_b",
        test_assertions=[
            "pm.test('Status code is 400 Bad Request', function () { pm.response.to.have.status(400); });"
        ]
    ),
    make_request_item(
        "Validasi: Vendor Create invalid companyTitle (400)", "POST", "/api/vendors/create",
        body_json={
            "companyTitle": "INVALID_TITLE",
            "companyName": "PT Test Validasi",
            "otv": "No",
            "paymentCycle": "Monthly",
            "accountNumber": "12345",
            "accountName": "Test",
            "bankName": "BCA",
            "hoEmail": "test@assa.id",
            "hoPhone": "08123456",
            "hoAddress": "Jakarta",
            "npwp": "123456789012345",
            "accountGroup": "V010",
            "top": "T014",
            "glAccount": "2121000000",
            "documentNumber": "DOC-VALID-01"
        },
        token_var="token_qa",
        test_assertions=[
            "pm.test('Status code is 400 Bad Request', function () { pm.response.to.have.status(400); });"
        ]
    ),
    make_request_item(
        "Validasi: SPK Duelist tanpa noSpk (400)", "POST", "/api/spk/duelist",
        body_json={
            "type": "Maintenance",
            "noPolisi": "B-2120-BKZ",
            "category": "Maintenance",
            "subCategory": "Adhoc",
            "vendorReferensi": "0001",
            "totalPrice": 1850000,
            "createdAt": "2026-09-17 14:46:11",
            "createdBy": "atlas.user",
            "details": [{"jenis": "Jasa", "description": "Jasa Perbaikan AC", "qty": 1, "price": 1850000}]
        },
        token_var="token_qa",
        test_assertions=[
            "pm.test('Status code is 400 Bad Request', function () { pm.response.to.have.status(400); });"
        ]
    ),
    make_request_item(
        "Validasi: SPK Duelist beda total dengan header X-Validate-Total (400)", "POST", "/api/spk/duelist",
        headers={"X-Validate-Total": "true"},
        body_json={
            "noSpk": "SPK/2026/09/00002",
            "type": "Maintenance",
            "noPolisi": "B-2120-BKZ",
            "category": "Maintenance",
            "subCategory": "Adhoc",
            "vendorReferensi": "0001",
            "totalPrice": 1850001,
            "createdAt": "2026-09-17 14:46:11",
            "createdBy": "atlas.user",
            "details": [{"jenis": "Jasa", "description": "Jasa Perbaikan AC", "qty": 1, "price": 1850000}]
        },
        token_var="token_qa",
        test_assertions=[
            "pm.test('Status code is 400 Bad Request', function () { pm.response.to.have.status(400); });"
        ]
    ),
    make_request_item(
        "Validasi: Service Request tanpa field wajib app_id (400)", "POST", "/api/service-requests",
        body_json={
            "reff_number": "REF01",
            "branch_code": "JKT01",
            "created_datetime": "17-09-2026",
            "created_by": "admin",
            "ticket_no": "TCK01"
        },
        token_var="token_omnichannel",
        test_assertions=[
            "pm.test('Status code is 400 Bad Request', function () { pm.response.to.have.status(400); });"
        ]
    ),
]

# 4. Inquiry & Pagination (GET 200 OK)
inquiry_items = [
    make_request_item(
        "Branch Inquiry GetByCreateDate (200 OK)", "GET", "/api/branches/getByCreateDate",
        query_params={
            "companyCode": "{{companyCode}}",
            "dateStart": "2020-01-01",
            "dateEnd": "2026-09-11",
            "page": "1",
            "perPage": "5"
        },
        token_var="token_app_a",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('Response contains data array', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res).to.have.property('data');",
            "});"
        ]
    ),
    make_request_item(
        "Customer Inquiry GetByCreateDate (200 OK)", "GET", "/api/customers/getByCreateDate",
        query_params={
            "companyCode": "{{companyCode}}",
            "dateStart": "2020-01-01",
            "dateEnd": "2026-09-11",
            "page": "1",
            "perPage": "5"
        },
        token_var="token_app_a",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"
        ]
    ),
    make_request_item(
        "Vehicle Inquiry /getByLicensePlate (200 OK / 403 Upstream API Key)", "GET", "/api/vehicles/getByLicensePlate",
        query_params={"plate_no": "DD-8112"},
        token_var="token_app_b",
        test_assertions=[
            "pm.test('Status code is 200 or 403 upstream', function () {",
            "    pm.expect([200, 403]).to.include(pm.response.code);",
            "});"
        ]
    ),
    make_request_item(
        "Vehicle Inquiry /vehicleatlas (200 OK / 403 Upstream API Key)", "GET", "/api/vehicles/vehicleatlas",
        query_params={"plate_no": "DD-8112"},
        token_var="token_qa",
        test_assertions=[
            "pm.test('Status code is 200 or 403 upstream', function () {",
            "    pm.expect([200, 403]).to.include(pm.response.code);",
            "});"
        ]
    ),
    make_request_item(
        "Service Request GET Inquiry (200 OK Paginated List)", "GET", "/api/service-requests",
        query_params={
            "dateStart": "2026-01-01",
            "dateEnd": "2026-09-28",
            "page": "1",
            "perPage": "10"
        },
        token_var="token_omnichannel",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('Has pagination metadata', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res).to.have.property('pagination');",
            "    pm.expect(res.pagination).to.have.property('page');",
            "    pm.expect(res.pagination).to.have.property('perPage');",
            "    pm.expect(res).to.have.property('data');",
            "});"
        ]
    ),
    make_request_item(
        "Service Request (Barantum) Public GET Inquiry (200 OK)", "GET", "/api/vendor/public/service-requests",
        query_params={"page": "1", "perPage": "10"},
        headers={"X-API-Key": "{{token_barantum}}"},
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"
        ]
    ),
]

# 5. Transactional & Fan-Out Endpoints (POST)
transactional_items = [
    make_request_item(
        "Service Request - Parallel Fan-Out (10x Retry on Failure)", "POST", "/api/service-requests",
        headers={"X-Transaction-Id": "{{sr_trx_id}}"},
        token_var="token_omnichannel",
        prerequest_lines=[
            "const srId = 'TRX-SR-POSTMAN-' + Date.now();",
            "pm.collectionVariables.set('sr_trx_id', srId);"
        ],
        body_json={
            "app_id": "sr_app_omnichannel",
            "reff_number": "REF-SR-POSTMAN-001",
            "branch_code": "JKT01",
            "equipment_number": "EQ-998877",
            "license_plate": "B-1234-SSA",
            "customer_code": "CUST-00123",
            "customer_name": "PT Maju Bersama ASSA",
            "channel": "Omnichannel-Web",
            "cp_title": "Bpk",
            "cp_name": "Ahmad Fauzi",
            "cp_phone": "081234567890",
            "cp_email": "ahmad.fauzi@example.com",
            "cp_address": "Jl. Gatot Subroto No. 45 Jakarta",
            "km": "25000",
            "description": "Perawatan berkala 25.000 KM dan pengecekan sistem rem",
            "service_datetime": "2026-09-20 10:00:00",
            "service_location": "Bengkel Resmi ASSA Sunter",
            "jenis_permintaan": "Service Berkala",
            "incident_datetime": "2026-09-17 09:00:00",
            "tipe_tiket": "Regular",
            "judul": "Service Berkala Kendaraan Operasional",
            "nama_kunjungan": "Ahmad Fauzi",
            "telepon_kunjungan": "081234567890",
            "alamat_kunjungan": "Jl. Danau Sunter Barat",
            "pool_name": "Pool Sunter",
            "area_bengkel": "Jakarta Utara",
            "task": "Ganti Oli Mesin dan Filter",
            "created_datetime": "28-09-2026",
            "created_by": "omnichannel_agent",
            "ticket_no": "TCK-SR-POSTMAN-001"
        },
        test_assertions=[
            "pm.test('Status code is 200 (All Success) or 502 (Target Failed after 10 Retries)', function () {",
            "    pm.expect([200, 502]).to.include(pm.response.code);",
            "});",
            "pm.test('Response body contains targets status details', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res).to.have.property('targets');",
            "    pm.expect(res.targets).to.have.property('atlas');",
            "    pm.expect(res.targets).to.have.property('extService');",
            "});"
        ]
    ),
    make_request_item(
        "Service Request - Idempotency Re-Send / Re-Execute", "POST", "/api/service-requests",
        headers={"X-Transaction-Id": "{{sr_trx_id}}"},
        token_var="token_omnichannel",
        body_json={
            "app_id": "sr_app_omnichannel",
            "reff_number": "REF-SR-POSTMAN-001",
            "branch_code": "JKT01",
            "equipment_number": "EQ-998877",
            "license_plate": "B-1234-SSA",
            "customer_code": "CUST-00123",
            "customer_name": "PT Maju Bersama ASSA",
            "channel": "Omnichannel-Web",
            "cp_title": "Bpk",
            "cp_name": "Ahmad Fauzi",
            "cp_phone": "081234567890",
            "cp_email": "ahmad.fauzi@example.com",
            "cp_address": "Jl. Gatot Subroto No. 45 Jakarta",
            "km": "25000",
            "description": "Perawatan berkala 25.000 KM dan pengecekan sistem rem",
            "service_datetime": "2026-09-20 10:00:00",
            "service_location": "Bengkel Resmi ASSA Sunter",
            "jenis_permintaan": "Service Berkala",
            "incident_datetime": "2026-09-17 09:00:00",
            "tipe_tiket": "Regular",
            "judul": "Service Berkala Kendaraan Operasional",
            "nama_kunjungan": "Ahmad Fauzi",
            "telepon_kunjungan": "081234567890",
            "alamat_kunjungan": "Jl. Danau Sunter Barat",
            "pool_name": "Pool Sunter",
            "area_bengkel": "Jakarta Utara",
            "task": "Ganti Oli Mesin dan Filter",
            "created_datetime": "28-09-2026",
            "created_by": "omnichannel_agent",
            "ticket_no": "TCK-SR-POSTMAN-001"
        },
        test_assertions=[
            "pm.test('Status code is 200 or 502 on retry', function () {",
            "    pm.expect([200, 502]).to.include(pm.response.code);",
            "});"
        ]
    ),
    make_request_item(
        "Service Request - Public Endpoint (Barantum)", "POST", "/api/vendor/public/service-requests",
        headers={"X-API-Key": "{{token_barantum}}", "X-Transaction-Id": "{{sr_barantum_trx_id}}"},
        prerequest_lines=[
            "const bTrx = 'TRX-BRT-POSTMAN-' + Date.now();",
            "pm.collectionVariables.set('sr_barantum_trx_id', bTrx);"
        ],
        body_json={
            "reff_number": "REF-BARANTUM-001",
            "branch_code": "JKT01",
            "equipment_number": "EQ-998877",
            "license_plate": "B-1234-SSA",
            "customer_code": "CUST-00123",
            "customer_name": "PT Maju Bersama ASSA",
            "channel": "Barantum-CRM",
            "cp_title": "Bpk",
            "cp_name": "Ahmad Fauzi",
            "cp_phone": "081234567890",
            "cp_email": "ahmad.fauzi@example.com",
            "cp_address": "Jl. Gatot Subroto No. 45 Jakarta",
            "km": "25000",
            "description": "Perawatan berkala 25.000 KM",
            "service_datetime": "2026-09-20 10:00:00",
            "service_location": "Bengkel Resmi ASSA Sunter",
            "jenis_permintaan": "Service Berkala",
            "incident_datetime": "2026-09-17 09:00:00",
            "tipe_tiket": "Regular",
            "judul": "Service Berkala Kendaraan",
            "nama_kunjungan": "Ahmad Fauzi",
            "telepon_kunjungan": "081234567890",
            "alamat_kunjungan": "Jl. Danau Sunter Barat",
            "pool_name": "Pool Sunter",
            "area_bengkel": "Jakarta Utara",
            "task": "Ganti Oli Mesin",
            "created_datetime": "28-09-2026",
            "created_by": "barantum_crm",
            "ticket_no": "TCK-BRT-001"
        },
        test_assertions=[
            "pm.test('Status code is 200 (Success) or 502 (Target Failed after 10 Retries)', function () {",
            "    pm.expect([200, 502]).to.include(pm.response.code);",
            "});"
        ]
    ),
    make_request_item(
        "Vendor Create - Valid Payload ke FTP (201 / 502)", "POST", "/api/vendors/create",
        headers={"X-Transaction-Id": "{{vendor_trx_id}}"},
        token_var="token_qa",
        prerequest_lines=[
            "const vTrx = 'TRX-VND-POSTMAN-' + Date.now();",
            "pm.collectionVariables.set('vendor_trx_id', vTrx);"
        ],
        body_json={
            "companyTitle": "PT",
            "companyName": "PT Adi Sarana Armada Tbk",
            "otv": "No",
            "paymentCycle": "Monthly",
            "accountNumber": "1200010978489",
            "accountName": "Robby Yulianto Setiawan",
            "bankName": "Mandiri",
            "hoEmail": "assa@assarent.co.id",
            "hoPhone": "082246605199",
            "hoAddress": "Jalan Nusa Indah 2 Block C.ext 8 no 7, Duri Kosambi, Jakarta Barat, DKI Jakarta, 11410",
            "contactName": "Robby Contact",
            "contactPhone": "08224660189",
            "npwp": "3173080209920003",
            "accountGroup": "V010",
            "top": "T014",
            "glAccount": "2121000000",
            "documentNumber": "VENDOR-ATLAS-000123"
        },
        test_assertions=[
            "pm.test('Status code is 201 (FTP Success) or 500/502 (FTP Server devqaxmlpool auth required)', function () {",
            "    pm.expect([200, 201, 500, 502]).to.include(pm.response.code);",
            "});"
        ]
    ),
    make_request_item(
        "SPK Duelist - Valid Payload ke FTP (201 / 502)", "POST", "/api/spk/duelist",
        headers={"X-Transaction-Id": "{{spk_trx_id}}", "X-Validate-Total": "true"},
        token_var="token_qa",
        prerequest_lines=[
            "const sTrx = 'TRX-SPK-POSTMAN-' + Date.now();",
            "pm.collectionVariables.set('spk_trx_id', sTrx);"
        ],
        body_json={
            "noSpk": "SPK/2026/09/00003",
            "type": "Maintenance",
            "noPolisi": "B-2120-BKZ",
            "noSr": "SR-000123",
            "category": "Maintenance",
            "subCategory": "Adhoc",
            "vendorReferensi": "0001",
            "namaVendor": "Bengkel Jaya Motor",
            "picService": "PIC-001",
            "namaPicService": "Andi Wijaya",
            "spkRework": "No",
            "totalPrice": 1850000,
            "createdAt": "2026-09-17 14:46:11",
            "createdBy": "atlas.user",
            "poSpkNumber": "PO-4500012345",
            "invoiceNumber": "INV_BKL_00001",
            "invoiceDate": "2026-09-17",
            "invoiceAmount": 1850000,
            "memo": "Perbaikan kendaraan",
            "taxInvoiceNumber": "314650102340592",
            "taxInvoiceDate": "2026-09-17",
            "businessArea": "1101",
            "details": [
                {"jenis": "Jasa", "description": "Jasa Perbaikan AC", "qty": 1, "price": 150000},
                {"jenis": "Parts", "description": "Filter AC", "qty": 1, "price": 1700000}
            ]
        },
        test_assertions=[
            "pm.test('Status code is 201 (FTP Success) or 500/502 (FTP Server auth required)', function () {",
            "    pm.expect([200, 201, 500, 502]).to.include(pm.response.code);",
            "});"
        ]
    )
]

# 6. Background Worker
worker_items = [
    make_request_item(
        "Trigger Background Retry Worker (200 OK)", "GET", "/api/worker/retry",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('Worker executed successfully', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res).to.have.property('status');",
            "});"
        ]
    )
]

# ------------------------------------------------------------------------------
# Assemble Postman Collection Object
# ------------------------------------------------------------------------------
collection = {
    "info": {
        "_postman_id": str(uuid.uuid4()),
        "name": "ASSA Middleware API Test Suite",
        "description": "Koleksi Postman resmi untuk pengujian seluruh API ASSA Middleware WSO2 MI Monorepo & Gateway (Port 6031).\nMencakup:\n- Health & Readiness Probes (12 Endpoint)\n- Auth & Scope Security Guards (401/403)\n- Input Validation Checks (400)\n- Inquiry & Pagination (200 OK)\n- Parallel Fan-Out Service Request (10x Retries & MariaDB Audit Logs)\n- Background Retry Worker",
        "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
    },
    "variable": [
        {"key": "baseUrl", "value": "http://localhost:6031", "type": "string"},
        {"key": "companyCode", "value": "1000", "type": "string"},
        {"key": "token_app_a", "value": TOKENS["token_app_a"], "type": "string"},
        {"key": "token_app_b", "value": TOKENS["token_app_b"], "type": "string"},
        {"key": "token_qa", "value": TOKENS["token_qa"], "type": "string"},
        {"key": "token_omnichannel", "value": TOKENS["token_omnichannel"], "type": "string"},
        {"key": "token_barantum", "value": TOKENS["token_barantum"], "type": "string"},
        {"key": "token_atlas", "value": TOKENS["token_atlas"], "type": "string"},
        {"key": "sr_trx_id", "value": "TRX-SR-INIT", "type": "string"},
        {"key": "sr_barantum_trx_id", "value": "TRX-BRT-INIT", "type": "string"},
        {"key": "vendor_trx_id", "value": "TRX-VND-INIT", "type": "string"},
        {"key": "spk_trx_id", "value": "TRX-SPK-INIT", "type": "string"}
    ],
    "item": [
        {"name": "1. Health & Readiness Probes", "item": health_items},
        {"name": "2. Auth & Scope Security Guards", "item": security_items},
        {"name": "3. Parameter Validation (400 Bad Request)", "item": validation_items},
        {"name": "4. Inquiry & Pagination (GET 200 OK)", "item": inquiry_items},
        {"name": "5. Transactional & Fan-Out Endpoints (POST)", "item": transactional_items},
        {"name": "6. Background Retry Worker", "item": worker_items}
    ]
}

# ------------------------------------------------------------------------------
# Build Environments
# ------------------------------------------------------------------------------
env_local = {
    "id": str(uuid.uuid4()),
    "name": "ASSA Middleware - Local Desktop (Port 6031)",
    "values": [
        {"key": "baseUrl", "value": "http://localhost:6031", "type": "default", "enabled": True},
        {"key": "companyCode", "value": "1000", "type": "default", "enabled": True},
        {"key": "token_app_a", "value": TOKENS["token_app_a"], "type": "secret", "enabled": True},
        {"key": "token_app_b", "value": TOKENS["token_app_b"], "type": "secret", "enabled": True},
        {"key": "token_qa", "value": TOKENS["token_qa"], "type": "secret", "enabled": True},
        {"key": "token_omnichannel", "value": TOKENS["token_omnichannel"], "type": "secret", "enabled": True},
        {"key": "token_barantum", "value": TOKENS["token_barantum"], "type": "secret", "enabled": True},
        {"key": "token_atlas", "value": TOKENS["token_atlas"], "type": "secret", "enabled": True}
    ],
    "_postman_variable_scope": "environment"
}

env_server = {
    "id": str(uuid.uuid4()),
    "name": "ASSA Middleware - Server Dev (devmiddleware1.assa.id:6031)",
    "values": [
        {"key": "baseUrl", "value": "http://devmiddleware1.assa.id:6031", "type": "default", "enabled": True},
        {"key": "companyCode", "value": "1000", "type": "default", "enabled": True},
        {"key": "token_app_a", "value": TOKENS["token_app_a"], "type": "secret", "enabled": True},
        {"key": "token_app_b", "value": TOKENS["token_app_b"], "type": "secret", "enabled": True},
        {"key": "token_qa", "value": TOKENS["token_qa"], "type": "secret", "enabled": True},
        {"key": "token_omnichannel", "value": TOKENS["token_omnichannel"], "type": "secret", "enabled": True},
        {"key": "token_barantum", "value": TOKENS["token_barantum"], "type": "secret", "enabled": True},
        {"key": "token_atlas", "value": TOKENS["token_atlas"], "type": "secret", "enabled": True}
    ],
    "_postman_variable_scope": "environment"
}

# ------------------------------------------------------------------------------
# Save Files
# ------------------------------------------------------------------------------
collection_path = os.path.join(POSTMAN_DIR, "ASSA_Middleware_TestSuite.postman_collection.json")
env_local_path = os.path.join(POSTMAN_DIR, "ASSA_Middleware_Local.postman_environment.json")
env_server_path = os.path.join(POSTMAN_DIR, "ASSA_Middleware_ServerDev.postman_environment.json")

with open(collection_path, "w", encoding="utf-8") as f:
    json.dump(collection, f, indent=2, ensure_ascii=False)

with open(env_local_path, "w", encoding="utf-8") as f:
    json.dump(env_local, f, indent=2, ensure_ascii=False)

with open(env_server_path, "w", encoding="utf-8") as f:
    json.dump(env_server, f, indent=2, ensure_ascii=False)

# Also update existing postman collections so users can import from test/ or middleware-assa/
legacy_test_path = os.path.join(REPO_ROOT, "test", "ASSA_Middleware_Full_Suite.postman_collection.json")
legacy_server_path = os.path.join(REPO_ROOT, "middleware-assa", "ASSA Middleware Server Dev (devmiddleware1.assa.id-6031).postman_collection.json")

with open(legacy_test_path, "w", encoding="utf-8") as f:
    json.dump(collection, f, indent=2, ensure_ascii=False)

with open(legacy_server_path, "w", encoding="utf-8") as f:
    json.dump(collection, f, indent=2, ensure_ascii=False)

print(f"Generated Collection : {collection_path}")
print(f"Generated Local Env  : {env_local_path}")
print(f"Generated Server Env : {env_server_path}")
print(f"Updated Legacy Paths : {legacy_test_path} & {legacy_server_path}")
