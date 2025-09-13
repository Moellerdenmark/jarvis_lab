# --- WORKDIR BOOTSTRAP ---
try {
  if ($PSScriptRoot) { Set-Location (Join-Path $PSScriptRoot "..") }
  elseif ($PSCommandPath) { Set-Location (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) }
  else {
    $dir = (Get-Location).Path
    while ($dir -and -not (Test-Path (Join-Path $dir ".git"))) { $dir = Split-Path -Parent $dir }
    if ($dir) { Set-Location $dir }
  }
} catch {}
# --- END WORKDIR BOOTSTRAP ---

$ErrorActionPreference = "Stop"

# Lockfile (hindrer overlappende run)
$LockPath = ".\.autopilot.lock"
$LockMaxAgeMinutes = 60
if (Test-Path $LockPath) {
  try {
    $ageMin = ((Get-Date) - (Get-Item $LockPath).LastWriteTime).TotalMinutes
    if ($ageMin -lt $LockMaxAgeMinutes) {
      Write-Host ("Another run is active (lock age {0:N0}m). Exiting." -f $ageMin) -ForegroundColor Yellow
      return
    } else {
      Write-Host "Stale lock detected. Removing..." -ForegroundColor DarkYellow
      Remove-Item -LiteralPath $LockPath -Force -ErrorAction SilentlyContinue
    }
  } catch {}
}
Set-Content -Encoding ascii -Path $LockPath -Value ((Get-Date).ToString("s"))

# Log setup
$logDir = ".\logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$stamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = Join-Path $logDir ("orchestrator_" + $stamp + ".txt")
Start-Transcript -Path $logPath -Force | Out-Null

try {
  # Healthcheck (kompakt)
  try { $branch = (git rev-parse --abbrev-ref HEAD).Trim() } catch { $branch = "(unknown)" }
  $remote = (git remote get-url origin 2>$null)
  try { $disk = (Get-PSDrive -Name C).Free/1GB } catch { $disk = 0 }
  Write-Host ("Health: branch={0} remote={1} freeC={2:N1}GB" -f $branch,$remote,$disk) -ForegroundColor DarkGray

  # Intake + loop
  & powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\pull_inbox.ps1
  & powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\ai_loop.ps1

  # Push via SSH med st?jfilter
  if ($remote) {
    $pushOut = & git push -u origin $branch 2>&1
    $txt = ($pushOut | Out-String)
    if ($LASTEXITCODE -eq 0 -or $txt -match "Everything up-to-date" -or $txt -match "new branch") {
      Write-Host $txt
    } else {
      if ($txt -match "HTTP 500" -or $txt -match "RPC failed") {
        Write-Host "Server 500/RPC: repacking and retry..." -ForegroundColor Yellow
        try { git repack -adf --max-pack-size=200m | Out-Null } catch {}
        $pushOut2 = & git push -u origin $branch 2>&1
        Write-Host ($pushOut2 | Out-String)
      } else {
        Write-Host $txt -ForegroundColor Red
      }
    }
  } else {
    Write-Host "No remote 'origin' configured. Skipping push." -ForegroundColor DarkGray
  }

  # Valgfri PR (kun hvis gh er logget ind)
  $gh = Get-Command gh -EA SilentlyContinue
  if ($gh) {
    try {
      & gh auth status 1>$null 2>$null
      if ($LASTEXITCODE -eq 0) {
        $head = (git rev-parse --abbrev-ref origin/HEAD 2>$null)
        $base = "main"; if ($head -and $head -match "origin/(.+)$") { $base = $Matches[1] }
        if ($branch -ne $base) {
          try { & gh pr create --head $branch --base $base --title ("Jarvis Autodev: " + $branch) --body "Automated changes by orchestrator." | Out-Null } catch {}
        }
      }
    } catch {}
  }

  # Log-rotation (14 dage)
  try {
    Get-ChildItem $logDir -Filter "orchestrator_*.txt" -File |
      Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-14) } |
      Remove-Item -Force -ErrorAction SilentlyContinue
  } catch {}
}
catch {
  $msg = $_.Exception.Message
  if ($msg -match "Everything up-to-date" -or $msg -match "^\s*remote:\s*$") {
    Write-Host ("Note: " + $msg) -ForegroundColor DarkGray
  } else {
    Write-Host ("Orchestrator error: " + $msg) -ForegroundColor Red
  }
}
finally {
  try { Stop-Transcript | Out-Null } catch {}
  try { if (Test-Path $LockPath) { Remove-Item -LiteralPath $LockPath -Force } } catch {}
  Write-Host ("Log saved to " + $logPath) -ForegroundColor Cyan
}
