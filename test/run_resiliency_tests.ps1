# ==============================================================================
# Script Pengujian Otomatis Fitur Resiliency, Retry, Idempotency & MariaDB
# ASSA Middleware (WSO2 Micro Integrator)
# ==============================================================================

param (
    [string]$BaseUrl = "http://localhost:8290",
    [string]$MariaDbPath = "C:\Users\eksad\Downloads\assa\mariadb\bin\mariadb.exe",
    [int]$MariaDbPort = 3307
)

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  ASSA MIDDLEWARE RESILIENCY & RETRY TEST RUNNER" -ForegroundColor Cyan
Write-Host "  Target Host : $BaseUrl" -ForegroundColor Cyan
Write-Host "  MariaDB Port: $MariaDbPort" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

$PassedCount = 0
$FailedCount = 0

function Query-MariaDB {
    param ([string]$Sql)
    if (Test-Path $MariaDbPath) {
        try {
            $Result = & $MariaDbPath -P $MariaDbPort -u root -e "USE assa_middleware_db; $Sql"
            if ($Result) { return $Result }
        } catch {}
    }
    # Fallback to docker container
    try {
        $Result = docker exec middleware-assa-mariadb mysql -u root -e "USE assa_middleware_db; $Sql" 2>$null
        return $Result
    } catch {
        return ""
    }
}

# ------------------------------------------------------------------------------
# Test 1: Health Check
# ------------------------------------------------------------------------------
Write-Host "[TEST 1] Health Check Liveness Probe" -ForegroundColor Yellow
try {
    $Resp = Invoke-RestMethod -Uri "$BaseUrl/health" -Method GET -ErrorAction Stop
    if ($Resp.status -eq "UP") {
        Write-Host "  Status: 200 (UP) -> [PASSED]" -ForegroundColor Green
        $PassedCount++
    } else {
        Write-Host "  Status Unexpected: $($Resp.status) -> [FAILED]" -ForegroundColor Red
        $FailedCount++
    }
} catch {
    Write-Host "  Health check failed: $($_.Exception.Message) -> [FAILED]" -ForegroundColor Red
    $FailedCount++
}
Write-Host ""

# ------------------------------------------------------------------------------
# Test 2: Success Call, DB Transaction & Attempt Log
# ------------------------------------------------------------------------------
$TrxSuccess = "TRX-SUCCESS-" + (Get-Date -Format "yyyyMMddHHmmss")
Write-Host "[TEST 2] Successful External API Call with Idempotency Key ($TrxSuccess)" -ForegroundColor Yellow

try {
    $Headers = @{
        "Authorization" = "Bearer token-assa-app-a-secret-12345"
        "X-Transaction-Id" = $TrxSuccess
    }
    $Resp = Invoke-WebRequest -Uri "$BaseUrl/api/vehicles/vehicleatlas?plate_no=DD-8112" -Headers $Headers -UseBasicParsing -ErrorAction Stop
    $StatusCode = $Resp.StatusCode
    $Body = $Resp.Content
    $TrxHeader = $Resp.Headers["X-Transaction-Id"]

    Write-Host "  HTTP Status: $StatusCode | X-Transaction-Id: $TrxHeader" -ForegroundColor Gray
    
    # Verify in MariaDB
    $TrxRow = Query-MariaDB "SELECT transaction_id, status, attempt_count FROM api_transaction WHERE transaction_id = '$TrxSuccess';"
    $LogRow = Query-MariaDB "SELECT transaction_id, attempt_number, response_status, error_message FROM api_transaction_log WHERE transaction_id = '$TrxSuccess';"

    Write-Host "  [MariaDB api_transaction]:" -ForegroundColor DarkCyan
    Write-Host $TrxRow -ForegroundColor DarkGray
    Write-Host "  [MariaDB api_transaction_log]:" -ForegroundColor DarkCyan
    Write-Host $LogRow -ForegroundColor DarkGray

    if ($StatusCode -eq 200 -and $TrxRow -match "SUCCESS" -and $LogRow -match "200") {
        Write-Host "  Transaksi tersimpan SUCCESS & attempt_log tercatat 200 OK -> [PASSED]" -ForegroundColor Green
        $PassedCount++
    } else {
        Write-Host "  Verifikasi database tidak sesuai -> [FAILED]" -ForegroundColor Red
        $FailedCount++
    }
} catch {
    Write-Host "  Test 2 failed: $($_.Exception.Message) -> [FAILED]" -ForegroundColor Red
    $FailedCount++
}
Write-Host ""

# ------------------------------------------------------------------------------
# Test 3: Idempotency Check (Duplicate Transaction / Order #123 created lagi)
# ------------------------------------------------------------------------------
Write-Host "[TEST 3] Idempotency Check - Duplicate Transaction ID ($TrxSuccess)" -ForegroundColor Yellow

