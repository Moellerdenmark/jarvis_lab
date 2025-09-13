# --- WORKDIR BOOTSTRAP ---
$ErrorActionPreference = "Stop"
try {
  # Antag: denne fil ligger i <repo>\tools
  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
  if (-not (Test-Path (Join-Path $repoRoot ".git"))) {
    $probe = & git rev-parse --show-toplevel 2>$null
    if ($probe) { $repoRoot = $probe.Trim() }
  }
  Set-Location $repoRoot
} catch {}
# --- END WORKDIR BOOTSTRAP ---

# --- Lock ---
$LockPath = Join-Path $repoRoot ".autopilot.lock"
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
Set-Content -Encoding ascii -Path $LockPath -Value ((Get-Date).ToString('s'))

# --- Log setup ---
$logDir = Join-Path $repoRoot "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$stamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = Join-Path $logDir ("orchestrator_" + $stamp + ".txt")
Start-Transcript -Path $logPath -Force | Out-Null

# --- Helpers ---
function Invoke-Git([string]$argLine){
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName               = 'git'
  $psi.Arguments              = "-C `"$repoRoot`" $argLine"
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute        = $false
  $psi.CreateNoWindow         = $true
  $psi.WorkingDirectory       = $repoRoot
  $p = [System.Diagnostics.Process]::Start($psi)
  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()
  $txt  = (($stdout + "`n" + $stderr) -replace '\r','').Trim()
  $code = $p.ExitCode
  @{ Exit=$code; Text=$txt }
}

function Push-Quiet([string]$branch){
  $r = Invoke-Git "push -u origin $branch"
  $txt  = $r.Text
  $code = $r.Exit
  $benign = ($code -eq 0) -or
            ($txt -match 'Everything up-to-date') -or
            ($txt -match '^\s*(remote:|To\s+github\.com:)') -or
            ($txt -match 'gh\.io/lfs') -or
            ($txt -match 'warning:\s+See\s+https?://gh\.io/lfs')
  if ($benign) {
    $lines = @()
    if ($txt) { $lines = $txt -split "`n" | Where-Object {$_ -and ($_ -notmatch '^\s*(remote:|To\s+github\.com:)')} }
    if ($lines.Count -gt 0) { Write-Host ($lines -join [Environment]::NewLine) } else { Write-Host ("Push OK ? {0}" -f $branch) -ForegroundColor DarkGray }
    return $true
  }
  if ($txt -match 'HTTP 500' -or $txt -match 'RPC failed') {
    Write-Host 'Server 500/RPC: repacking and retry...' -ForegroundColor Yellow
    Invoke-Git "repack -adf --max-pack-size=200m" | Out-Null
    $r2 = Invoke-Git "push -u origin $branch"
    $txt2 = $r2.Text
    $code2 = $r2.Exit
    $benign2 = ($code2 -eq 0) -or
               ($txt2 -match 'Everything up-to-date') -or
               ($txt2 -match '^\s*(remote:|To\s+github\.com:)') -or
               ($txt2 -match 'gh\.io/lfs')
    if ($benign2) { Write-Host "Push OK after repack" -ForegroundColor DarkGray; return $true }
    Write-Host $txt2 -ForegroundColor Red
    return $false
  }
  Write-Host $txt -ForegroundColor Red
  return $false
}

try {
  # --- Health ---
  $branch = (& git -C $repoRoot rev-parse --abbrev-ref HEAD 2>$null).Trim()
  if (-not $branch) { $branch = "(unknown)" }
  $remote = (& git -C $repoRoot remote get-url origin 2>$null)
  $disk   = 0; try { $disk = (Get-PSDrive -Name C).Free/1GB } catch {}
  Write-Host ("Health: branch={0} remote={1} freeC={2:N1}GB" -f $branch,$remote,$disk) -ForegroundColor DarkGray

  # --- Intake + loop ---
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "tools\pull_inbox.ps1")
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "tools\ai_loop.ps1")
  # --- Post-sanitize & sanity test (auto-fix README) ---
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "tools\post_sanitize.ps1")
  if ($LASTEXITCODE -ne 0) { Write-Host "Post-sanitize fejlede" -ForegroundColor Yellow }

  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "tools\tests\readme_sanity.ps1")
  $tests_ok = ($LASTEXITCODE -eq 0)

  # stage/commit hvis post_sanitize ændrede noget
  $dirty = (& git -C $repoRoot status --porcelain).Trim()
  if ($dirty) {
    & git -C $repoRoot add README.md
    try { & git -C $repoRoot commit -m "fix: normalize README markers and fences" | Out-Null } catch {}
  }

  if (-not $tests_ok) {
    Write-Host "Sanity tests failed; skipping push/PR." -ForegroundColor Yellow
    return
  }

  # Efter AI-loop kan branch v?re skiftet
  $branch = (& git -C $repoRoot rev-parse --abbrev-ref HEAD).Trim()

  # --- Quiet push ---
  if ($remote) {
    [void](Push-Quiet $branch)
  } else {
    Write-Host "No remote 'origin' configured. Skipping push." -ForegroundColor DarkGray
  }

  # --- Optional PR (base=autopilot_main) ---
  $gh = Get-Command gh -EA SilentlyContinue
  if ($gh) {
    try {
      & $gh.Source auth status 1>$null 2>$null
      if ($LASTEXITCODE -eq 0 -and $branch -ne 'autopilot_main') {
        try { & $gh.Source pr create --head $branch --base autopilot_main --title ("Jarvis Autodev: " + $branch) --body "Automated changes by orchestrator." | Out-Null } catch {}
      }
    } catch {}
  }

  # --- Log rotation (14d) ---
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
      Write-Host ("Note: " + $msg) -ForegroundColor DarkGray
    } else {
      Write-Host ("Orchestrator error: " + $msg) -ForegroundColor Red
    }
  } catch {}
}
finally {
  try { Stop-Transcript | Out-Null } catch {}
  try {
    if ($logPath -and (Test-Path $logPath)) {
      Write-Host ("Log saved to " + (Resolve-Path $logPath)) -ForegroundColor Cyan
    } else {
      Write-Host "Log saved (path unavailable)" -ForegroundColor DarkGray
    }
  } catch {}
  try { if (Test-Path $LockPath) { Remove-Item -LiteralPath $LockPath -Force -ErrorAction SilentlyContinue } } catch {}
}

