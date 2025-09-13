param([int]$EveryMinutes=15)
$ErrorActionPreference = "Stop"
$psExe  = (Get-Command powershell).Source
$script = (Resolve-Path ".\tools\orchestrator.ps1").Path
$task   = "JarvisAutoDev"

try { schtasks.exe /Delete /TN $task /F | Out-Null } catch {}
$tr = '"' + $psExe + '" -NoProfile -ExecutionPolicy Bypass -File ' + '"' + $script + '"'
$args = @("/Create","/F","/SC","MINUTE","/MO","$EveryMinutes","/TN",$task,"/TR",$tr)
# K?r som h?jeste rettigheder hvis muligt (kr?ver admin); ellers udelad /RL
try { schtasks.exe @($args + @("/RL","HIGHEST")) | Out-Null } catch { schtasks.exe @args | Out-Null }
Write-Host ("Scheduled task '" + $task + "' hver " + $EveryMinutes + " minut(er).") -Fore Green
