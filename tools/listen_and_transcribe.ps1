param(
  [int]$Seconds = 6,
  [switch]$Copy,
  [switch]$Beep
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root  = "C:\Users\gubbi\jarvis_core"
$Tools = Join-Path $Root "tools"
$Rec   = Join-Path $Tools "record_jabra_auto.ps1"   # auto-vælger bedste Jabra input
$STT   = Join-Path $Tools "stt_force_da.ps1"
$Last  = Join-Path (Join-Path $Root "out\listen") "last_stt.txt"
$Py    = "C:\Users\gubbi\jarvis_core\.venv\Scripts\python.exe"
$TTS   = Join-Path $Tools "tts_sapi.ps1"

if (!(Test-Path $Rec)) { throw "Mangler recorder: $Rec" }
if (!(Test-Path $STT)) { throw "Mangler STT: $STT" }
if (!(Test-Path $TTS)) { throw "Mangler TTS: $TTS" }

Write-Host "[1/3] Optager $Seconds sek..." -ForegroundColor Cyan
& $Rec $Seconds | Write-Host

Write-Host "[2/3] Kører STT (da, uden VAD)..." -ForegroundColor Cyan
& $STT | Write-Host

Write-Host "[3/3] Resultat:" -ForegroundColor Cyan
if (Test-Path $Last) {
  $txt = Get-Content $Last -Raw
  if ($txt) {
    Write-Host $txt -ForegroundColor Green
    if ($Copy) { Set-Clipboard -Value $txt; Write-Host "(Kopieret til clipboard)" -ForegroundColor DarkGray }

    # TAL DET HØJT med Helle
    & $Py $TTS --text $txt --voice "MSTTS_V110_daDK_Helle" --rate 200 --volume 1.0 | Out-Null
  } else {
    Write-Host "<EMPTY>" -ForegroundColor Yellow
  }
} else {
  Write-Host "Filen findes ikke: $Last" -ForegroundColor Yellow
}

if ($Beep) { [console]::Beep(1000,200) }
