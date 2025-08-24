param(
  [string]$Prompt = "",
  [switch]$LoginOnly,
  [int]$TimeoutSec = 180
)
$ErrorActionPreference = "Stop"

# Find projektrod og venv-python
$ROOT = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$pyCandidates = @(
  (Join-Path $ROOT ".venv\Scripts\python.exe"),
  (Join-Path $PWD  ".venv\Scripts\python.exe"),
  "python"
)
$python = $pyCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $python) { throw "Python ikke fundet. Opret .venv eller installer Python 3.x." }

# Sørg for Playwright i samme Python
try { & $python -m pip show playwright 2>$null | Out-Null } catch {}
if ($LASTEXITCODE -ne 0) {
  Write-Host "[SETUP] Installerer Playwright i venv…"
  & $python -m pip install playwright | Out-Null
}

Write-Host "[SETUP] Sikrer chromium driver…"
& $python -m playwright install chromium | Out-Null

# Kør automations-scriptet
$pyScript = Join-Path $PSScriptRoot "chatgpt_web.py"
$argsList = @("--root",$ROOT,"--timeout",$TimeoutSec)
if ($LoginOnly) { $argsList += @("--login-only") }
if ($Prompt)    { $argsList += @("--prompt",$Prompt) }

$reply = & $python $pyScript @argsList
$reply
