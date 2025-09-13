param([string]$RepoRoot)
$ErrorActionPreference = "Stop"
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path }

# Load local config (optional)
$cfgPath = Join-Path $RepoRoot "tools\local.config.psd1"
$cfg = @{}
if (Test-Path $cfgPath) { $cfg = Import-PowerShellDataFile $cfgPath }

$NasRoot  = $cfg.NasRoot
$useNas   = [bool]$cfg.UseNas
$journal  = [bool]$cfg.Journal

# Gather run info
$runId   = Get-Date -Format "yyyyMMdd_HHmmss"
$branch  = (& git -C $RepoRoot rev-parse --abbrev-ref HEAD 2>$null).Trim()
$head    = (& git -C $RepoRoot rev-parse HEAD 2>$null).Trim()
$lastLog = Get-ChildItem (Join-Path $RepoRoot "logs") -Filter "orchestrator_*.txt" -File |
           Sort-Object LastWriteTime -desc | Select-Object -First 1

# Prepare local artifacts snapshot
$locArt = Join-Path $RepoRoot "artifacts\$runId"
New-Item -ItemType Directory -Force $locArt | Out-Null
Copy-Item -Force (Join-Path $RepoRoot "README.md") $locArt -ErrorAction SilentlyContinue
if ($lastLog) { Copy-Item -Force $lastLog.FullName $locArt }
$tasks = Join-Path $RepoRoot "ai_tasks"
if (Test-Path $tasks) { Copy-Item -Recurse -Force $tasks $locArt\ai_tasks -ErrorAction SilentlyContinue }

Write-Host "Post-run: local snapshot -> $locArt"

# Mirror to NAS (optional)
if ($useNas -and $NasRoot -and (Test-Path $NasRoot)) {
  $nasRun = Join-Path $NasRoot ("lab\runs\" + $runId)
  New-Item -ItemType Directory -Force $nasRun | Out-Null
  Copy-Item -Recurse -Force $locArt\* $nasRun
  Write-Host "Post-run: NAS sync -> $nasRun"
} else {
  if ($useNas) { Write-Host "Post-run: NAS not reachable or NasRoot unset" -ForegroundColor Yellow }
}

# Learning journal (CSV på NAS)
if ($journal -and $NasRoot -and (Test-Path $NasRoot)) {
  $csv = Join-Path $NasRoot "journal\learning.csv"
  New-Item -ItemType Directory -Force (Split-Path $csv) | Out-Null
  if (-not (Test-Path $csv)) { "runId,branch,head,timestamp" | Out-File -Encoding UTF8 $csv }
  "$runId,$branch,$head,$([DateTime]::UtcNow.ToString('s'))Z" | Add-Content -Encoding UTF8 $csv
  Write-Host "Post-run: journal appended"
}

# (Senere) Device registry (read-only for now)
if ($cfg.RegistryFile -and (Test-Path $cfg.RegistryFile)) {
  try {
    $devs = Get-Content $cfg.RegistryFile -Raw | ConvertFrom-Json
    $count = @($devs).Count
    Write-Host "Registry: $count device(s) registered (read-only now)."
  } catch { Write-Host "Registry read failed: $($_.Exception.Message)" -ForegroundColor Yellow }
}

Write-Host "Post-run: OK"
