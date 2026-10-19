"""NOT aubio. A stand-in with the same calls the analyzer makes (pitch(),
set_unit, set_silence, get_confidence, tempo(), get_last, get_bpm,
get_confidence), so the glue code can be run where aubio isn't installed. It
proves the plumbing only; it says nothing about how real aubio performs."""
import numpy as np
version = "stub"
float_type = np.float32


class pitch:
    def __init__(self, method, buf, hop, sr):
        assert method == "yinfft" and buf == hop
        self.sr, self.n, self.conf = sr, buf, 0.0

    def set_unit(self, u): assert u == "Hz"
    def set_silence(self, db): pass

    def __call__(self, x):
        assert x.dtype == np.float32 and len(x) == self.n
        f = np.fft.rfft(x, 2 * self.n)
        r = np.fft.irfft(f * np.conj(f))[: self.n // 2]
        if r[0] <= 1e-12:
            self.conf = 0.0
            return np.array([0.0], np.float32)
        r = r / r[0]
        lo = 20
        k = lo + int(np.argmax(r[lo:]))
        self.conf = float(max(0.0, r[k]))
        return np.array([self.sr / k], np.float32)

    def get_confidence(self): return self.conf


class tempo:
    def __init__(self, method, win, hop, sr):
        assert method == "default" and hop == 512
        self.sr, self.hop, self.n, self.last = sr, hop, 0, 0

    def __call__(self, x):
        assert x.dtype == np.float32 and len(x) == self.hop
        a, b = self.n, self.n + self.hop
        self.n = b
        period = int(0.5 * self.sr)
        if b // period > a // period:
            self.last = (b // period) * period
            return np.array([self.last], np.float32)
        return np.array([0.0], np.float32)

    def get_last(self): return self.last
    def get_bpm(self): return 120.0
    def get_confidence(self): return 0.8
