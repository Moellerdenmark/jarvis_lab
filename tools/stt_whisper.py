import argparse, os, sys, re
import numpy as np
import sounddevice as sd
from scipy.io.wavfile import write as wav_write

os.environ["KMP_WARNINGS"] = "0"

def record(seconds=6, samplerate=16000, channels=1, device=None):
    sd.default.samplerate = samplerate
    sd.default.channels = channels
    if device is not None:
        sd.default.device = (device, None)  # (input_device, output_device)
    audio = sd.rec(int(seconds*samplerate), dtype="float32")
    sd.wait()
    audio = np.clip(audio, -1.0, 1.0)
    pcm16 = (audio * 32767).astype(np.int16)
    return samplerate, pcm16

def fixups(text: str) -> str:
    # Ret typiske fejl for "Jarvis" og nogle danske fraser
    repl = [
        (r"\bjob\s*is\b", "jarvis"),
        (r"\bjavis\b", "jarvis"),
        (r"\bjarivs\b", "jarvis"),
        (r"\bchavez\b", "jarvis"),
        (r"\bcharvis\b", "jarvis"),
        (r"\bjav\s*is\b", "jarvis"),
        (r"\bjermis\b", "jarvis"),
        (r"\bhøj\b\s+jarvis", "hej jarvis"),  # "høj jarvis" -> "hej jarvis"
    ]
    out = text
    for rx, rep in repl:
        out = re.sub(rx, rep, out, flags=re.IGNORECASE)
    return out

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--outdir", required=True)
    p.add_argument("--seconds", type=int, default=6)
    p.add_argument("--lang", default="da")
    p.add_argument("--model", default="small")           # small -> hurtig; medium -> bedre
    p.add_argument("--device", type=int, default=None)   # input device index
    args = p.parse_args()

    os.makedirs(args.outdir, exist_ok=True)
    wav_path = os.path.join(args.outdir, "jarvis_in.wav")
    txt_path = os.path.join(args.outdir, "last_stt.txt")

    # Optag
    sr, pcm16 = record(seconds=args.seconds, device=args.device)
    wav_write(wav_path, sr, pcm16)

    # Transskriber
    text = ""
    try:
        from faster_whisper import WhisperModel
        model = WhisperModel(args.model, device="cpu", compute_type="int8")
        # Bias mod dansk + Jarvis, lidt stærkere søgning end standard
        segments, info = model.transcribe(
            wav_path,
            language=args.lang,
            vad_filter=True,
            initial_prompt="Dette er dansk tale. Navnet 'Jarvis' kan forekomme. Vær opmærksom på kommandoer.",
            beam_size=1,
            best_of=1,
            condition_on_previous_text=False
        )
        text = "".join(seg.text for seg in segments).strip()
        text = fixups(text)
    except Exception as e:
        print(f"[WARN] Whisper: {e}", file=sys.stderr)

    with open(txt_path, "w", encoding="utf-8") as f:
        f.write(text)

    print(f"[STT] -> {text}")

if __name__ == "__main__":
    main()




