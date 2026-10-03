"""Rebuild audio/ from its recorded CC0 sources (see audio/LICENSES.md).

Usage (needs ffmpeg on PATH, plus numpy and soundfile; scipy makes it faster):

    python3 tools/build_audio.py [cache_dir]

Sources are downloaded once into cache_dir (default: .audio_cache, git-ignored). Output:
effects as 44.1 kHz 16-bit mono WAV with leading silence trimmed, short fades and gain set so
the K-weighted loudness of the sounding part is SFX_LUFS (capped so the sample peak stays at
or below PEAK_CAP); the music as OGG Vorbis stereo at MUSIC_LUFS, cut to its exact loop
length so it repeats without a gap. The helpers are the ones WormSlip's tools/build_audio.py
uses.
"""
import math, os, shutil, subprocess, sys, zipfile
import numpy as np
import soundfile as sf

FF = shutil.which("ffmpeg") or "/opt/homebrew/bin/ffmpeg"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(ROOT, ".audio_cache")
OUT = os.path.join(ROOT, "audio")
SR = 44100
SFX_LUFS = -16.0
MUSIC_LUFS = -18.0
PEAK_CAP = -1.0
## The music is 60 bars at 145 BPM; cutting it to exactly that keeps the loop on the beat.
MUSIC_BARS = 60
MUSIC_BPM = 145.0

KENNEY = "https://kenney.nl/media/pages/assets/"
FILES = {
    "kenney_interface.zip": KENNEY + "interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip",
    "kenney_digital.zip": KENNEY + "digital-audio/216eac4753-1677590265/kenney_digital-audio.zip",
    "kenney_impact.zip": KENNEY + "impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip",
    "kenney_casino.zip": KENNEY + "casino-audio/2472606a04-1721639069/kenney_casino-audio.zip",
    "kenney_jingles.zip": KENNEY + "music-jingles/f37e530b9e-1677590399/kenney_music-jingles.zip",
    "neon_sign_circuit_bpm145.ogg": "https://opengameart.org/sites/default/files/neon_sign_circuit_bpm145.ogg",
}


def fetch():
    os.makedirs(SRC, exist_ok=True)
    open(os.path.join(SRC, ".gdignore"), "a").close()  # keep Godot from importing the cache
    for name, url in FILES.items():
        out = os.path.join(SRC, name)
        if not os.path.exists(out):
            subprocess.run(["curl", "-sfL", "-o", out, url], check=True)
        if name.endswith(".zip") and not os.path.isdir(out[:-4]):
            zipfile.ZipFile(out).extractall(out[:-4])


