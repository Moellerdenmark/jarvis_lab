from faster_whisper import WhisperModel
m = WhisperModel("small", device="cpu", compute_type="int8")
print("OK – model hentet og klar")
