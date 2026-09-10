"""Generate soft Idle Party SFX (owned procedural one-shots).

Replaces Kenney RPG Audio clips in gameplay with muted idle-RPG tones.
Spell school chirps stay in generate_combat_spell_sfx.py.
"""

from __future__ import annotations

import math
import pathlib
import random
import struct
import wave

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "custom" / "audio" / "sfx"
RATE = 22050


def write(name: str, seconds: float, fn, vol: float = 0.38) -> None:
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
            env = min(1.0, t * 50.0, max(0.0, (seconds - t) * 14.0))
            s = fn(t) * env * vol
            v = int(max(-1.0, min(1.0, s)) * 32767)
            frames += struct.pack("<h", v)
        w.writeframes(frames)
    print("wrote", path.relative_to(ROOT), path.stat().st_size)


def tone(freq: float, t: float, mul: float = 1.0) -> float:
    return math.sin(2 * math.pi * freq * t) * mul


def hit_thud(base: float, noise: float = 0.06) -> callable:
    def fn(t: float) -> float:
        return (
            tone(base, t, 0.55)
            + tone(base * 1.5, t, 0.2) * max(0.0, 1 - t * 8)
            + (random.random() * 2 - 1) * noise * max(0.0, 1 - t * 25)
        )

    return fn


def main() -> None:
    write("ui.wav", 0.06, lambda t: tone(880, t, 0.35) + tone(1320, t, 0.15), vol=0.28)

    write(
        "loot.wav",
        0.14,
        lambda t: tone(660 + t * 120, t, 0.45) + tone(990, t, 0.2) * max(0.0, 1 - t * 6),
        vol=0.32,
    )

    write(
        "unlock.wav",
        0.28,
        lambda t: tone(440, t, 0.35)
        + tone(554, t, 0.28) * max(0.0, min(1.0, t * 8))
        + tone(660, t, 0.22) * max(0.0, min(1.0, (t - 0.06) * 10)),
        vol=0.34,
    )

    write(
        "level.wav",
        0.32,
        lambda t: tone(330, t, 0.3)
        + tone(440, t, 0.28) * max(0.0, min(1.0, (t - 0.04) * 12))
        + tone(554, t, 0.22) * max(0.0, min(1.0, (t - 0.10) * 10)),
        vol=0.36,
    )

    write(
        "clear.wav",
        0.35,
        lambda t: tone(220, t, 0.25)
        + tone(330, t, 0.3) * max(0.0, min(1.0, t * 6))
        + tone(440, t, 0.2) * max(0.0, min(1.0, (t - 0.08) * 8)),
        vol=0.34,
    )

    write(
        "crit.wav",
        0.16,
        lambda t: tone(180, t, 0.5) + tone(360, t, 0.25) + (random.random() * 2 - 1) * 0.12,
        vol=0.42,
    )

    write("kill.wav", 0.12, lambda t: tone(120, t, 0.55) + tone(90, t, 0.35), vol=0.38)

    write(
        "flask.wav",
        0.22,
        lambda t: tone(520, t, 0.35)
        + tone(780, t, 0.25) * max(0.0, 1 - t * 4)
        + (random.random() * 2 - 1) * 0.04,
        vol=0.34,
    )

    write(
        "boss.wav",
        0.40,
        lambda t: tone(55, t, 0.45) + tone(82, t, 0.35) + tone(110, t, 0.2),
        vol=0.40,
    )

    write(
        "wipe.wav",
        0.38,
        lambda t: tone(70, t, 0.5) + tone(105, t, 0.3) * max(0.0, 1 - t * 2.5),
        vol=0.38,
    )

    write("hit.wav", 0.10, hit_thud(140), vol=0.36)
    write("hit_blade.wav", 0.09, hit_thud(220, 0.05), vol=0.34)
    write("hit_axe.wav", 0.11, hit_thud(95, 0.08), vol=0.36)
    write("hit_blunt.wav", 0.12, hit_thud(75, 0.07), vol=0.36)
    write("hit_dagger.wav", 0.08, hit_thud(280, 0.04), vol=0.30)
    write("hit_fist.wav", 0.09, hit_thud(110, 0.05), vol=0.32)
    write(
        "hit_bow.wav",
        0.14,
        lambda t: tone(180 + t * 80, t, 0.4)
        + (random.random() * 2 - 1) * 0.05 * max(0.0, 1 - t * 12),
        vol=0.32,
    )


if __name__ == "__main__":
    main()
