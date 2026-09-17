# ==============================================================================
# Script Pengujian Otomatis / Manual Test Runner — ASSA Middleware
# Lokasi: notes/test/run_manual_tests.ps1
# ==============================================================================

param (
    [string]$BaseUrl = "http://localhost:8290"
)

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  ASSA MIDDLEWARE MANUAL TEST RUNNER (WSO2 Micro Integrator)" -ForegroundColor Cyan
Write-Host "  Target Host: $BaseUrl" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

$PassedCount = 0
$FailedCount = 0

function Test-Endpoint {
    param (
        [string]$TestId,
        [string]$Description,
        [string]$Method = "GET",
        [string]$Path,
        [hashtable]$Headers = @{},
        [int]$ExpectedStatus
    )

    $Url = "$BaseUrl$Path"
    Write-Host "[$TestId] $Description" -ForegroundColor Yellow
    Write-Host "  $Method $Url" -ForegroundColor Gray

    try {
        $Response = Invoke-WebRequest -Uri $Url -Method $Method -Headers $Headers -UseBasicParsing -ErrorAction SilentlyContinue
        $StatusCode = $Response.StatusCode
        $Body = $Response.Content
        $CorrId = $Response.Headers["X-Correlation-Id"]
    } catch {
        $StatusCode = $_.Exception.Response.StatusCode.value__
        if (-not $StatusCode -and $_.Exception.Response) {
            $StatusCode = [int]$_.Exception.Response.StatusCode
        }
        if (-not $StatusCode) {
            $StatusCode = 0
        }
        $Reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $Body = $Reader.ReadToEnd()
        $CorrId = $_.Exception.Response.Headers["X-Correlation-Id"]
    }

    if ($StatusCode -eq $ExpectedStatus) {
        Write-Host "  Status: $StatusCode (Expected $ExpectedStatus) -> [PASSED]" -ForegroundColor Green
        if ($CorrId) {
            Write-Host "  X-Correlation-Id: $CorrId" -ForegroundColor DarkGray
        }
        if ($Body) {
            $TruncatedBody = if ($Body.Length -gt 250) { $Body.Substring(0, 250) + "... (truncated)" } else { $Body }
            Write-Host "  Response: $TruncatedBody" -ForegroundColor DarkGray
        }
        $script:PassedCount++
    } else {
        Write-Host "  Status: $StatusCode (Expected $ExpectedStatus) -> [FAILED]" -ForegroundColor Red
        if ($Body) {
            Write-Host "  Response: $Body" -ForegroundColor Red
        }
        $script:FailedCount++
    }
    Write-Host ""
}

# ------------------------------------------------------------------------------
# 1. Health Checks
# ------------------------------------------------------------------------------
Test-Endpoint -TestId "TC-01" -Description "Liveness Probe" `
    -Path "/health" -ExpectedStatus 200

Test-Endpoint -TestId "TC-02" -Description "Readiness Probe" `
    -Path "/health/ready" -ExpectedStatus 200

# ------------------------------------------------------------------------------
# 2. Security & Auth Guard
# ------------------------------------------------------------------------------
Test-Endpoint -TestId "TC-03" -Description "Auth Guard: Akses tanpa token (Expect 401)" `
    -Path "/api/branches/getByCreateDate" -ExpectedStatus 401

Test-Endpoint -TestId "TC-04" -Description "Auth Guard: Akses token palsu (Expect 401)" `
    -Path "/api/branches/getByCreateDate" `
    -Headers @{ "Authorization" = "Bearer token-palsu-12345" } `
    -ExpectedStatus 401

Test-Endpoint -TestId "TC-05" -Description "Auth Guard: Scope tidak berhak (app_b ke branches - Expect 403)" `
    -Path "/api/branches/getByCreateDate" `
    -Headers @{ "Authorization" = "Bearer token-assa-app-b-secret-67890" } `
    -ExpectedStatus 403

# ------------------------------------------------------------------------------
# 3. Domain Branches
# ------------------------------------------------------------------------------
Test-Endpoint -TestId "TC-06" -Description "Branch: Parameter lengkap dengan token app_a (Expect 200)" `
    -Path "/api/branches/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11" `
    -Headers @{ "Authorization" = "Bearer token-assa-app-a-secret-12345" } `
    -ExpectedStatus 200

Test-Endpoint -TestId "TC-07" -Description "Branch: Parameter default fallback (Expect 200)" `
    -Path "/api/branches/getByCreateDate" `
    -Headers @{ "Authorization" = "Bearer token-assa-app-a-secret-12345" } `
    -ExpectedStatus 200

# ------------------------------------------------------------------------------
# 4. Domain Customers
# ------------------------------------------------------------------------------
Test-Endpoint -TestId "TC-08" -Description "Customer: Get by Create Date dengan token app_a (Expect 200)" `
    -Path "/api/customers/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11" `
    -Headers @{ "Authorization" = "Bearer token-assa-app-a-secret-12345" } `
    -ExpectedStatus 200

# ------------------------------------------------------------------------------
# 5. Domain Vehicles
# ------------------------------------------------------------------------------
Test-Endpoint -TestId "TC-09" -Description "Vehicle: Tanpa plat nomor (Expect 400)" `
    -Path "/api/vehicles/getByLicensePlate?companyCode=1000" `
    -Headers @{ "Authorization" = "Bearer token-assa-app-b-secret-67890" } `
    -ExpectedStatus 400

Test-Endpoint -TestId "TC-10" -Description "Vehicle: Plat nomor valid DD-8112 Vehicle Atlas (Expect 200)" `
    -Path "/api/vehicles/vehicleatlas?plate_no=DD-8112" `
    -Headers @{ "Authorization" = "Bearer token-assa-app-b-secret-67890" } `
    -ExpectedStatus 200

# ------------------------------------------------------------------------------
# 6. Observability & Tracing
# ------------------------------------------------------------------------------
Test-Endpoint -TestId "TC-11" -Description "Tracing: Custom Correlation ID echo (Expect 200)" `
    -Path "/api/branches/getByCreateDate" `
    -Headers @{ 
        "Authorization" = "Bearer token-assa-app-a-secret-12345"
        "X-Correlation-Id" = "CUSTOM-TRACE-AUDIT-9999"
    } `
    -ExpectedStatus 200

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  HASIL PENGUJIAN: $PassedCount PASSED, $FailedCount FAILED" -ForegroundColor $(if ($FailedCount -eq 0) { "Green" } else { "Red" })
Write-Host "=================================================================" -ForegroundColor Cyan
