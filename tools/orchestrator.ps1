function Invoke-GitPush([string]$branch){
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
# Log setup
$logDir = ".\logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$stamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = Join-Path $logDir ("orchestrator_" + $stamp + ".txt")
Start-Transcript -Path $logPath -Force | Out-Null
  try {
    $out = & git push -u origin $branch 2>&1
    $txt = ($out | Out-String)
    $code = $LASTEXITCODE
  } finally { $ErrorActionPreference = $old }
  $benign = ($code -eq 0) -or
            ($txt -match 'Everything up-to-date') -or
            ($txt -match '^\s*(remote:|To\s+github\.com:)') -or
            ($txt -match 'gh\.io/lfs') -or
            ($txt -match 'warning:\s+See\s+https?://gh\.io/lfs')
  @{ Exit=$code; Text=$txt; Benign=$benign }
}
# --- WORKDIR BOOTSTRAP ---
try {
  if ($PSScriptRoot) { Set-Location (Join-Path $PSScriptRoot "..") }
  elseif ($PSCommandPath) { Set-Location (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) }
  else {
    $dir = (Get-Location).Path
    while ($dir -and -not (Test-Path (Join-Path $dir ".git"))) { $dir = Split-Path -Parent $dir }
    if ($dir) { Set-Location $dir }
  }
}catch{
  try {
    $msg = function Invoke-GitPush([string]$branch){
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
# Log setup
$logDir = ".\logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$stamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = Join-Path $logDir ("orchestrator_" + $stamp + ".txt")
Start-Transcript -Path $logPath -Force | Out-Null
  try {
    $out = & git push -u origin $branch 2>&1
    $txt = ($out | Out-String)
    $code = $LASTEXITCODE
  } finally { $ErrorActionPreference = $old }
  $benign = ($code -eq 0) -or
            ($txt -match 'Everything up-to-date') -or
            ($txt -match '^\s*(remote:|To\s+github\.com:)') -or
            ($txt -match 'gh\.io/lfs') -or
            ($txt -match 'warning:\s+See\s+https?://gh\.io/lfs')
  @{ Exit=$code; Text=$txt; Benign=$benign }
}
# --- WORKDIR BOOTSTRAP ---
try {
  if ($PSScriptRoot) { Set-Location (Join-Path $PSScriptRoot "..") }
  elseif ($PSCommandPath) { Set-Location (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) }
  else {
    $dir = (Get-Location).Path
    while ($dir -and -not (Test-Path (Join-Path $dir ".git"))) { $dir = Split-Path -Parent $dir }
    if ($dir) { Set-Location $dir }
  }
}catch{
  try {
    $msg = $_.Exception.Message
    if ([string]::IsNullOrWhiteSpace($msg) -or
        $msg -match 'Everything up-to-date' -or
        $msg -match '^\s*remote:' -or
        $msg -match '^\s*To\s+github\.com:' -or
        $msg -match 'gh\.io/lfs' -or
        $msg -match 'warning:\s+See\s+https?://gh\.io/lfs') {
      Write-Host ('Note: ' + $msg) -ForegroundColor DarkGray
    } else {
      Write-Host ('Orchestrator error: ' + $msg) -ForegroundColor Red
    }
  } catch {}
} finally {
  try { Stop-Transcript | Out-Null } catch {}
  try { if (Test-Path $LockPath) { Remove-Item -LiteralPath $LockPath -Force } } catch {}
  Write-Host ("Log saved to " + $logPath) -ForegroundColor Cyan
}





.Exception.Message
    if ([string]::IsNullOrWhiteSpace($msg) -or
        $msg -match 'Everything up-to-date' -or
        $msg -match '^\s*remote:' -or
        $msg -match '^\s*To\s+github\.com:' -or
        $msg -match 'gh\.io/lfs' -or
        $msg -match 'warning:\s+See\s+https?://gh\.io/lfs') {
      Write-Host ('Note: ' + $msg) -ForegroundColor DarkGray
    } else {
      Write-Host ('Orchestrator error: ' + $msg) -ForegroundColor Red
    }
  } catch {}
} finally {
  try { Stop-Transcript | Out-Null } catch {}
  try {
    if ($logPath -and (Test-Path $logPath)) {
      Write-Host ("Log saved to " + (Resolve-Path $logPath)) -ForegroundColor Cyan
    } else {
      Write-Host "Log saved (path unavailable)" -ForegroundColor DarkGray
    }
  } catch {}
} catch {}
  try { if (Test-Path $LockPath) { Remove-Item -LiteralPath $LockPath -Force } } catch {}
  Write-Host ("Log saved to " + $logPath) -ForegroundColor Cyan
}






