param(
    [int]$Duration = 5
)

$ErrorActionPreference = "Stop"

$Root   = "C:\Users\gubbi\jarvis_core"
$OutDir = Join-Path $Root "out\listen"
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

$PyFile = Join-Path $Root "tools\_listen.py"

# ==== skriv lille python script til at optage ====
@"
import sys, sounddevice as sd, scipy.io.wavfile as wav, time

duration = int(sys.argv[1]) if len(sys.argv) > 1 else 5
samplerate = 16000
print(f"[PY] Recording {duration} sec at {samplerate} Hz...")

data = sd.rec(int(duration * samplerate), samplerate=samplerate, channels=1, dtype='int16')
sd.wait()
out = sys.argv[2]
wav.write(out, samplerate, data)
print(f"[PY] Saved: {out}")
"@ | Set-Content -Path $PyFile -Encoding UTF8 -Force

# ==== definer output wav ====
$WavFile = Join-Path $OutDir ("mic_{0:yyyyMMdd_HHmmss}.wav" -f (Get-Date))

# ==== kør python optagelse ====
$env:Path = "C:\Users\gubbi\jarvis_core\.venv\Scripts;" + $env:Path
python $PyFile $Duration $WavFile

Write-Host "[INFO] Optagelse færdig: $WavFile" -ForegroundColor Green

# ==== kør Whisper på dansk ====
python -m whisper "$WavFile" --language da --model small
