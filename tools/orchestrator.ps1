# --- WORKDIR BOOTSTRAP ---
try {
  if ($PSScriptRoot) { Set-Location (Join-Path $PSScriptRoot '..') }
  elseif ($PSCommandPath) { Set-Location (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) }
  else {
    $dir = (Get-Location).Path
    while ($dir -and -not (Test-Path (Join-Path $dir '.git'))) { $dir = Split-Path -Parent $dir }
    if ($dir) { Set-Location $dir }
  }
} catch {}
# --- END WORKDIR BOOTSTRAP ---

$ErrorActionPreference = 'Stop'

# Lockfile
$LockPath = '.\.autopilot.lock'
$LockMaxAgeMinutes = 60
if (Test-Path $LockPath) {
  try {
    $ageMin = ((Get-Date) - (Get-Item $LockPath).LastWriteTime).TotalMinutes
    if ($ageMin -lt $LockMaxAgeMinutes) {
      Write-Host ("Another run is active (lock age {0:N0}m). Exiting." -f $ageMin) -ForegroundColor Yellow
      return
    } else {
      Write-Host 'Stale lock detected. Removing...' -ForegroundColor DarkYellow
      Remove-Item -LiteralPath $LockPath -Force -ErrorAction SilentlyContinue
    }
  } catch {}
}
Set-Content -Encoding ascii -Path $LockPath -Value ((Get-Date).ToString('s'))

# Log setup
$logDir = '.\logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$logPath = Join-Path $logDir ("orchestrator_" + $stamp + ".txt")
Start-Transcript -Path $logPath -Force | Out-Null

function Invoke-GitPush([string]$branch){
  # Start git som .NET-proces og fang begge streams
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = 'git'
  $psi.Arguments = "push -u origin $branch"
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute        = $false
  $psi.CreateNoWindow         = $true

  $p = [System.Diagnostics.Process]::Start($psi)
  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()

  $txt  = (($stdout + "`n" + $stderr) -replace '\r','').Trim()
  $code = $p.ExitCode

  $benign = ($code -eq 0) -or
            ($txt -match 'Everything up-to-date') -or
            ($txt -match '^\s*(remote:|To\s+github\.com:)') -or
            ($txt -match 'gh\.io/lfs') -or
            ($txt -match 'warning:\s+See\s+https?://gh\.io/lfs')

  @{ Exit=$code; Text=$txt; Benign=$benign }
} finally { $ErrorActionPreference = $old }
  $benign = ($code -eq 0) -or
            ($txt -match 'Everything up-to-date') -or
            ($txt -match '^\s*(remote:|To\s+github\.com:)') -or
            ($txt -match 'gh\.io/lfs') -or
            ($txt -match 'warning:\s+See\s+https?://gh\.io/lfs')
  @{ Exit=$code; Text=$txt; Benign=$benign }
}

