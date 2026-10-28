#!/usr/bin/env python3
"""Synthesize the endless woods' ambience and animal calls (CC0, no services).

Every sound is generated from fixed seeds with the standard library, so the
WAV files are reproducible and carry no third-party licence. Run it again to
rebuild them; `--check` verifies that the committed files match.
"""
import argparse
import io
import math
from pathlib import Path
import random
import struct
import sys
import wave

RATE = 22050
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "scenes" / "endless_woods" / "audio"


def lowpass(samples, cutoff):
    a = 1 - math.exp(-2 * math.pi * cutoff / RATE)
    y = 0.0
    out = []
    for x in samples:
        y += a * (x - y)
        out.append(y)
    return out


def bandpass(samples, centre, q):
    # RBJ biquad band-pass (constant peak gain).
    w = 2 * math.pi * centre / RATE
    alpha = math.sin(w) / (2 * q)
    b0, b2 = alpha, -alpha
    a0, a1, a2 = 1 + alpha, -2 * math.cos(w), 1 - alpha
    x1 = x2 = y1 = y2 = 0.0
    out = []
    for x in samples:
        y = (b0 * x + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1, y2, y1 = x1, x, y1, y
        out.append(y)
    return out


def noise(rng, count):
    return [rng.uniform(-1, 1) for _ in range(count)]


def envelope(t, attack, length, release):
    if t < 0 or t > length:
        return 0.0
    return min(1.0, t / attack if attack else 1.0, (length - t) / release if release else 1.0)


def loop_crossfade(samples, loop, fade):
    """Fold the tail past `loop` into the head with an equal-power crossfade."""
    out = samples[:loop]
    for i in range(fade):
        p = i / fade
        out[i] = samples[i] * math.sin(p * math.pi / 2) + samples[loop + i] * math.cos(p * math.pi / 2)
    return out


def normalize(samples, peak):
    top = max(1e-9, max(abs(s) for s in samples))
    return [s * peak / top for s in samples]


def wind_loop():
    """Soft wind and leaf rustle, 23 s, looping without a seam."""
    rng = random.Random(23101)
    seconds = 23
    loop = seconds * RATE
    fade = 2 * RATE
    count = loop + fade
    base = lowpass(lowpass(noise(rng, count), 380), 520)
    leaves = bandpass(noise(rng, count), 2600, 0.8)
    out = []
    for i in range(count):
        t = (i % loop) / loop
        # Integer cycles per loop keep the slow swells continuous at the seam.
        gust = 0.55 + 0.25 * math.sin(2 * math.pi * 2 * t) + 0.2 * math.sin(2 * math.pi * 5 * t + 1.3)
        rustle = max(0.0, math.sin(2 * math.pi * 7 * t + 0.4)) ** 3
        out.append(base[i] * 6.0 * gust + leaves[i] * 0.22 * rustle * gust)
    return normalize(loop_crossfade(out, loop, fade), 0.5)


def bird_loop():
    """Sparse, varied birdsong phrases over silence, 19 s (a different period)."""
    rng = random.Random(19207)
    count = 19 * RATE
    out = [0.0] * count
    start = 0.6
    while start < 17.5:
        song = rng.choice(["warble", "pair", "trill"])
        base = rng.uniform(2600, 4300)
        notes = {"warble": rng.randint(3, 5), "pair": 2, "trill": rng.randint(6, 9)}[song]
        gap = {"warble": 0.16, "pair": 0.22, "trill": 0.07}[song]
        level = rng.uniform(0.25, 0.6)
        for n in range(notes):
            length = {"warble": 0.12, "pair": 0.15, "trill": 0.05}[song] * rng.uniform(0.8, 1.2)
            sweep = rng.uniform(-900, 900)
            first = int((start + n * gap) * RATE)
            phase = 0.0
            for k in range(int(length * RATE)):
                i = first + k
                if i >= count:
                    break
                t = k / RATE
                f = base + sweep * (t / length) + 120 * math.sin(2 * math.pi * 30 * t)
                phase += 2 * math.pi * f / RATE
                out[i] += level * math.sin(phase) * envelope(t, 0.01, length, 0.03)
        start += notes * gap + rng.uniform(1.2, 3.4)
    return normalize(out, 0.35)


def tone(length, pitch, harmonics, vibrato=0.0, attack=0.05, release=0.2):
    out = []
    phase = 0.0
    for i in range(int(length * RATE)):
        t = i / RATE
        f = pitch(t) * (1 + vibrato * math.sin(2 * math.pi * 5.2 * t))
        phase += 2 * math.pi * f / RATE
        s = sum(a * math.sin(phase * (n + 1)) for n, a in enumerate(harmonics))
        out.append(s * envelope(t, attack, length, release))
    return out


def wolf_howl():
    rng = random.Random(501)
    length = 2.8
    pitch = lambda t: 360 + 170 * math.sin(min(1.0, t / 0.9) * math.pi / 2) - 90 * max(0.0, t - 1.9)
    voice = tone(length, pitch, [1.0, 0.45, 0.22, 0.1], vibrato=0.012, attack=0.35, release=0.7)
    breath = lowpass(noise(rng, len(voice)), 1800)
    return normalize([v + 0.08 * b * envelope(i / RATE, 0.3, length, 0.7) for i, (v, b) in enumerate(zip(voice, breath))], 0.8)


def lynx_growl():
    rng = random.Random(502)
    length = 1.5
    rough = bandpass(noise(rng, int(length * RATE)), 260, 1.2)
    out = []
    for i, n in enumerate(rough):
        t = i / RATE
        am = 0.55 + 0.45 * math.sin(2 * math.pi * 27 * t)
        body = math.sin(2 * math.pi * (105 + 25 * math.sin(2 * math.pi * 0.7 * t)) * t)
        out.append((n * 2.5 * am + 0.35 * body * am) * envelope(t, 0.12, length, 0.35))
    return normalize(out, 0.75)


def boar_grunt():
    rng = random.Random(503)
    out = []
    for g, (length, pitch) in enumerate([(0.24, 92), (0.18, 84), (0.3, 78)]):
        pulses = []
        phase = 0.0
        for i in range(int(length * RATE)):
            t = i / RATE
            phase += pitch * (1 - 0.25 * t / length) / RATE
            pulses.append((1.0 if phase % 1.0 < 0.18 else 0.0) + 0.35 * rng.uniform(-1, 1))
        voiced = lowpass(bandpass(pulses, 420, 0.9), 1100)
        out += [v * envelope(i / RATE, 0.02, length, 0.08) for i, v in enumerate(voiced)]
        out += [0.0] * int(0.09 * RATE)
    return normalize(out, 0.75)


def deer_bark():
    rng = random.Random(504)
    out = []
    for length in [0.22, 0.26]:
        burst = bandpass(noise(rng, int(length * RATE)), 950, 2.2)
        voice = tone(length, lambda t: 520 - 260 * t, [0.6, 0.3, 0.15], attack=0.005, release=0.15)
        out += [(b * 3.0 + v) * envelope(i / RATE, 0.004, length, 0.16) for i, (b, v) in enumerate(zip(burst, voice))]
        out += [0.0] * int(0.32 * RATE)
    return normalize(out, 0.75)


def fox_yip():
    out = []
    for k in range(3):
        length = 0.09 + 0.02 * k
        out += tone(length, lambda t, k=k: 950 + 520 * (t / length) - 40 * k, [1.0, 0.5, 0.3, 0.15], attack=0.006, release=0.05)
        out += [0.0] * int(0.14 * RATE)
    return normalize(out, 0.7)


def hare_thump():
    out = []
    for k in range(2):
        length = 0.16
        out += tone(length, lambda t: 70 - 25 * t / length, [1.0, 0.3], attack=0.002, release=0.13)
        out += [0.0] * int(0.18 * RATE)
    return normalize(out, 0.6)


SOUNDS = {
    "ambience_wind.wav": wind_loop,
    "ambience_birds.wav": bird_loop,
    "wolf_howl.wav": wolf_howl,
    "lynx_growl.wav": lynx_growl,
    "boar_grunt.wav": boar_grunt,
    "deer_bark.wav": deer_bark,
    "fox_yip.wav": fox_yip,
    "hare_thump.wav": hare_thump,
}


def encode(samples) -> bytes:
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, round(s * 32767)))) for s in samples))
    return buffer.getvalue()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify committed WAVs match the generator")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    stale = []
    for name, build in SOUNDS.items():
        data = encode(build())
        path = OUT / name
        if args.check:
            if not path.exists() or path.read_bytes() != data:
                stale.append(name)
        else:
            path.write_bytes(data)
            print(f"wrote {path.relative_to(ROOT)} ({len(data) // 1024} KiB)")
    if stale:
        print("Out of date: " + ", ".join(stale), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
