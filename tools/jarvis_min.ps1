param(
  [string]$Model    = "llama3.1:8b",
  [int]   $DeviceID = 1,
  [int]   $Duration = 6
)

$ErrorActionPreference = "Stop"
$Root  = "C:\Users\gubbi\jarvis_core"
$Tools = Join-Path $Root "tools"
$Out   = Join-Path $Root "out\listen"
$Py    = Join-Path $Root ".venv\Scripts\python.exe"

$WavIn  = Join-Path $Out  "jarvis_in.wav"
$TxtOut = Join-Path $Out  "last_stt.txt"

function Record-Audio {
  Write-Host "🎤 Tal nu (optager $Duration s)..." -ForegroundColor Yellow
  & $Py (Join-Path $Tools "record.py") --out $WavIn --seconds $Duration --device $DeviceID
  if (-not (Test-Path $WavIn)) { throw "Ingen optagefil blev lavet: $WavIn" }
}

function Transcribe-Audio {
  Write-Host "[STT] Transskriberer $WavIn ..." -ForegroundColor Cyan
  stt "$WavIn" | Out-Null
  if (Test-Path $TxtOut) { return (Get-Content $TxtOut -Raw).Trim() }
  return ""
}

function Speak {
  param([string]$Text)
  # Brug eksisterende stemme – INGEN -Voice parameter her
  & (Join-Path $Tools "say.ps1") -Text $Text
}

Write-Host "🎙 Jarvis klar. Sig 'stop' eller 'slut' for at afslutte." -ForegroundColor Green
do {
  Record-Audio
  $msg = Transcribe-Audio
  if (-not $msg) { continue }

  Write-Host "🗣 Du: $msg" -ForegroundColor White

  if ($msg -match '\b(stop|slut)\b') {
    Speak "Okay, jeg stopper nu."
    break
  }

  # Svar foreløbigt bare med at gentage (du kan koble LLM på her senere)
  Speak "Jeg hørte: $msg"

} while ($true)
