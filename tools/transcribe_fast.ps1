param(
  [string]$WavIn   = "C:\Users\gubbi\jarvis_core\out\listen\jarvis_in_boosted.wav",
  [string]$ModelId = "tiny",     # tiny/base/small/medium
  [string]$Compute = "int8"      # int8/int8_float16/float16 (CPU: int8 er hurtigst)
)
$ErrorActionPreference = "Stop"
$Root = "C:\Users\gubbi\jarvis_core"
$Py   = Join-Path $Root ".venv\Scripts\python.exe"

# Kør inline Python med faster-whisper
$code = @"
from faster_whisper import WhisperModel
import sys, os

wav = r"$WavIn"
model_id = r"$ModelId"
compute = r"$Compute"
out_txt = os.path.join(r"$Root", "out", "listen", "last_stt.txt")

model = WhisperModel(model_id, device="cpu", compute_type=compute)
segments, info = model.transcribe(wav, language="da", vad_filter=True, vad_parameters=dict(min_silence_duration_ms=200))

with open(out_txt, "w", encoding="utf-8") as f:
    for seg in segments:
        f.write(seg.text.strip() + " ")
print("OK:", out_txt)
"@

$Tmp = Join-Path $env:TEMP "fw_run.py"
Set-Content -Path $Tmp -Value $code -Encoding UTF8
& $Py $Tmp
Remove-Item $Tmp -Force -ErrorAction SilentlyContinue
