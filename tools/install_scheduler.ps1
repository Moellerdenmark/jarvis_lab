param(
  [int]$EveryMinutes=15,
  [switch]$AsService,            # k?r ogs? n?r brugeren ikke er logget ind
  [string]$RunAsUser=$env:USERNAME
)
$ErrorActionPreference = "Stop"
$psExe  = (Get-Command powershell).Source
$script = (Resolve-Path ".\tools\orchestrator.ps1").Path
$task   = "JarvisAutoDev"

try { schtasks.exe /Delete /TN $task /F | Out-Null } catch {}
$tr = '"' + $psExe + '"' + ' -NoProfile -ExecutionPolicy Bypass -File "' + $script + '"'
$base = @("/Create","/F","/SC","MINUTE","/MO","$EveryMinutes","/TN",$task,"/TR",$tr)

if ($AsService) {
  # BEM?RK: /RP "*" vil bede om Windows-adgangskode interaktivt.
  schtasks.exe @($base + @("/RU",$RunAsUser,"/RP","*")) | Out-Null
} else {
  try { schtasks.exe @($base + @("/RL","HIGHEST")) | Out-Null } catch { schtasks.exe @base | Out-Null }
}
Write-Host ("Scheduled task '" + $task + "' every " + $EveryMinutes + " minute(s).") -ForegroundColor Green
