#!/usr/bin/env python3
"""
Generates the sounds of the game by physical synthesis: each material rings with its own
damped modes (stone, marble, brass, walnut, steel tines), impacts bounce as real objects do,
and everything is placed in a small wooden room by a short reverb.

    python3 tools/audio/make_sounds.py        (needs numpy)

Seeded: running it again gives the same files. Writes res/sound/*.wav (44.1 kHz, 16 bits, mono).
Variants (place_1.wav, place_2.wav...) are picked at random by src/Audio.hx.
"""
import os
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "res", "sound")
SR = 44100


# --- Building blocks ----------------------------------------------------------------------

def silence(seconds):
    return np.zeros(int(seconds * SR), np.float64)


def modes(spec, seconds, rng, attack=0.0002):
    """A sum of damped sines: spec = [(frequency Hz, decay s, amplitude), ...]."""
    t = np.arange(int(seconds * SR)) / SR
    out = np.zeros_like(t)
    for f, tau, a in spec:
        if f >= SR / 2 * 0.95:
            continue
        out += a * np.exp(-t / tau) * np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi))
    env = np.clip(t / attack, 0, 1) if attack > 0 else 1
    return fade_out(out * env)


def fade_out(x, seconds=0.03):
    """Ends a signal smoothly: a resonance cut while still ringing would click."""
    n = min(int(seconds * SR), len(x))
    x = x.copy()
    x[len(x) - n:] *= np.cos(np.linspace(0, np.pi / 2, n)) ** 2
    return x


def cut(x, seconds):
    """The first `seconds` of a signal, faded out."""
    return fade_out(x[: int(seconds * SR)])


def add(*signals):
    """Sums signals of different lengths (the shorter ones end with silence)."""
    out = np.zeros(max(len(x) for x in signals))
    for x in signals:
        out[: len(x)] += x
    return out


def biquad(x, kind, f0, q=0.707):
    """RBJ biquad filter (lowpass, highpass, bandpass)."""
    w = 2 * np.pi * f0 / SR
    alpha = np.sin(w) / (2 * q)
    cw = np.cos(w)
    if kind == "lowpass":
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
    elif kind == "highpass":
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
    else:
        b = [alpha, 0, -alpha]
    a = [1 + alpha, -2 * cw, 1 - alpha]
    b = [v / a[0] for v in b]
    a1, a2 = a[1] / a[0], a[2] / a[0]
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        o = b[0] * v + b[1] * x1 + b[2] * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        y[i] = o
    return y


def click(rng, seconds=0.0012, highpass=2500):
    """The contact itself: a very short burst of noise."""
    n = int(seconds * SR)
    burst = rng.standard_normal(n) * np.exp(-np.arange(n) / (n / 4))
    return biquad(np.concatenate([burst, np.zeros(64)]), "highpass", highpass)


def mix(length, *parts):
    """Adds (start seconds, signal, gain) parts, in a buffer of at least `length` seconds."""
    size = max([int(length * SR)] + [int(start * SR) + len(sig) for start, sig, _ in parts])
    out = np.zeros(size)
    for start, sig, gain in parts:
        i = int(start * SR)
        out[i:i + len(sig)] += sig * gain
    return out


def room(x, rng, wet=0.12, rt60=0.35):
    """A small wooden room: early reflections and a short, dark tail."""
    n = int(rt60 * 1.2 * SR)
    t = np.arange(n) / SR
    tail = rng.standard_normal(n) * np.exp(-6.9 * t / rt60)
    tail = biquad(tail, "lowpass", 3500)
    tail[: int(0.004 * SR)] = 0
    for ms, g in ((5.3, 0.5), (8.9, 0.35), (13.1, 0.28), (19.7, 0.2)):
        tail[int(ms / 1000 * SR)] += g * 8
    tail /= np.sqrt(np.sum(tail ** 2))
    size = len(x) + n
    nfft = 1 << (size - 1).bit_length()
    wet_sig = np.fft.irfft(np.fft.rfft(x, nfft) * np.fft.rfft(tail, nfft), nfft)[:size]
    dry = np.concatenate([x, np.zeros(n)])
    return dry + wet * wet_sig


