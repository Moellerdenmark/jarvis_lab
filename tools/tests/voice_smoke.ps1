$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$cfgPath  = Join-Path $repoRoot "tools\models.psd1"
$cfg = @{}; if (Test-Path $cfgPath) { $cfg = Import-PowerShellDataFile $cfgPath }
$outDir = Join-Path $repoRoot ($cfg.OutDir ? $cfg.OutDir : "out\\voice")

& pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "tools\voice\jarvis_talk.ps1") -InputText "Hej Jarvis" -NoPlay

$wav = Get-ChildItem $outDir -Filter *.wav -File | Sort-Object LastWriteTime -desc | Select-Object -First 1
if (-not $wav) { throw "Ingen WAV fundet i $outDir" }
if ($wav.Length -le 44) { throw "WAV for lille ($($wav.Length) bytes)" }
Write-Host "Voice smoke: OK"
