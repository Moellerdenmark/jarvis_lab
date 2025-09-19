param(
  [string]$Model = "llama3.2:3b"  # hurtig og fin til CPU
)

$ErrorActionPreference = "Stop"

# 1) Sørg for UTF-8 i konsol og Python
chcp 65001 > $null
$env:PYTHONIOENCODING = "utf-8"

# 2) Tjek at Ollama kører (på 11434)
$busy = (netstat -ano | Select-String ":11434\s+LISTENING") -ne $null
if (-not $busy) {
  Start-Process -WindowStyle Minimized "ollama.exe" -ArgumentList "serve" | Out-Null
  Start-Sleep 2
}

# 3) Tjek at modellen findes
try {
  $tags = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 5
  $has = $tags.models | Where-Object { $_.name -eq $Model }
  if (-not $has) { & ollama pull $Model }
} catch {
  Write-Host "Kunne ikke tale med Ollama. Er den installeret?" -ForegroundColor Yellow
}

# 4) Start loopet
& (Join-Path $PSScriptRoot "jarvis_loop.ps1") -Model $Model