try {
    $Headers = @{
        "Authorization" = "Bearer token-assa-app-a-secret-12345"
        "X-Transaction-Id" = $TrxSuccess
    }
    $Resp = Invoke-WebRequest -Uri "$BaseUrl/api/vehicles/vehicleatlas?plate_no=DD-8112" -Headers $Headers -UseBasicParsing -ErrorAction Stop
    $StatusCode = $Resp.StatusCode
    $IdempotentHeader = $Resp.Headers["X-Idempotent-Replay"]

    Write-Host "  HTTP Status: $StatusCode | X-Idempotent-Replay: $IdempotentHeader" -ForegroundColor Gray
    
    # Verify attempt log count in DB (should STILL be 1 attempt, NOT re-executed)
    $AttemptCount = Query-MariaDB "SELECT COUNT(*) FROM api_transaction_log WHERE transaction_id = '$TrxSuccess';"
    Write-Host "  Jumlah attempt log di database (harus tetap 1):" -ForegroundColor DarkCyan
    Write-Host $AttemptCount -ForegroundColor DarkGray

    if ($StatusCode -eq 200 -and $IdempotentHeader -eq "true" -and $AttemptCount -match "1") {
        Write-Host "  Idempotency bekerja! Request duplikat dijawab langsung dari cache tanpa memanggil backend -> [PASSED]" -ForegroundColor Green
        $PassedCount++
    } else {
        Write-Host "  Idempotency replay gagal -> [FAILED]" -ForegroundColor Red
        $FailedCount++
    }
} catch {
    Write-Host "  Test 3 failed: $($_.Exception.Message) -> [FAILED]" -ForegroundColor Red
    $FailedCount++
}
Write-Host ""

# ------------------------------------------------------------------------------
# Test 4: Failure, 3x Retry Loop with Interval & Database Logging
# ------------------------------------------------------------------------------
$TrxFail = "TRX-FAIL-" + (Get-Date -Format "yyyyMMddHHmmss")
Write-Host "[TEST 4] 3x Retry Loop on Failed Backend Call ($TrxFail)" -ForegroundColor Yellow
Write-Host "  Mengirim request ke backend down dengan interval 1 detik (X-Retry-Interval-Seconds: 1)..." -ForegroundColor Gray

$StartTime = Get-Date
try {
    $Headers = @{
        "Authorization" = "Bearer token-assa-app-a-secret-12345"
        "X-Transaction-Id" = $TrxFail
        "X-Retry-Interval-Seconds" = "1"
        "X-Target-Backend-Url" = "http://127.0.0.1:59999"
    }
    $Resp = Invoke-WebRequest -Uri "$BaseUrl/api/branches/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11" -Headers $Headers -UseBasicParsing -ErrorAction Stop
    $StatusCode = $Resp.StatusCode
} catch {
    $StatusCode = $_.Exception.Response.StatusCode.value__
    if (-not $StatusCode -and $_.Exception.Response) {
        $StatusCode = [int]$_.Exception.Response.StatusCode
    }
    $Reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    $ErrorBody = $Reader.ReadToEnd()
}
$EndTime = Get-Date
$TotalSeconds = ($EndTime - $StartTime).TotalSeconds

Write-Host "  Final HTTP Status: $StatusCode | Total Waktu Eksekusi: $([math]::Round($TotalSeconds, 2)) detik" -ForegroundColor Gray
Write-Host "  Response Error: $ErrorBody" -ForegroundColor DarkGray

# Verify in MariaDB
$TrxFailRow = Query-MariaDB "SELECT transaction_id, status, attempt_count, next_retry_at FROM api_transaction WHERE transaction_id = '$TrxFail';"
$LogFailRows = Query-MariaDB "SELECT attempt_number, response_status, error_message, duration_ms FROM api_transaction_log WHERE transaction_id = '$TrxFail' ORDER BY attempt_number ASC;"

Write-Host "  [MariaDB api_transaction]:" -ForegroundColor DarkCyan
Write-Host $TrxFailRow -ForegroundColor DarkGray
Write-Host "  [MariaDB api_transaction_log (3 Percobaan)]: " -ForegroundColor DarkCyan
Write-Host $LogFailRows -ForegroundColor DarkGray

if ($TrxFailRow -match "FAILED" -and $TrxFailRow -match "3" -and $LogFailRows -match "1" -and $LogFailRows -match "2" -and $LogFailRows -match "3") {
    Write-Host "  Percobaan gagal 3x tercatat lengkap di api_transaction_log dan status akhir FAILED -> [PASSED]" -ForegroundColor Green
    $PassedCount++
} else {
    Write-Host "  Verifikasi retry log gagal -> [FAILED]" -ForegroundColor Red
    $FailedCount++
}
Write-Host ""

# ------------------------------------------------------------------------------
# Test 5: Asynchronous Background Worker Trigger (/api/worker/retry)
# ------------------------------------------------------------------------------
Write-Host "[TEST 5] Trigger Asynchronous Background Worker (/api/worker/retry)" -ForegroundColor Yellow

try {
    $Resp = Invoke-RestMethod -Uri "$BaseUrl/api/worker/retry" -Method POST -ErrorAction Stop
    Write-Host "  Worker Response: $($Resp | ConvertTo-Json -Compress)" -ForegroundColor Gray

    if ($Resp.status -eq "COMPLETED") {
        Write-Host "  Background worker triggered and processed retry queue successfully -> [PASSED]" -ForegroundColor Green
        $PassedCount++
    } else {
        Write-Host "  Worker response unexpected -> [FAILED]" -ForegroundColor Red
        $FailedCount++
    }
} catch {
    Write-Host "  Worker trigger failed: $($_.Exception.Message) -> [FAILED]" -ForegroundColor Red
    $FailedCount++
}
Write-Host ""

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  HASIL AKHIR: $PassedCount PASSED, $FailedCount FAILED" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
