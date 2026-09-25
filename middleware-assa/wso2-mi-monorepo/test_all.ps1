# ==============================================================================
# ASSA Middleware - Automated Manual Test Runner (PowerShell)
# Menjalankan seluruh skenario pengujian API pada satu WSO2 MI runtime
# ==============================================================================

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "     ASSA MIDDLEWARE - AUTOMATED TEST SUITE" -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan

# Load .env file if present
$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envFile)) {
    $envFile = ".env"
}
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $parts = $line.Split("=", 2)
            $k = $parts[0].Trim()
            $v = $parts[1].Trim().Trim('"').Trim("'")
            [System.Environment]::SetEnvironmentVariable($k, $v, "Process")
        }
    }
}

$baseUrl = if ($env:BASE_URL) { $env:BASE_URL } else { "http://localhost:8290" }
$baseUrlCustomer = if ($env:BASE_URL1) { $env:BASE_URL1 } else { "http://localhost:8291" }
$baseUrlVehicle = if ($env:BASE_URL2) { $env:BASE_URL2 } else { "http://localhost:8292" }
$baseUrlVendor = if ($env:BASE_URL3) { $env:BASE_URL3 } else { "http://localhost:8293" }
$baseUrlSpk = if ($env:BASE_URL4) { $env:BASE_URL4 } else { "http://localhost:8294" }
$baseUrlServiceRequest = if ($env:BASE_URL5) { $env:BASE_URL5 } else { "http://localhost:8295" }
$baseUrl = $baseUrl.TrimEnd('/')
$baseUrlCustomer = $baseUrlCustomer.TrimEnd('/')
$baseUrlVehicle = $baseUrlVehicle.TrimEnd('/')
$baseUrlVendor = $baseUrlVendor.TrimEnd('/')
$baseUrlSpk = $baseUrlSpk.TrimEnd('/')
$baseUrlServiceRequest = $baseUrlServiceRequest.TrimEnd('/')
$baseUri = [System.Uri]$baseUrl
$baseHost = $baseUri.Host
$basePort = if ($baseUri.Port -gt 0) {
    $baseUri.Port
} elseif ($baseUri.Scheme -eq "https") {
    443
} else {
    80
}
$tokenAppA = if ($env:AUTH_APP_A_TOKEN) { $env:AUTH_APP_A_TOKEN } 
$tokenAppB = if ($env:AUTH_APP_B_TOKEN) { $env:AUTH_APP_B_TOKEN } 
$tokenQA   = if ($env:AUTH_APP_QA_TOKEN) { $env:AUTH_APP_QA_TOKEN } 
$tokenOmnichannel = if ($env:AUTH_APP_OMNICHANNEL_TOKEN) { $env:AUTH_APP_OMNICHANNEL_TOKEN } 


# 1. Cek Koneksi Server
Write-Host "[1/10] Memeriksa apakah WSO2 MI aktif di $baseHost`:$basePort..." -NoNewline
try {
    $conn = Test-NetConnection -ComputerName $baseHost -Port $basePort -InformationLevel Quiet -WarningAction SilentlyContinue
    if (-not $conn) {
        Write-Host " GAGAL!" -ForegroundColor Red
        Write-Host "Server WSO2 MI belum aktif di $baseHost`:$basePort." -ForegroundColor Yellow
        Write-Host "Silakan jalankan server terlebih dahulu di terminal:" -ForegroundColor Yellow
        Write-Host '`$env:JAVA_HOME = "C:\Users\eksad\tools\jdk-21.0.3+9"' -ForegroundColor White
        Write-Host '& "C:\Users\eksad\.wso2-mi\micro-integrator\wso2mi-4.6.0\bin\micro-integrator.bat"`n' -ForegroundColor White
        exit 1
    }
    Write-Host " TERHUBUNG (OK)" -ForegroundColor Green
} catch {
    Write-Host " ERROR: $_" -ForegroundColor Red
    exit 1
}

