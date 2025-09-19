$ErrorActionPreference = "Stop"

function Test-Ollama([string]$Url = "http://localhost:11434") {
  try {
    Invoke-WebRequest -Uri "$Url/api/tags" -UseBasicParsing -TimeoutSec 2 | Out-Null
    return $true
  } catch { return $false }
}

function Get-PortOwner([int]$Port) {
  # 1) Brug Get-NetTCPConnection hvis muligt
  if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
    $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($conn) {
      $pid = $conn.OwningProcess
      $p = Get-Process -Id $pid -ErrorAction SilentlyContinue
      return [PSCustomObject]@{
        ProcId = $pid
        Image  = if ($p) { $p.ProcessName + ".exe" } else { "<ukendt>" }
        Line   = "LISTEN :$Port (Get-NetTCPConnection)"
      }
    }
  }

  # 2) Fallback: netstat + findstr
  $lines = netstat -aon | findstr /R /C:":$Port .*LISTEN" 2>$null
  if (-not $lines) { return $null }

  # Vælg første match og parse PID (sidste kolonne)
  $first = ($lines | Select-Object -First 1).ToString().Trim()
  $parts = ($first -split "\s+") | Where-Object { $_ -ne "" }
  $pid = $parts[-1]
  $name = try { (tasklist /FI "PID eq $pid" /FO CSV | ConvertFrom-Csv)[0].ImageName } catch { "<ukendt>" }
  return [PSCustomObject]@{ ProcId = [int]$pid; Image = $name; Line = $first }
}

# 0) Allerede oppe?
if (Test-Ollama) {
  Write-Host "[Ollama] Allerede klar på :11434" -ForegroundColor Green
  return
}

# 1) Port-check
$owner = Get-PortOwner 11434
if ($owner) {
  Write-Host "[PORT] 11434 er optaget af $($owner.Image) (PID $($owner.ProcId))" -ForegroundColor Yellow
  Write-Host "       $($owner.Line)"
  throw "Stop processen eller ændr porten – ellers kan Ollama ikke starte."
}

# 2) Prøv lokal ollama.exe
$exe = "$env:ProgramFiles\Ollama\ollama.exe"
if (-not (Test-Path $exe)) { $exe = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe" }

if (Test-Path $exe) {
  Write-Host "[Ollama] Starter lokal ollama.exe serve..." -ForegroundColor Cyan
  try { Start-Process -WindowStyle Hidden -FilePath $exe -ArgumentList "serve" } catch {}
} else {
  Write-Host "[Ollama] Fandt ikke ollama.exe — prøver Docker fallback." -ForegroundColor Yellow
}

# 3) Vent op til ~16s på API
for ($i=0; $i -lt 20 -and -not (Test-Ollama); $i++) { Start-Sleep -Milliseconds 800 }
if (Test-Ollama) { Write-Host "[Ollama] OK – API svarer på :11434." -ForegroundColor Green; return }

# 4) Docker fallback
Write-Host "[Ollama] Starter Docker fallback..." -ForegroundColor Cyan
docker rm -f ollama 2>$null | Out-Null
docker run -d --name ollama -p 11434:11434 -v ollama:/root/.ollama ollama/ollama:latest | Out-Null

for ($i=0; $i -lt 20 -and -not (Test-Ollama); $i++) { Start-Sleep -Milliseconds 800 }
if (Test-Ollama) {
  Write-Host "[Ollama] OK – Docker API svarer på :11434." -ForegroundColor Green
} else {
  throw "Ollama kunne ikke startes (hverken exe eller Docker). Tjek firewall/AV eller start app’en manuelt."
}

