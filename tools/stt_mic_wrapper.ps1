param([double]$Seconds=3.0,[string]$DeviceName="Microphone (Jabra SPEAK 510 USB)")
$ErrorActionPreference="Stop"; Set-StrictMode -Version Latest
try{ [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); $OutputEncoding=[Text.UTF8Encoding]::new($false) }catch{}
$ScriptDir = if($PSScriptRoot){$PSScriptRoot}else{ Split-Path -Parent $MyInvocation.MyCommand.Path }
$engine = Join-Path $ScriptDir 'stt_engine.ps1'
if(-not (Test-Path $engine)){ throw "Mangler $engine" }
$raw = (& $engine -Seconds $Seconds -DeviceName $DeviceName 2>$null *>&1 | Out-String)
$txt = ($raw -split "(`r`n|`n|`r)" | Where-Object { $_ -match '\S' } | Select-Object -Last 1)
if($txt){ $txt.Trim() }
