$headers = @{
    "Authorization" = "Bearer ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d"
    "Content-Type" = "application/json"
    "X-Transaction-Id" = "TRX-MANUAL-20260917114529"
    "X-Forwarded-For" = "10.20.30.40"
}

$body = @{
    Vendor_ID = "82165871"
    Company_Code = "1000"
    Company_Name = "PT Adi Sarana Armada Tbk"
    Vendor_Type = "New/Extend"
    Account_Number = "1200010978489"
    Account_Name = "Robby Yulianto Setiawan"
    Bank_Name = "Mandiri"
    HO_Email = "assa@assarent.co.id"
    HO_Phone = "082246605199"
    HO_Address = "Jalan Nusa Indah 2 Block C.ext 8 no 7, Duri Kosambi, Jakarta Barat, DKI Jakarta, 11410"
    Contact_Name = "Robby Contact"
    Contact_Phone = "08224660189"
    NPWP = "3173080209920003"
    TOP = "T014"
    Account_Group = "V010"
    GL_Account = "2121000000"
    DocumentNumber = "VENDOR-ATLAS-000123"
} | ConvertTo-Json

try {
    $response = Invoke-WebRequest -Uri "http://localhost:8290/api/vendors/create" -Method Post -Headers $headers -Body $body -UseBasicParsing
    Write-Host "STATUS CODE:" $response.StatusCode -ForegroundColor Green
    Write-Host "X-Idempotent-Replay:" $response.Headers["X-Idempotent-Replay"] -ForegroundColor Cyan
    Write-Host "CONTENT:" $response.Content -ForegroundColor Yellow
} catch {
    Write-Host "ERROR:" $_.Exception.Message -ForegroundColor Red
}
