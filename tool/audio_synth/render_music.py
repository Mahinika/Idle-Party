"""Owned beds: five cave moods, hub air, boss, clear, and wipe.

Does not touch music/hub.ogg or music/dungeon.mp3.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))

from audio_synth.engine import (  # noqa: E402
    RATE,
    lowpass,
    midi_hz,
    mix_at,
    noise,
    normalize,
    reverb,
    seamless,
    tone,
    write_ogg,
)

MUSIC = ROOT / "assets" / "custom" / "audio" / "music"
AMB = ROOT / "assets" / "custom" / "audio" / "ambience"


def _drone(seconds: float, midi: float, amp: float = 0.2) -> np.ndarray:
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    hz = midi_hz(midi)
    y = np.sin(2 * np.pi * hz * t)
    y += 0.35 * np.sin(2 * np.pi * hz * 1.003 * t)
    y += 0.18 * np.sin(2 * np.pi * hz * 2 * t)
    trem = 0.86 + 0.14 * np.sin(2 * np.pi * 0.06 * t)
    return y * trem * amp


def _pluck(midi: float, seconds: float = 1.6, amp: float = 0.22) -> np.ndarray:
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    hz = midi_hz(midi)
    e = np.exp(-t * 2.4)
    y = np.sin(2 * np.pi * hz * t) * e
    y += 0.28 * np.sin(2 * np.pi * hz * 2 * t) * np.exp(-t * 5)
    return y * amp


def bed(
    scale: tuple[int, ...],
    root: float,
    seconds: float,
    seed: int,
    brightness: float,
    air: float,
) -> np.ndarray:
    rng = np.random.default_rng(seed)
    buf = _drone(seconds, root, 0.16) + _drone(seconds, root + 7, 0.08)
    pattern = (0, 2, 4, 7, 4, 2, 5, 3)
    t = 1.2
    i = 0
    while t < seconds - 2.0:
        deg = pattern[i % len(pattern)]
        note = root + 12 + scale[deg % len(scale)]
        mix_at(buf, t, _pluck(note, 2.2, 0.16 + brightness * 0.04))
        if i % 4 == 0:
            mix_at(buf, t, _pluck(note - 12, 2.8, 0.08))
        t += 2.6 if i % 5 else 3.4
        i += 1
    air_bed = lowpass(noise(seconds, rng, 700 + brightness * 900), 500 + brightness * 400)
    air_bed *= 0.04 + air * 0.05
    # Slow swell so the noise is not a steady hiss.
    n = air_bed.size
    swell = 0.65 + 0.35 * np.sin(2 * np.pi * 0.03 * np.arange(n) / RATE)
    buf += air_bed * swell
    buf = reverb(buf, wet=0.28, decay=0.62)
    buf = seamless(buf, 1.4)
    return normalize(buf, peak=0.8, target_rms=0.07)


def ambience(seed: int, seconds: float, cutoff: float, drone_midi: float, amount: float) -> np.ndarray:
    rng = np.random.default_rng(seed)
    n = int(seconds * RATE)
    air = lowpass(noise(seconds, rng, cutoff), cutoff * 0.6)
    t = np.arange(n) / RATE
    swell = 0.55 + 0.45 * np.sin(2 * np.pi * 0.04 * t)
    y = air * swell * amount
    y += _drone(seconds, drone_midi, 0.05)
    y = reverb(y, wet=0.35, decay=0.7)
    y = seamless(y, 1.2)
    return normalize(y, peak=0.7, target_rms=0.045)


def resolve_phrase() -> np.ndarray:
    buf = np.zeros(int(6.5 * RATE))
    for i, note in enumerate((62, 67, 69, 74)):
        mix_at(buf, 0.35 * i, _pluck(note, 2.4, 0.2))
        mix_at(buf, 0.35 * i, _drone(2.2, note - 12, 0.06))
    return normalize(reverb(buf, wet=0.3, decay=0.55), peak=0.8, target_rms=0.08)


def down_phrase() -> np.ndarray:
    buf = np.zeros(int(4.8 * RATE))
    for i, note in enumerate((64, 60, 55, 50)):
        mix_at(buf, 0.45 * i, tone(1.3, midi_hz(note), 0.45, harmonics=(1, 0.25, 0.08)), 0.35)
    return normalize(reverb(buf, wet=0.32, decay=0.6), peak=0.78, target_rms=0.08)


def boss_bed() -> np.ndarray:
    seconds = 24.0
    buf = _drone(seconds, 38, 0.22) + _drone(seconds, 49, 0.08)
    # Minor second pulse, never lands.
    n = buf.size
    t = np.arange(n) / RATE
    pulse = (np.sin(2 * np.pi * 0.5 * t) > 0.2).astype(np.float64)
    pulse = lowpass(pulse, 8)
    clash = np.sin(2 * np.pi * midi_hz(49) * t) * pulse * 0.07
    buf += clash
    buf = reverb(buf, wet=0.34, decay=0.7)
    buf = seamless(buf, 1.3)
    return normalize(buf, peak=0.8, target_rms=0.075)


def render() -> None:
    print("rendering beds", flush=True)
    moods = {
        "warm": dict(scale=(0, 2, 3, 5, 7, 9, 10), root=50, seed=11, brightness=0.4, air=0.35),
        "dark": dict(scale=(0, 1, 3, 5, 7, 8, 10), root=45, seed=22, brightness=0.1, air=0.55),
        "ice": dict(scale=(0, 2, 3, 5, 7, 8, 10), root=57, seed=33, brightness=0.85, air=0.25),
        "wet": dict(scale=(0, 2, 5, 7, 9), root=47, seed=44, brightness=0.3, air=0.7),
        "storm": dict(scale=(0, 3, 5, 6, 10), root=46, seed=55, brightness=0.55, air=0.45),
    }
    for name, spec in moods.items():
        print("bed", name, flush=True)
        write_ogg(
            MUSIC / f"bed_{name}.ogg",
            bed(
                spec["scale"],
                spec["root"],
                49.5,
                spec["seed"],
                spec["brightness"],
                spec["air"],
            ),
        )
    print("boss resolve down")
    write_ogg(MUSIC / "boss.ogg", boss_bed())
    write_ogg(MUSIC / "resolve.ogg", resolve_phrase())
    write_ogg(MUSIC / "down.ogg", down_phrase())

    amb = {
        "hub": (1, 18.0, 500, 55, 0.08),
        "warm": (2, 20.0, 420, 50, 0.1),
        "dark": (3, 20.0, 220, 40, 0.12),
        "ice": (4, 20.0, 1400, 64, 0.07),
        "wet": (5, 20.0, 300, 43, 0.11),
        "storm": (6, 20.0, 700, 46, 0.1),
    }
    for name, (seed, seconds, cut, drone, amount) in amb.items():
        print("amb", name)
        write_ogg(AMB / f"{name}.ogg", ambience(seed, seconds, cut, drone, amount))
    print("music written")


if __name__ == "__main__":
    render()
