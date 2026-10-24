"""Writes the sound effects of the game in res/sound/ (synthesized: no file to download).

    python3 tools/make_sounds.py

Replace any of them by a real sound with the same name (.wav or .mp3): the game picks it up.
"""
import math, os, random, struct, wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "res", "sound")


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))


def tone(f0, f1, seconds, volume=0.5, square=False, noise=0.0):
    """A tone sliding from f0 to f1 Hz, with a short attack and a linear fade out."""
    out, phase, n = [], 0.0, int(RATE * seconds)
    for i in range(n):
        t = i / n
        phase += 2 * math.pi * (f0 + (f1 - f0) * t) / RATE
        s = math.sin(phase)
        if square:
            s = 1.0 if s > 0 else -1.0
        s = s * (1 - noise) + (random.random() * 2 - 1) * noise
        env = min(1.0, i / (RATE * 0.005)) * (1 - t)
        out.append(s * env * volume)
    return out


def boom(seconds, volume=0.8, low=0.15):
    """Noise through a low pass filter that closes over time: an explosion."""
    out, y, n = [], 0.0, int(RATE * seconds)
    for i in range(n):
        t = i / n
        a = low + (1 - low) * (1 - t) ** 3
        y += a * ((random.random() * 2 - 1) - y)
        out.append(y * volume * (1 - t) ** 1.5)
    return out


random.seed(7)
write("shoot", tone(1400, 300, 0.09, 0.25, square=True))
write("explosion", boom(0.45))
write("ship_hit", [a + b for a, b in zip(boom(0.7, 0.9, 0.05), tone(220, 50, 0.7, 0.4))])
write("game_over", tone(440, 110, 0.4, 0.35, square=True) + tone(330, 80, 0.7, 0.35, square=True))
write("record", tone(523, 523, 0.12, 0.3, True) + tone(659, 659, 0.12, 0.3, True) + tone(784, 784, 0.12, 0.3, True) + tone(1047, 1047, 0.35, 0.3, True))
write("ui_move", tone(880, 880, 0.04, 0.2, square=True))
write("ui_confirm", tone(660, 660, 0.05, 0.25, True) + tone(990, 990, 0.08, 0.25, True))
write("ui_back", tone(660, 440, 0.08, 0.25, square=True))
write("pause", tone(600, 600, 0.06, 0.25, True) + tone(400, 400, 0.08, 0.25, True))
