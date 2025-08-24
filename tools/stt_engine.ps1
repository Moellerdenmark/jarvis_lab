param(
  [double]$Seconds = 3.0,
  [string]$DeviceName = "Microphone (Jabra SPEAK 510 USB)",
  [string]$Lang = "da",
  [string]$OutBase
)
$ErrorActionPreference="Stop"; Set-StrictMode -Version Latest
try{ [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); $OutputEncoding=[Text.UTF8Encoding]::new($false) }catch{}
$ScriptDir = if($PSScriptRoot){$PSScriptRoot}else{ Split-Path -Parent $MyInvocation.MyCommand.Path }
$Root = Split-Path -Parent $ScriptDir
$outDir = Join-Path $Root "out\listen"
$cfgPath= Join-Path $ScriptDir "whisper_local.json"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
if(-not (Test-Path $cfgPath)){ throw "Mangler $cfgPath (exe/model). Opret den, fx via dit tidligere setup)." }
$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
$exe=$cfg.exe; $model=$cfg.model; if($cfg.lang){$Lang=$cfg.lang}
if(-not (Test-Path $exe)){ throw "whisper exe ikke fundet: $exe" }
if(-not (Test-Path $model)){ throw "whisper model ikke fundet: $model" }

if(-not $OutBase -or $OutBase.Trim() -eq ""){
  $stamp=(Get-Date).ToString("yyyyMMdd_HHmmssfff")
  $OutBase = Join-Path $outDir ("stt_{0}" -f $stamp)
}else{
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutBase) | Out-Null
}
$wav="$OutBase.wav"; $txtOut="$OutBase.txt"

# Optag WAV (fejltolerant)
$prevEAP=$ErrorActionPreference; $ErrorActionPreference="Continue"
& ffmpeg -hide_banner -loglevel error -f dshow -i ("audio=" + $DeviceName) -t $Seconds -ac 1 -ar 16000 -vn -acodec pcm_s16le -y $wav 2>$null | Out-Null
$ErrorActionPreference=$prevEAP
$tries=0; while(-not (Test-Path $wav) -and $tries -lt 80){ Start-Sleep -Milliseconds 25; $tries++ }
if(-not (Test-Path $wav)){ "" ; return }

# Kør whisper (fejltolerant)
$threads=[Math]::Max(1,[Environment]::ProcessorCount)
$prevEAP=$ErrorActionPreference; $ErrorActionPreference="Continue"
& $exe -m $model -f $wav -l $Lang -t $threads -otxt -of $OutBase 2>$null | Out-Null
$ErrorActionPreference=$prevEAP
$tries=0; while(-not (Test-Path $txtOut) -and $tries -lt 200){ Start-Sleep -Milliseconds 25; $tries++ }
if(-not (Test-Path $txtOut)){ "" ; return }

(Get-Content $txtOut -Raw -Encoding UTF8).Trim()

