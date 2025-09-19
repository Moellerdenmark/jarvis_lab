import sys
import sounddevice as sd
import soundfile as sf

"""
Brug:
  python record6s.py <output_wav> <device_id> [samplerate] [seconds]

- output_wav: fuld sti til WAV der SKAL gemmes (fx C:\...\jarvis_in.wav)
- device_id : sounddevice device index (fx 1 eller 12)
- samplerate: default 16000
- seconds   : default 6
"""

if len(sys.argv) < 3:
    print("Usage: python record6s.py <output_wav> <device_id> [samplerate] [seconds]")
    sys.exit(2)

out_wav     = sys.argv[1]
device_id   = int(sys.argv[2])
samplerate  = int(sys.argv[3]) if len(sys.argv) > 3 else 16000
seconds     = int(sys.argv[4]) if len(sys.argv) > 4 else 6

print(f"[PY] Recording {seconds}s at {samplerate} Hz (device={device_id}) ...", flush=True)
audio = sd.rec(int(seconds * samplerate), samplerate=samplerate, channels=1, dtype="int16", device=device_id)
sd.wait()
sf.write(out_wav, audio, samplerate)
print(f"[PY] Saved: {out_wav}", flush=True)