function Run-Test {
    param(
        [string]$TestNumber,
        [string]$TestName,
        [string]$Url,
        [string]$Token = "",
        [string]$Method = "GET",
        [string]$Body = "",
        [hashtable]$ExtraHeaders = @{},
        [int]$ExpectedStatus = 200
    )

    Write-Host "`n--------------------------------------------------------" -ForegroundColor Gray
    Write-Host "[$TestNumber] $TestName" -ForegroundColor Yellow
    Write-Host "URL: $Url" -ForegroundColor Gray
    Write-Host "Method: $Method" -ForegroundColor Gray

    $headers = @{
        "X-Retry-Interval-Seconds" = "1"
    }
    if ($Token -ne "") {
        $headers["Authorization"] = "Bearer $Token"
        Write-Host "Auth: Bearer $Token" -ForegroundColor Gray
    } else {
        Write-Host "Auth: (Tanpa Token)" -ForegroundColor Gray
    }

    foreach ($key in $ExtraHeaders.Keys) {
        $headers[$key] = $ExtraHeaders[$key]
    }

    if ($Body -ne "") {
        $headers["Content-Type"] = "application/json"
    }

    try {
        if ($Body -ne "") {
            $response = Invoke-WebRequest -Uri $Url -Headers $headers -Method $Method -Body $Body -UseBasicParsing -ErrorAction Stop
        } else {
            $response = Invoke-WebRequest -Uri $Url -Headers $headers -Method $Method -UseBasicParsing -ErrorAction Stop
        }
        $statusCode = $response.StatusCode
        $content = $response.Content
    } catch {
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $content = $reader.ReadToEnd()
        } else {
            Write-Host "Status: KONEKSI GAGAL ($($_.Exception.Message))" -ForegroundColor Red
            return
        }
    }

    Write-Host "HTTP Status: $statusCode (Ekspektasi: $ExpectedStatus)" -NoNewline
    if ($statusCode -eq $ExpectedStatus) {
        Write-Host " -> LULUS (PASS)" -ForegroundColor Green
    } else {
        Write-Host " -> GAGAL (FAIL)" -ForegroundColor Red
    }

    Write-Host "Response Body:" -ForegroundColor DarkGray
    Write-Host $content -ForegroundColor White
}

function Get-ResponseItemCount {
    param([string]$Content)

    try {
        $json = $Content | ConvertFrom-Json
    } catch {
        return -1
    }

    if ($json -is [System.Array]) {
        return @($json).Count
    }
    if ($null -ne $json.data -and $json.data -is [System.Collections.IEnumerable] -and $json.data -isnot [string]) {
        return @($json.data).Count
    }
    if ($null -ne $json.values -and $json.values -is [System.Collections.IEnumerable] -and $json.values -isnot [string]) {
        return @($json.values).Count
    }

    return -1
}

function Get-ResponseHash {
    param([string]$Content)

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
        return ([System.BitConverter]::ToString($sha256.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha256.Dispose()
    }
}

function Get-ResponsePaginationMetadata {
    param([string]$Content)

    try {
        $json = $Content | ConvertFrom-Json
    } catch {
        return [pscustomobject]@{
            Count = -1
            Total = -1
            Page = -1
            PerPage = -1
        }
    }

    $total = if ($null -ne $json.total) { [int]$json.total } else { -1 }
    $page = if ($null -ne $json.page) { [int]$json.page } else { -1 }
    $perPage = if ($null -ne $json.perPage) { [int]$json.perPage } else { -1 }

    return [pscustomobject]@{
        Count = Get-ResponseItemCount -Content $Content
        Total = $total
        Page = $page
        PerPage = $perPage
    }
}

function Invoke-PaginationRequest {
    param(
        [string]$Url,
        [string]$Token
    )

    $headers = @{
        "Authorization" = "Bearer $Token"
        "X-Retry-Interval-Seconds" = "1"
    }

    try {
        $response = Invoke-WebRequest -Uri $Url -Headers $headers -Method GET -UseBasicParsing -ErrorAction Stop
        return [pscustomobject]@{
            StatusCode = [int]$response.StatusCode
            Content = $response.Content
        }
    } catch {
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            try {
                $content = $reader.ReadToEnd()
            } finally {
                $reader.Dispose()
            }
            return [pscustomobject]@{
                StatusCode = $statusCode
                Content = $content
            }
        }

        return [pscustomobject]@{
            StatusCode = 0
            Content = "Connection failed: $($_.Exception.Message)"
        }
    }
}

