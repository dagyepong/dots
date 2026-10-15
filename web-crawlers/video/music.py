"""Original cheerful soundtrack for the Web crawlers video, synthesized from scratch.

    python music.py [--out build/music.wav] [--seed 7]

G major, 120 BPM, 4/4, 11 bars = exactly 22.000 s (48 kHz stereo, 16-bit).
Only numpy + the standard library (no scipy: it is binary-incompatible with the
installed numpy here). Every sound is an oscillator / noise burst with an envelope.

Section map (bar = 2.000 s; the video cuts on these lines):
  0     intro    Cmaj7 | D        shaker, bell teaser, riser into bar 1
  1-4   A        G D Em C         bouncy groove + main melody (the call phrase)
  5-6   B        C D/D7           half-time, plucky arpeggios, question/answer lead, fill + riser
  7-9   A'       G D C/D          four-on-the-floor, answer phrase + harmony a third below, lift
  10    outro    G                final hit, bell arpeggio, fade to true silence
"""
import argparse
import json
import math
import os
import wave

import numpy as np

SR = 48000
BPM = 120
BAR = 60 / BPM * 4          # 2.0 s
STEP = BAR / 16             # one 16th = 0.125 s
BARS = 11
DUR = BARS * BAR            # 40.0 s
N = int(round(DUR * SR))    # 1,920,000

SECTIONS = [('intro', 0, 1), ('A', 1, 5), ('B', 5, 7), ("A'", 7, 10), ('outro', 10, 11)]
SEC = {n: (a, b) for n, a, b in SECTIONS}

ap = argparse.ArgumentParser()
ap.add_argument('--out', default=os.path.join(os.path.dirname(__file__), 'build', 'music.wav'))
ap.add_argument('--seed', type=int, default=7)
args = ap.parse_args()
rng = np.random.default_rng(args.seed)

# stems (stereo)
L = {k: np.zeros(N) for k in ('drums', 'bass', 'chords', 'lead', 'fx')}
Rt = {k: np.zeros(N) for k in L}


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def t_of(bar, step=0.0):
    return bar * BAR + step * STEP


def place(stem, sig, t, pan=0.0, gain=1.0):
    """Add a mono signal at time t (s) with constant-power pan (-1..1)."""
    i = int(round(t * SR))
    if i >= N:
        return
    sig = sig[: N - i]
    a = (pan + 1) * math.pi / 4
    L[stem][i:i + len(sig)] += sig * gain * math.cos(a)
    Rt[stem][i:i + len(sig)] += sig * gain * math.sin(a)


def env(n, a=0.005, d=0.0, s=1.0, r=0.03, length=None):
    """Linear attack, exponential-ish decay to sustain, linear release. Never clicks."""
    t = np.arange(n) / SR
    e = np.ones(n)
    na = max(1, int(a * SR))
    e[:na] = np.linspace(0, 1, na)
    if d > 0:
        e[na:] = s + (1 - s) * np.exp(-(t[na:] - a) / d)
    nr = min(n, max(1, int(r * SR)))
    e[-nr:] *= np.linspace(1, 0, nr)
    return e


# ---------------------------------------------------------------- instruments
def kick(gain=1.0):
    n = int(0.32 * SR)
    t = np.arange(n) / SR
    f = 46 + 80 * np.exp(-t * 32)
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = np.sin(ph) * np.exp(-t * 9.5)
    click = rng.standard_normal(n) * np.exp(-t * 900) * 0.15
    return (s + click) * env(n, a=0.001, r=0.02) * gain


def noise_hp(n, order=1):
    x = rng.standard_normal(n + order)
    for _ in range(order):
        x = np.diff(x)
    return x / (np.abs(x).max() + 1e-9)


def clap(gain=1.0):
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    x = noise_hp(n, 1)
    e = np.exp(-t * 26)
    for off in (0.0, 0.009, 0.018):  # three micro-bursts, each with a 0.5 ms onset (no digital click)
        e = e + 0.6 * np.exp(-np.clip(t - off, 0, None) * 140) * np.clip((t - off) / 0.0005, 0, 1)
    return x * e * env(n, a=0.001, r=0.03) * 0.6 * gain


def snare(gain=1.0):
    n = int(0.16 * SR)
    t = np.arange(n) / SR
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30)
    return (noise_hp(n, 1) * np.exp(-t * 22) * 0.6 + tone * 0.5) * env(n, a=0.001, r=0.02) * gain


