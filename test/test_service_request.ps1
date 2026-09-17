# ==============================================================================
# Script Otomatisasi Pengujian: Service Request (SR) Parallel Fan-Out
# Endpoint: POST http://localhost:8290/api/service-requests
# Referensi: notes/GUIDE_SR.md
# ==============================================================================

Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host " MEMULAI PENGUJIAN FITUR SERVICE REQUEST (SR) PARALEL FAN-OUT" -ForegroundColor Cyan
Write-Host "====================================================================" -ForegroundColor Cyan

$baseUrl = "http://localhost:8290/api/service-requests"
$omnichannelToken = "token-assa-omnichannel-secret-99999"
$appBToken = "token-assa-app-b-secret-67890"

# ------------------------------------------------------------------------------
# Test 1: 401 Unauthorized (Tanpa Token)
# ------------------------------------------------------------------------------
Write-Host "`n[TEST 1] Uji 401 Unauthorized (Tanpa Token Bearer)..." -ForegroundColor Yellow
$res1 = curl.exe -s -w "`nHTTP_CODE:%{http_code}" -X POST $baseUrl -H "Content-Type: application/json" -d "{}"
Write-Host $res1
if ($res1 -match "HTTP_CODE:401") {
    Write-Host "--> TEST 1: BERHASIL (401 Unauthorized)" -ForegroundColor Green
} else {
    Write-Host "--> TEST 1: GAGAL" -ForegroundColor Red
}

# ------------------------------------------------------------------------------
# Test 2: 403 Forbidden (Token App B tanpa scope service_requests)
# ------------------------------------------------------------------------------
Write-Host "`n[TEST 2] Uji 403 Forbidden (App B token, scope tidak cocok)..." -ForegroundColor Yellow
$res2 = curl.exe -s -w "`nHTTP_CODE:%{http_code}" -X POST $baseUrl -H "Authorization: Bearer $appBToken" -H "Content-Type: application/json" -d "{}"
Write-Host $res2
if ($res2 -match "HTTP_CODE:403") {
    Write-Host "--> TEST 2: BERHASIL (403 Forbidden)" -ForegroundColor Green
} else {
    Write-Host "--> TEST 2: GAGAL" -ForegroundColor Red
}

# ------------------------------------------------------------------------------
# Test 3: 400 Bad Request (Field Wajib app_id Kosong)
# ------------------------------------------------------------------------------
Write-Host "`n[TEST 3] Uji 400 Bad Request (Field wajib app_id tidak diisi)..." -ForegroundColor Yellow
$res3 = curl.exe -s -w "`nHTTP_CODE:%{http_code}" -X POST $baseUrl -H "Authorization: Bearer $omnichannelToken" -H "Content-Type: application/json" --data '{\"reff_number\":\"REF001\",\"branch_code\":\"JKT01\",\"created_datetime\":\"17-09-2026\",\"created_by\":\"admin\",\"ticket_no\":\"TCK01\"}'
Write-Host $res3
if ($res3 -match "HTTP_CODE:400" -and $res3 -match "app_id") {
    Write-Host "--> TEST 3: BERHASIL (400 Bad Request Validasi Field)" -ForegroundColor Green
} else {
    Write-Host "--> TEST 3: GAGAL" -ForegroundColor Red
}

# ------------------------------------------------------------------------------
# Test 4: 200 OK Happy Path (Fan-out Paralel ke Target 1 & Target 2)
# ------------------------------------------------------------------------------
Write-Host "`n[TEST 4] Uji 200 OK Happy Path (Fan-out Paralel)..." -ForegroundColor Yellow
$uniqueTrx = "TRX-SR-" + (Get-Date -Format "yyyyMMddHHmmss")
$res4 = curl.exe -s -w "`nHTTP_CODE:%{http_code}" -X POST $baseUrl -H "Authorization: Bearer $omnichannelToken" -H "Content-Type: application/json" -H "X-Transaction-Id: $uniqueTrx" --data-binary "@test/payload_sr_test.json"
Write-Host $res4
if ($res4 -match "HTTP_CODE:200" -and $res4 -match "extService" -and $res4 -match "SUCCESS") {
    Write-Host "--> TEST 4: BERHASIL (200 OK Fan-out Berhasil)" -ForegroundColor Green
} else {
    Write-Host "--> TEST 4: GAGAL" -ForegroundColor Red
}

# ------------------------------------------------------------------------------
# Test 5: Idempotency Replay (Kirim Ulang Transaction ID yang Sama)
# ------------------------------------------------------------------------------
Write-Host "`n[TEST 5] Uji Idempotency Replay (Replay Transaction ID: $uniqueTrx)..." -ForegroundColor Yellow
$res5 = curl.exe -i -s -X POST $baseUrl -H "Authorization: Bearer $omnichannelToken" -H "Content-Type: application/json" -H "X-Transaction-Id: $uniqueTrx" --data-binary "@test/payload_sr_test.json"
Write-Host $res5
if ($res5 -match "X-Idempotent-Replay: true" -and $res5 -match "200 OK") {
    Write-Host "--> TEST 5: BERHASIL (Idempotency Replay Cache Terverifikasi)" -ForegroundColor Green
} else {
    Write-Host "--> TEST 5: GAGAL" -ForegroundColor Red
}

# ------------------------------------------------------------------------------
# Test 6: Audit Log MariaDB
# ------------------------------------------------------------------------------
Write-Host "`n[TEST 6] Verifikasi Audit Database (MariaDB)..." -ForegroundColor Yellow
docker exec middleware-assa-mariadb mysql -u root -e "USE assa_middleware_db; SELECT transaction_id, status, attempt_count FROM api_transaction WHERE transaction_id = '$uniqueTrx'; SELECT transaction_id, attempt_number, endpoint, response_status, duration_ms FROM api_transaction_log WHERE transaction_id = '$uniqueTrx';"

Write-Host "`n====================================================================" -ForegroundColor Cyan
Write-Host " SELURUH RANGKAIAN PENGUJIAN SERVICE REQUEST TELAH SELESAI!" -ForegroundColor Cyan
Write-Host "====================================================================" -ForegroundColor Cyan