function Run-Pagination-Test {
    param(
        [string]$TestNumber,
        [string]$TestName,
        [string]$BaseUrl,
        [string]$Token,
        [string]$Path
    )

    $pageOne = Invoke-PaginationRequest -Url "$BaseUrl$Path&page=1&perPage=1" -Token $Token
    $pageTwo = Invoke-PaginationRequest -Url "$BaseUrl$Path&page=2&perPage=1" -Token $Token
    $pageTen = Invoke-PaginationRequest -Url "$BaseUrl$Path&page=1&perPage=10" -Token $Token

    $pageOneCount = Get-ResponseItemCount -Content $pageOne.Content
    $pageTwoCount = Get-ResponseItemCount -Content $pageTwo.Content
    $pageTenCount = Get-ResponseItemCount -Content $pageTen.Content
    $pageOneMeta = Get-ResponsePaginationMetadata -Content $pageOne.Content
    $pageTwoMeta = Get-ResponsePaginationMetadata -Content $pageTwo.Content
    $pageTenMeta = Get-ResponsePaginationMetadata -Content $pageTen.Content
    $pageOneHash = Get-ResponseHash -Content $pageOne.Content
    $pageTwoHash = Get-ResponseHash -Content $pageTwo.Content

    $statusOk = $pageOne.StatusCode -eq 200 -and $pageTwo.StatusCode -eq 200 -and $pageTen.StatusCode -eq 200
    $metadataOk = $pageOneMeta.Page -eq 1 -and $pageOneMeta.PerPage -eq 1 -and $pageTwoMeta.Page -eq 2 -and $pageTwoMeta.PerPage -eq 1 -and $pageTenMeta.Page -eq 1 -and $pageTenMeta.PerPage -eq 10
    $sizeOk = $pageOneCount -ge 0 -and $pageOneCount -le 1 -and $pageTenCount -ge $pageOneCount
    $emptyResult = $pageOneMeta.Total -eq 0 -and $pageTwoMeta.Total -eq 0 -and $pageTenMeta.Total -eq 0
    $pageChanged = $pageOneHash -ne $pageTwoHash

    Write-Host "`n--------------------------------------------------------" -ForegroundColor Gray
    Write-Host "[$TestNumber] $TestName" -ForegroundColor Yellow
    Write-Host "Page 1/perPage 1: HTTP $($pageOne.StatusCode), items $pageOneCount" -ForegroundColor Gray
    Write-Host "Page 2/perPage 1: HTTP $($pageTwo.StatusCode), items $pageTwoCount" -ForegroundColor Gray
    Write-Host "Page 1/perPage 10: HTTP $($pageTen.StatusCode), items $pageTenCount" -ForegroundColor Gray

    if (-not $statusOk) {
        Write-Host " -> GAGAL (pagination request returned a non-200 status)" -ForegroundColor Red
    } elseif (-not $metadataOk) {
        Write-Host " -> GAGAL (response metadata page/perPage tidak sesuai)" -ForegroundColor Red
    } elseif (-not $sizeOk -or (-not $emptyResult -and -not $pageChanged)) {
        Write-Host " -> GAGAL (page/perPage tidak mengubah hasil sesuai ekspektasi)" -ForegroundColor Red
    } else {
        Write-Host " -> LULUS (PASS)" -ForegroundColor Green
    }
}

