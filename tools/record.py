# record.py – enkel 16 kHz mono optagelse
import argparse, sounddevice as sd, numpy as np, scipy.io.wavfile as wav, os
p = argparse.ArgumentParser()
p.add_argument("--out", required=True)
p.add_argument("--seconds", type=float, default=6)
p.add_argument("--device", type=int, default=None)
p.add_argument("--rate", type=int, default=16000)
a = p.parse_args()
sd.default.device = a.device
sd.default.samplerate = a.rate
sd.default.channels = 1
audio = sd.rec(int(a.seconds * a.rate), dtype="int16")
sd.wait()
os.makedirs(os.path.dirname(a.out), exist_ok=True)
wav.write(a.out, a.rate, audio)
print(f"[PY] Saved: {a.out}")