def hat(length=0.05, gain=1.0):
    n = int(length * SR)
    t = np.arange(n) / SR
    return noise_hp(n, 2) * np.exp(-t / (length / 4)) * env(n, a=0.001, r=0.01) * 0.6 * gain


def crash(gain=1.0):
    n = int(1.8 * SR)
    t = np.arange(n) / SR
    return noise_hp(n, 2) * np.exp(-t * 2.4) * env(n, a=0.002, r=0.3) * 0.22 * gain


def tone(m, dur, partials, decay=None, a=0.006, r=0.05, vib=0.0):
    """Additive voice: partials = [(harmonic, amp, extra_decay_per_s)]."""
    n = int((dur + r) * SR)
    t = np.arange(n) / SR
    f = midi(m)
    if vib:
        f = f * (1 + vib * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.15) / 0.2, 0, 1))
        ph = 2 * np.pi * np.cumsum(f) / SR
    else:
        ph = 2 * np.pi * f * t
    s = np.zeros(n)
    for h, amp, k in partials:
        if midi(m) * h < SR / 2.2:
            s += amp * np.sin(h * ph) * (np.exp(-t * k) if k else 1)
    if decay:
        s *= np.exp(-t * decay)
    e = env(n, a=a, r=r)
    hold = int(dur * SR)
    e[hold:] *= np.linspace(1, 0, n - hold) if n > hold else 1
    return s * e


def pluck(m, dur=0.22):   # chord stabs / arps: bright attack, fast mellowing
    return tone(m, dur, [(1, 1, 0), (2, .55, 5), (3, .35, 9), (4, .22, 13), (5, .14, 18), (6, .08, 24)], decay=7, a=0.003, r=0.04)


def lead(m, dur):         # soft square, light vibrato
    return tone(m, dur, [(1, 1, 0), (2, .18, 3), (3, .38, 1.2), (5, .22, 2.5), (7, .13, 4), (9, .08, 6)], a=0.008, r=0.06, vib=0.004) * 0.9


def soft(m, dur):         # harmony voice: rounded triangle-ish
    return tone(m, dur, [(1, 1, 0), (3, .11, 2), (5, .04, 4)], a=0.012, r=0.08)


def bass(m, dur):         # warm plucked bass
    return tone(m, dur, [(1, 1, 0), (2, .45, 6), (3, .22, 10), (4, .1, 14)], decay=2.2, a=0.004, r=0.04)


def bell(m, dur=1.2):     # FM bell for intro / outro sparkle
    n = int((dur + 0.4) * SR)
    t = np.arange(n) / SR
    f = midi(m)
    idx = 2.2 * np.exp(-t * 5)
    s = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * 3.5 * t)) * np.exp(-t * 2.6)
    return s * env(n, a=0.002, r=0.3)


