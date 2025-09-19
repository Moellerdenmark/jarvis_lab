param(
    [int]$DeviceID = 1,   # Brug 1 (Headset KENDO) eller 12 (WASAPI) iflg. din liste
    [int]$Duration = 5
)

$ErrorActionPreference = "Stop"

$ROOT   = "C:\Users\gubbi\jarvis_core"
$PYTHON = Join-Path $ROOT ".venv\Scripts\python.exe"
$WAV    = Join-Path (Join-Path $ROOT "out\listen") "mic_input.wav"

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
  Write-Warning "ffmpeg ikke fundet i PATH (men du har det allerede iflg. tidligere tjek)."
}

# --- Python: optag til WAV ---
$recCode = @"
import sounddevice as sd
import numpy as np
from scipy.io.wavfile import write
import sys

device   = int(sys.argv[1])
seconds  = int(sys.argv[2])
fs       = 16000
out_path = sys.argv[3]

print(f"[PY] Recording {seconds}s on device {device} @ {fs} Hz...")
audio = sd.rec(int(seconds*fs), samplerate=fs, channels=1, dtype='float32', device=device)
sd.wait()
int16 = (audio * 32767).astype('int16')
write(out_path, fs, int16)
print(f"[PY] Saved: {out_path}")
"@

$recPy = Join-Path $TOOLS "_rec_tmp.py"
Set-Content -Path $recPy -Value $recCode -Encoding UTF8
& $PYTHON $recPy $DeviceID $Duration $WAV
Remove-Item $recPy -Force

# --- Python: transskriber med Whisper (dansk) ---
$trCode = @"
import whisper, sys
wav = sys.argv[1]
print("[PY] Loading Whisper base...")
model = whisper.load_model("base")
result = model.transcribe(wav, language="da")
print("TRANSKRIBERET:", result["text"])
"@
$trPy = Join-Path $TOOLS "_tr_tmp.py"
Set-Content -Path $trPy -Value $trCode -Encoding UTF8
& $PYTHON $trPy $WAV
Remove-Item $trPy -Force
