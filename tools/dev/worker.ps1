param([string]$Repo="$((Resolve-Path "$PSScriptRoot\..\..").Path)",[string]$Core="'$core'",[int]$AiStepTimeoutSec=3600,[int]$IdleSleepSec=5)
$ErrorActionPreference="Stop"
while($true){
  Remove-Item (Join-Path $Repo '.autopilot.lock') -Force -EA SilentlyContinue
  try{
    & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Repo 'tools\orchestrator_strict.ps1') `
      -Repo $Repo -Core $Core -AiStepTimeoutSec $AiStepTimeoutSec
  } catch {
    Write-Host ("[worker] ERROR: {0}" -f $_.Exception.Message)
  }
  Start-Sleep -Seconds $IdleSleepSec
}
