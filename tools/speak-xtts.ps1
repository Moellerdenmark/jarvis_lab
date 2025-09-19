param(
  [Parameter(Mandatory=$true)][string] $Text,
  [string] $Out = "C:\Users\gubbi\jarvis_core\out.wav",
  [string] $SpeakerWav = $null
)

$PyExe = "C:\Users\gubbi\jarvis_core\.venv\Scripts\python.exe"
if (-not (Test-Path $PyExe)) { throw "Python i .venv blev ikke fundet: $PyExe" }

$payload = @{ text = $Text; out = $Out; lang = "da" }
if ($SpeakerWav) { $payload["speaker"] = $SpeakerWav }

# send JSON som argument 1
$json = ($payload | ConvertTo-Json -Depth 5 -Compress)
& $PyExe "C:\Users\gubbi\jarvis_core\tools\_xtts_say.py" $json | Out-Null

if (-not (Test-Path $Out)) { throw "XTTS lavede ikke filen: $Out" }

# Afspil i standardafspiller
Start-Process $Out
