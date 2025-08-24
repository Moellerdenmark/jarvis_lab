param([int]$MaxTasks=3,[switch]$Approve,[switch]$UseLLM)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\selfbuild_guard.ps1"
$env:JARVIS_FORCE_LOCAL_TEST = "1"
if (-not (Get-Command Start-JarvisLoop -ErrorAction SilentlyContinue)) { throw "Start-JarvisLoop ikke fundet i wrappers." }
Write-Host "[SELFBUILD] Starter loop (MaxTasks=$MaxTasks, Approve=$Approve, UseLLM=$UseLLM)" -ForegroundColor Cyan
Start-JarvisLoop -Approve:$Approve -UseLLM:$UseLLM -MaxTasks $MaxTasks