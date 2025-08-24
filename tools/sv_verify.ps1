param(
  [Parameter(Mandatory=$true)][string]$Name,
  [double]$Seconds = 1.2,
  [double]$Threshold = 0.72,
  [string]$DeviceName = "Microphone (Jabra SPEAK 510 USB)",
  [string]$OutWav
)
$ErrorActionPreference = "Stop"

# Robust paths + common DSP
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $ScriptDir 'sv_common.ps1')

$Root      = Split-Path -Parent $ScriptDir
$DataDir   = Join-Path $Root "data\voices\$Name"
$EmbedJson = Join-Path $DataDir "embed.json"
if (-not (Test-Path $EmbedJson)) { throw "Mangler enrollment: $EmbedJson" }

if (-not $OutWav) { $OutWav = Get-TempWavPath "verify" }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutWav) | Out-Null

Write-Host "[VERIFY] Optager $Seconds s fra '$DeviceName' -> $OutWav" -ForegroundColor Cyan

# ffmpeg: stille og korrekt quoting
& ffmpeg -hide_banner -loglevel error `
  -f dshow -i ("audio=" + $DeviceName) `
  -t $Seconds -ac 1 -ar 16000 -vn -acodec pcm_s16le -y $OutWav 2>$null | Out-Null

# Vent til filen faktisk eksisterer
$tries = 0
while (-not (Test-Path $OutWav) -and $tries -lt 10) { Start-Sleep -Milliseconds 25; $tries++ }
if (-not (Test-Path $OutWav)) { throw "ffmpeg skrev ingen WAV (forkert DeviceName eller busy?)" }

# Embedding + score
$enr      = Get-Content $EmbedJson -Raw | ConvertFrom-Json
$probeEmb = Compute-Embedding @($OutWav)
$score    = [Math]::Round((CosSim ([double[]]$enr.embedding) $probeEmb), 4)
$pass     = ($score -ge $Threshold)

if ($pass) {
  Write-Host ("[VERIFY] PASS score={0} (>= {1})" -f $score, $Threshold) -ForegroundColor Green
  1
} else {
  Write-Host ("[VERIFY] FAIL score={0} (< {1})" -f $score, $Threshold) -ForegroundColor Yellow
  0
}
