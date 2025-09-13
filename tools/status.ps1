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
Write-Host "Scheduler:" -ForegroundColor DarkGray
try {
  schtasks /Query /TN JarvisAutoDev /V /FO LIST | Out-String | Write-Host
} catch {
  Write-Host "  (task 'JarvisAutoDev' not found)" -ForegroundColor DarkGray
}