try {
  # Health
  try { $branch = (git rev-parse --abbrev-ref HEAD).Trim() } catch { $branch = '(unknown)' }
  $remote = (git remote get-url origin 2>$null)
  try { $disk = (Get-PSDrive -Name C).Free/1GB } catch { $disk = 0 }
  Write-Host ("Health: branch={0} remote={1} freeC={2:N1}GB" -f $branch,$remote,$disk) -ForegroundColor DarkGray

  # Intake + loop
  & powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\pull_inbox.ps1
  & powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\ai_loop.ps1

# Push via SSH (quiet/filtered)
if ($remote) {
  $r = Invoke-GitPush $branch
  if ($r.Benign) {
    $lines = @()
    if ($r.Text) {
      $lines = $r.Text -split "`n" | Where-Object { # --- WORKDIR BOOTSTRAP ---
try {
  if ($PSScriptRoot) { Set-Location (Join-Path $PSScriptRoot '..') }
  elseif ($PSCommandPath) { Set-Location (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) }
  else {
    $dir = (Get-Location).Path
    while ($dir -and -not (Test-Path (Join-Path $dir '.git'))) { $dir = Split-Path -Parent $dir }
    if ($dir) { Set-Location $dir }
  }
} catch {}
# --- END WORKDIR BOOTSTRAP ---

$ErrorActionPreference = 'Stop'

# Lockfile
$LockPath = '.\.autopilot.lock'
$LockMaxAgeMinutes = 60
if (Test-Path $LockPath) {
  try {
    $ageMin = ((Get-Date) - (Get-Item $LockPath).LastWriteTime).TotalMinutes
    if ($ageMin -lt $LockMaxAgeMinutes) {
      Write-Host ("Another run is active (lock age {0:N0}m). Exiting." -f $ageMin) -ForegroundColor Yellow
      return
    } else {
      Write-Host 'Stale lock detected. Removing...' -ForegroundColor DarkYellow
      Remove-Item -LiteralPath $LockPath -Force -ErrorAction SilentlyContinue
    }
  } catch {}
}
Set-Content -Encoding ascii -Path $LockPath -Value ((Get-Date).ToString('s'))

# Log setup
$logDir = '.\logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$logPath = Join-Path $logDir ("orchestrator_" + $stamp + ".txt")
Start-Transcript -Path $logPath -Force | Out-Null

function Invoke-GitPush([string]$branch){
  # Start git som .NET-proces og fang begge streams
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = 'git'
  $psi.Arguments = "push -u origin $branch"
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute        = $false
  $psi.CreateNoWindow         = $true

  $p = [System.Diagnostics.Process]::Start($psi)
  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()

  $txt  = (($stdout + "`n" + $stderr) -replace '\r','').Trim()
  $code = $p.ExitCode

  $benign = ($code -eq 0) -or
            ($txt -match 'Everything up-to-date') -or
            ($txt -match '^\s*(remote:|To\s+github\.com:)') -or
            ($txt -match 'gh\.io/lfs') -or
            ($txt -match 'warning:\s+See\s+https?://gh\.io/lfs')

  @{ Exit=$code; Text=$txt; Benign=$benign }
} finally { $ErrorActionPreference = $old }
  $benign = ($code -eq 0) -or
            ($txt -match 'Everything up-to-date') -or
            ($txt -match '^\s*(remote:|To\s+github\.com:)') -or
            ($txt -match 'gh\.io/lfs') -or
            ($txt -match 'warning:\s+See\s+https?://gh\.io/lfs')
  @{ Exit=$code; Text=$txt; Benign=$benign }
}

try {
  # Health
  try { $branch = (git rev-parse --abbrev-ref HEAD).Trim() } catch { $branch = '(unknown)' }
  $remote = (git remote get-url origin 2>$null)
  try { $disk = (Get-PSDrive -Name C).Free/1GB } catch { $disk = 0 }
  Write-Host ("Health: branch={0} remote={1} freeC={2:N1}GB" -f $branch,$remote,$disk) -ForegroundColor DarkGray

  # Intake + loop
  & powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\pull_inbox.ps1
  & powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\ai_loop.ps1

  # Push via SSH (benign-output filtered)
  if ($remote) {
    $r = Invoke-GitPush $branch
    if ($r.Benign) {
      if ($r.Text -and $r.Text.Trim()) { Write-Host $r.Text }
    } else {
      if ($r.Text -match 'HTTP 500' -or $r.Text -match 'RPC failed') {
        Write-Host 'Server 500/RPC: repacking and retry...' -ForegroundColor Yellow
        try { git repack -adf --max-pack-size=200m | Out-Null } catch {}
        $r = Invoke-GitPush $branch
      }
      if (-not $r.Benign) { Write-Host $r.Text -ForegroundColor Red }
    }
  } else {
    Write-Host "No remote 'origin' configured. Skipping push." -ForegroundColor DarkGray
  }

  # Optional PR (base = autopilot_main)
  $gh = Get-Command gh -EA SilentlyContinue
  if ($gh) {
    try {
      & gh auth status 1>$null 2>$null
      if ($LASTEXITCODE -eq 0) {
        $base = 'autopilot_main'
        if ($branch -ne $base) {
          try { & gh pr create --head $branch --base $base --title ("Jarvis Autodev: " + $branch) --body 'Automated changes by orchestrator.' | Out-Null } catch {}
        }
      }
    } catch {}
  }

  # Log rotation (14 days)
  try {
    Get-ChildItem $logDir -Filter 'orchestrator_*.txt' -File |
      Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-14) } |
      Remove-Item -Force -ErrorAction SilentlyContinue
  } catch {}
}
catch {
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
}
finally {
  try { Stop-Transcript | Out-Null } catch {}
  try {
    if ($logPath -and (Test-Path $logPath)) {
      Write-Host ("Log saved to " + (Resolve-Path $logPath)) -ForegroundColor Cyan
    } else {
      Write-Host 'Log saved (path unavailable)' -ForegroundColor DarkGray
    }
  } catch {}
  try { if (Test-Path $LockPath) { Remove-Item -LiteralPath $LockPath -Force -ErrorAction SilentlyContinue } } catch {}
}
 -and (# --- WORKDIR BOOTSTRAP ---
try {
  if ($PSScriptRoot) { Set-Location (Join-Path $PSScriptRoot '..') }
  elseif ($PSCommandPath) { Set-Location (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) }
  else {
    $dir = (Get-Location).Path
    while ($dir -and -not (Test-Path (Join-Path $dir '.git'))) { $dir = Split-Path -Parent $dir }
    if ($dir) { Set-Location $dir }
  }
} catch {}
# --- END WORKDIR BOOTSTRAP ---

$ErrorActionPreference = 'Stop'

# Lockfile
$LockPath = '.\.autopilot.lock'
$LockMaxAgeMinutes = 60
if (Test-Path $LockPath) {
  try {
    $ageMin = ((Get-Date) - (Get-Item $LockPath).LastWriteTime).TotalMinutes
    if ($ageMin -lt $LockMaxAgeMinutes) {
      Write-Host ("Another run is active (lock age {0:N0}m). Exiting." -f $ageMin) -ForegroundColor Yellow
      return
    } else {
      Write-Host 'Stale lock detected. Removing...' -ForegroundColor DarkYellow
      Remove-Item -LiteralPath $LockPath -Force -ErrorAction SilentlyContinue
    }
  } catch {}
}
Set-Content -Encoding ascii -Path $LockPath -Value ((Get-Date).ToString('s'))

# Log setup
$logDir = '.\logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$logPath = Join-Path $logDir ("orchestrator_" + $stamp + ".txt")
Start-Transcript -Path $logPath -Force | Out-Null

function Invoke-GitPush([string]$branch){
  # Start git som .NET-proces og fang begge streams
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = 'git'
  $psi.Arguments = "push -u origin $branch"
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute        = $false
  $psi.CreateNoWindow         = $true

  $p = [System.Diagnostics.Process]::Start($psi)
  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()

  $txt  = (($stdout + "`n" + $stderr) -replace '\r','').Trim()
  $code = $p.ExitCode

  $benign = ($code -eq 0) -or
            ($txt -match 'Everything up-to-date') -or
            ($txt -match '^\s*(remote:|To\s+github\.com:)') -or
            ($txt -match 'gh\.io/lfs') -or
            ($txt -match 'warning:\s+See\s+https?://gh\.io/lfs')

  @{ Exit=$code; Text=$txt; Benign=$benign }
} finally { $ErrorActionPreference = $old }
  $benign = ($code -eq 0) -or
            ($txt -match 'Everything up-to-date') -or
            ($txt -match '^\s*(remote:|To\s+github\.com:)') -or
            ($txt -match 'gh\.io/lfs') -or
            ($txt -match 'warning:\s+See\s+https?://gh\.io/lfs')
  @{ Exit=$code; Text=$txt; Benign=$benign }
}

try {
  # Health
  try { $branch = (git rev-parse --abbrev-ref HEAD).Trim() } catch { $branch = '(unknown)' }
  $remote = (git remote get-url origin 2>$null)
  try { $disk = (Get-PSDrive -Name C).Free/1GB } catch { $disk = 0 }
  Write-Host ("Health: branch={0} remote={1} freeC={2:N1}GB" -f $branch,$remote,$disk) -ForegroundColor DarkGray

  # Intake + loop
  & powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\pull_inbox.ps1
  & powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\ai_loop.ps1

  # Push via SSH (benign-output filtered)
  if ($remote) {
    $r = Invoke-GitPush $branch
    if ($r.Benign) {
      if ($r.Text -and $r.Text.Trim()) { Write-Host $r.Text }
    } else {
      if ($r.Text -match 'HTTP 500' -or $r.Text -match 'RPC failed') {
        Write-Host 'Server 500/RPC: repacking and retry...' -ForegroundColor Yellow
        try { git repack -adf --max-pack-size=200m | Out-Null } catch {}
        $r = Invoke-GitPush $branch
      }
      if (-not $r.Benign) { Write-Host $r.Text -ForegroundColor Red }
    }
  } else {
    Write-Host "No remote 'origin' configured. Skipping push." -ForegroundColor DarkGray
  }

  # Optional PR (base = autopilot_main)
  $gh = Get-Command gh -EA SilentlyContinue
  if ($gh) {
    try {
      & gh auth status 1>$null 2>$null
      if ($LASTEXITCODE -eq 0) {
        $base = 'autopilot_main'
        if ($branch -ne $base) {
          try { & gh pr create --head $branch --base $base --title ("Jarvis Autodev: " + $branch) --body 'Automated changes by orchestrator.' | Out-Null } catch {}
        }
      }
    } catch {}
  }

  # Log rotation (14 days)
  try {
    Get-ChildItem $logDir -Filter 'orchestrator_*.txt' -File |
      Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-14) } |
      Remove-Item -Force -ErrorAction SilentlyContinue
  } catch {}
}
catch {
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
}
finally {
  try { Stop-Transcript | Out-Null } catch {}
  try {
    if ($logPath -and (Test-Path $logPath)) {
      Write-Host ("Log saved to " + (Resolve-Path $logPath)) -ForegroundColor Cyan
    } else {
      Write-Host 'Log saved (path unavailable)' -ForegroundColor DarkGray
    }
  } catch {}
  try { if (Test-Path $LockPath) { Remove-Item -LiteralPath $LockPath -Force -ErrorAction SilentlyContinue } } catch {}
}
 -notmatch '^\s*(remote:|To\s+github\.com:)') }
    }
    if ($lines.Count -gt 0) {
      Write-Host ($lines -join [Environment]::NewLine)
    } else {
      Write-Host ("Push OK ? {0}" -f $branch) -ForegroundColor DarkGray
    }
  } else {
    if ($r.Text -match 'HTTP 500' -or $r.Text -match 'RPC failed') {
      Write-Host 'Server 500/RPC: repacking and retry...' -ForegroundColor Yellow
      try { git repack -adf --max-pack-size=200m | Out-Null } catch {}
      $r = Invoke-GitPush $branch
      if (-not $r.Benign) { Write-Host $r.Text -ForegroundColor Red }
    } else {
      Write-Host $r.Text -ForegroundColor Red
    }
  }
} else {
  Write-Host "No remote 'origin' configured. Skipping push." -ForegroundColor DarkGray
}
  # Optional PR (base = autopilot_main)
  $gh = Get-Command gh -EA SilentlyContinue
  if ($gh) {
    try {
      & gh auth status 1>$null 2>$null
      if ($LASTEXITCODE -eq 0) {
        $base = 'autopilot_main'
        if ($branch -ne $base) {
          try { & gh pr create --head $branch --base $base --title ("Jarvis Autodev: " + $branch) --body 'Automated changes by orchestrator.' | Out-Null } catch {}
        }
      }
    } catch {}
  }

  # Log rotation (14 days)
  try {
    Get-ChildItem $logDir -Filter 'orchestrator_*.txt' -File |
      Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-14) } |
      Remove-Item -Force -ErrorAction SilentlyContinue
  } catch {}
}
catch {
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
}
finally {
  try { Stop-Transcript | Out-Null } catch {}
  try {
    if ($logPath -and (Test-Path $logPath)) {
      Write-Host ("Log saved to " + (Resolve-Path $logPath)) -ForegroundColor Cyan
    } else {
      Write-Host 'Log saved (path unavailable)' -ForegroundColor DarkGray
    }
  } catch {}
  try { if (Test-Path $LockPath) { Remove-Item -LiteralPath $LockPath -Force -ErrorAction SilentlyContinue } } catch {}
}

