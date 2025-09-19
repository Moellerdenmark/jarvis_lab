$ErrorActionPreference = "SilentlyContinue"

# Autodetect Ollama (11435 -> 11434)
$ports = 11435,11434
$base  = $null
foreach ($p in $ports) {
  try {
    $u = "http://127.0.0.1:$p/api/tags"
    $null = Invoke-RestMethod -Uri $u -Method GET -TimeoutSec 2
    $base = "http://127.0.0.1:$p"
    break
  } catch {}
}

if (-not $base) {
  Write-Host "== OLLAMA ==" -Fore Cyan
  Write-Host "Kunne ikke nå Ollama på 11435/11434. Start 'ollama serve'." -Fore Red
  Write-Host 'PROVE: FAIL'
  exit 1
}

$env:OLLAMA_HOST      = $base
$env:OLLAMA_BASE_URL  = $base
$env:OLLAMA_API_BASE  = $base
$env:OLLAMA_KEEP_ALIVE = "5m"

Push-Location (Resolve-Path ..\jarvis_core)
try {
  $out = powershell -NoProfile -ExecutionPolicy Bypass -File .\core-e2e-smoke.ps1 2>&1
  $out | Out-Host
  if ($LASTEXITCODE -eq 0 -or $out -match 'ALLE KONTROLLER') {
    Write-Host 'PROVE: OK'
    exit 0
  } else {
    Write-Host 'PROVE: FAIL'
    exit 1
  }
} finally {
  Pop-Location
}
