import argparse, os, sys, torch
from TTS.api import TTS

parser = argparse.ArgumentParser()
parser.add_argument("--text", required=True)
parser.add_argument("--out", required=True)
parser.add_argument("--lang", default="da")
parser.add_argument("--speaker", default=None)  # optional wav to clone
args = parser.parse_args()

# cpu only
device = "cuda" if torch.cuda.is_available() else "cpu"

tts = TTS(model_name="tts_models/multilingual/multi-dataset/xtts_v2",
          progress_bar=False, gpu=(device=="cuda"))

# ensure output folder exists
os.makedirs(os.path.dirname(args.out), exist_ok=True)

tts.tts_to_file(
    text=args.text,
    file_path=args.out,
    speaker_wav=args.speaker,
    language=args.lang
)

print(f"[OK] Wrote: {args.out}")
