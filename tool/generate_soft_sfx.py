"""Generate soft Idle Party SFX (owned procedural one-shots).

Muted idle-RPG tones — warm, short, no arcade fanfare.
Hit families get 3 variants (_a/_b/_c) for combat mix variety.
Spell school chirps stay in generate_combat_spell_sfx.py.
unlock.wav is an owned ElevenLabs clip — skipped here.
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


def write(
    name: str,
    seconds: float,
    fn,
    vol: float = 0.34,
    attack: float = 80.0,
    release: float = 10.0,
) -> None:
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
            env = min(1.0, t * attack, max(0.0, (seconds - t) * release))
            s = fn(t) * env * vol
            v = int(max(-1.0, min(1.0, s)) * 32767)
            frames += struct.pack("<h", v)
        w.writeframes(frames)
    print("wrote", path.relative_to(ROOT), path.stat().st_size)


def tone(freq: float, t: float, mul: float = 1.0) -> float:
    return math.sin(2 * math.pi * freq * t) * mul


def soft_noise(t: float, amount: float, decay: float = 18.0) -> float:
    return (random.random() * 2 - 1) * amount * max(0.0, 1.0 - t * decay)


def hit_thud(base: float, noise: float = 0.045, bright: float = 1.0) -> callable:
    def fn(t: float) -> float:
        body = tone(base * bright, t, 0.5) * math.exp(-t * 14)
        body += tone(base * 0.5, t, 0.28) * math.exp(-t * 10)
        body += tone(base * 2.0 * bright, t, 0.12) * math.exp(-t * 22)
        return body + soft_noise(t, noise, 28)

    return fn


def write_hit_family(
    stem: str,
    base: float,
    noise: float,
    seconds: float,
    vol: float,
    attack: float,
    release: float,
    bow: bool = False,
) -> None:
    """Three slight material variants so combat mix can randomize."""
    specs = (
        (0.92, 0.90, 0),
        (1.00, 1.00, 1),
        (1.08, 1.10, 2),
    )
    for letter, (bright, noise_mul, seed_off) in zip("abc", specs):
        random.seed(11 + seed_off + hash(stem) % 97)
        if bow:

            def make_bow(b=bright, n=noise * noise_mul):
                return lambda t: tone((160 + t * 70) * b, t, 0.34) * math.exp(
                    -t * 7
                ) + soft_noise(t, n, 16)

            write(
                f"{stem}_{letter}.wav",
                seconds,
                make_bow(),
                vol=vol,
                attack=attack,
                release=release,
            )
        else:
            write(
                f"{stem}_{letter}.wav",
                seconds,
                hit_thud(base, noise * noise_mul, bright=bright),
                vol=vol,
                attack=attack,
                release=release,
            )


def main() -> None:
    random.seed(7)

    write(
        "ui.wav",
        0.07,
        lambda t: tone(720, t, 0.32) + tone(1080, t, 0.12) * math.exp(-t * 30),
        vol=0.24,
        attack=90,
        release=18,
    )

    write(
        "loot.wav",
        0.16,
        lambda t: tone(520 + t * 90, t, 0.38)
        + tone(780, t, 0.16) * math.exp(-t * 8)
        + soft_noise(t, 0.02, 20),
        vol=0.28,
        attack=60,
        release=12,
    )

    # unlock.wav: owned ElevenLabs — do not overwrite.

    write(
        "level.wav",
        0.38,
        lambda t: tone(262, t, 0.28)
        + tone(330, t, 0.24) * max(0.0, min(1.0, (t - 0.05) * 10))
        + tone(392, t, 0.18) * max(0.0, min(1.0, (t - 0.12) * 8))
        + tone(523, t, 0.10) * max(0.0, min(1.0, (t - 0.18) * 8)),
        vol=0.30,
        attack=40,
        release=8,
    )

    write(
        "clear.wav",
        0.42,
        lambda t: tone(196, t, 0.22)
        + tone(247, t, 0.26) * max(0.0, min(1.0, t * 5))
        + tone(294, t, 0.18) * max(0.0, min(1.0, (t - 0.08) * 7))
        + tone(370, t, 0.10) * max(0.0, min(1.0, (t - 0.16) * 6)),
        vol=0.28,
        attack=35,
        release=7,
    )

    write(
        "crit.wav",
        0.18,
        lambda t: tone(150, t, 0.42) * math.exp(-t * 9)
        + tone(300, t, 0.18) * math.exp(-t * 14)
        + soft_noise(t, 0.08, 22),
        vol=0.36,
        attack=70,
        release=12,
    )

    write(
        "kill.wav",
        0.14,
        lambda t: tone(95, t, 0.48) * math.exp(-t * 11)
        + tone(140, t, 0.22) * math.exp(-t * 16),
        vol=0.34,
        attack=80,
        release=14,
    )

    write(
        "flask.wav",
        0.24,
        lambda t: tone(460, t, 0.28) * math.exp(-t * 5)
        + tone(690, t, 0.18) * math.exp(-t * 7)
        + soft_noise(t, 0.025, 16),
        vol=0.30,
        attack=50,
        release=10,
    )

    write(
        "boss.wav",
        0.48,
        lambda t: tone(48, t, 0.42)
        + tone(72, t, 0.30)
        + tone(96, t, 0.16) * math.exp(-t * 2),
        vol=0.34,
        attack=25,
        release=6,
    )

    write(
        "wipe.wav",
        0.44,
        lambda t: tone(62, t, 0.46) * math.exp(-t * 2.2)
        + tone(93, t, 0.26) * math.exp(-t * 3.0),
        vol=0.32,
        attack=28,
        release=6,
    )

    write_hit_family("hit", 130, 0.045, 0.11, 0.32, 100, 16)
    write_hit_family("hit_blade", 210, 0.035, 0.10, 0.30, 110, 18)
    write_hit_family("hit_axe", 88, 0.055, 0.12, 0.32, 90, 14)
    write_hit_family("hit_blunt", 68, 0.05, 0.13, 0.32, 85, 13)
    write_hit_family("hit_dagger", 260, 0.03, 0.09, 0.26, 120, 20)
    write_hit_family("hit_fist", 100, 0.04, 0.10, 0.28, 100, 16)
    write_hit_family("hit_bow", 160, 0.035, 0.15, 0.28, 70, 12, bow=True)

    # Remove legacy single-hit files if present (variants replace them).
    for legacy in (
        "hit.wav",
        "hit_blade.wav",
        "hit_axe.wav",
        "hit_blunt.wav",
        "hit_dagger.wav",
        "hit_fist.wav",
        "hit_bow.wav",
    ):
        p = OUT / legacy
        if p.exists():
            p.unlink()
            print("removed", p.relative_to(ROOT))


if __name__ == "__main__":
    main()