# Run All Tests
Run-Test -TestNumber "HEALTH 1" -TestName "Branch Health Check (Liveness)" -Url "$baseUrl/health/branch" -ExpectedStatus 200
Run-Test -TestNumber "HEALTH 2" -TestName "Branch Readiness Check" -Url "$baseUrl/readiness/branch" -ExpectedStatus 200
Run-Test -TestNumber "HEALTH 3" -TestName "Customer Health Check (Liveness)" -Url "$baseUrlCustomer/health/customer" -ExpectedStatus 200
Run-Test -TestNumber "HEALTH 4" -TestName "Customer Readiness Check" -Url "$baseUrlCustomer/readiness/customer" -ExpectedStatus 200
Run-Test -TestNumber "HEALTH 5" -TestName "Vehicle Health Check (Liveness)" -Url "$baseUrlVehicle/health/vehicle" -ExpectedStatus 200
Run-Test -TestNumber "HEALTH 6" -TestName "Vehicle Readiness Check" -Url "$baseUrlVehicle/readiness/vehicle" -ExpectedStatus 200
Run-Test -TestNumber "HEALTH 7" -TestName "Vendor Health Check (Liveness)" -Url "$baseUrlVendor/health/vendor" -ExpectedStatus 200
Run-Test -TestNumber "HEALTH 8" -TestName "Vendor Readiness Check" -Url "$baseUrlVendor/readiness/vendor" -ExpectedStatus 200
Run-Test -TestNumber "HEALTH 9" -TestName "SPK Health Check (Liveness)" -Url "$baseUrlSpk/health/spk" -ExpectedStatus 200
Run-Test -TestNumber "HEALTH 10" -TestName "SPK Readiness Check" -Url "$baseUrlSpk/readiness/spk" -ExpectedStatus 200
Run-Test -TestNumber "HEALTH 11" -TestName "Service Request Health Check (Liveness)" -Url "$baseUrlServiceRequest/health/service-request" -ExpectedStatus 200
Run-Test -TestNumber "HEALTH 12" -TestName "Service Request Readiness Check" -Url "$baseUrlServiceRequest/readiness/service-request" -ExpectedStatus 200
Run-Test -TestNumber "TEST 3" -TestName "Auth Guard: Tanpa Token (Harus 401)" -Url "$baseUrl/api/branches/getByCreateDate?companyCode=1000" -ExpectedStatus 401
Run-Test -TestNumber "TEST 4" -TestName "Auth Guard: Token Palsu (Harus 401)" -Url "$baseUrl/api/branches/getByCreateDate?companyCode=1000" -Token "token-palsu-ngawur" -ExpectedStatus 401
Run-Test -TestNumber "TEST 5" -TestName "Scope Guard: App B panggil Branch (Harus 403)" -Url "$baseUrl/api/branches/getByCreateDate?companyCode=1000" -Token $tokenAppB -ExpectedStatus 403
Run-Test -TestNumber "TEST 6" -TestName "Scope Guard: App B panggil Customer (Harus 403)" -Url "$baseUrlCustomer/api/customers/getByCreateDate?companyCode=1000" -Token $tokenAppB -ExpectedStatus 403
Run-Test -TestNumber "TEST 7" -TestName "Validasi Parameter: Vehicle tanpa parameter pencarian (Harus 400)" -Url "$baseUrlVehicle/api/vehicles/getByLicensePlate?companyCode=1000" -Token $tokenAppB -ExpectedStatus 400
Run-Test -TestNumber "TEST 8" -TestName "Vehicle Service Atlas /getByLicensePlate (App B Token, plate_no)" -Url "$baseUrlVehicle/api/vehicles/getByLicensePlate?plate_no=DD-8112" -Token $tokenAppB -ExpectedStatus 200
Run-Test -TestNumber "TEST 9" -TestName "Vehicle Service Atlas /vehicleatlas (QA Token, plate_no)" -Url "$baseUrlVehicle/api/vehicles/vehicleatlas?plate_no=DD-8112" -Token $tokenQA -ExpectedStatus 200
Run-Test -TestNumber "TEST 10" -TestName "Customer Service (App A Token)" -Url "$baseUrlCustomer/api/customers/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11&page=1&perPage=10" -Token $tokenAppA -ExpectedStatus 200
Run-Test -TestNumber "TEST 11" -TestName "Branch Service (App A Token)" -Url "$baseUrl/api/branches/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11&page=1&perPage=10" -Token $tokenAppA -ExpectedStatus 200
Run-Pagination-Test -TestNumber "PAGINATION 1" -TestName "Customer pagination (page/perPage)" -BaseUrl $baseUrlCustomer -Token $tokenAppA -Path "/api/customers/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11"
Run-Pagination-Test -TestNumber "PAGINATION 2" -TestName "Branch pagination (page/perPage)" -BaseUrl $baseUrl -Token $tokenAppA -Path "/api/branches/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11"

