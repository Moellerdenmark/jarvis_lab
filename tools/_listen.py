import sys, sounddevice as sd, scipy.io.wavfile as wav, time

duration = int(sys.argv[1]) if len(sys.argv) > 1 else 5
samplerate = 16000
print(f"[PY] Recording {duration} sec at {samplerate} Hz...")

data = sd.rec(int(duration * samplerate), samplerate=samplerate, channels=1, dtype='int16')
sd.wait()
out = sys.argv[2]
wav.write(out, samplerate, data)
print(f"[PY] Saved: {out}")
