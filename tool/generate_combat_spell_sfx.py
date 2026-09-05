"""Generate short Idle Party spell combat SFX (owned procedural chirps)."""

from __future__ import annotations

import math
import pathlib
import random
import struct
import wave

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "custom" / "audio" / "sfx"
RATE = 22050


def write(name: str, seconds: float, fn, vol: float = 0.45) -> None:
    n = int(RATE * seconds)
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for i in range(n):
            t = i / RATE
            env = min(1.0, t * 40.0, max(0.0, (seconds - t) * 12.0))
            s = fn(t) * env * vol
            v = int(max(-1.0, min(1.0, s)) * 32767)
            frames += struct.pack("<h", v)
        w.writeframes(frames)
    print("wrote", path.relative_to(ROOT), path.stat().st_size)


def main() -> None:
    write(
        "spell_fire.wav",
        0.18,
        lambda t: (random.random() * 2 - 1) * 0.7
        + math.sin(2 * math.pi * (420 - t * 900) * t) * 0.5,
    )
    write(
        "spell_frost.wav",
        0.20,
        lambda t: math.sin(2 * math.pi * (880 + t * 200) * t) * 0.55
        + math.sin(2 * math.pi * 1320 * t) * 0.25 * max(0.0, 1 - t * 3),
    )
    write(
        "spell_holy.wav",
        0.22,
        lambda t: math.sin(2 * math.pi * 660 * t) * 0.4
        + math.sin(2 * math.pi * 990 * t) * 0.3
        + math.sin(2 * math.pi * 1320 * t) * 0.2,
    )
    write(
        "spell_shadow.wav",
        0.22,
        lambda t: math.sin(2 * math.pi * (90 + t * 40) * t) * 0.6
        + (random.random() * 2 - 1) * 0.2,
    )
    write(
        "spell_arcane.wav",
        0.16,
        lambda t: math.sin(2 * math.pi * (1200 + math.sin(t * 80) * 200) * t)
        * 0.5
        + math.sin(2 * math.pi * 2400 * t) * 0.15,
    )
    write(
        "spell_nature.wav",
        0.20,
        lambda t: math.sin(2 * math.pi * (220 + t * 60) * t) * 0.35
        + math.sin(2 * math.pi * 330 * t) * 0.25
        + (random.random() * 2 - 1) * 0.08,
    )
    write(
        "spell_lightning.wav",
        0.14,
        lambda t: (random.random() * 2 - 1)
        * 0.85
        * (1 if (int(t * 90) % 3 == 0) else 0.2)
        + math.sin(2 * math.pi * 1500 * t) * 0.2,
    )


if __name__ == "__main__":
    main()