# Vendor Create Tests (GUIDE_VENDOR_CREATE_XML_FTP_V2.md)
Run-Test -TestNumber "TEST 12" -TestName "Vendor Create: Tanpa Token (Harus 401)" -Url "$baseUrlVendor/api/vendors/create" -Method "POST" -Body "{}" -ExpectedStatus 401
Run-Test -TestNumber "TEST 13" -TestName "Vendor Create: App B Token tanpa scope 'vendors' (Harus 403)" -Url "$baseUrlVendor/api/vendors/create" -Method "POST" -Token $tokenAppB -Body "{}" -ExpectedStatus 403

$invalidVendorJson = '{"companyTitle":"INVALID","companyName":"PT Test","otv":"No","paymentCycle":"Monthly","accountNumber":"123","accountName":"Test","bankName":"BCA","hoEmail":"test@assa.id","hoPhone":"08123","hoAddress":"Jakarta","npwp":"12345","accountGroup":"V010","top":"T014","glAccount":"2121000000","documentNumber":"DOC-01"}'
Run-Test -TestNumber "TEST 14" -TestName "Vendor Create: Validasi Gagal companyTitle invalid (Harus 400)" -Url "$baseUrlVendor/api/vendors/create" -Method "POST" -Token $tokenQA -Body $invalidVendorJson -ExpectedStatus 400

$uniqueTrxId = "TRX-SUITE-" + (Get-Date -Format "yyyyMMddHHmmss")
$validVendorJson = @{
    companyTitle = "PT"
    companyName = "PT Adi Sarana Armada Tbk"
    otv = "No"
    paymentCycle = "Monthly"
    accountNumber = "1200010978489"
    accountName = "Robby Yulianto Setiawan"
    bankName = "Mandiri"
    hoEmail = "assa@assarent.co.id"
    hoPhone = "082246605199"
    hoAddress = "Jalan Nusa Indah 2 Block C.ext 8 no 7, Duri Kosambi, Jakarta Barat, DKI Jakarta, 11410"
    contactName = "Robby Contact"
    contactPhone = "08224660189"
    npwp = "3173080209920003"
    accountGroup = "V010"
    top = "T014"
    glAccount = "2121000000"
    documentNumber = "VENDOR-ATLAS-000123"
} | ConvertTo-Json

Run-Test -TestNumber "TEST 15" -TestName "Vendor Create: Valid Payload ke FTP devqaxmlpool.assa.id (Harus 201)" -Url "$baseUrlVendor/api/vendors/create" -Method "POST" -Token $tokenQA -Body $validVendorJson -ExtraHeaders @{ "X-Transaction-Id" = $uniqueTrxId } -ExpectedStatus 201

Run-Test -TestNumber "TEST 16" -TestName "Vendor Create: Idempotency Replay (Harus 200 replay)" -Url "$baseUrlVendor/api/vendors/create" -Method "POST" -Token $tokenQA -Body $validVendorJson -ExtraHeaders @{ "X-Transaction-Id" = $uniqueTrxId } -ExpectedStatus 200

# SPK Duelist Tests (GUIDE_SPK_DUELIST_XML_FTP_V2.md)
Run-Test -TestNumber "TEST 17" -TestName "SPK Duelist: Tanpa Token (Harus 401)" -Url "$baseUrlSpk/api/spk/duelist" -Method "POST" -Body "{}" -ExpectedStatus 401
Run-Test -TestNumber "TEST 18" -TestName "SPK Duelist: App B tanpa scope 'spk' (Harus 403)" -Url "$baseUrlSpk/api/spk/duelist" -Method "POST" -Token $tokenAppB -Body "{}" -ExpectedStatus 403

