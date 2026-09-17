$headers = @{
    "Authorization" = "Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d"
    "Content-Type" = "application/json"
    "X-Transaction-Id" = "TRX-MANUAL-" + (Get-Date -Format "yyyyMMddHHmmss")
    "X-Forwarded-For" = "10.20.30.40"
}

$body = @{
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

try {
    $response = Invoke-RestMethod -Uri "http://localhost:8290/api/vendors/create" -Method Post -Headers $headers -Body $body
    Write-Host "RESPONSE RECEIVED SUCCESSFULLY:" -ForegroundColor Green
    $response | Format-List
} catch {
    Write-Host "ERROR:" -ForegroundColor Red
    $_.Exception.Message
    if ($_.Exception.Response) {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        Write-Host "BODY:" $reader.ReadToEnd()
    }
}
