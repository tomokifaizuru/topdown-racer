"""Generates the original procedural sound effects in audio/ (no external assets)."""
import numpy as np, struct, os
SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
def write_wav(name, data, loop=False):
    data = np.clip(data, -1, 1)
    pcm = (data * 32000).astype("<i2").tobytes()
    fmt = struct.pack("<HHIIHH", 1, 1, SR, SR * 2, 2, 16)
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    chunks += b"data" + struct.pack("<I", len(pcm)) + pcm
    if loop:  # 'smpl' chunk with a forward loop over the whole file
        n = len(data)
        smpl = struct.pack("<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, n - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)
rng = np.random.default_rng(3)
t = np.arange(SR) / SR  # 1 second
# Engine: 60 Hz base with harmonics (integer cycles -> seamless loop)
f = 60.0
eng = (0.55 * np.sin(2*np.pi*f*t) + 0.3 * np.sin(2*np.pi*2*f*t + 0.5) + 0.2 * np.sin(2*np.pi*3*f*t + 1.1)
       + 0.12 * np.sign(np.sin(2*np.pi*f*t)) + 0.08 * np.sin(2*np.pi*5*f*t))
eng *= 0.85 + 0.15 * np.sin(2*np.pi*10*t)  # firing pulse wobble
eng += 0.04 * rng.standard_normal(SR)
write_wav("engine.wav", eng * 0.6, loop=True)
# Skid: band-limited noise + squeal, loop
n = SR // 2
tt = np.arange(n) / SR
noise = rng.standard_normal(n)
noise = np.convolve(noise, np.ones(6)/6, mode="same")
squeal = np.sin(2*np.pi*(900*tt + 30*np.sin(2*np.pi*8*tt)))  # 900Hz*0.5s = integer cycles
skid = 0.5 * noise + 0.35 * squeal
fade = 200
skid[:fade] *= np.linspace(0.6, 1, fade); skid[-fade:] *= np.linspace(1, 0.6, fade)
write_wav("skid.wav", skid * 0.7, loop=True)
def tone(freq, dur, vol=0.5):
    tt = np.arange(int(SR*dur)) / SR
    w = np.sign(np.sin(2*np.pi*freq*tt)) * 0.6 + np.sin(2*np.pi*freq*tt) * 0.4
    env = np.minimum(1, np.minimum(tt / 0.005, (dur - tt) / 0.04))
    return w * env * vol
write_wav("beep.wav", tone(660, 0.18))
write_wav("go.wav", tone(990, 0.5))
# Bump: short low thud + noise
n = int(SR*0.22); tt = np.arange(n)/SR
bump = (np.sin(2*np.pi*(90 - 120*tt)*tt) * 0.8 + 0.5*rng.standard_normal(n)*np.exp(-tt*40)) * np.exp(-tt*18)
write_wav("bump.wav", bump * 0.8)
print("ok")