def decode(path, af="", channels=1, ss=None, t=None):
    cmd = [FF, "-v", "error"]
    if ss is not None:
        cmd += ["-ss", str(ss)]
    if t is not None:
        cmd += ["-t", str(t)]
    cmd += ["-i", os.path.join(SRC, path)]
    if af:
        cmd += ["-af", af]
    cmd += ["-ac", str(channels), "-ar", str(SR), "-f", "f32le", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    x = np.frombuffer(raw, np.float32).astype(np.float64)
    return x.reshape(-1, channels) if channels > 1 else x


def biquad(x, b, a):
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    b0, b1, b2 = b
    _, a1, a2 = a
    for i in range(len(x)):
        v = b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, x[i], y1, v
        y[i] = v
    return y


def k_filter_coeffs(rate):
    # ITU-R BS.1770 K-weighting (high shelf + high pass), re-derived for any rate.
    f0, g, q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    k = math.tan(math.pi * f0 / rate)
    vh = 10 ** (g / 20)
    vb = vh ** 0.4996667741545416
    a0 = 1 + k / q + k * k
    shelf = ([(vh + vb * k / q + k * k) / a0, 2 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0],
             [1, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0])
    f0, q = 38.13547087602444, 0.5003270373238773
    k = math.tan(math.pi * f0 / rate)
    a0 = 1 + k / q + k * k
    hp = ([1, -2, 1], [1, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0])
    return shelf, hp


def kweight(x):
    shelf, hp = k_filter_coeffs(SR)
    try:
        from scipy.signal import lfilter  # fast path if available
        return lfilter(hp[0], hp[1], lfilter(shelf[0], shelf[1], x))
    except ImportError:
        return biquad(biquad(x, *shelf), *hp)


def loudness(x):
    """Gated integrated loudness (LUFS). Block size shrinks for very short sounds so
    a 50 ms click is measured over its own length instead of being diluted."""
    chans = x.T if x.ndim > 1 else [x]
    weighted = [kweight(c) for c in chans]
    n = len(weighted[0])
    block = min(int(0.4 * SR), max(int(0.02 * SR), n))
    hop = max(block // 4, 1)
    z = []
    for i in range(0, max(n - block, 0) + 1, hop):
        z.append(sum(np.mean(w[i:i + block] ** 2) for w in weighted))
    z = np.array(z)
    lk = -0.691 + 10 * np.log10(z + 1e-20)
    z = z[lk > -70]
    rel = -0.691 + 10 * np.log10(np.mean(z)) - 10
    z = z[(-0.691 + 10 * np.log10(z)) > rel]
    return -0.691 + 10 * np.log10(np.mean(z))


def active(x, db=-50.0):
    """Drop leading and trailing samples quieter than db relative to the peak."""
    env = np.abs(x)
    idx = np.where(env > env.max() * 10 ** (db / 20))[0]
    return x[idx[0]:idx[-1] + 1]


def soft_limit(x, drive_db):
    """tanh saturation that keeps the peak and lifts the body by up to drive_db, so
    peaky one-shots reach a usable loudness without clipping."""
    d = 10 ** (drive_db / 20)
    p = np.abs(x).max()
    return np.tanh(x / p * d) / np.tanh(d) * p


def fades(x, fin=0.001, fout=0.02):
    x = x.copy()
    a, b = int(fin * SR), int(fout * SR)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b) ** 2
    return x


def decay_tail(x, start, end):
    """Exponential-ish fade from `start` s to `end` s, then cut: a quick natural decay."""
    x = x[:int(end * SR)].copy()
    s = int(start * SR)
    n = len(x) - s
    if n > 0:
        x[s:] *= np.exp(-np.linspace(0, 6.0, n))
        x[-int(0.005 * SR):] *= np.linspace(1, 0, int(0.005 * SR))
    return x


def finish(name, x, target=SFX_LUFS):
    lu = loudness(x)
    gain = target - lu
    peak = 20 * np.log10(np.abs(x).max())
    gain = min(gain, PEAK_CAP - peak)
    y = x * 10 ** (gain / 20)
    path = os.path.join(OUT, name)
    sf.write(path, y.astype(np.float32), SR, subtype="PCM_16")
    print(f"{name:10s} {len(y) / SR:5.2f}s  loudness {loudness(y):6.1f} LUFS  peak {20 * np.log10(np.abs(y).max()):5.1f} dBFS"
          f"  (gain {gain:+.1f} dB{', peak-limited' if gain < target - lu - 0.05 else ''})")


def pitch(ratio):
    """Resample-based pitch change (also changes length), as a tape would."""
    return f"asetrate={SR}*{ratio:.6f},aresample={SR}"


def one(path, af="", fin=0.001, fout=0.02, db=-50.0):
    return fades(active(decode(path, af), db), fin, fout)


def build_sfx():
    ui = "kenney_interface/Audio/"
    digital = "kenney_digital/Audio/"
    impact = "kenney_impact/Audio/"

    # UI and driving: short and light, since they play many times a run.
    finish("click.wav", one(ui + "click_001.ogg", fout=0.005))
    finish("switch.wav", one(ui + "toggle_002.ogg"))  # colour switch
    finish("orb.wav", one(ui + "glass_002.ogg"), SFX_LUFS - 3.0)  # every orb picked up
    finish("gate.wav", one(ui + "confirmation_001.ogg"))  # passed a gate in its colour
    finish("warn.wav", one(ui + "error_004.ogg"))  # low fuel
    finish("start.wav", one(ui + "maximize_006.ogg"))  # GO!

    # A lane change is a quick swish: a card slid across felt, cut to its swell and
    # high-passed so it stays out of the way of the music's bass.
    x = active(decode("kenney_casino/Audio/card-slide-1.ogg", "highpass=f=400:p=2"))
    finish("lane.wav", soft_limit(fades(x[:int(0.16 * SR)], 0.01, 0.05), 4), SFX_LUFS - 4.0)
    finish("coin.wav", one("kenney_casino/Audio/chip-lay-1.ogg"))

    # Arcade bleeps for the kart's moves and power-ups.
    finish("jump.wav", one(digital + "phaserUp5.ogg"))
    finish("fuel.wav", one(digital + "powerUp2.ogg"))
    finish("prism.wav", one(digital + "powerUp11.ogg"))  # Prism Overdrive starts
    finish("revive.wav", one(digital + "powerUp7.ogg"))
    finish("sputter.wav", one(digital + "lowDown.ogg"))  # out of fuel

    # Hits: a soft thump on landing, glass for smashing through in Overdrive, and a metal
    # crunch over a heavy body hit for a crash.
    finish("land.wav", one(impact + "impactSoft_medium_001.ogg"), SFX_LUFS - 3.0)
    finish("smash.wav", soft_limit(one(impact + "impactGlass_heavy_000.ogg"), 10))
    metal = active(decode(impact + "impactMetal_heavy_000.ogg"))
    body = active(decode(impact + "impactSoft_heavy_000.ogg"))
    mix = np.zeros(max(len(metal), len(body)))
    mix[:len(metal)] += metal
    mix[:len(body)] += body * 10 ** (-4 / 20)
    finish("crash.wav", soft_limit(fades(mix, 0.001, 0.08), 10))

    # A short pizzicato jingle when a world or vehicle unlocks.
    x = active(decode("kenney_jingles/Audio/Pizzicato jingles/jingles_PIZZI01.ogg"))
    finish("unlock.wav", decay_tail(x, 0.8, 1.1))


def build_music():
    # MintoDog's "Neon sign Circuit", made to loop. It is cut to exactly MUSIC_BARS bars so
    # the loop lands on the downbeat, and gets no fades: the end runs straight into the start.
    x = decode("neon_sign_circuit_bpm145.ogg", channels=2)
    n = int(round(MUSIC_BARS * 4 * 60.0 / MUSIC_BPM * SR))
    x = x[:n]
    lu = loudness(x)
    gain = min(MUSIC_LUFS - lu, PEAK_CAP - 20 * np.log10(np.abs(x).max()))
    y = (x * 10 ** (gain / 20)).astype(np.float32)
    path = os.path.join(OUT, "music.ogg")
    # libsndfile maps compression_level to Vorbis quality (q = 1 - level): 0.7 is about 96 kbps.
    # Written in chunks: one big write crashes libsndfile's Vorbis encoder.
    with sf.SoundFile(path, "w", SR, 2, format="OGG", subtype="VORBIS", compression_level=0.7) as f:
        for i in range(0, len(y), 8192):
            f.write(y[i:i + 8192])
    print(f"music.ogg  {len(y) / SR:6.2f}s  loudness {loudness(y):6.1f} LUFS  peak {20 * np.log10(np.abs(y).max()):5.1f} dBFS  "
          f"{os.path.getsize(path) / 1024:.0f} KiB (gain {gain:+.1f} dB)")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    fetch()
    build_sfx()
    build_music()
