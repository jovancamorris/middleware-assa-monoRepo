$headers = @{
    "Authorization" = "Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d"
    "Content-Type" = "application/json"
    "X-Transaction-Id" = "TRX-MANUAL-20260917114529"
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
    $response = Invoke-WebRequest -Uri "http://localhost:8290/api/vendors/create" -Method Post -Headers $headers -Body $body -UseBasicParsing
    Write-Host "STATUS CODE:" $response.StatusCode -ForegroundColor Green
    Write-Host "X-Idempotent-Replay:" $response.Headers["X-Idempotent-Replay"] -ForegroundColor Cyan
    Write-Host "CONTENT:" $response.Content -ForegroundColor Yellow
} catch {
    Write-Host "ERROR:" $_.Exception.Message -ForegroundColor Red
}