def finish(x, peak, fade=0.02):
    """Trims the silent end, fades out, and normalizes to `peak`."""
    level = np.abs(x)
    above = np.nonzero(level > np.max(level) * 0.0015)[0]
    end = min(len(x), (above[-1] if len(above) else len(x)) + int(0.03 * SR))
    x = x[:end].copy()
    f = min(int(fade * SR), len(x))
    x[-f:] *= np.linspace(1, 0, f)
    return x / np.max(np.abs(x)) * peak


def write(name, x):
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", f"res/sound/{name}.wav", f"{len(x) / SR:.2f} s")


# --- Materials ----------------------------------------------------------------------------

def stone_hit(rng, energy=1.0, size=1.0):
    """A small polished stone ball struck: high, short, slightly inharmonic modes."""
    f0 = rng.uniform(6800, 8200) / size
    spec = [(f0 * r, rng.uniform(0.004, 0.009) * (1.2 - 0.1 * i), a * energy ** (0.3 + 0.25 * i))
            for i, (r, a) in enumerate(((1, 1), (1.47, 0.6), (2.09, 0.35), (2.71, 0.2)))]
    return add(modes(spec, 0.06, rng), click(rng) * 0.5 * energy ** 0.7)


def marble_hit(rng, energy=1.0):
    """The marble board under the blow: a dense, dull 'tock'."""
    spec = [(f * rng.uniform(0.97, 1.03), tau, a * energy ** (0.4 + 0.2 * i))
            for i, (f, tau, a) in enumerate(((1180, 0.05, 0.5), (1860, 0.035, 0.45), (2690, 0.025, 0.35), (3720, 0.018, 0.25), (5100, 0.012, 0.15)))]
    return modes(spec, 0.15, rng)


def brass_ring(rng, energy=1.0, f0=3150):
    """A brass ring or plate: long, bright, inharmonic."""
    spec = [(f0 * r * rng.uniform(0.995, 1.005), tau, a * energy ** (0.4 + 0.15 * i))
            for i, (r, tau, a) in enumerate(((1, 0.28, 0.5), (1.55, 0.2, 0.4), (2.29, 0.14, 0.3), (3.07, 0.09, 0.2), (3.95, 0.06, 0.12)))]
    return modes(spec, 0.9, rng)


def wood_hit(rng, energy=1.0, pitch=1.0, damp=1.0):
    """Walnut struck: a warm, quickly damped knock."""
    spec = [(f * pitch * rng.uniform(0.96, 1.04), tau * damp, a * energy ** (0.4 + 0.2 * i))
            for i, (f, tau, a) in enumerate(((310, 0.045, 0.7), (480, 0.035, 0.6), (770, 0.025, 0.45), (1180, 0.016, 0.3), (1900, 0.01, 0.2), (2900, 0.006, 0.12)))]
    return add(modes(spec, 0.25, rng, attack=0.0004), click(rng, 0.0015, 1200) * 0.15 * energy)


def friction(rng, seconds, center, q, grain_rate):
    """Rubbing: band-limited noise made of stick-slip grains."""
    n = int(seconds * SR)
    noise = biquad(rng.standard_normal(n), "bandpass", center, q)
    grains = np.zeros(n)
    pos = 0
    while pos < n:
        grains[pos] = rng.uniform(0.3, 1)
        pos += int(SR / grain_rate * rng.uniform(0.4, 1.6))
    k = int(0.003 * SR)
    grains = np.convolve(grains, np.exp(-np.arange(k) / (k / 3)), "same")
    return noise * (0.35 + grains)


# --- The sounds ---------------------------------------------------------------------------

def place(rng):
    """A stone dropped into a marble cup ringed with brass: impact, bounces, a short roll."""
    parts = []
    t, e, gap = 0.0, 1.0, rng.uniform(0.055, 0.075)
    ring_luck = rng.uniform(0.04, 0.16)
    for k in range(6):
        hit = add(stone_hit(rng, e) * 0.6, marble_hit(rng, e) * 0.9)
        if k == 0 or rng.random() < 0.4:
            hit = add(hit, brass_ring(rng, e) * ring_luck * (1 if k == 0 else 0.5))
        parts.append((t, hit, e))
        t += gap
        gap *= rng.uniform(0.42, 0.52)
        e *= rng.uniform(0.32, 0.42)
    roll = friction(rng, 0.22, 3200, 1.2, 380) * np.linspace(1, 0, int(0.22 * SR)) ** 2 * 0.06
    parts.append((t, roll, 1))
    return finish(room(mix(1.2, *parts), rng, 0.1), 0.85)


