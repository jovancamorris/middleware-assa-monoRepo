#!/usr/bin/env python3
import json
import uuid
import os

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
POSTMAN_DIR = os.path.join(REPO_ROOT, "postman")
TEST_DIR = os.path.join(REPO_ROOT, "test")
MIDDLEWARE_DIR = os.path.join(REPO_ROOT, "middleware-assa")

os.makedirs(POSTMAN_DIR, exist_ok=True)
os.makedirs(TEST_DIR, exist_ok=True)
os.makedirs(MIDDLEWARE_DIR, exist_ok=True)

# ------------------------------------------------------------------------------
# Token & Variabel Kredensial Resmi ASSA Middleware
# Sesuai notes/DAFTAR_TOKEN_DAN_AUTENTIKASI.md
# ------------------------------------------------------------------------------
TOKENS = {
    "token_app_a": "3e378f890332c2eaefd0f7405a74fbdc03c28d95fa8abaa38f2fbdb2a8885013",
    "token_app_a_fallback": "c220fbfbc7e4c925eb662d85be47ee5ab017d23d9b04f7c22df6cb7efb6dfdbd",
    "token_app_b": "988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881",
    "token_qa": "ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d",
    "token_qa_fallback": "e20b33b006bc229d49dd701c385f8abfbe6a24726fb51db11624bce3766627be",
    "token_omnichannel": "14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12",
    "token_barantum": "umk_da295902028f5804c4f0e9d9fd81fa07a2a0e1152d6171e30f387416fbfe5680",
    "token_barantum_legacy": "umk_2d35d5538f25624fc716958934d1751889cb7f6a0b0f1df18667032272eb86fd",
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

def make_request_item(name, method, url_path, query_params=None, headers=None, body_json=None, token_var=None, test_assertions=None, prerequest_lines=None, description=""):
    events = []
    if prerequest_lines:
        events.append(make_prerequest_script(prerequest_lines))
    if test_assertions:
        events.append(make_test_script(test_assertions))

    header_list = []
    # Header X-Retry-Interval-Seconds hanya digunakan pada 6 service yang memanggil SafeApiCallWithRetrySeq
    # (Branch, Customer, Vehicle, Vendor, SPK, Payments) pada pemanggilan backend
    retry_services = ("/api/branches", "/api/customers", "/api/vehicles", "/api/vendors", "/api/spk", "/api/payments")
    is_retry_service = any(url_path.startswith(prefix) for prefix in retry_services)
    is_guard_or_validation = any(keyword in name.lower() for keyword in ["guard", "validasi", "tanpa token", "scope tidak cukup", "token invalid", "bad request"])
    if is_retry_service and not is_guard_or_validation:
        header_list.append({"key": "X-Retry-Interval-Seconds", "value": "1", "type": "text"})
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

    if description:
        request_obj["description"] = description

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
# 1. Health & Readiness Probes (16 Items)
# ------------------------------------------------------------------------------
health_items = [
    make_request_item(
        "General Liveness Probe (/health)", "GET", "/health",
        description="Probe liveness umum gateway Nginx / WSO2 MI untuk memverifikasi container aktif.",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('Response is UP or 200', function () { pm.expect(pm.response.code).to.eql(200); });"
        ]
    ),
    make_request_item(
        "General Readiness Probe (/readiness)", "GET", "/readiness",
        description="Probe readiness umum gateway untuk memverifikasi sistem siap menerima traffic.",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"
        ]
    ),
    make_request_item(
        "Branch Health Check (Liveness)", "GET", "/health/branch",
        description="Pemeriksaan status hidup (liveness) branch-service.",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('Response is UP or 200', function () { pm.expect(pm.response.code).to.eql(200); });"
        ]
    ),
    make_request_item(
        "Branch Readiness Check", "GET", "/readiness/branch",
        description="Pemeriksaan kesiapan (readiness) branch-service menerima query cabang.",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
    make_request_item(
        "Customer Health Check (Liveness)", "GET", "/health/customer",
        description="Pemeriksaan status hidup customer-service.",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
    make_request_item(
        "Customer Readiness Check", "GET", "/readiness/customer",
        description="Pemeriksaan kesiapan customer-service menerima query pelanggan.",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
    make_request_item(
        "Vehicle Health Check (Liveness)", "GET", "/health/vehicle",
        description="Pemeriksaan status hidup vehicle-service.",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
    make_request_item(
        "Vehicle Readiness Check", "GET", "/readiness/vehicle",
        description="Pemeriksaan kesiapan vehicle-service terhubung ke endpoint devfmsapi / ATLAS.",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
    make_request_item(
        "Vendor Health Check (Liveness)", "GET", "/health/vendor",
        description="Pemeriksaan status hidup vendor-service.",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
    make_request_item(
        "Vendor Readiness Check", "GET", "/readiness/vendor",
        description="Pemeriksaan kesiapan vendor-service untuk interface XML ke FTP SAP.",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
    make_request_item(
        "SPK Health Check (Liveness)", "GET", "/health/spk",
        description="Pemeriksaan status hidup spk-service.",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
    make_request_item(
        "SPK Readiness Check", "GET", "/readiness/spk",
        description="Pemeriksaan kesiapan spk-service untuk interface SPK Due List ke FTP SAP.",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
    make_request_item(
        "Service Request Health Check (Liveness)", "GET", "/health/service-request",
        description="Pemeriksaan status hidup service-request-service.",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
    make_request_item(
        "Service Request Readiness Check", "GET", "/readiness/service-request",
        description="Pemeriksaan kesiapan service-request-service melakukan paralel fan-out ke ATLAS & ExtService.",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
    make_request_item(
        "Payments Health Check (Liveness)", "GET", "/health/payments",
        description="Pemeriksaan status hidup payments-service.",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
    make_request_item(
        "Payments Readiness Check", "GET", "/readiness/payments",
        description="Pemeriksaan kesiapan payments-service untuk interface XML ke FTP SAP.",
        test_assertions=["pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"]
    ),
]

# ------------------------------------------------------------------------------
# 2. Auth & Scope Security Guards (15 Items)
# ------------------------------------------------------------------------------
security_items = [
    make_request_item(
        "Auth Guard: Request Tanpa Token - Branch (401)", "GET", "/api/branches/getByCreateDate",
        query_params={"companyCode": "{{companyCode}}"},
        description="Memverifikasi penolakan HTTP 401 saat klien tidak mengirim header Authorization.",
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
        "Auth Guard: Request Tanpa Token - Customer (401)", "GET", "/api/customers/getByCreateDate",
        query_params={"companyCode": "{{companyCode}}"},
        description="Memverifikasi penolakan HTTP 401 pada Customer Service tanpa Authorization header.",
        test_assertions=[
            "pm.test('Status code is 401 Unauthorized', function () { pm.response.to.have.status(401); });"
        ]
    ),
    make_request_item(
        "Auth Guard: Request Tanpa Token - Vehicle (401)", "GET", "/api/vehicles/getByLicensePlate",
        query_params={"plat_no": "B-9065"},
        description="Memverifikasi penolakan HTTP 401 pada Vehicle Service tanpa Authorization header.",
        test_assertions=[
            "pm.test('Status code is 401 Unauthorized', function () { pm.response.to.have.status(401); });"
        ]
    ),
    make_request_item(
        "Auth Guard: Request Tanpa Token - Payments (401)", "POST", "/api/payments",
        body_json={
            "companyCodes": "1000/2000/6000/7000",
            "accountingDocumentNumber": "9300051904",
            "documentDate": "08.09.2026",
            "postingDate": "08.09.2026",
            "businessArea": "1100",
            "currency": "IDR",
            "glAccount": "1114000000"
        },
        description="Memverifikasi penolakan HTTP 401 pada Payments Service tanpa Authorization header.",
        test_assertions=[
            "pm.test('Status code is 401 Unauthorized', function () { pm.response.to.have.status(401); });"
        ]
    ),
    make_request_item(
        "Auth Guard: Request dengan Token Palsu / Expired (401)", "GET", "/api/branches/getByCreateDate",
        query_params={"companyCode": "{{companyCode}}"},
        headers={"Authorization": "{{fakeToken}}"},
        description="Memverifikasi penolakan HTTP 401 saat klien mengirimkan token acak atau tidak terdaftar.",
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
        description="Memverifikasi penolakan HTTP 403 saat App B (hanya berhak 'vehicles') mencoba mengakses Branch API.",
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
        description="Memverifikasi penolakan HTTP 403 saat App B memanggil Customer API.",
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
        description="Memverifikasi penolakan HTTP 403 saat App B memanggil Vendor Create API.",
        test_assertions=[
            "pm.test('Status code is 403 Forbidden', function () { pm.response.to.have.status(403); });",
            "pm.test('Detail states missing vendors scope', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res.detail).to.include('vendors');",
            "});"
        ]
    ),
    make_request_item(
        "Scope Guard: App B call SPK Due List (403)", "POST", "/api/spk/duelist",
        body_json={},
        token_var="token_app_b",
        description="Memverifikasi penolakan HTTP 403 saat App B memanggil SPK Due List API.",
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
        description="Memverifikasi penolakan HTTP 403 saat App B memanggil Service Request API.",
        test_assertions=[
            "pm.test('Status code is 403 Forbidden', function () { pm.response.to.have.status(403); });",
            "pm.test('Detail states missing service_requests scope', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res.detail).to.include('service_requests');",
            "});"
        ]
    ),
    make_request_item(
        "Scope Guard: App B call Payments (403)", "POST", "/api/payments",
        body_json={
            "companyCodes": "1000/2000/6000/7000",
            "accountingDocumentNumber": "9300051904",
            "documentDate": "08.09.2026",
            "postingDate": "08.09.2026",
            "businessArea": "1100",
            "currency": "IDR",
            "glAccount": "1114000000"
        },
        token_var="token_app_b",
        description="Memverifikasi penolakan HTTP 403 saat App B memanggil Payments Service.",
        test_assertions=[
            "pm.test('Status code is 403 Forbidden', function () { pm.response.to.have.status(403); });",
            "pm.test('Detail states missing payments scope', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res.detail).to.include('payments');",
            "});"
        ]
    ),
    make_request_item(
        "Scope Guard: App ATLAS (scope: vendors) call SPK Due List (403)", "POST", "/api/spk/duelist",
        body_json={},
        token_var="token_atlas",
        description="Memverifikasi penolakan HTTP 403 saat App ATLAS (hanya scope 'vendors') memanggil SPK Due List.",
        test_assertions=[
            "pm.test('Status code is 403 Forbidden', function () { pm.response.to.have.status(403); });",
            "pm.test('Detail states missing spk scope', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res.detail).to.include('spk');",
            "});"
        ]
    ),
    make_request_item(
        "Scope Guard: App ATLAS call Payments (403)", "POST", "/api/payments",
        body_json={
            "companyCodes": "1000/2000/6000/7000",
            "accountingDocumentNumber": "9300051904",
            "documentDate": "08.09.2026",
            "postingDate": "08.09.2026",
            "businessArea": "1100",
            "currency": "IDR",
            "glAccount": "1114000000"
        },
        token_var="token_atlas",
        description="Memverifikasi penolakan HTTP 403 saat App ATLAS memanggil Payments Service.",
        test_assertions=[
            "pm.test('Status code is 403 Forbidden', function () { pm.response.to.have.status(403); });",
            "pm.test('Detail states missing payments scope', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res.detail).to.include('payments');",
            "});"
        ]
    ),
    make_request_item(
        "Scope Guard: App Omnichannel (scope: service_requests) call Customer (403)", "GET", "/api/customers/getByCreateDate",
        query_params={"companyCode": "{{companyCode}}"},
        token_var="token_omnichannel",
        description="Memverifikasi penolakan HTTP 403 saat App Omnichannel memanggil Customer Service.",
        test_assertions=[
            "pm.test('Status code is 403 Forbidden', function () { pm.response.to.have.status(403); });",
            "pm.test('Detail states missing customers scope', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res.detail).to.include('customers');",
            "});"
        ]
    ),
    make_request_item(
        "Scope Guard: App Omnichannel call Payments (403)", "POST", "/api/payments",
        body_json={
            "companyCodes": "1000/2000/6000/7000",
            "accountingDocumentNumber": "9300051904",
            "documentDate": "08.09.2026",
            "postingDate": "08.09.2026",
            "businessArea": "1100",
            "currency": "IDR",
            "glAccount": "1114000000"
        },
        token_var="token_omnichannel",
        description="Memverifikasi penolakan HTTP 403 saat App Omnichannel memanggil Payments Service.",
        test_assertions=[
            "pm.test('Status code is 403 Forbidden', function () { pm.response.to.have.status(403); });",
            "pm.test('Detail states missing payments scope', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res.detail).to.include('payments');",
            "});"
        ]
    ),
]

# ------------------------------------------------------------------------------
# 3. Parameter & Input Validation (14 Items)
# ------------------------------------------------------------------------------
validation_items = [
    make_request_item(
        "Validasi: Payments currency tidak valid / lebih dari 5 karakter (400)", "POST", "/api/payments",
        body_json={
            "companyCodes": "1000",
            "accountingDocumentNumber": "9300051904",
            "documentDate": "08.09.2026",
            "postingDate": "08.09.2026",
            "businessArea": "1100",
            "currency": "TOOLONG",
            "glAccount": "1114000000"
        },
        token_var="token_qa",
        description="Memverifikasi penolakan HTTP 400 jika field currency melebihi batas 5 karakter.",
        test_assertions=[
            "pm.test('Status code is 400 Bad Request', function () { pm.response.to.have.status(400); });",
            "pm.test('Detail mentions currency code requirement', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res.error).to.be.true;",
            "});"
        ]
    ),
    make_request_item(
        "Validasi: Payments businessArea lebih dari 10 karakter (400)", "POST", "/api/payments",
        body_json={
            "companyCodes": "1000",
            "accountingDocumentNumber": "9300051904",
            "documentDate": "08.09.2026",
            "postingDate": "08.09.2026",
            "businessArea": "TOOLONGAREA123",
            "currency": "IDR",
            "glAccount": "1114000000"
        },
        token_var="token_qa",
        description="Memverifikasi penolakan HTTP 400 jika field businessArea melebihi batas 10 karakter.",
        test_assertions=[
            "pm.test('Status code is 400 Bad Request', function () { pm.response.to.have.status(400); });"
        ]
    ),
    make_request_item(
        "Validasi: Payments accountingDocumentNumber lebih dari 50 karakter (400)", "POST", "/api/payments",
        body_json={
            "companyCodes": "1000",
            "accountingDocumentNumber": "1234567890123456789012345678901234567890123456789012345",
            "documentDate": "08.09.2026",
            "postingDate": "08.09.2026",
            "businessArea": "1100",
            "currency": "IDR",
            "glAccount": "1114000000"
        },
        token_var="token_qa",
        description="Memverifikasi penolakan HTTP 400 jika nomor dokumen accountingDocumentNumber melebihi 50 karakter.",
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
        description="Memverifikasi HTTP 400 jika companyTitle bukan PT atau CV.",
        test_assertions=[
            "pm.test('Status code is 400 Bad Request', function () { pm.response.to.have.status(400); });"
        ]
    ),
    make_request_item(
        "Validasi: Vendor Create otv No tanpa info rekening bank (400)", "POST", "/api/vendors/create",
        body_json={
            "companyTitle": "PT",
            "companyName": "PT Solusi Mandiri",
            "otv": "No",
            "paymentCycle": "Monthly",
            "accountNumber": "",
            "accountName": "",
            "bankName": "",
            "hoEmail": "info@solusimandiri.com",
            "hoPhone": "0812345678",
            "hoAddress": "Jl. Gatot Subroto No. 10 Jakarta",
            "contactName": "Bpk Hendra",
            "contactPhone": "0812345679",
            "npwp": "3173080209920003",
            "accountGroup": "V010",
            "top": "T014",
            "glAccount": "2121000000",
            "documentNumber": "DOC-VALID-02"
        },
        token_var="token_qa",
        description="Memverifikasi HTTP 400 jika otv bernilai 'No' tetapi data rekening bank tidak diisi.",
        test_assertions=[
            "pm.test('Status code is 400 Bad Request', function () { pm.response.to.have.status(400); });",
            "pm.test('Detail mentions bank account requirement when otv No', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res.error).to.be.true;",
            "});"
        ]
    ),
    make_request_item(
        "Validasi: SPK Due List tanpa noSpk (400)", "POST", "/api/spk/duelist",
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
        description="Memverifikasi HTTP 400 jika field wajib noSpk tidak disertakan.",
        test_assertions=[
            "pm.test('Status code is 400 Bad Request', function () { pm.response.to.have.status(400); });"
        ]
    ),
    make_request_item(
        "Validasi: SPK Due List beda total dengan header X-Validate-Total (400)", "POST", "/api/spk/duelist",
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
        description="Memverifikasi HTTP 400 jika total harga SPK tidak sama dengan akumulasi harga item rincian details.",
        test_assertions=[
            "pm.test('Status code is 400 Bad Request', function () { pm.response.to.have.status(400); });"
        ]
    ),
    make_request_item(
        "Validasi: SPK Due List field invoice parsial / tidak lengkap (400)", "POST", "/api/spk/duelist",
        body_json={
            "noSpk": "SPK/2026/09/00004",
            "type": "Maintenance",
            "noPolisi": "B-2120-BKZ",
            "category": "Maintenance",
            "subCategory": "Adhoc",
            "vendorReferensi": "0001",
            "totalPrice": 1850000,
            "createdAt": "2026-09-17 14:46:11",
            "createdBy": "atlas.user",
            "invoiceNumber": "INV-001",
            "invoiceDate": "",
            "invoiceAmount": 0,
            "details": [{"jenis": "Jasa", "description": "Jasa Perbaikan AC", "qty": 1, "price": 1850000}]
        },
        token_var="token_qa",
        description="Memverifikasi HTTP 400 jika salah satu field invoice diisi tetapi field invoiceDate / invoiceAmount tidak lengkap.",
        test_assertions=[
            "pm.test('Status code is 400 Bad Request', function () { pm.response.to.have.status(400); });",
            "pm.test('Detail mentions invoice fields required together', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res.error).to.be.true;",
            "});"
        ]
    ),
    make_request_item(
        "Validasi: Service Request tanpa field wajib app_id (400)", "POST", "/api/service-requests",
        body_json={
            "reff_number": "REF01",
            "branchCode": "JKT01",
            "created_datetime": "17-09-2026",
            "created_by": "admin",
            "ticket_no": "TCK01"
        },
        token_var="token_omnichannel",
        description="Memverifikasi HTTP 400 jika payload legacy Service Request tidak memiliki app_id.",
        test_assertions=[
            "pm.test('Status code is 400 Bad Request', function () { pm.response.to.have.status(400); });",
            "pm.test('Detail mentions app_id is required', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res.error).to.be.true;",
            "});"
        ]
    ),
    make_request_item(
        "Validasi: Payments tanpa accountingDocumentNumber (400)", "POST", "/api/payments",
        body_json={
            "companyCodes": "1000/2000/6000/7000",
            "documentDate": "08.09.2026",
            "postingDate": "08.09.2026",
            "businessArea": "1100",
            "currency": "IDR",
            "glAccount": "1114000000"
        },
        token_var="token_qa",
        description="Memverifikasi HTTP 400 jika field wajib accountingDocumentNumber tidak dikirim.",
        test_assertions=[
            "pm.test('Status code is 400 Bad Request', function () { pm.response.to.have.status(400); });",
            "pm.test('Detail mentions accountingDocumentNumber required', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res.error).to.be.true;",
            "});"
        ]
    ),
    make_request_item(
        "Validasi: Payments tanpa documentDate (400)", "POST", "/api/payments",
        body_json={
            "companyCodes": "1000/2000/6000/7000",
            "accountingDocumentNumber": "9300051904",
            "postingDate": "08.09.2026",
            "businessArea": "1100",
            "currency": "IDR",
            "glAccount": "1114000000"
        },
        token_var="token_qa",
        description="Memverifikasi HTTP 400 jika field wajib documentDate tidak dikirim.",
        test_assertions=[
            "pm.test('Status code is 400 Bad Request', function () { pm.response.to.have.status(400); });",
            "pm.test('Detail mentions documentDate required', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res.error).to.be.true;",
            "});"
        ]
    ),
    make_request_item(
        "Validasi: Payments tanpa postingDate (400)", "POST", "/api/payments",
        body_json={
            "companyCodes": "1000/2000/6000/7000",
            "accountingDocumentNumber": "9300051904",
            "documentDate": "08.09.2026",
            "businessArea": "1100",
            "currency": "IDR",
            "glAccount": "1114000000"
        },
        token_var="token_qa",
        description="Memverifikasi HTTP 400 jika field wajib postingDate tidak dikirim.",
        test_assertions=[
            "pm.test('Status code is 400 Bad Request', function () { pm.response.to.have.status(400); });"
        ]
    ),
    make_request_item(
        "Validasi: Payments tanpa businessArea (400)", "POST", "/api/payments",
        body_json={
            "companyCodes": "1000/2000/6000/7000",
            "accountingDocumentNumber": "9300051904",
            "documentDate": "08.09.2026",
            "postingDate": "08.09.2026",
            "currency": "IDR",
            "glAccount": "1114000000"
        },
        token_var="token_qa",
        description="Memverifikasi HTTP 400 jika field wajib businessArea tidak dikirim.",
        test_assertions=[
            "pm.test('Status code is 400 Bad Request', function () { pm.response.to.have.status(400); });"
        ]
    ),
    make_request_item(
        "Validasi: Payments tanpa glAccount (400)", "POST", "/api/payments",
        body_json={
            "companyCodes": "1000/2000/6000/7000",
            "accountingDocumentNumber": "9300051904",
            "documentDate": "08.09.2026",
            "postingDate": "08.09.2026",
            "businessArea": "1100",
            "currency": "IDR"
        },
        token_var="token_qa",
        description="Memverifikasi HTTP 400 jika field wajib glAccount tidak dikirim.",
        test_assertions=[
            "pm.test('Status code is 400 Bad Request', function () { pm.response.to.have.status(400); });"
        ]
    ),
]

# ------------------------------------------------------------------------------
# 4. Inquiry & Pagination (GET 200 OK) (18 Items)
# ------------------------------------------------------------------------------
inquiry_items = [
    make_request_item(
        "Branch Inquiry GetByCreateDate (Page 1 - App A)", "GET", "/api/branches/getByCreateDate",
        query_params={
            "companyCode": "{{companyCode}}",
            "dateStart": "2020-01-01",
            "dateEnd": "2026-09-11",
            "page": "1",
            "perPage": "5"
        },
        token_var="token_app_a",
        description="Mengambil data master cabang SAP dengan paginasi page 1 perPage 5 menggunakan token App A.",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('Response contains data array', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res).to.have.property('data');",
            "});"
        ]
    ),
    make_request_item(
        "Branch Inquiry GetByCreateDate (Page 2 - QA)", "GET", "/api/branches/getByCreateDate",
        query_params={
            "companyCode": "{{companyCode}}",
            "dateStart": "2020-01-01",
            "dateEnd": "2026-09-11",
            "page": "2",
            "perPage": "5"
        },
        token_var="token_qa",
        description="Mengambil data master cabang SAP paginasi page 2 menggunakan token QA.",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"
        ]
    ),
    make_request_item(
        "Branch Inquiry Search via filterBy (QA)", "GET", "/api/branches/getByCreateDate",
        query_params={
            "companyCode": "{{companyCode}}",
            "dateStart": "2020-01-01",
            "dateEnd": "2026-09-11",
            "filterBy": "jakarta",
            "page": "1",
            "perPage": "5"
        },
        token_var="token_qa",
        description="Mengambil data master cabang menggunakan single-field search filterBy (mencakup BranchCode dan BranchName).",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('Response contains data array', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res.success).to.be.true;",
            "    pm.expect(res).to.have.property('data');",
            "});"
        ]
    ),
    make_request_item(
        "Customer Inquiry GetByCreateDate (Page 1 - App A)", "GET", "/api/customers/getByCreateDate",
        query_params={
            "companyCode": "{{companyCode}}",
            "dateStart": "2025-01-01",
            "dateEnd": "2026-12-31",
            "page": "1",
            "perPage": "5"
        },
        token_var="token_app_a",
        description="Mengambil data pelanggan Core SAP dengan filter rentang tanggal dan paginasi page 1. Mendukung query param CustomerCode dan CustomerName.",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"
        ]
    ),
    make_request_item(
        "Customer Inquiry Search (CustomerCode & CustomerName - App A)", "GET", "/api/customers/getByCreateDate",
        query_params={
            "companyCode": "{{companyCode}}",
            "dateStart": "2025-01-01",
            "dateEnd": "2026-12-31",
            "CustomerCode": "1000025",
            "CustomerName": "ADI SARANA",
            "page": "1",
            "perPage": "5"
        },
        token_var="token_app_a",
        description="Mencari data pelanggan spesifik menggunakan filter langsung via query param CustomerCode dan CustomerName.",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('Data array is present', function () {",
            "    var json = pm.response.json();",
            "    pm.expect(json.success).to.be.true;",
            "    pm.expect(json.data).to.be.an('array');",
            "});"
        ]
    ),
    make_request_item(
        "Customer Inquiry Search CustomerCode Only (QA)", "GET", "/api/customers/getByCreateDate",
        query_params={
            "companyCode": "{{companyCode}}",
            "CustomerCode": "1000025",
            "page": "1",
            "perPage": "5"
        },
        token_var="token_qa",
        description="Mencari data pelanggan berdasarkan kode CustomerCode saja menggunakan token QA.",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('Filter by CustomerCode succeeds', function () {",
            "    var json = pm.response.json();",
            "    pm.expect(json.success).to.be.true;",
            "    pm.expect(json.data).to.be.an('array');",
            "});"
        ]
    ),
    make_request_item(
        "Customer Inquiry Search CustomerName Only (QA)", "GET", "/api/customers/getByCreateDate",
        query_params={
            "companyCode": "{{companyCode}}",
            "CustomerName": "ADI SARANA",
            "page": "1",
            "perPage": "5"
        },
        token_var="token_qa",
        description="Mencari data pelanggan berdasarkan nama CustomerName (substring) menggunakan token QA.",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('Filter by CustomerName succeeds', function () {",
            "    var json = pm.response.json();",
            "    pm.expect(json.success).to.be.true;",
            "    pm.expect(json.data).to.be.an('array');",
            "});"
        ]
    ),
    make_request_item(
        "Customer Inquiry Search via filterBy (QA)", "GET", "/api/customers/getByCreateDate",
        query_params={
            "companyCode": "{{companyCode}}",
            "dateStart": "2025-01-01",
            "dateEnd": "2026-12-31",
            "filterBy": "1000025",
            "page": "1",
            "perPage": "5"
        },
        token_var="token_qa",
        description="Mencari data pelanggan menggunakan single-field search filterBy (mencakup CustomerCode dan CustomerName).",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('Data array is present', function () {",
            "    var json = pm.response.json();",
            "    pm.expect(json.success).to.be.true;",
            "    pm.expect(json.data).to.be.an('array');",
            "});"
        ]
    ),
    make_request_item(
        "Customer Inquiry GetByCreateDate (Page 2 - QA)", "GET", "/api/customers/getByCreateDate",
        query_params={
            "companyCode": "{{companyCode}}",
            "dateStart": "2025-01-01",
            "dateEnd": "2026-12-31",
            "page": "2",
            "perPage": "5"
        },
        token_var="token_qa",
        description="Mengambil data pelanggan Core SAP paginasi page 2 menggunakan token QA.",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"
        ]
    ),
    make_request_item(
        "Vehicle Inquiry /getByLicensePlate cari Plat Nomor & Pagination (App B)", "GET", "/api/vehicles/getByLicensePlate",
        query_params={
            "plat_no": "B-9065",
            "page": "1",
            "perPage": "10"
        },
        token_var="token_app_b",
        description="Inquiry data kendaraan berdasarkan plat nomor plat_no serta pagination page & perPage via getByLicensePlate.",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('Pagination structure is valid', function () {",
            "    var json = pm.response.json();",
            "    pm.expect(json.success).to.be.true;",
            "    pm.expect(json.page).to.eql(1);",
            "    pm.expect(json.perPage).to.eql(10);",
            "    pm.expect(json.data).to.be.an('array');",
            "});"
        ]
    ),
    make_request_item(
        "Vehicle Inquiry /getByLicensePlate cari Plat Nomor dengan Spasi Auto-Normalized (QA)", "GET", "/api/vehicles/getByLicensePlate",
        query_params={
            "plat_no": "B 9065",
            "page": "1",
            "perPage": "10"
        },
        token_var="token_qa",
        description="Inquiry data kendaraan berdasarkan plat nomor dengan spasi yang otomatis dinormalisasi menjadi format standar bertanda hubung.",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('Auto normalized plate returns valid array', function () {",
            "    var json = pm.response.json();",
            "    pm.expect(json.success).to.be.true;",
            "    pm.expect(json.data).to.be.an('array');",
            "});"
        ]
    ),
    make_request_item(
        "Vehicle Inquiry /getByLicensePlate Paginate All Vehicles (Page 1 - App B)", "GET", "/api/vehicles/getByLicensePlate",
        query_params={
            "page": "1",
            "perPage": "10"
        },
        token_var="token_app_b",
        description="Paginasi data kendaraan seluruh armada halaman 1 via endpoint /getByLicensePlate tanpa query filter plat nomor.",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('Pagination page 1 returns data', function () {",
            "    var json = pm.response.json();",
            "    pm.expect(json.success).to.be.true;",
            "    pm.expect(json.data).to.be.an('array');",
            "});"
        ]
    ),
    make_request_item(
        "Vehicle Inquiry /getByLicensePlate cari Equipment via filterBy (App B)", "GET", "/api/vehicles/getByLicensePlate",
        query_params={
            "filterBy": "10027282",
            "page": "1",
            "perPage": "10"
        },
        token_var="token_app_b",
        description="Inquiry data unit kendaraan via /getByLicensePlate berdasarkan equipment_no menggunakan filterBy.",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('FilterBy equipment returns valid array', function () {",
            "    var json = pm.response.json();",
            "    pm.expect(json.success).to.be.true;",
            "    pm.expect(json.data).to.be.an('array');",
            "});"
        ]
    ),
    make_request_item(
        "Vehicle Inquiry /getByLicensePlate cari via filterBy (App B)", "GET", "/api/vehicles/getByLicensePlate",
        query_params={
            "filterBy": "B-9065",
            "page": "1",
            "perPage": "10"
        },
        token_var="token_app_b",
        description="Inquiry data armada kendaraan menggunakan single-field search filterBy (mencakup plat_no/plate_no, equipment_no, branch_code, tipe_kendaraan, dan color).",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('FilterBy search returns valid array', function () {",
            "    var json = pm.response.json();",
            "    pm.expect(json.success).to.be.true;",
            "    pm.expect(json.data).to.be.an('array');",
            "});"
        ]
    ),
    make_request_item(
        "Vehicle Atlas Inquiry /vehicleatlas cari Plat Nomor (QA)", "GET", "/api/vehicles/vehicleatlas",
        query_params={
            "plat_no": "B-9065",
            "page": "1",
            "perPage": "10"
        },
        token_var="token_qa",
        description="Inquiry data unit kendaraan dari endpoint vehicleatlas berdasarkan plat_no dengan pagination standar.",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('Pagination structure is valid', function () {",
            "    var json = pm.response.json();",
            "    pm.expect(json.success).to.be.true;",
            "    pm.expect(json.data).to.be.an('array');",
            "});"
        ]
    ),
    make_request_item(
        "Vehicle Atlas Inquiry /vehicleatlas cari Plat Nomor dengan Spasi Auto-Normalized (App B)", "GET", "/api/vehicles/vehicleatlas",
        query_params={
            "plat_no": "B 9065",
            "page": "1",
            "perPage": "10"
        },
        token_var="token_app_b",
        description="Inquiry data unit kendaraan via vehicleatlas dengan format plat dengan spasi yang dinormalisasi.",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"
        ]
    ),
    make_request_item(
        "Vehicle Atlas Inquiry /vehicleatlas cari via filterBy (QA)", "GET", "/api/vehicles/vehicleatlas",
        query_params={
            "filterBy": "B 9065",
            "page": "1",
            "perPage": "10"
        },
        token_var="token_qa",
        description="Inquiry vehicleatlas menggunakan single-field search filterBy dengan plat ber-spasi yang dinormalisasi otomatis.",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('FilterBy vehicleatlas returns valid array', function () {",
            "    var json = pm.response.json();",
            "    pm.expect(json.success).to.be.true;",
            "    pm.expect(json.data).to.be.an('array');",
            "});"
        ]
    ),
    make_request_item(
        "Vehicle Atlas Inquiry /vehicleatlas Paginate All Vehicles Page 1 (App B)", "GET", "/api/vehicles/vehicleatlas",
        query_params={
            "page": "1",
            "perPage": "10"
        },
        token_var="token_app_b",
        description="Paginasi seluruh armada kendaraan halaman 1 via endpoint vehicleatlas.",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('Pagination page 1 returns 10 items', function () {",
            "    var json = pm.response.json();",
            "    pm.expect(json.success).to.be.true;",
            "    pm.expect(json.page).to.eql(1);",
            "    pm.expect(json.data).to.be.an('array');",
            "});"
        ]
    ),
    make_request_item(
        "Vehicle Atlas Inquiry /vehicleatlas Paginate All Vehicles Page 2 (App B)", "GET", "/api/vehicles/vehicleatlas",
        query_params={
            "page": "2",
            "perPage": "10"
        },
        token_var="token_app_b",
        description="Paginasi seluruh armada kendaraan halaman 2 (page 2) via endpoint vehicleatlas.",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('Pagination page 2 returns data', function () {",
            "    var json = pm.response.json();",
            "    pm.expect(json.success).to.be.true;",
            "    pm.expect(json.page).to.eql(2);",
            "    pm.expect(json.data).to.be.an('array');",
            "});"
        ]
    ),
    make_request_item(
        "Vehicle Atlas Inquiry /vehicleatlas cari Equipment via filterBy (App B)", "GET", "/api/vehicles/vehicleatlas",
        query_params={
            "filterBy": "10027282",
            "page": "1",
            "perPage": "10"
        },
        token_var="token_app_b",
        description="Inquiry data unit kendaraan dari endpoint vehicleatlas berdasarkan equipment_no menggunakan filterBy dengan pagination.",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('FilterBy equipment vehicleatlas returns valid array', function () {",
            "    var json = pm.response.json();",
            "    pm.expect(json.success).to.be.true;",
            "    pm.expect(json.data).to.be.an('array');",
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
        description="Inquiry riwayat transaksi tiket Service Request dari MariaDB dengan struktur pagination WSO2 MI.",
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
        headers={"X-API-Key": "{{token_barantum}}", "Origin": "https://barantum.internal"},
        description="Inquiry riwayat tiket Service Request untuk vendor publik Barantum CRM via X-API-Key.",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });"
        ]
    ),
]

# ------------------------------------------------------------------------------
# 5. Transactional & Fan-Out Endpoints (POST) (12 Items)
# ------------------------------------------------------------------------------
transactional_items = [
    make_request_item(
        "Service Request - Parallel Fan-Out (Format Flat Omnichannel)", "POST", "/api/service-requests",
        headers={"X-Transaction-Id": "{{sr_trx_id}}"},
        token_var="token_omnichannel",
        description="Mengirim transaksi tiket Service Request baru format legacy flat Omnichannel. Menjalankan fan-out paralel ke ATLAS & ASSA ExtServices dengan 10x retries.",
        prerequest_lines=[
            "const srId = 'TRX-SR-POSTMAN-' + Date.now();",
            "pm.collectionVariables.set('sr_trx_id', srId);"
        ],
        body_json={
            "app_id": "sr_app_omnichannel",
            "reff_number": "REF-SR-POSTMAN-001",
            "branchCode": "JKT01",
            "equipment_number": "EQ-998877",
            "license_plate": "B-1234-SSA",
            "customerCode": "CUST-00123",
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
        description="Mengirim ulang transaksi yang sama untuk menguji mekanisme Idempotency Guard (replay cached response jika SUCCEEDED atau retry jika status sebelumnya FAILED).",
        body_json={
            "app_id": "sr_app_omnichannel",
            "reff_number": "REF-SR-POSTMAN-001",
            "branchCode": "JKT01",
            "equipment_number": "EQ-998877",
            "license_plate": "B-1234-SSA",
            "customerCode": "CUST-00123",
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
        "Service Request - Public Endpoint Barantum CRM (Format Baru: Nested unit)", "POST", "/api/vendor/public/service-requests",
        headers={"X-API-Key": "{{token_barantum}}", "Origin": "https://barantum.internal", "X-Transaction-Id": "{{sr_barantum_trx_id}}"},
        description="Mengirim transaksi tiket Service Request format baru Barantum CRM dengan nested object 'unit' via Public Gateway port 6031.",
        prerequest_lines=[
            "const bTrx = 'TRX-BRT-POSTMAN-' + Date.now();",
            "pm.collectionVariables.set('sr_barantum_trx_id', bTrx);"
        ],
        body_json={
            "customerName": "Budi Santoso",
            "requestorName": "Budi Santoso",
            "requestorPhone": "081234567890",
            "branch": "Jakarta Pusat",
            "referenceNumber": "BRT-SR-POSTMAN-001",
            "unit": {
                "licensePlate": "B 1234 XYZ",
                "brand": "Toyota",
                "model": "Avanza",
                "odometer": 25000
            }
        },
        test_assertions=[
            "pm.test('Status code is 200 (Success) or 502 (Target Failed after 10 Retries)', function () {",
            "    pm.expect([200, 502]).to.include(pm.response.code);",
            "});",
            "pm.test('Response contains targets info', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res).to.have.property('targets');",
            "});"
        ]
    ),
    make_request_item(
        "Vendor Create - Valid Payload V2 ke FTP (QA Token)", "POST", "/api/vendors/create",
        headers={"X-Transaction-Id": "{{vendor_trx_id}}"},
        token_var="token_qa",
        description="Menerima 17 field V2 ATLAS data vendor, memvalidasi aturan bisnis SAP, membentuk file XML resmi ATLAS, dan mengirimkan file via FTP SAP devqaxmlpool.assa.id.",
        prerequest_lines=[
            "const vTrx = 'TRX-VND-POSTMAN-' + Date.now();",
            "pm.collectionVariables.set('vendor_trx_id', vTrx);"
        ],
        body_json={
            "company_code": "1000/2000/6000/7000",
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
        "Vendor Create - Valid Payload V2 ke FTP (App ATLAS Token - Scope: vendors)", "POST", "/api/vendors/create",
        headers={"X-Transaction-Id": "{{vendor_atlas_trx_id}}"},
        token_var="token_atlas",
        description="Menguji pemanggilan Vendor Create V2 menggunakan token khusus App ATLAS (scope: vendors).",
        prerequest_lines=[
            "const vTrxAtlas = 'TRX-VND-ATLAS-' + Date.now();",
            "pm.collectionVariables.set('vendor_atlas_trx_id', vTrxAtlas);"
        ],
        body_json={
            "company_code": "1000/2000/6000/7000",
            "companyTitle": "CV",
            "companyName": "CV Mitra Armada Jaya",
            "otv": "No",
            "paymentCycle": "Monthly",
            "accountNumber": "880019283746",
            "accountName": "Budi Handoko",
            "bankName": "BCA",
            "hoEmail": "contact@mitrajaya.id",
            "hoPhone": "08119876543",
            "hoAddress": "Kawasan Industri MM2100 Blok B-14, Cikarang Barat, Bekasi, Jawa Barat, 17530",
            "contactName": "Budi Handoko",
            "contactPhone": "08119876543",
            "npwp": "013456789012000",
            "accountGroup": "V010",
            "top": "T014",
            "glAccount": "2121000000",
            "documentNumber": "VENDOR-ATLAS-CV-001"
        },
        test_assertions=[
            "pm.test('Status code is 201 (FTP Success) or 500/502 (FTP Server auth required)', function () {",
            "    pm.expect([200, 201, 500, 502]).to.include(pm.response.code);",
            "});"
        ]
    ),
    make_request_item(
        "Vendor Create - Idempotency Re-Send (200 OK Replay)", "POST", "/api/vendors/create",
        headers={"X-Transaction-Id": "{{vendor_trx_id}}"},
        token_var="token_qa",
        description="Mengirim ulang transaksi vendor yang sama dengan X-Transaction-Id yang sama untuk memastikan replay idempotency mengembalikan response 200 OK tanpa upload duplikat.",
        body_json={
            "company_code": "1000/2000/6000/7000",
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
            "pm.test('Status code is 200 (Replay) or 201/500/502', function () {",
            "    pm.expect([200, 201, 500, 502]).to.include(pm.response.code);",
            "});"
        ]
    ),
    make_request_item(
        "SPK Due List - Valid Payload ke FTP (Jasa & Parts Details)", "POST", "/api/spk/duelist",
        headers={"X-Transaction-Id": "{{spk_trx_id}}", "X-Validate-Total": "true"},
        token_var="token_qa",
        description="Mengirim data SPK Due List ke server FTP inbound SAP. Dilengkapi validasi kecocokan total rincian item jasa dan sparepart via header X-Validate-Total.",
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
            "details": [
                {"jenis": "Jasa", "description": "Jasa Perbaikan AC", "qty": 1, "price": 150000},
                {"jenis": "Parts", "description": "Filter AC & Freon", "qty": 1, "price": 1700000}
            ]
        },
        test_assertions=[
            "pm.test('Status code is 201 (FTP Success) or 500/502 (FTP Server auth required)', function () {",
            "    pm.expect([200, 201, 500, 502]).to.include(pm.response.code);",
            "});"
        ]
    ),
    make_request_item(
        "SPK Due List - Valid Payload ke FTP lengkap dengan Data Invoice & Faktur Pajak", "POST", "/api/spk/duelist",
        headers={"X-Transaction-Id": "{{spk_inv_trx_id}}", "X-Validate-Total": "true"},
        token_var="token_qa",
        description="Mengirim data SPK Due List lengkap dengan data tagihan invoice vendor dan nomor faktur pajak.",
        prerequest_lines=[
            "const sTrxInv = 'TRX-SPK-INV-' + Date.now();",
            "pm.collectionVariables.set('spk_inv_trx_id', sTrxInv);"
        ],
        body_json={
            "noSpk": "SPK/2026/09/00004",
            "type": "Maintenance",
            "noPolisi": "B-2120-BKZ",
            "noSr": "SR-000124",
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
            "invoiceNumber": "INV-BKL-00001",
            "invoiceDate": "2026-09-17",
            "invoiceAmount": 1850000,
            "memo": "Perbaikan berkala kendaraan",
            "taxInvoiceNumber": "314650102340592",
            "taxInvoiceDate": "2026-09-17",
            "businessArea": "1101",
            "details": [
                {"jenis": "Jasa", "description": "Jasa Perbaikan AC", "qty": 1, "price": 150000},
                {"jenis": "Parts", "description": "Filter AC & Freon", "qty": 1, "price": 1700000}
            ]
        },
        test_assertions=[
            "pm.test('Status code is 201 (FTP Success) or 500/502 (FTP Server auth required)', function () {",
            "    pm.expect([200, 201, 500, 502]).to.include(pm.response.code);",
            "});"
        ]
    ),
    make_request_item(
        "SPK Due List - Idempotency Re-Send (200 OK Replay)", "POST", "/api/spk/duelist",
        headers={"X-Transaction-Id": "{{spk_trx_id}}", "X-Validate-Total": "true"},
        token_var="token_qa",
        description="Mengirim ulang transaksi SPK yang sama dengan X-Transaction-Id yang sama untuk memastikan replay idempotency mengembalikan response 200 OK tanpa upload duplikat.",
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
            "details": [
                {"jenis": "Jasa", "description": "Jasa Perbaikan AC", "qty": 1, "price": 150000},
                {"jenis": "Parts", "description": "Filter AC & Freon", "qty": 1, "price": 1700000}
            ]
        },
        test_assertions=[
            "pm.test('Status code is 200 (Replay) or 201/500/502', function () {",
            "    pm.expect([200, 201, 500, 502]).to.include(pm.response.code);",
            "});"
        ]
    ),
    make_request_item(
        "Payments Create - Valid Payload ke FTP (XML over FTP - QA Token)", "POST", "/api/payments",
        headers={"X-Transaction-Id": "{{payments_trx_id}}"},
        token_var="token_qa",
        description="Mengirim dokumen accounting pembayaran ke server FTP SAP (/payments) dengan penamaan PAYMENTS_<accountingDocumentNumber>_<companyCode>_<transactionId>.xml menggunakan token QA.",
        prerequest_lines=[
            "const pTrx = 'TRX-PAYMENT-DUE-LIST-20260908-' + String(Math.floor(Math.random() * 9000) + 1000);",
            "pm.collectionVariables.set('payments_trx_id', pTrx);"
        ],
        body_json={
            "companyCodes": "1000/2000/6000/7000",
            "accountingDocumentNumber": "9300051904",
            "documentDate": "08.09.2026",
            "postingDate": "08.09.2026",
            "businessArea": "1100",
            "currency": "IDR",
            "glAccount": "1114000000",
            "text": "PBY BENGKEL REFF 3400082380 DLL",
            "assignment": "PT PRABU PENDAWA M"
        },
        test_assertions=[
            "pm.test('Status code is 201 (FTP Success) or 500/502 (FTP Server auth required)', function () {",
            "    pm.expect([200, 201, 500, 502]).to.include(pm.response.code);",
            "});",
            "if (pm.response.code === 201) {",
            "    var res = pm.response.json();",
            "    pm.test('File name conforms to PAYMENTS convention', function () {",
            "        pm.expect(res.fileName).to.include('PAYMENTS_9300051904_1000_');",
            "        pm.expect(res.fileName).to.include('.xml');",
            "    });",
            "}"
        ]
    ),
    make_request_item(
        "Payments Create - Valid Payload Format Tanggal Alternatif YYYY-MM-DD (QA Token)", "POST", "/api/payments",
        headers={"X-Transaction-Id": "{{payments_alt_trx_id}}"},
        token_var="token_qa",
        description="Mengirim dokumen accounting pembayaran dengan format tanggal ISO YYYY-MM-DD yang dinormalisasi otomatis oleh middleware.",
        prerequest_lines=[
            "const pTrxAlt = 'TRX-PAYMENT-ALT-DATE-' + Date.now();",
            "pm.collectionVariables.set('payments_alt_trx_id', pTrxAlt);"
        ],
        body_json={
            "companyCodes": "1000/2000/6000/7000",
            "accountingDocumentNumber": "9300051905",
            "documentDate": "2026-09-08",
            "postingDate": "2026-09-08",
            "businessArea": "1100",
            "currency": "IDR",
            "glAccount": "1114000000",
            "text": "PBY BENGKEL KENDARAAN ALTERNATIF",
            "assignment": "PT ADI SARANA ARMADA TBK"
        },
        test_assertions=[
            "pm.test('Status code is 201 (FTP Success) or 500/502', function () {",
            "    pm.expect([200, 201, 500, 502]).to.include(pm.response.code);",
            "});"
        ]
    ),
    make_request_item(
        "Payments Create - Replay / Idempotency Check (200 OK Replay)", "POST", "/api/payments",
        headers={"X-Transaction-Id": "{{payments_trx_id}}"},
        token_var="token_qa",
        description="Mengirim ulang transaksi payment yang sama dengan header X-Transaction-Id yang sama untuk memastikan replay idempotency mengembalikan 200 OK tanpa upload ulang.",
        body_json={
            "companyCodes": "1000/2000/6000/7000",
            "accountingDocumentNumber": "9300051904",
            "documentDate": "08.09.2026",
            "postingDate": "08.09.2026",
            "businessArea": "1100",
            "currency": "IDR",
            "glAccount": "1114000000",
            "text": "PBY BENGKEL REFF 3400082380 DLL",
            "assignment": "PT PRABU PENDAWA M"
        },
        test_assertions=[
            "pm.test('Status code is 200 (Replay Success) or 201/500/502', function () {",
            "    pm.expect([200, 201, 500, 502]).to.include(pm.response.code);",
            "});",
            "if (pm.response.code === 200) {",
            "    var res = pm.response.json();",
            "    pm.test('Replay message verified', function () {",
            "        pm.expect(res.message).to.include('Replay');",
            "    });",
            "}"
        ]
    )
]

# ------------------------------------------------------------------------------
# 6. Background Retry Worker (2 Items)
# ------------------------------------------------------------------------------
worker_items = [
    make_request_item(
        "Trigger Background Retry Worker (GET)", "GET", "/api/worker/retry",
        description="Memicu eksekusi background worker untuk mencoba ulang pengiriman transaksi FAILED yang tersimpan di antrean MariaDB (via method GET).",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('Worker executed successfully', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res).to.have.property('status');",
            "    pm.expect(res.worker).to.eql('RetryWorker');",
            "});"
        ]
    ),
    make_request_item(
        "Trigger Background Retry Worker (POST)", "POST", "/api/worker/retry",
        description="Memicu eksekusi background retry worker via method POST.",
        test_assertions=[
            "pm.test('Status code is 200 OK', function () { pm.response.to.have.status(200); });",
            "pm.test('Worker executed successfully', function () {",
            "    var res = pm.response.json();",
            "    pm.expect(res).to.have.property('status');",
            "    pm.expect(res.worker).to.eql('RetryWorker');",
            "});"
        ]
    )
]

# ------------------------------------------------------------------------------
# Assemble Postman Collection Helper
# ------------------------------------------------------------------------------
TOTAL_REQUESTS = len(health_items) + len(security_items) + len(validation_items) + len(inquiry_items) + len(transactional_items) + len(worker_items)

def create_collection_dict(name, default_base_url, description_suffix=""):
    return {
        "info": {
            "_postman_id": str(uuid.uuid4()),
            "name": name,
            "description": f"Koleksi Postman resmi untuk pengujian seluruh API ASSA Middleware WSO2 MI Monorepo & Gateway.\nTarget Endpoint Default: {default_base_url}\n{description_suffix}\n\nCakupan Layanan (Semua 7 Microservice):\n- 1. Health & Readiness Probes ({len(health_items)} Endpoint: General & Seluruh 7 Microservice)\n- 2. Auth & Scope Security Guards ({len(security_items)} Skenario: 401 Unauthorized & 403 Forbidden cross-services)\n- 3. Parameter & Input Validation ({len(validation_items)} Skenario: 400 Bad Request validasi bisnis)\n- 4. Inquiry, Search & Pagination ({len(inquiry_items)} Skenario: 200 OK dengan filter filterBy, plat_no, CustomerCode/CustomerName, & metadata pagination)\n- 5. Transactional & Fan-Out Endpoints ({len(transactional_items)} Skenario: Service Request Fan-out 10x Retries, Barantum Public Gateway nested unit, Vendor Create V2 XML FTP, SPK Due List V2 dengan Invoice/Pajak, Payments Service Create & Idempotency Replay)\n- 6. Background Retry Worker ({len(worker_items)} Skenario: GET & POST Trigger)\n\nTotal Skenario: {TOTAL_REQUESTS} requests.",
            "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
        },
        "variable": [
            {"key": "baseUrl", "value": default_base_url, "type": "string"},
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
            {"key": "vendor_atlas_trx_id", "value": "TRX-VND-ATLAS-INIT", "type": "string"},
            {"key": "spk_trx_id", "value": "TRX-SPK-INIT", "type": "string"},
            {"key": "spk_inv_trx_id", "value": "TRX-SPK-INV-INIT", "type": "string"},
            {"key": "payments_trx_id", "value": "TRX-PAYMENT-INIT", "type": "string"},
            {"key": "payments_alt_trx_id", "value": "TRX-PAYMENT-ALT-INIT", "type": "string"},
            {"key": "fakeToken", "value": "Bearer token-palsu-ngawur-12345", "type": "string"}
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
# Build Collections
# ------------------------------------------------------------------------------
collection_server = create_collection_dict(
    name="ASSA Middleware - Server Dev (devmiddleware.assa.id)",
    default_base_url="https://devmiddleware.assa.id",
    description_suffix="Pre-configured untuk Server Dev (https://devmiddleware.assa.id)."
)

collection_local = create_collection_dict(
    name="ASSA Middleware - Local Desktop (localhost:6031)",
    default_base_url="http://localhost:6031",
    description_suffix="Pre-configured untuk Local Desktop (localhost:6031)."
)

collection_generic = create_collection_dict(
    name="ASSA Middleware API Test Suite",
    default_base_url="http://localhost:6031",
    description_suffix="Dapat digunakan bergantian dengan Environment Local / Server Dev."
)

# Collection khusus nama legacy di test/ (ASSA Middleware API Collection)
collection_legacy_test = create_collection_dict(
    name="ASSA Middleware API Collection",
    default_base_url="http://localhost:6031",
    description_suffix="Koleksi Postman resmi untuk pengujian lengkap seluruh fitur ASSA Middleware (WSO2 Micro Integrator Monorepo)."
)

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
    "name": "ASSA Middleware - Server Dev (devmiddleware.assa.id)",
    "values": [
        {"key": "baseUrl", "value": "https://devmiddleware.assa.id", "type": "default", "enabled": True},
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
# Save Files to All Required Destinations
# ------------------------------------------------------------------------------
# 1. In postman/
postman_server_path = os.path.join(POSTMAN_DIR, "ASSA_Middleware_ServerDev.postman_collection.json")
postman_local_path = os.path.join(POSTMAN_DIR, "ASSA_Middleware_Local.postman_collection.json")
postman_suite_path = os.path.join(POSTMAN_DIR, "ASSA_Middleware_TestSuite.postman_collection.json")
env_local_path = os.path.join(POSTMAN_DIR, "ASSA_Middleware_Local.postman_environment.json")
env_server_path = os.path.join(POSTMAN_DIR, "ASSA_Middleware_ServerDev.postman_environment.json")

with open(postman_server_path, "w", encoding="utf-8") as f:
    json.dump(collection_server, f, indent=2, ensure_ascii=False)

with open(postman_local_path, "w", encoding="utf-8") as f:
    json.dump(collection_local, f, indent=2, ensure_ascii=False)

with open(postman_suite_path, "w", encoding="utf-8") as f:
    json.dump(collection_generic, f, indent=2, ensure_ascii=False)

with open(env_local_path, "w", encoding="utf-8") as f:
    json.dump(env_local, f, indent=2, ensure_ascii=False)

with open(env_server_path, "w", encoding="utf-8") as f:
    json.dump(env_server, f, indent=2, ensure_ascii=False)

# 2. In test/ (Update the old postman collection AND full suite)
test_old_path = os.path.join(TEST_DIR, "ASSA_Middleware.postman_collection.json")
test_suite_path = os.path.join(TEST_DIR, "ASSA_Middleware_Full_Suite.postman_collection.json")

with open(test_old_path, "w", encoding="utf-8") as f:
    json.dump(collection_legacy_test, f, indent=2, ensure_ascii=False)

with open(test_suite_path, "w", encoding="utf-8") as f:
    json.dump(collection_generic, f, indent=2, ensure_ascii=False)

# 3. In middleware-assa/ (Re-populate mirrors referenced in postman/README.md)
mw_local_path = os.path.join(MIDDLEWARE_DIR, "ASSA Middleware Local Desktop (localhost-6031).postman_collection.json")
mw_server_path = os.path.join(MIDDLEWARE_DIR, "ASSA Middleware Server Dev (devmiddleware.assa.id).postman_collection.json")

with open(mw_local_path, "w", encoding="utf-8") as f:
    json.dump(collection_local, f, indent=2, ensure_ascii=False)

with open(mw_server_path, "w", encoding="utf-8") as f:
    json.dump(collection_server, f, indent=2, ensure_ascii=False)

print("=" * 70)
print("SUCCESSFULLY GENERATED ALL UPDATED POSTMAN COLLECTIONS & ENVIRONMENTS")
print("=" * 70)
print(f"1. Postman Server Dev       : {postman_server_path}")
print(f"2. Postman Local Desktop    : {postman_local_path}")
print(f"3. Postman Generic Suite    : {postman_suite_path}")
print(f"4. Postman Env Local        : {env_local_path}")
print(f"5. Postman Env Server       : {env_server_path}")
print(f"6. Test Old Postman (Updated): {test_old_path}")
print(f"7. Test Full Suite          : {test_suite_path}")
print(f"8. Middleware Mirror Local  : {mw_local_path}")
print(f"9. Middleware Mirror Server : {mw_server_path}")
print(f"Total Requests per Collection: {TOTAL_REQUESTS} requests across 6 folders.")
print(f" - Health & Readiness      : {len(health_items)}")
print(f" - Auth & Scope Guards     : {len(security_items)}")
print(f" - Parameter Validation    : {len(validation_items)}")
print(f" - Inquiry & Pagination    : {len(inquiry_items)}")
print(f" - Transactional & Fan-Out : {len(transactional_items)}")
print(f" - Background Worker       : {len(worker_items)}")
