import sounddevice as sd
import numpy as np
import scipy.io.wavfile as wav
import whisper

device   = 1
duration = 5
samplerate = 16000

print(f"[INFO] Optager {duration} sek fra device {device} ...")
audio = sd.rec(int(duration*samplerate), samplerate=samplerate, channels=1, dtype='float32', device=device)
sd.wait()

wav.write("recorded.wav", samplerate, (audio*32767).astype(np.int16))
print("[OK] Lyd gemt som recorded.wav")

model = whisper.load_model("base")
result = model.transcribe("recorded.wav", language="da")
print("[TRANSKRIBERET]")
print(result["text"])
