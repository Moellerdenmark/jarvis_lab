import argparse, os, sys, glob, numpy as np
try:
    from resemblyzer import VoiceEncoder, preprocess_wav
    import soundfile as sf
except Exception as e:
    print(f"[ERR] resemblyzer/soundfile mangler: {e}", file=sys.stderr)
    sys.exit(3)

BASE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SPKDIR = os.path.join(BASE, "models", "speakers")
os.makedirs(SPKDIR, exist_ok=True)
enc = VoiceEncoder()

def embed(path):
    wav, sr = sf.read(path)
    wav = preprocess_wav(wav, source_sr=sr)
    return enc.embed_utterance(wav)

def enroll(name, files):
    embs = [embed(f) for f in files]
    mean = np.mean(np.vstack(embs), axis=0)
    out = os.path.join(SPKDIR, f"{name}.npy")
    np.save(out, mean)
    print(out)

def cos(a,b): return float(np.dot(a,b) / (np.linalg.norm(a)*np.linalg.norm(b) + 1e-9))

def verify(wav, who, minscore):
    e = embed(wav)
    files = [os.path.join(SPKDIR, f"{n}.npy") for n in who] if who else glob.glob(os.path.join(SPKDIR,"*.npy"))
    if not files:
        print("[ERR] ingen kendte stemmer i models/speakers", file=sys.stderr); sys.exit(4)
    best = ("", -1.0)
    for f in files:
        name = os.path.splitext(os.path.basename(f))[0]
        ref = np.load(f)
        s = cos(e, ref)
        if s > best[1]: best = (name, s)
    name, score = best
    if score >= minscore:
        print(f"ACCEPT {name} {score:.3f}")
        sys.exit(0)
    else:
        print(f"REJECT {name} {score:.3f}")
        sys.exit(2)

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    p_en = sub.add_parser("enroll"); p_en.add_argument("--name", required=True); p_en.add_argument("--files", nargs="+", required=True)
    p_v  = sub.add_parser("verify"); p_v.add_argument("--file", required=True); p_v.add_argument("--min", type=float, default=0.82); p_v.add_argument("--who", nargs="*")
    args = ap.parse_args()
    if args.cmd == "enroll": enroll(args.name, args.files)
    else: verify(args.file, args.who, args.min)
