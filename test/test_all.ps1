# ==============================================================================
# ASSA MIDDLEWARE — MASTER TEST RUNNER (ALL-IN-ONE)
# Menjalankan seluruh rangkaian tes:
# 1. Fungsional API & Auth Guard (11 Test)
# 2. Resiliency, 3x Retry, Idempotency & MariaDB (5 Test)
# 3. Vendor Create XML & Delivery ke FTP SAP (4 Test)
# 4. Service Request Paralel Fan-Out ke External Services & ATLAS (6 Test)
# ==============================================================================

Write-Host "====================================================================" -ForegroundColor Magenta
Write-Host "       ASSA MIDDLEWARE — MASTER TEST SUITE (ALL SUITES RUNNER)      " -ForegroundColor Magenta
Write-Host "====================================================================" -ForegroundColor Magenta

$rootPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

# 1. Functional Tests
Write-Host "`n>>> [SUITE 1/4] MENJALANKAN PENGUJIAN FUNGSIONAL API & AUTH GUARD..." -ForegroundColor Cyan
powershell -ExecutionPolicy Bypass -File "$rootPath\run_manual_tests.ps1"

# 2. Resiliency & Retry Tests
Write-Host "`n>>> [SUITE 2/4] MENJALANKAN PENGUJIAN RESILIENCY, 3X RETRY & MARIADB..." -ForegroundColor Cyan
powershell -ExecutionPolicy Bypass -File "$rootPath\run_resiliency_tests.ps1"

# 3. Vendor Create FTP Tests
Write-Host "`n>>> [SUITE 3/4] MENJALANKAN PENGUJIAN VENDOR CREATE XML & FTP..." -ForegroundColor Cyan
powershell -ExecutionPolicy Bypass -File "$rootPath\test_vendor_create.ps1"

# 4. Service Request Fan-Out Tests
Write-Host "`n>>> [SUITE 4/4] MENJALANKAN PENGUJIAN SERVICE REQUEST FAN-OUT PARALEL..." -ForegroundColor Cyan
powershell -ExecutionPolicy Bypass -File "$rootPath\test_service_request.ps1"

Write-Host "`n====================================================================" -ForegroundColor Magenta
Write-Host "       SELURUH 4 SUITE PENGUJIAN ASSA MIDDLEWARE SELESAI!          " -ForegroundColor Magenta
Write-Host "====================================================================" -ForegroundColor Magenta
