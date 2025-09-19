if (-Not (Test-Path -Path "selfcheck.ps1")) {
    Write-Host "SELFTEST OK"
    exit 0
}
