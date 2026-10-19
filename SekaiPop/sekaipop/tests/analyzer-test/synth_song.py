"""Makes a made-up 120 BPM song (kick, snare, hats, bass line, a sung-like lead)
and the list of when each thing really happens, to test sekai_analyzer.py.
Only a sanity check: it says nothing about how real recordings will behave."""
import numpy as np

SR = 44100


def kick(n=SR // 4):
    t = np.arange(n) / SR
    f = 50 + 90 * np.exp(-t * 28)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 11) * 0.9


def snare(n=SR // 5, rng=None):
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    # a bit of band-passing by differencing: brighter noise
    noise = noise - 0.5 * np.concatenate(([0], noise[:-1]))
    return (noise * np.exp(-t * 22) * 0.35 + np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25) * 0.5)


def hat(n=SR // 12, rng=None):
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    hp = noise - np.concatenate(([0], noise[:-1]))
    hp = hp - np.concatenate(([0], hp[:-1]))
    return hp * np.exp(-t * 70) * 0.18


def voice(f0_track, level, n):
    """Harmonic tone with a little vibrato, f0_track in Hz per sample."""
    ph = 2 * np.pi * np.cumsum(f0_track) / SR
    sig = np.zeros(n)
    for k in range(1, 9):
        sig += np.sin(k * ph) / k ** 1.1
    return sig * level


def make(seconds=24, seed=1):
    rng = np.random.default_rng(seed)
    n = seconds * SR
    mix = np.zeros(n)
    truth = {"k": [], "s": [], "h": [], "b": [], "lead": []}
    beat = 0.5
    # drums: kick on every beat, snare on 2 and 4, hats on the off-eighths
    for i in range(int(seconds / beat)):
        t = i * beat
        a = int(t * SR)
        k = kick()
        mix[a:a + len(k)] += k[: n - a][: len(k)] if a + len(k) <= n else k[: n - a]
        truth["k"].append(t)
        if i % 2 == 1:
            s = snare(rng=rng)
            if a + len(s) <= n:
                mix[a:a + len(s)] += s
            truth["s"].append(t)
        th = t + beat / 2
        a = int(th * SR)
        h = hat(rng=rng)
        if a + len(h) <= n:
            mix[a:a + len(h)] += h
        truth["h"].append(th)
    # bass line: notes of 0.5 s on a repeating pattern (A1 55, C2 65.4, D2 73.4, E2 82.4)
    pat = [55.0, 55.0, 65.41, 73.42, 82.41, 73.42, 65.41, 55.0]
    for i in range(int(seconds / beat)):
        f = pat[i % len(pat)]
        a = int(i * beat * SR)
        m = int(beat * SR * 0.9)
        if a + m > n:
            break
        tt = np.arange(m) / SR
        env = np.minimum(1, tt * 80) * np.exp(-tt * 2.0)
        mix[a:a + m] += (np.sin(2 * np.pi * f * tt) + 0.4 * np.sin(2 * np.pi * 2 * f * tt)) * env * 0.35
        if pat[i % len(pat)] != pat[(i - 1) % len(pat)]:
            truth["b"].append(i * beat)
    # lead: phrases (start, length, f0 start, f0 end), with silence between them
    phrases = [(2.0, 1.6, 330, 330), (4.2, 1.2, 392, 440), (6.5, 2.5, 294, 349),
               (10.0, 1.0, 440, 440), (12.0, 2.0, 262, 330), (15.0, 1.4, 349, 392),
               (18.0, 3.0, 392, 392), (22.0, 1.5, 330, 294)]
    for (st, ln, f0, f1) in phrases:
        a = int(st * SR)
        m = int(ln * SR)
        if a + m > n:
            break
        tt = np.arange(m) / SR
        f = np.linspace(f0, f1, m) * (1 + 0.006 * np.sin(2 * np.pi * 5.5 * tt))
        env = np.minimum(1, tt * 30) * np.minimum(1, (ln - tt) * 30)
        mix[a:a + m] += voice(f, 0.22, m) * env
        truth["lead"].append((st, st + ln))
    mix = mix / (np.max(np.abs(mix)) * 1.1)
    return mix.astype(np.float32), truth


if __name__ == "__main__":
    import sys
    x, truth = make()
    (np.clip(x, -1, 1) * 32767).astype("<i2").tofile(sys.argv[1] if len(sys.argv) > 1 else "song.raw")
