# PATH: tools\spk_embed.py
import sys, json
import numpy as np
try:
    import soundfile as sf
    import librosa
except Exception as e:
    print(json.dumps({"error": f"Missing deps: {e}"})); sys.exit(1)

def l2norm(x):
    n = np.linalg.norm(x) + 1e-9
    return x / n

def embed(wav_path):
    y, sr = sf.read(wav_path, dtype='float32', always_2d=False)
    if y.ndim > 1: y = np.mean(y, axis=1)
    if sr != 16000:
        y = librosa.resample(y, orig_sr=sr, target_sr=16000)
        sr = 16000
    if len(y) < sr//2:
        y = np.pad(y, (0, sr//2 - len(y)), mode='constant')
    yt, _ = librosa.effects.trim(y, top_db=25)
    mfcc = librosa.feature.mfcc(y=yt if len(yt)>0 else y, sr=sr, n_mfcc=40)
    mu  = np.mean(mfcc, axis=1)
    sd  = np.std(mfcc, axis=1)
    v = np.concatenate([mu, sd]).astype('float32')
    v = l2norm(v)
    return v.tolist()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error":"usage: spk_embed.py <wav>"})); sys.exit(2)
    try:
        vec = embed(sys.argv[1])
        print(json.dumps({"embedding": vec}))
    except Exception as e:
        print(json.dumps({"error": str(e)})); sys.exit(3)