$invalidSpkJson = @{
    type = "Maintenance"
    noPolisi = "B-2120-BKZ"
    category = "Maintenance"
    subCategory = "Adhoc"
    vendorReferensi = "0001"
    totalPrice = 1850000
    createdAt = "2026-09-17 14:46:11"
    createdBy = "atlas.user"
    details = @(
        @{ jenis = "Jasa"; description = "Jasa Perbaikan AC"; qty = 1; price = 1850000 }
    )
} | ConvertTo-Json -Depth 10
Run-Test -TestNumber "TEST 19" -TestName "SPK Duelist: Validasi noSpk wajib (Harus 400)" -Url "$baseUrlSpk/api/spk/duelist" -Method "POST" -Token $tokenQA -Body $invalidSpkJson -ExpectedStatus 400

$invalidTotalSpkJson = @{
    noSpk = "SPK/2026/09/00002"
    type = "Maintenance"
    noPolisi = "B-2120-BKZ"
    category = "Maintenance"
    subCategory = "Adhoc"
    vendorReferensi = "0001"
    totalPrice = 1850001
    createdAt = "2026-09-17 14:46:11"
    createdBy = "atlas.user"
    details = @(
        @{ jenis = "Jasa"; description = "Jasa Perbaikan AC"; qty = 1; price = 1850000 }
    )
} | ConvertTo-Json -Depth 10
Run-Test -TestNumber "TEST 20" -TestName "SPK Duelist: Total validation via X-Validate-Total (Harus 400)" -Url "$baseUrlSpk/api/spk/duelist" -Method "POST" -Token $tokenQA -Body $invalidTotalSpkJson -ExtraHeaders @{ "X-Validate-Total" = "true" } -ExpectedStatus 400

$spkTrxId = "SPK-SUITE-" + (Get-Date -Format "yyyyMMddHHmmss")
$validSpkJson = @{
    noSpk = "SPK/2026/09/00003"
    type = "Maintenance"
    noPolisi = "B-2120-BKZ"
    noSr = "SR-000123"
    category = "Maintenance"
    subCategory = "Adhoc"
    vendorReferensi = "0001"
    namaVendor = "Bengkel Jaya Motor"
    picService = "PIC-001"
    namaPicService = "Andi Wijaya"
    spkRework = "No"
    totalPrice = 1850000
    createdAt = "2026-09-17 14:46:11"
    createdBy = "atlas.user"
    poSpkNumber = "PO-4500012345"
    invoiceNumber = "INV_BKL_00001"
    invoiceDate = "2026-09-17"
    invoiceAmount = 1850000
    memo = "Perbaikan kendaraan"
    taxInvoiceNumber = "314650102340592"
    taxInvoiceDate = "2026-09-17"
    businessArea = "1101"
    details = @(
        @{ jenis = "Jasa"; description = "Jasa Perbaikan AC"; qty = 1; price = 150000 }
        @{ jenis = "Parts"; description = "Filter AC"; qty = 1; price = 1700000 }
    )
} | ConvertTo-Json -Depth 10
Run-Test -TestNumber "TEST 21" -TestName "SPK Duelist: Valid Payload + Total Validation ke FTP (Harus 201)" -Url "$baseUrlSpk/api/spk/duelist" -Method "POST" -Token $tokenQA -Body $validSpkJson -ExtraHeaders @{ "X-Transaction-Id" = $spkTrxId; "X-Forwarded-For" = "10.20.30.40"; "X-Validate-Total" = "true" } -ExpectedStatus 201
Run-Test -TestNumber "TEST 22" -TestName "SPK Duelist: Idempotency Replay (Harus 200 replay)" -Url "$baseUrlSpk/api/spk/duelist" -Method "POST" -Token $tokenQA -Body $validSpkJson -ExtraHeaders @{ "X-Transaction-Id" = $spkTrxId; "X-Forwarded-For" = "10.20.30.40"; "X-Validate-Total" = "true" } -ExpectedStatus 200

