param(
  [Parameter(Mandatory=$true)][string]$Name,
  [int]$Samples = 5,
  [double]$Seconds = 2.0,
  [string]$DeviceName = "Microphone (Jabra SPEAK 510 USB)"
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\sv_common.ps1"

$Root    = Split-Path -Parent $PSScriptRoot
$DataDir = Join-Path $Root "data\voices\$Name"
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

Write-Host "[ENROLL] Name=$Name Samples=$Samples Sec=$Seconds Device='$DeviceName'" -ForegroundColor Cyan

[string[]]$wavList = @()
for ($i=1; $i -le $Samples; $i++) {
  $out = Join-Path $DataDir ("enroll_{0:D3}.wav" -f $i)
  Write-Host ("  -> Optager {0}/{1} → {2}" -f $i,$Samples,$out)
  ffmpeg -hide_banner -loglevel warning -f dshow -i "audio=$DeviceName" -t $Seconds -ac 1 -ar 16000 -vn -acodec pcm_s16le -y "$out" 2>$null
  $wavList += ,$out
}

$emb = Compute-Embedding $wavList
$embedJson = Join-Path $DataDir "embed.json"
$obj = [PSCustomObject]@{ name=$Name; model="ps-mfcc-26d"; dim=$emb.Length; embedding=$emb }
$obj | ConvertTo-Json -Depth 4 | Set-Content -Path $embedJson -Encoding UTF8

Write-Host "[ENROLL] Gemte: $embedJson" -ForegroundColor Green