def pick(rng):
    """A stone taken from the velvet tray: it touches its neighbour, the velvet whispers."""
    a = stone_hit(rng, 0.5, size=1.0) + stone_hit(rng, 0.45, size=1.03)
    a = biquad(a, "lowpass", 9000)
    rustle = biquad(friction(rng, 0.09, 1800, 0.9, 900), "lowpass", 4500) * np.hanning(int(0.09 * SR)) * 0.12
    second = stone_hit(rng, 0.2)
    return finish(room(mix(0.35, (0, rustle, 1), (0.012, a, 1), (0.04, second, 0.5)), rng, 0.08), 0.45)


def remove(rng):
    """A stone lifted out of its cup: a short scrape on the brass, a light tick."""
    scrape = friction(rng, 0.07, 4200, 1.5, 700) * np.hanning(int(0.07 * SR)) * 0.35
    tick = add(cut(brass_ring(rng, 0.25), 0.4) * 0.12, stone_hit(rng, 0.25) * 0.4)
    return finish(room(mix(0.5, (0, scrape, 1), (0.05, tick, 1)), rng, 0.08), 0.4)


def move(rng):
    """The cursor: a soft tick of walnut."""
    tick = wood_hit(rng, 0.4, pitch=3.2, damp=0.5)
    return finish(room(tick, rng, 0.06), 0.22)


def button(rng):
    """The brass push button: press, the latch, the spring coming back, the case answering."""
    press = add(cut(brass_ring(rng, 0.6, f0=2400), 0.5) * 0.35, click(rng, 0.001, 2000) * 0.6)
    case = wood_hit(rng, 0.9, pitch=0.62, damp=1.3)
    latch = add(cut(brass_ring(rng, 0.3, f0=3900), 0.3) * 0.2, click(rng, 0.0008, 3500) * 0.4)
    spring = modes([(5200, 0.15, 0.05), (7900, 0.1, 0.03)], 0.4, rng)
    return finish(room(mix(0.9, (0, press, 1), (0, case, 0.8), (0.012, latch, 1), (0.11, latch, 0.6), (0.115, spring, 1)), rng, 0.12), 0.7)


def peg(rng, f0):
    """A small metal key peg pushed into its hole: a tick on the marble and a short ring."""
    ring = modes([(f0 * r * rng.uniform(0.99, 1.01), tau, a) for r, tau, a in
                  ((1, 0.09, 0.5), (1.51, 0.06, 0.35), (2.37, 0.04, 0.25), (3.18, 0.025, 0.15))], 0.4, rng)
    tock = modes([(1700, 0.015, 0.4), (2600, 0.01, 0.3)], 0.1, rng)
    return finish(room(mix(0.5, (0, click(rng, 0.0008, 3000), 0.6), (0, ring, 1), (0, tock, 1)), rng, 0.1), 0.55)


def invalid(rng):
    """Not possible: a muted knock on the case."""
    a = biquad(wood_hit(rng, 1.0, pitch=0.9, damp=0.8), "lowpass", 1500)
    b = biquad(wood_hit(rng, 0.6, pitch=0.85, damp=0.8), "lowpass", 1400)
    return finish(room(mix(0.4, (0, a, 1), (0.085, b, 0.7)), rng, 0.1), 0.5)


def lid(rng):
    """The key turns, the walnut shutter slides away, and stops against its frame."""
    key1 = add(cut(brass_ring(rng, 0.4, f0=3000), 0.25) * 0.3, click(rng, 0.0008, 2500) * 0.5)
    key2 = add(cut(brass_ring(rng, 0.35, f0=3300), 0.25) * 0.25, click(rng, 0.0008, 2800) * 0.45)
    slide_len = 0.5
    n = int(slide_len * SR)
    speed = np.sin(np.linspace(0, np.pi, n)) ** 0.8
    slide = friction(rng, slide_len, 900, 0.8, 140) * 0.6 + friction(rng, slide_len, 2400, 1.0, 260) * 0.25
    body = np.zeros(n)
    for f, tau in ((420, 0.02), (690, 0.015), (1150, 0.01)):
        t = np.arange(int(0.05 * SR)) / SR
        body += np.convolve(slide, np.exp(-t / tau) * np.sin(2 * np.pi * f * t), "same")[:n] * 0.004
    slide = (slide + body) * speed
    stop = add(wood_hit(rng, 1.0, pitch=0.7), cut(brass_ring(rng, 0.3, f0=2800), 0.25) * 0.05)
    return finish(room(mix(1.2, (0, key1, 1), (0.085, key2, 1), (0.16, slide, 0.45), (0.16 + slide_len - 0.01, stop, 0.9)), rng, 0.14), 0.7)


