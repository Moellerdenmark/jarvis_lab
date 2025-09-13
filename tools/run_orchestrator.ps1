$ErrorActionPreference = "Stop"

# G?r GH-CLI tilg?ngelig i Scheduler-milj?et
$ghDir = 'C:\Program Files\GitHub CLI'
if (Test-Path $ghDir) { $env:Path = "$env:Path;$ghDir" }

# Robust PSScriptRoot fallback (PS5)
if (-not $PSScriptRoot -or [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
  $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

# K?r orchestrator fra tools-mappen
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'orchestrator.ps1')