# Service Request (SR) Tests (GUIDE_SR.md)
Run-Test -TestNumber "TEST 23" -TestName "Service Request: Tanpa Token (Harus 401)" -Url "$baseUrlServiceRequest/api/service-requests" -Method "POST" -Body "{}" -ExpectedStatus 401
Run-Test -TestNumber "TEST 24" -TestName "Service Request: App B tanpa scope 'service_requests' (Harus 403)" -Url "$baseUrlServiceRequest/api/service-requests" -Method "POST" -Token $tokenAppB -Body "{}" -ExpectedStatus 403

$invalidSrJson = @{
    reff_number = "REF01"
    branch_code = "JKT01"
    created_datetime = "17-09-2026"
    created_by = "admin"
    ticket_no = "TCK01"
} | ConvertTo-Json
Run-Test -TestNumber "TEST 25" -TestName "Service Request: Validasi app_id wajib (Harus 400)" -Url "$baseUrlServiceRequest/api/service-requests" -Method "POST" -Token $tokenOmnichannel -Body $invalidSrJson -ExpectedStatus 400

$srTrxId = "TRX-SR-SUITE-" + (Get-Date -Format "yyyyMMddHHmmss")
$validSrJson = @{
    app_id = "sr_app_omnichannel"
    reff_number = "REF-SR-20260917-001"
    branch_code = "JKT01"
    equipment_number = "EQ-998877"
    license_plate = "B-1234-SSA"
    customer_code = "CUST-00123"
    customer_name = "PT Maju Bersama ASSA"
    channel = "Omnichannel-Web"
    cp_title = "Bpk"
    cp_name = "Ahmad Fauzi"
    cp_phone = "081234567890"
    cp_email = "ahmad.fauzi@example.com"
    cp_address = "Jl. Gatot Subroto No. 45 Jakarta"
    km = "25000"
    description = "Perawatan berkala 25.000 KM dan pengecekan rem"
    service_datetime = "2026-09-20 10:00:00"
    service_location = "Bengkel Resmi ASSA Sunter"
    jenis_permintaan = "Service Berkala"
    incident_datetime = "2026-09-17 09:00:00"
    tipe_tiket = "Regular"
    judul = "Service Berkala Kendaraan Operasional"
    nama_kunjungan = "Ahmad Fauzi"
    telepon_kunjungan = "081234567890"
    alamat_kunjungan = "Jl. Danau Sunter Barat Blok A"
    pool_name = "Pool Sunter"
    area_bengkel = "Jakarta Utara"
    task = "Ganti Oli Mesin dan Filter Oli"
    created_datetime = "17-09-2026"
    created_by = "omnichannel_agent"
    ticket_no = "TICKET-SR-99901"
} | ConvertTo-Json

Run-Test -TestNumber "TEST 26" -TestName "Service Request: Valid Fan-out Paralel (Harus 200)" -Url "$baseUrlServiceRequest/api/service-requests" -Method "POST" -Token $tokenOmnichannel -Body $validSrJson -ExtraHeaders @{ "X-Transaction-Id" = $srTrxId } -ExpectedStatus 200
Run-Test -TestNumber "TEST 27" -TestName "Service Request: Idempotency Replay (Harus 200 replay)" -Url "$baseUrlServiceRequest/api/service-requests" -Method "POST" -Token $tokenOmnichannel -Body $validSrJson -ExtraHeaders @{ "X-Transaction-Id" = $srTrxId } -ExpectedStatus 200

# Background Worker Tests (GUIDE / Retry Worker)
Run-Test -TestNumber "TEST 28" -TestName "Background Worker: Manual Trigger Retry Worker (Harus 200)" -Url "$baseUrlServiceRequest/api/worker/retry" -Method "GET" -ExpectedStatus 200

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "     SELURUH PENGUJIAN SELESAI (40 SKENARIO)!" -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan
