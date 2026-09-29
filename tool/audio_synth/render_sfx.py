"""Owned one-shots: hits, spells, menus, and fight moments."""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))

from audio_synth.engine import (  # noqa: E402
    RATE,
    burst,
    fm_bell,
    highpass,
    midi_hz,
    mix_at,
    noise,
    normalize,
    reverb,
    saturate,
    tone,
    write_ogg,
)

OUT = ROOT / "assets" / "custom" / "audio" / "sfx"


def _clip(seconds: float, rng: np.random.Generator, build, wet: float = 0.1) -> np.ndarray:
    buf = np.zeros(int(seconds * RATE))
    build(buf, rng)
    return normalize(reverb(saturate(buf, 1.15), wet=wet, decay=0.28), peak=0.72, target_rms=0.11)


def _hit(kind: str, variant: int) -> np.ndarray:
    rng = np.random.default_rng(1000 + variant * 17 + sum(ord(c) for c in kind))
    tilt = 0.92 + variant * 0.035

    def build(buf, rng):
        if kind == "blade":
            mix_at(buf, 0, burst(0.09, rng, 4200 * tilt, 0.03), 0.55)
            mix_at(buf, 0.004, tone(0.16, 680 * tilt, 0.05, harmonics=(1, 0.45, 0.2, 0.08)), 0.7)
        elif kind == "axe":
            mix_at(buf, 0, burst(0.12, rng, 900, 0.05), 0.7)
            mix_at(buf, 0.002, tone(0.2, 140 * tilt, 0.08, harmonics=(1, 0.4, 0.15)), 0.85)
        elif kind == "blunt":
            mix_at(buf, 0, tone(0.22, 78 * tilt, 0.09, harmonics=(1, 0.25, 0.08)), 0.9)
            mix_at(buf, 0, burst(0.08, rng, 600, 0.04), 0.35)
        elif kind == "dagger":
            mix_at(buf, 0, burst(0.05, rng, 5000 * tilt, 0.018), 0.45)
            mix_at(buf, 0, tone(0.08, 1400 * tilt, 0.03, harmonics=(1, 0.2)), 0.55)
        elif kind == "fist":
            mix_at(buf, 0, tone(0.14, 95 * tilt, 0.06, harmonics=(1, 0.15)), 0.8)
            mix_at(buf, 0, burst(0.07, rng, 400, 0.04), 0.4)
        elif kind == "bow":
            mix_at(buf, 0, highpass(burst(0.07, rng, 2400, 0.02), 800), 0.4)
            mix_at(buf, 0.02, tone(0.12, 420 * tilt, 0.05, harmonics=(1, 0.3, 0.1)), 0.55)
            mix_at(buf, 0.03, burst(0.06, rng, 1800, 0.03), 0.3)

    return _clip(0.28, rng, build, wet=0.08)


def _spell(school: str, variant: int) -> np.ndarray:
    rng = np.random.default_rng(3000 + variant * 23 + sum(ord(c) for c in school))
    tilt = 0.94 + variant * 0.025

    def build(buf, rng):
        if school == "fire":
            mix_at(buf, 0, burst(0.22, rng, 900 * tilt, 0.08), 0.75)
            mix_at(buf, 0, tone(0.2, 180 * tilt, 0.07, harmonics=(1, 0.5, 0.2)), 0.45)
        elif school == "frost":
            mix_at(buf, 0, fm_bell(0.28, 880 * tilt, 2.76, 1.4, 0.16), 0.6)
            mix_at(buf, 0.01, burst(0.12, rng, 5000, 0.04), 0.18)
        elif school == "holy":
            mix_at(buf, 0, tone(0.32, 523 * tilt, 0.16, harmonics=(1, 0.25, 0.08)), 0.45)
            mix_at(buf, 0.02, tone(0.28, 659 * tilt, 0.14, harmonics=(1, 0.15)), 0.35)
        elif school == "shadow":
            mix_at(buf, 0, tone(0.3, 110 * tilt, 0.14, harmonics=(1, 0.2, 0.05)), 0.7)
            mix_at(buf, 0, burst(0.2, rng, 500, 0.1), 0.35)
        elif school == "arcane":
            mix_at(buf, 0, fm_bell(0.26, 660 * tilt, 1.5, 3.2, 0.12), 0.65)
        elif school == "nature":
            mix_at(buf, 0, tone(0.24, 392 * tilt, 0.1, harmonics=(1, 0.15, 0.04)), 0.55)
            mix_at(buf, 0.01, burst(0.1, rng, 700, 0.06), 0.2)
        elif school == "lightning":
            mix_at(buf, 0, highpass(burst(0.08, rng, 6000, 0.02), 1200), 0.7)
            mix_at(buf, 0.01, tone(0.12, 1800 * tilt, 0.03, harmonics=(1, 0.4)), 0.35)
        elif school == "demon":
            mix_at(buf, 0, tone(0.28, 73 * tilt, 0.12, harmonics=(1, 0.6, 0.3, 0.1)), 0.8)
            mix_at(buf, 0, burst(0.16, rng, 350, 0.08), 0.3)
        elif school == "poison":
            mix_at(buf, 0, burst(0.22, rng, 800 * tilt, 0.09), 0.4)
            mix_at(buf, 0.02, tone(0.18, 310 * tilt, 0.08, harmonics=(1, 0.2)), 0.35)
            mix_at(buf, 0.06, tone(0.12, 370 * tilt, 0.05, harmonics=(1,)), 0.2)

    return _clip(0.36, rng, build, wet=0.16)


def _swish(kind: str, variant: int) -> np.ndarray:
    rng = np.random.default_rng(5000 + variant + (0 if kind == "melee" else 9))
    cut = 1400 if kind == "melee" else 2200

    def build(buf, rng):
        mix_at(buf, 0, highpass(burst(0.09, rng, cut, 0.04), 500), 0.7)

    return _clip(0.12, rng, build, wet=0.02)


def _material(kind: str) -> np.ndarray:
    rng = np.random.default_rng(hash(kind) % 10000)

    def build(buf, rng):
        if kind == "flesh":
            mix_at(buf, 0, tone(0.08, 120, 0.04, harmonics=(1, 0.2)), 0.6)
        elif kind == "bone":
            mix_at(buf, 0, tone(0.07, 900, 0.03, harmonics=(1, 0.4, 0.15)), 0.5)
        elif kind == "wet":
            mix_at(buf, 0, burst(0.08, rng, 500, 0.04), 0.55)
        else:
            mix_at(buf, 0, tone(0.08, 240, 0.03, harmonics=(1, 0.5, 0.2)), 0.45)
            mix_at(buf, 0, burst(0.04, rng, 2000, 0.015), 0.25)

    return _clip(0.12, rng, build, wet=0.04)


def _simple(seed: int, build, seconds: float = 0.4, wet: float = 0.14, rms: float = 0.1) -> np.ndarray:
    rng = np.random.default_rng(seed)
    buf = np.zeros(int(seconds * RATE))
    build(buf, rng)
    return normalize(reverb(saturate(buf, 1.1), wet=wet, decay=0.32), peak=0.74, target_rms=rms)


def render_soft() -> None:
    letters6 = "abcdef"
    for kind in ("blade", "axe", "blunt", "dagger", "fist"):
        for i, letter in enumerate(letters6):
            write_ogg(OUT / f"hit_{kind}_{letter}.ogg", _hit(kind, i))
    for i, letter in enumerate("abcd"):
        write_ogg(OUT / f"hit_bow_{letter}.ogg", _hit("bow", i))
    for kind in ("melee", "bow"):
        for i, letter in enumerate("abc"):
            write_ogg(OUT / f"swish_{kind}_{letter}.ogg", _swish(kind, i))
    for kind in ("flesh", "bone", "wet", "stone"):
        write_ogg(OUT / f"mat_{kind}.ogg", _material(kind))

    def crit(buf, rng):
        mix_at(buf, 0, tone(0.22, 880, 0.08, harmonics=(1, 0.3)), 0.5)
        mix_at(buf, 0.04, tone(0.2, 1320, 0.07, harmonics=(1, 0.2)), 0.4)

    def kill(buf, rng):
        mix_at(buf, 0, tone(0.28, 196, 0.12, harmonics=(1, 0.4, 0.15)), 0.55)
        mix_at(buf, 0.06, tone(0.22, 392, 0.1, harmonics=(1, 0.2)), 0.35)

    for i in range(4):
        write_ogg(OUT / f"crit_{'abcd'[i]}.ogg", _simple(800 + i, crit, 0.32, 0.12))
        write_ogg(OUT / f"kill_{'abcd'[i]}.ogg", _simple(900 + i, kill, 0.36, 0.14))
    print("soft sfx written")


def render_spells() -> None:
    schools = (
        "fire",
        "frost",
        "holy",
        "shadow",
        "arcane",
        "nature",
        "lightning",
        "demon",
        "poison",
    )
    for school in schools:
        for i, letter in enumerate("abcdef"):
            write_ogg(OUT / f"spell_{school}_{letter}.ogg", _spell(school, i))
    print("spell sfx written")


def render_moments() -> None:
    def ui_tap(buf, rng):
        mix_at(buf, 0, tone(0.04, 1400, 0.015, harmonics=(1, 0.2)), 0.4)

    def ui_tab(buf, rng):
        mix_at(buf, 0, tone(0.05, 880, 0.02, harmonics=(1, 0.15)), 0.4)

    def ui_confirm(buf, rng):
        mix_at(buf, 0, tone(0.08, 523, 0.04, harmonics=(1, 0.15)), 0.4)
        mix_at(buf, 0.07, tone(0.1, 784, 0.05, harmonics=(1, 0.12)), 0.35)

    def ui_back(buf, rng):
        mix_at(buf, 0, tone(0.08, 659, 0.04, harmonics=(1,)), 0.35)
        mix_at(buf, 0.06, tone(0.1, 392, 0.05, harmonics=(1,)), 0.3)

    def ui_deny(buf, rng):
        mix_at(buf, 0, tone(0.1, 140, 0.05, harmonics=(1, 0.2)), 0.55)

    def gold(buf, rng):
        mix_at(buf, 0, tone(0.08, 1568, 0.03, harmonics=(1, 0.4)), 0.3)
        mix_at(buf, 0.05, tone(0.1, 2093, 0.04, harmonics=(1, 0.25)), 0.25)

    def equip(buf, rng):
        mix_at(buf, 0, burst(0.05, rng, 1800, 0.02), 0.3)
        mix_at(buf, 0.02, tone(0.12, 440, 0.05, harmonics=(1, 0.3, 0.1)), 0.4)

    def forge(buf, rng):
        mix_at(buf, 0, tone(0.1, 220, 0.05, harmonics=(1, 0.4)), 0.4)
        mix_at(buf, 0.08, tone(0.16, 440, 0.07, harmonics=(1, 0.3)), 0.45)
        mix_at(buf, 0.16, tone(0.18, 660, 0.08, harmonics=(1, 0.2)), 0.35)

    def achievement(buf, rng):
        for i, hz in enumerate((523, 659, 784)):
            mix_at(buf, i * 0.09, tone(0.22, hz, 0.1, harmonics=(1, 0.15)), 0.35)

    def ascend(buf, rng):
        for i, hz in enumerate((196, 247, 294, 392)):
            mix_at(buf, 0.05 * i, tone(0.7, hz, 0.28, harmonics=(1, 0.2, 0.06)), 0.28)

    def loot(buf, rng):
        mix_at(buf, 0, tone(0.12, 784, 0.05, harmonics=(1, 0.2)), 0.4)

    def loot_rare(buf, rng):
        mix_at(buf, 0, tone(0.14, 880, 0.06, harmonics=(1, 0.25)), 0.4)
        mix_at(buf, 0.06, tone(0.14, 1175, 0.06, harmonics=(1, 0.15)), 0.3)

    def loot_epic(buf, rng):
        mix_at(buf, 0, tone(0.16, 698, 0.07, harmonics=(1, 0.2)), 0.35)
        mix_at(buf, 0.07, tone(0.18, 880, 0.08, harmonics=(1, 0.2)), 0.35)
        mix_at(buf, 0.14, tone(0.2, 1175, 0.08, harmonics=(1, 0.15)), 0.3)

    def loot_leg(buf, rng):
        for i, hz in enumerate((523, 659, 784, 1046)):
            mix_at(buf, i * 0.08, tone(0.28, hz, 0.12, harmonics=(1, 0.2)), 0.32)

    def level(buf, rng):
        mix_at(buf, 0, tone(0.2, 392, 0.08, harmonics=(1, 0.2)), 0.4)
        mix_at(buf, 0.1, tone(0.28, 523, 0.12, harmonics=(1, 0.2)), 0.45)
        mix_at(buf, 0.22, tone(0.3, 784, 0.14, harmonics=(1, 0.15)), 0.35)

    def clear(buf, rng):
        mix_at(buf, 0, tone(0.4, 349, 0.18, harmonics=(1, 0.2, 0.06)), 0.35)
        mix_at(buf, 0.12, tone(0.4, 440, 0.18, harmonics=(1, 0.15)), 0.3)

    def boss(buf, rng):
        mix_at(buf, 0, tone(0.45, 98, 0.2, harmonics=(1, 0.45, 0.2)), 0.55)
        mix_at(buf, 0.08, tone(0.4, 146, 0.16, harmonics=(1, 0.3)), 0.3)

    def wipe(buf, rng):
        mix_at(buf, 0, tone(0.5, 220, 0.22, harmonics=(1, 0.3)), 0.4)
        mix_at(buf, 0.16, tone(0.45, 146, 0.2, harmonics=(1, 0.25)), 0.4)
        mix_at(buf, 0.32, tone(0.4, 98, 0.18, harmonics=(1, 0.2)), 0.35)

    def flask(buf, rng):
        mix_at(buf, 0, burst(0.06, rng, 1200, 0.03), 0.25)
        mix_at(buf, 0.04, tone(0.18, 660, 0.08, harmonics=(1, 0.15)), 0.4)

    def unlock(buf, rng):
        mix_at(buf, 0, tone(0.2, 523, 0.08, harmonics=(1, 0.2)), 0.35)
        mix_at(buf, 0.1, tone(0.25, 659, 0.1, harmonics=(1, 0.15)), 0.35)
        mix_at(buf, 0.2, tone(0.3, 880, 0.12, harmonics=(1, 0.12)), 0.3)

    def hero_down(buf, rng):
        mix_at(buf, 0, tone(0.4, 330, 0.16, harmonics=(1, 0.2)), 0.4)
        mix_at(buf, 0.12, tone(0.35, 196, 0.16, harmonics=(1, 0.15)), 0.4)

    def heal(buf, rng):
        mix_at(buf, 0, tone(0.22, 523, 0.1, harmonics=(1, 0.12)), 0.35)
        mix_at(buf, 0.06, tone(0.22, 784, 0.1, harmonics=(1, 0.1)), 0.28)

    def shield(buf, rng):
        mix_at(buf, 0, fm_bell(0.16, 1200, 2.2, 1.2, 0.06), 0.4)

    def tell(buf, rng):
        n = int(0.55 * RATE)
        t = np.arange(n) / RATE
        hz = 220 * (2 ** (t * 1.4))
        mix_at(buf, 0, np.sin(2 * np.pi * np.cumsum(hz) / RATE) * np.linspace(0.2, 1, n), 0.45)

    def enrage(buf, rng):
        mix_at(buf, 0, tone(0.35, 70, 0.14, harmonics=(1, 0.55, 0.25)), 0.7)
        mix_at(buf, 0, burst(0.2, rng, 300, 0.08), 0.35)

    def enemy_hit(buf, rng):
        mix_at(buf, 0, tone(0.12, 90, 0.05, harmonics=(1, 0.2)), 0.7)
        mix_at(buf, 0, burst(0.06, rng, 400, 0.03), 0.3)

    def die_flesh(buf, rng):
        mix_at(buf, 0, tone(0.2, 110, 0.08, harmonics=(1, 0.3)), 0.6)
        mix_at(buf, 0, burst(0.1, rng, 500, 0.05), 0.3)

    def die_bone(buf, rng):
        mix_at(buf, 0, tone(0.14, 740, 0.04, harmonics=(1, 0.45, 0.2)), 0.45)
        mix_at(buf, 0, burst(0.05, rng, 3000, 0.02), 0.3)

    def die_stone(buf, rng):
        mix_at(buf, 0, tone(0.22, 160, 0.08, harmonics=(1, 0.5, 0.2)), 0.55)
        mix_at(buf, 0, burst(0.08, rng, 900, 0.03), 0.35)

    singles = {
        "ui_tap": (ui_tap, 0.08),
        "ui_tab": (ui_tab, 0.1),
        "ui_confirm": (ui_confirm, 0.24),
        "ui_back": (ui_back, 0.22),
        "ui_deny": (ui_deny, 0.16),
        "gold": (gold, 0.2),
        "equip": (equip, 0.18),
        "forge_up": (forge, 0.4),
        "achievement": (achievement, 0.5),
        "ascend": (ascend, 0.9),
        "loot": (loot, 0.2),
        "loot_rare": (loot_rare, 0.28),
        "loot_epic": (loot_epic, 0.4),
        "loot_legendary": (loot_leg, 0.6),
        "level": (level, 0.55),
        "clear": (clear, 0.6),
        "boss": (boss, 0.55),
        "wipe": (wipe, 0.7),
        "flask": (flask, 0.28),
        "unlock": (unlock, 0.55),
        "hero_down": (hero_down, 0.5),
    }
    for i, (name, (fn, seconds)) in enumerate(singles.items()):
        write_ogg(OUT / f"{name}.ogg", _simple(2000 + i, fn, seconds, 0.12, 0.1))

    for i, letter in enumerate("abc"):
        write_ogg(OUT / f"enemy_hit_{letter}.ogg", _simple(3000 + i, enemy_hit, 0.16, 0.06))
        write_ogg(OUT / f"enemy_die_flesh_{letter}.ogg", _simple(3100 + i, die_flesh, 0.28, 0.1))
        write_ogg(OUT / f"enemy_die_bone_{letter}.ogg", _simple(3200 + i, die_bone, 0.22, 0.08))
        write_ogg(OUT / f"enemy_die_stone_{letter}.ogg", _simple(3300 + i, die_stone, 0.28, 0.1))
    for i, letter in enumerate("ab"):
        write_ogg(OUT / f"heal_{letter}.ogg", _simple(3400 + i, heal, 0.3, 0.14))
        write_ogg(OUT / f"shield_{letter}.ogg", _simple(3500 + i, shield, 0.2, 0.1))
        write_ogg(OUT / f"boss_tell_{letter}.ogg", _simple(3600 + i, tell, 0.6, 0.16))
        write_ogg(OUT / f"enrage_{letter}.ogg", _simple(3700 + i, enrage, 0.4, 0.12))
    print("moment sfx written")


def main() -> None:
    render_soft()
    render_spells()
    render_moments()


if __name__ == "__main__":
    main()