def tine(rng, freq, seconds=2.2, energy=1.0):
    """A tuned steel tine of a music box comb: the fundamental and its beam overtones."""
    spec = [(freq, 1.4, 0.6 * energy), (freq * 2.0, 0.5, 0.05 * energy),
            (freq * 6.27, 0.08, 0.12 * energy), (freq * 17.55, 0.02, 0.05 * energy)]
    pluck = click(rng, 0.0006, 4000) * 0.08 * energy
    return mix(seconds, (0, modes(spec, seconds, rng), 1), (0, pluck, 1))


def win(rng):
    """A music box: an arpeggio climbing up to the final chord."""
    note = lambda midi: 440 * 2 ** ((midi - 69) / 12)
    seq = [(0.0, 79), (0.11, 84), (0.22, 88), (0.33, 91), (0.46, 96), (0.62, 88), (0.62, 91), (0.62, 96), (0.62, 100)]
    parts = [(t, tine(rng, note(m), energy=rng.uniform(0.85, 1.0)), 1) for t, m in seq]
    box = modes([(310, 0.08, 0.2), (520, 0.05, 0.12)], 0.3, rng)
    for t, _ in seq[:5]:
        parts.append((t, box, 0.3))
    return finish(room(mix(3.2, *parts), rng, 0.18, rt60=0.5), 0.6)


def lose(rng):
    """The spiral gong of a mantel clock: two slow strokes, the second a minor third lower."""
    def gong(f0):
        spec = [(f0 * r, tau, a) for r, tau, a in
                ((1, 3.2, 0.6), (2.756, 2.0, 0.35), (5.404, 1.1, 0.2), (8.933, 0.6, 0.1), (13.34, 0.3, 0.05))]
        return add(modes(spec, 4.5, rng, attack=0.0015), click(rng, 0.002, 800) * 0.05)
    return finish(room(mix(5.0, (0, gong(196), 1), (0.95, gong(164.8), 0.8)), rng, 0.16, rt60=0.6), 0.65)


def restart(rng):
    """The stones gathered into the walnut box: a rattle that settles."""
    parts = []
    for i in range(46):
        t = rng.beta(1.3, 2.6) * 0.95
        e = rng.uniform(0.25, 1.0) * (1 - t * 0.6)
        if rng.random() < 0.7:
            parts.append((t, stone_hit(rng, e, size=rng.uniform(0.9, 1.15)), e * 0.6))
        else:
            parts.append((t, wood_hit(rng, e, pitch=rng.uniform(0.8, 1.3), damp=0.7), e * 0.5))
    roll = friction(rng, 0.8, 2800, 0.9, 500) * np.hanning(int(0.8 * SR)) * 0.05
    parts.append((0.05, roll, 1))
    return finish(room(mix(1.6, *parts), rng, 0.14), 0.65)


def main():
    os.makedirs(OUT, exist_ok=True)
    rng = np.random.default_rng(1851)
    for i in range(4):
        write(f"place_{i + 1}", place(rng))
    for i in range(3):
        write(f"pick_{i + 1}", pick(rng))
    for i in range(2):
        write(f"remove_{i + 1}", remove(rng))
    for i in range(3):
        write(f"move_{i + 1}", move(rng))
    write("button", button(rng))
    for i in range(3):
        write(f"peg_good_{i + 1}", peg(rng, rng.uniform(4000, 4400)))
        write(f"peg_bad_{i + 1}", peg(rng, rng.uniform(5300, 5700)))
    write("invalid", invalid(rng))
    write("lid", lid(rng))
    write("win", win(rng))
    write("lose", lose(rng))
    write("restart", restart(rng))


if __name__ == "__main__":
    main()
