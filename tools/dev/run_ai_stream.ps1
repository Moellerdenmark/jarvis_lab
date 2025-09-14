param([string]$TaskFile,[int]$TimeoutSec = 3600)
$ErrorActionPreference = 'Stop'
$tools  = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$logDir = Join-Path $tools 'logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$log   = Join-Path $logDir "ai_loop.stream.$stamp.log"
& pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tools 'ai_loop.ps1') -TaskFile $TaskFile 2>&1 |
  Tee-Object -FilePath $log
