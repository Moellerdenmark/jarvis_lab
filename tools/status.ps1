$ErrorActionPreference = "Stop"
Write-Host "=== Jarvis Status ===" -ForegroundColor Cyan
try { $branch = (git rev-parse --abbrev-ref HEAD).Trim() } catch { $branch = "(unknown)" }
try { $remote = (git remote get-url origin 2>$null) } catch { $remote = "(none)" }
Write-Host ("Branch : {0}" -f $branch)
Write-Host ("Remote : {0}" -f $remote)

$lock = ".\.autopilot.lock"
if (Test-Path $lock) {
  $age = ((Get-Date) - (Get-Item $lock).LastWriteTime)
  Write-Host ("Lock   : present ({0:N0} min old)" -f $age.TotalMinutes) -ForegroundColor Yellow
} else {
  Write-Host "Lock   : none" -ForegroundColor DarkGray
}

$last = Get-ChildItem .\logs\orchestrator_*.txt -File -EA SilentlyContinue | Sort-Object LastWriteTime -desc | Select-Object -First 1
if ($last) {
  Write-Host ("Log    : {0}" -f $last.FullName)
  Write-Host "--- tail ---" -ForegroundColor DarkGray
  Get-Content $last.FullName -Tail 40
} else {
  Write-Host "Log    : (none yet)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host ""
Write-Host "Scheduler:" -ForegroundColor DarkGray
try {
  $old = $ErrorActionPreference; $ErrorActionPreference='Continue'
  $raw = schtasks /Query /TN JarvisAutoDev /V /FO LIST 2>&1 | Out-String
  $ErrorActionPreference = $old
  if ($raw -match 'ERROR:') {
    Write-Host "  (task 'JarvisAutoDev' not found)" -ForegroundColor DarkGray
  } else {
    $raw | Write-Host
  }
} catch {
  Write-Host "  (task 'JarvisAutoDev' not found)" -ForegroundColor DarkGray
}

// touch 2025-09-14T12:26:00.9141771+02:00
