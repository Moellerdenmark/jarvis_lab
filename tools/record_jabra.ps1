param([int]$Seconds = 5)

$py = "C:\Users\gubbi\jarvis_core\.venv\Scripts\python.exe"
$bestIdx = 1

$code = @"
import sounddevice as sd, soundfile as sf, numpy as np, sys
idx = int(sys.argv[1]); dur = float(sys.argv[2]); sr=16000
out = r"C:\Users\gubbi\jarvis_core\out\listen\jarvis_in.wav"
print("Recording from index", idx, "->", sd.query_devices()[idx]["name"])
rec = sd.rec(int(dur*sr), samplerate=sr, channels=1, dtype="float32", device=idx)
sd.wait()
sf.write(out, np.clip(rec, -0.99, 0.99), sr, subtype="PCM_16")
print("Saved:", out)
"@

# Kør Python med korrekt argument-videregivelse via PowerShell pipe
$code | & $py - @("$bestIdx", "$Seconds")
