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
$logDir = ".\logs"
if(-not (Test-Path $logDir)){ New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = Join-Path $logDir ("orchestrator_" + $stamp + ".txt")
Start-Transcript -Path $logPath -Force | Out-Null
try {
  & powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\pull_inbox.ps1
  & powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\ai_loop.ps1

  # Push via SSH
  $branch = (git rev-parse --abbrev-ref HEAD).Trim()
  if (-not $branch) { throw "Could not read branch name" }
  $remotes = (git remote 2>$null)
  if ($remotes -notmatch "^\s*origin\s*$") { Write-Host "No remote origin, skipping push." -ForegroundColor DarkGray; return }
  $pushOut = & git push -u origin $branch 2>&1
  Write-Host ($pushOut | Out-String)
  if ($LASTEXITCODE -ne 0 -and ($pushOut -match "HTTP 500" -or $pushOut -match "RPC failed")) {
    Write-Host "Server 500/RPC: repacking and retry..." -ForegroundColor Yellow
    try { git repack -adf --max-pack-size=200m | Out-Null } catch {}
    $pushOut2 = & git push -u origin $branch 2>&1
    Write-Host ($pushOut2 | Out-String)
  }

  # Optional PR
  $gh = Get-Command gh -EA SilentlyContinue
  if($gh){
    $head = (git rev-parse --abbrev-ref origin/HEAD 2>$null)
    $base = "main"; if($head -and $head -match "origin/(.+)$"){ $base = $Matches[1] }
    try { & gh pr create --head $branch --base $base --title ("Jarvis Autodev: " + $branch) --body "Automated changes by orchestrator." | Out-Null } catch {}
  }
} catch {
  Write-Host ("Orchestrator error: " + $_.Exception.Message) -ForegroundColor Red
} finally {
  Stop-Transcript | Out-Null
  Write-Host ("Log saved to " + $logPath) -ForegroundColor Cyan
}
