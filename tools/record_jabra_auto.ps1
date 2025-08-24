param([int]$Seconds = 6)

$py = "C:\Users\gubbi\jarvis_core\.venv\Scripts\python.exe"

$code = @"
import sounddevice as sd, soundfile as sf, numpy as np, sys

# læs varighed fra argv
dur = float(sys.argv[1])
sr = 16000
probe = 1.2  # sek pr. kandidat
candidates = [6, 1, 12, 21]  # DirectSound, MME, WASAPI, WDM-KS
out = r"C:\Users\gubbi\jarvis_core\out\listen\jarvis_in.wav"

def rms(x: np.ndarray) -> float:
    x = x.astype('float32')
    return float(np.sqrt((x**2).mean()))

best = None
for idx in candidates:
    try:
        name = sd.query_devices()[idx]['name']
        rec = sd.rec(int(probe*sr), samplerate=sr, channels=1, dtype='float32', device=idx)
        sd.wait()
        level = rms(rec)
        print(f"TRY idx {idx} | {name} | RMS={level:.6f}")
        if best is None or level > best[2]:
            best = (idx, name, level)
    except Exception as e:
        print(f"FAIL idx {idx}: {e}")

if best is None:
    print("No usable input"); raise SystemExit(1)

idx, name, level = best
print(f"BEST idx {idx} | {name} | RMS={level:.6f}")
print(f"Recording {dur}s on BEST idx {idx} …")
full = sd.rec(int(dur*sr), samplerate=sr, channels=1, dtype='float32', device=idx)
sd.wait()
sf.write(out, np.clip(full, -0.99, 0.99), sr, subtype='PCM_16')
print("Saved:", out)
"@

# kør python og giv $Seconds som argument
$code | & $py - @("$Seconds")