def riser(dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = noise_hp(n, 1)
    ramp = (t / dur) ** 2.2
    sweep = np.sin(2 * np.pi * np.cumsum(300 + 1500 * (t / dur) ** 2) / SR) * 0.25
    return (x * 0.5 + sweep) * ramp * env(n, a=0.01, r=0.006) * 0.5


# ---------------------------------------------------------------- harmony
# chord per bar (two chords in a bar = list of (step, name))
CH = {
    'G': ([55, 59, 62, 67], 43), 'D': ([54, 57, 62, 66], 38), 'Em': ([55, 59, 64, 67], 40),
    'C': ([55, 60, 64, 67], 48), 'Bm': ([54, 59, 62, 66], 47), 'Cmaj7': ([60, 64, 67, 71], 48),
    'D7': ([54, 57, 60, 62], 38),
}
PROG = {
    0: [(0, 'Cmaj7'), (8, 'D')],
    1: [(0, 'G')], 2: [(0, 'D')], 3: [(0, 'Em')], 4: [(0, 'C')],
    5: [(0, 'C')], 6: [(0, 'D'), (8, 'D7')],
    7: [(0, 'G')], 8: [(0, 'D')], 9: [(0, 'C'), (8, 'D')],
    10: [(0, 'G')],
}


def chord_at(bar, step):
    cur = None
    for s, name in PROG.get(bar, []):
        if step >= s:
            cur = name
    return cur


# ---------------------------------------------------------------- melody (original)
# (bar offset, step, length in 16ths, midi)
G4, A4, B4, C5, D5, E5, Fs5, G5, A5, B5, C6, D6 = 67, 69, 71, 72, 74, 76, 78, 79, 81, 83, 84, 86
MAIN = [
    # call (G D Em C)
    (0, 0, 2, B4), (0, 2, 2, D5), (0, 4, 3, G5), (0, 7, 1, Fs5), (0, 8, 2, G5), (0, 10, 2, D5), (0, 12, 4, B4),
    (1, 0, 2, A4), (1, 2, 2, D5), (1, 4, 3, Fs5), (1, 7, 1, E5), (1, 8, 2, Fs5), (1, 10, 2, A5), (1, 12, 2, Fs5), (1, 14, 2, E5),
    (2, 0, 3, G5), (2, 3, 1, E5), (2, 4, 2, B4), (2, 6, 2, E5), (2, 8, 2, G5), (2, 10, 4, B5), (2, 14, 2, A5),
    (3, 0, 2, G5), (3, 2, 2, E5), (3, 4, 2, C5), (3, 6, 2, D5), (3, 8, 6, E5),
    # answer (G D C D)
    (4, 0, 2, B4), (4, 2, 2, D5), (4, 4, 3, G5), (4, 7, 1, A5), (4, 8, 2, B5), (4, 10, 2, A5), (4, 12, 4, G5),
    (5, 0, 2, Fs5), (5, 2, 2, A5), (5, 4, 2, D5), (5, 6, 2, Fs5), (5, 8, 3, A5), (5, 11, 1, G5), (5, 12, 4, Fs5),
    (6, 0, 2, E5), (6, 2, 2, G5), (6, 4, 2, C5), (6, 6, 1, E5), (6, 7, 1, G5), (6, 8, 3, G5), (6, 11, 1, A5), (6, 12, 2, G5), (6, 14, 2, E5),
    (7, 0, 3, Fs5), (7, 3, 1, G5), (7, 4, 4, A5), (7, 8, 2, D5), (7, 10, 2, E5), (7, 12, 4, Fs5),
]
B_LEAD = [  # staccato question / answer over C D Bm Em-D7
    (0, 0, 1, E5), (0, 2, 1, G5), (0, 4, 2, C6), (0, 8, 1, G5), (0, 10, 1, E5), (0, 12, 2, G5),
    (1, 0, 1, Fs5), (1, 2, 1, A5), (1, 4, 2, D6), (1, 8, 1, A5), (1, 10, 1, Fs5), (1, 12, 2, A5),
    (2, 0, 1, B5), (2, 2, 1, Fs5), (2, 4, 2, D5), (2, 8, 1, Fs5), (2, 10, 1, B5), (2, 12, 2, B5),
    (3, 0, 1, E5), (3, 2, 1, G5), (3, 4, 2, B5), (3, 8, 1, A5), (3, 10, 1, Fs5), (3, 12, 1, D5), (3, 14, 2, Fs5),
]
A2_END = [  # bar 17 (C | D) lifts into the final G
    (3, 0, 2, E5), (3, 2, 2, G5), (3, 4, 4, C6), (3, 8, 2, A5), (3, 10, 2, Fs5), (3, 12, 2, A5), (3, 14, 2, D6),
]
SCALE = [55, 57, 59, 60, 62, 64, 66, 67, 69, 71, 72, 74, 76, 78, 79, 81, 83, 84, 86]


def third_below(m):
    i = SCALE.index(m)
    return SCALE[i - 2]


def play_line(notes, bar0, voice, stem, gain, pan=0.0, echo=None):
    for bo, st, ln, m in notes:
        t = t_of(bar0 + bo, st)
        s = voice(m, ln * STEP * 0.92)
        place(stem, s, t, pan, gain)
        if echo:  # dotted-8th ping-pong echo
            d, g = echo
            place(stem, s, t + d, -0.6, gain * g)
            place(stem, s, t + 2 * d, 0.6, gain * g * g)


# ---------------------------------------------------------------- arrangement
for bar in range(BARS):
    sec = next(name for name, a, b in SECTIONS if a <= bar < b)
    for step in range(16):
        t = t_of(bar, step)
        ch = chord_at(bar, step)

        # drums
        if sec == 'intro':
            place('drums', hat(0.04, 0.35 + 0.25 * (step % 2)), t, 0.35 if step % 2 else -0.35)
            if bar == SEC['intro'][1] - 1 and step == 12:
                place('drums', clap(0.8), t)
        elif sec == 'A':
            if step in (0, 8, 11):
                place('drums', kick(1.0 if step != 11 else 0.7), t)
            if step in (4, 12):
                place('drums', clap(), t, 0.05)
            if step % 4 == 2:
                place('drums', hat(0.07, 0.9), t, 0.3)
            elif step % 2 == 1:
                place('drums', hat(0.03, 0.35), t, -0.3)
        elif sec == 'B':
            if step in (0, 10):
                place('drums', kick(0.85), t)
            if step == 8:
                place('drums', clap(0.9), t)
            if step % 4 == 2:
                place('drums', hat(0.05, 0.6), t, 0.3)
            if bar == SEC['B'][1] - 1 and step >= 8:  # snare fill, crescendo
                place('drums', snare(0.35 + 0.08 * (step - 8)), t, -0.1)
        elif sec == "A'":
            if step % 4 == 0:
                place('drums', kick(1.0), t)
            if step == 14:
                place('drums', kick(0.55), t)
            if step in (4, 12):
                place('drums', clap(1.05), t, 0.05)
            if step % 4 == 2:
                place('drums', hat(0.08, 1.0), t, 0.3)
            else:
                place('drums', hat(0.025, 0.4), t, -0.3)
        if sec == "A'" and bar == SEC["A'"][0] and step == 0:
            place('drums', crash(1.0), t, -0.2)

        # bass
        if ch and sec in ('A', "A'"):
            root = CH[ch][1]
            pat = {0: (root, 2), 3: (root, 1), 6: (root + 12, 2), 8: (root, 2), 11: (root + 7, 1), 12: (root, 2), 14: (root + 12, 2)}
            if step in pat:
                m, ln = pat[step]
                place('bass', bass(m, ln * STEP * 0.9), t, 0, 0.9)
        elif ch and sec == 'B':
            root = CH[ch][1]
            pat = {0: (root, 3), 6: (root, 2), 8: (root + 7, 3), 12: (root + 12, 2)}
            if step in pat:
                m, ln = pat[step]
                place('bass', bass(m, ln * STEP * 0.9), t, 0, 0.85)

        # chords: offbeat "skank" stabs (A, A'), soft pads in intro, arps in B
        if ch:
            notes = CH[ch][0]
            if sec in ('A', "A'") and step % 4 == 2:
                for k, m in enumerate(notes):
                    place('chords', pluck(m, 0.18), t + 0.004 * k, -0.45 + 0.3 * k, 0.32)
            elif sec == 'intro' and step in (0, 6, 10):
                for k, m in enumerate(notes):
                    place('chords', pluck(m, 0.6), t + 0.012 * k, -0.4 + 0.27 * k, 0.26)
            elif sec == 'B':
                arp = notes + [notes[1] + 12, notes[2] + 12]
                m = arp[(step * 3) % len(arp)] + 12
                place('chords', pluck(m, 0.11), t, -0.5 if step % 2 else 0.5, 0.17)
                if step in (0, 8):
                    for k, mm in enumerate(notes):
                        place('chords', pluck(mm, 0.3), t + 0.005 * k, -0.3 + 0.2 * k, 0.2)

# melody lines
ECHO = (STEP * 3, 0.32)
play_line([(0, 2, 2, E5), (0, 4, 4, G5), (0, 8, 2, A4), (0, 10, 2, D5), (0, 12, 4, Fs5)], SEC['intro'][0],
          lambda m, d: bell(m, d + 0.6), 'lead', 0.32, 0.15, echo=ECHO)
play_line([n for n in MAIN if n[0] < 4], SEC['A'][0], lead, 'lead', 0.36, 0.0, echo=ECHO)            # call
play_line([n for n in B_LEAD if n[0] < 2], SEC['B'][0], lead, 'lead', 0.34, 0.1, echo=ECHO)
A2 = [n for n in MAIN if n[0] in (4, 5)]                                                          # answer: G D
play_line(A2, SEC["A'"][0] - 4, lead, 'lead', 0.36, 0.0, echo=ECHO)
play_line(A2_END, SEC["A'"][0] - 1, lead, 'lead', 0.36, 0.0, echo=ECHO)                          # C | D lift
play_line([(b, s, l, third_below(m)) for b, s, l, m in A2], SEC["A'"][0] - 4, soft, 'lead', 0.17, -0.35)
play_line([(b, s, l, third_below(m)) for b, s, l, m in A2_END], SEC["A'"][0] - 1, soft, 'lead', 0.17, -0.35)

# risers into A and A'
place('fx', riser(BAR), t_of(SEC['intro'][0]), 0, 0.8)
place('fx', riser(BAR), t_of(SEC['B'][1] - 1), 0, 0.8)

# outro: final hit on G, bell arpeggio, ring out
T18 = t_of(SEC['outro'][0])
place('drums', kick(1.1), T18)
place('drums', crash(1.2), T18, 0.2)
place('bass', bass(43, 3.0), T18, 0, 1.0)
for k, m in enumerate(CH['G'][0] + [71, 74]):
    place('chords', pluck(m, 2.6), T18 + 0.01 * k, -0.5 + 0.2 * k, 0.24)
for k, m in enumerate([G5, B5, D6, 91]):
    place('fx', bell(m, 2.2 - 0.3 * k), T18 + 0.25 * (k + 1), (-0.4, 0.4)[k % 2], 0.22)
place('lead', lead(G5, 1.5), T18, 0, 0.36)

# ---------------------------------------------------------------- mix
GAIN = {'drums': 1.0, 'bass': 0.68, 'chords': 1.0, 'lead': 0.95, 'fx': 0.7}
mixL = sum(L[k] * g for k, g in GAIN.items())
mixR = sum(Rt[k] * g for k, g in GAIN.items())

# small room: FFT convolution of the melodic bus with a decaying noise tail
ir_n = int(0.9 * SR)
ir_t = np.arange(ir_n) / SR
ir = rng.standard_normal(ir_n) * np.exp(-ir_t * 5.5)
ir[: int(0.012 * SR)] = 0                         # pre-delay
ir /= np.sqrt((ir ** 2).sum())
for side, src in (('L', L), ('R', Rt)):
    send = (src['chords'] + src['lead'] + src['fx'] * 0.6) * 0.16
    size = 1 << int(np.ceil(np.log2(N + ir_n)))
    wet = np.fft.irfft(np.fft.rfft(send, size) * np.fft.rfft(np.roll(ir, 0), size), size)[:N]
    if side == 'L':
        mixL = mixL + wet
    else:
        mixR = mixR + wet[::1]

mix = np.stack([mixL, mixR])
mix -= mix.mean(axis=1, keepdims=True)              # no DC
# gentle glue: soft-knee saturation, then peak-normalise to -1.5 dBFS
mix = np.tanh(mix / (np.abs(mix).max() * 0.8)) * 0.8
mix *= 10 ** (-1.5 / 20) / np.abs(mix).max()

# fade the tail so the file ends in true silence at 40.000 s
fade_from, fade_to = int((DUR - 1.2) * SR), int((DUR - .15) * SR)
f = np.ones(N)
f[fade_from:fade_to] = np.cos(np.linspace(0, np.pi / 2, fade_to - fade_from)) ** 2
f[fade_to:] = 0
mix *= f
# 4 ms fade-in so the first sample is silent too
mix[:, : int(0.004 * SR)] *= np.linspace(0, 1, int(0.004 * SR))

# ---------------------------------------------------------------- write
os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
pcm = (np.clip(mix, -1, 1) * 32767).round().astype('<i2').T.copy()
with wave.open(args.out, 'wb') as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())

meta = {
    'bpm': BPM, 'sr': SR, 'duration': DUR,
    'bars': [{'index': b, 'start': b * BAR, 'section': next(n for n, a, e in SECTIONS if a <= b < e)} for b in range(BARS)],
    'sections': [{'name': n, 'start': a * BAR, 'end': e * BAR} for n, a, e in SECTIONS],
}
with open(os.path.splitext(args.out)[0] + '.json', 'w', encoding='utf-8') as fh:
    json.dump(meta, fh, indent=1)

def db(x):
    return 20 * np.log10(max(x, 1e-12))

print(f'wrote {args.out}: {pcm.shape[0]} samples x 2 ch @ {SR} Hz = {pcm.shape[0] / SR:.3f} s')
print(f'peak {db(np.abs(mix).max()):.2f} dBFS')
for n, a, e in SECTIONS:
    seg = mix[:, int(a * BAR * SR): int(e * BAR * SR)]
    print(f'  {n:6s} rms {db(np.sqrt((seg ** 2).mean())):6.1f} dBFS')
