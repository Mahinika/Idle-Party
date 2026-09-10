"""Generate Idle Party spell combat SFX (owned, 5-layer idle-RPG chirps).

Schools: shadow, fire, frost, nature, arcane, holy, lightning, demon, poison.
Physical (sword/arrow/blunt) stays in generate_soft_sfx.py (hit_* + swish_*).

Each clip stacks: Base · Grain/Identity · Motion · Impact · light FX tail.
Mono 22.05 kHz — stereo width from the design doc is approximated with
phase-ish noise density, not a second channel.
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


def clamp(x: float, lo: float = -1.0, hi: float = 1.0) -> float:
    return lo if x < lo else hi if x > hi else x


def env_adsr(
    t: float,
    attack: float,
    decay: float,
    sustain: float,
    release: float,
    dur: float,
    peak: float = 1.0,
) -> float:
    """ADSR with sustain level (0 = no sustain plateau)."""
    if t < 0 or t >= dur:
        return 0.0
    if attack > 0 and t < attack:
        return peak * (t / attack)
    td = t - attack
    if decay > 0 and td < decay:
        return peak + (sustain - peak) * (td / decay)
    rem = dur - t
    if release > 0 and rem < release:
        # Level just before release: sustain if we had plateau, else peak decay end.
        level = sustain if sustain > 0 else peak * 0.15
        return level * (rem / release)
    return sustain if sustain > 0 else 0.0


def soft_clip(x: float, drive: float = 1.4) -> float:
    return math.tanh(x * drive)


def bitcrush(x: float, bits: float = 10.0) -> float:
    steps = max(2.0, 2.0**bits)
    return round(x * (steps * 0.5)) / (steps * 0.5)


def noise() -> float:
    return random.random() * 2.0 - 1.0


def pinkish(state: list[float]) -> float:
    """Very cheap pink-ish noise (one-pole on white)."""
    w = noise()
    state[0] = state[0] * 0.92 + w * 0.08
    return state[0] * 3.5


def tone(freq: float, t: float) -> float:
    return math.sin(2.0 * math.pi * freq * t)


def fm(carrier: float, mod: float, index: float, t: float) -> float:
    return math.sin(2.0 * math.pi * carrier * t + index * math.sin(2.0 * math.pi * mod * t))


def write_buf(name: str, samples: list[float], vol: float = 0.42) -> None:
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = max((abs(s) for s in samples), default=1.0) or 1.0
    norm = vol / peak
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for s in samples:
            v = int(clamp(s * norm) * 32767)
            frames += struct.pack("<h", v)
        w.writeframes(frames)
    print("wrote", path.relative_to(ROOT), path.stat().st_size)


def render(seconds: float, layers, seed: int) -> list[float]:
    random.seed(seed)
    n = int(RATE * seconds)
    out = [0.0] * n
    pink = [0.0]
    # Simple one-pole LP/HP states shared per render.
    lp = [0.0]
    hp_prev = [0.0, 0.0]  # x[n-1], y[n-1]

    def lp_f(x: float, a: float = 0.12) -> float:
        lp[0] = lp[0] + a * (x - lp[0])
        return lp[0]

    def hp_f(x: float, a: float = 0.96) -> float:
        y = a * (hp_prev[1] + x - hp_prev[0])
        hp_prev[0], hp_prev[1] = x, y
        return y

    for i in range(n):
        t = i / RATE
        s = 0.0
        for layer in layers:
            s += layer(t, seconds, noise, pinkish, pink, tone, fm, bitcrush, lp_f, hp_f, env_adsr)
        # Light master EQ: +3k-ish via mild brighten, cut mud ~200 Hz.
        bright = s - lp_f(s, 0.08) * 0.35
        mud_cut = s - lp_f(s, 0.04) * 0.55
        mixed = s * 0.55 + bright * 0.25 + mud_cut * 0.20
        # Soft compression proxy.
        out[i] = soft_clip(mixed, 1.25)
    return out


# —— School layer factories ——


def shadow_layers():
    def base(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.012, 0.16, 0.0, 0.14, dur, 1.0)
        rumble = tone(55, t) * 0.55 + tone(70, t) * 0.25
        return lp(rumble + pinkish(pink) * 0.15, 0.06) * e * 0.9

    def grain(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.008, 0.18, 0.0, 0.12, dur, 1.0)
        return bitcrush(noise(), 9) * e * 0.22

    def motion(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        # Inward suck: reverse-shaped noise (louder later, then cut).
        e = env(t, 0.02, 0.22, 0.0, 0.1, dur, 1.0)
        suck = (t / max(dur, 1e-6)) ** 1.6
        return hp(noise(), 0.97) * suck * e * 0.28

    def impact(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.0, 0.09, 0.0, 0.08, dur, 1.0)
        pop = tone(1600, t) * math.exp(-t * 28) + tone(2100, t) * 0.4 * math.exp(-t * 40)
        return (pop + noise() * 0.15) * e * 0.7

    def fx(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.05, 0.2, 0.0, 0.18, dur, 0.6)
        return soft_clip(pinkish(pink) * 0.12 + tone(90, t) * 0.08, 2.0) * e * 0.35

    return [base, grain, motion, impact, fx]


def fire_layers():
    def base(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.015, 0.2, 0.05, 0.16, dur, 1.0)
        roar = lp(noise(), 0.18) * 0.7 + tone(260, t) * 0.2
        return roar * e * 0.85

    def crackle(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.0, 0.22, 0.0, 0.1, dur, 1.0)
        pops = 1.0 if (int(t * 55) % 4 == 0) else 0.15
        return bitcrush(noise(), 11) * pops * e * 0.28

    def motion(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.012, 0.18, 0.0, 0.12, dur, 1.0)
        whoosh = hp(noise(), 0.94) * (0.5 + 0.5 * math.sin(t * 40))
        return whoosh * e * 0.35

    def impact(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.0, 0.12, 0.0, 0.1, dur, 1.0)
        thump = tone(95, t) * math.exp(-t * 16) + tone(140, t) * 0.35 * math.exp(-t * 22)
        return thump * e * 0.9

    def fx(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.04, 0.22, 0.0, 0.2, dur, 0.5)
        return (hp(noise(), 0.98) * 0.1 + tone(3200, t) * 0.05 * math.exp(-t * 8)) * e

    return [base, crackle, motion, impact, fx]


def frost_layers():
    def base(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.02, 0.22, 0.0, 0.2, dur, 1.0)
        return pinkish(pink) * e * 0.55

    def crystal(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.005, 0.18, 0.0, 0.16, dur, 1.0)
        shimmer = tone(2800 + 400 * math.sin(t * 30), t) * 0.35 + tone(3600, t) * 0.2
        return shimmer * e * 0.55

    def motion(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.015, 0.2, 0.0, 0.14, dur, 1.0)
        brittle = bitcrush(hp(noise(), 0.95), 12) * 0.4
        return brittle * e * 0.4

    def impact(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.0, 0.1, 0.0, 0.12, dur, 1.0)
        crack = tone(1800, t) * math.exp(-t * 22) + tone(2400, t) * 0.5 * math.exp(-t * 35)
        return (crack + noise() * 0.2) * e * 0.75

    def fx(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.06, 0.28, 0.0, 0.22, dur, 0.45)
        return tone(2200, t) * 0.08 * e + pinkish(pink) * 0.06 * e

    return [base, crystal, motion, impact, fx]


def nature_layers():
    def base(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.015, 0.18, 0.05, 0.16, dur, 1.0)
        return (tone(140, t) * 0.5 + tone(180, t) * 0.3) * e * 0.7

    def organic(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.01, 0.2, 0.0, 0.14, dur, 1.0)
        rustle = pinkish(pink) * 0.35
        chime = tone(990, t) * 0.12 * math.exp(-t * 10) + tone(1320, t) * 0.08 * math.exp(-t * 14)
        return (rustle + chime) * e * 0.55

    def motion(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.012, 0.18, 0.0, 0.12, dur, 1.0)
        return hp(noise(), 0.96) * e * 0.28

    def impact(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.0, 0.11, 0.0, 0.1, dur, 1.0)
        thump = tone(150, t) * math.exp(-t * 14) + tone(220, t) * 0.3 * math.exp(-t * 20)
        return thump * e * 0.8

    def fx(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.05, 0.22, 0.0, 0.18, dur, 0.4)
        delay = tone(440, t - 0.04) * 0.06 if t > 0.04 else 0.0
        return (pinkish(pink) * 0.05 + delay) * e

    return [base, organic, motion, impact, fx]


def arcane_layers():
    def base(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.01, 0.16, 0.08, 0.14, dur, 1.0)
        return (tone(260, t) * 0.45 + tone(310, t) * 0.3) * e * 0.75

    def spark(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.0, 0.2, 0.0, 0.12, dur, 1.0)
        sparkle = tone(5200 + 600 * math.sin(t * 55), t) * 0.25
        sparkle += bitcrush(noise(), 12) * 0.12 * (1 if int(t * 70) % 3 == 0 else 0.2)
        return sparkle * e * 0.55

    def motion(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.015, 0.2, 0.0, 0.14, dur, 1.0)
        sweep = tone(400 + t * 1800, t) * 0.35
        return sweep * e * 0.5

    def impact(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.0, 0.09, 0.0, 0.1, dur, 1.0)
        pop = tone(1400, t) * math.exp(-t * 26) + tone(1900, t) * 0.4 * math.exp(-t * 38)
        return pop * e * 0.7

    def fx(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.04, 0.24, 0.0, 0.2, dur, 0.5)
        return (tone(4800, t) * 0.06 + pinkish(pink) * 0.05) * e

    return [base, spark, motion, impact, fx]


def holy_layers():
    def base(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.015, 0.18, 0.1, 0.18, dur, 1.0)
        return (tone(360, t) * 0.4 + tone(440, t) * 0.28) * e * 0.7

    def choir(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.03, 0.22, 0.08, 0.2, dur, 0.8)
        pad = tone(660, t) * 0.18 + tone(880, t) * 0.12 + tone(1100, t) * 0.08
        # Soft saw-ish via odd harmonics, LPF-ish by amplitude.
        saw = sum(tone(300 * k, t) / k for k in range(1, 5)) * 0.08
        return (pad + lp(saw, 0.1)) * e * 0.65

    def motion(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.012, 0.18, 0.0, 0.14, dur, 1.0)
        return hp(noise(), 0.97) * 0.2 * e + tone(1200 + t * 400, t) * 0.15 * e

    def impact(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.0, 0.12, 0.0, 0.14, dur, 1.0)
        chime = tone(1320, t) * math.exp(-t * 12) + tone(1980, t) * 0.45 * math.exp(-t * 18)
        return chime * e * 0.75

    def fx(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.08, 0.28, 0.0, 0.24, dur, 0.55)
        return (tone(990, t) * 0.07 + pinkish(pink) * 0.04) * e

    return [base, choir, motion, impact, fx]


def lightning_layers():
    """Storm lightning — electric hum + crackle + zap + thunder pop + bright delay."""

    def base(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.008, 0.15, 0.0, 0.1, dur, 1.0)
        hum = tone(110, t) * 0.4 + tone(220, t) * 0.25
        hum += fm(110, 220, 0.35, t) * 0.2
        band = hp(lp(noise(), 0.35), 0.85)  # ~1.5–4.5 kHz-ish proxy
        return (hum + band * 0.35 + bitcrush(noise(), 10) * 0.12) * e * 0.8

    def crackle(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.0, 0.08, 0.0, 0.05, dur, 1.0)
        snap = noise() * (1 if t < 0.012 else 0.25)
        crack = tone(400 + min(t, 0.04) / 0.04 * 1600, t) * math.exp(-t * 35)
        return (snap * 0.5 + crack * 0.6 + bitcrush(noise(), 8) * 0.2) * e * 0.85

    def motion(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.015, 0.22, 0.0, 0.16, dur, 1.0)
        whoosh = hp(noise(), 0.92) * 0.4
        sizzle = fm(900, 120, 0.45, t) * 0.25
        return (whoosh + sizzle) * e * 0.55

    def impact(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.0, 0.14, 0.0, 0.12, dur, 1.0)
        thump = tone(100, t) * math.exp(-t * 14)
        pop = tone(1600, t) * math.exp(-t * 24)
        thunder = tone(3200, t) * 0.35 * math.exp(-t * 30) + lp(noise(), 0.08) * 0.2 * math.exp(-t * 10)
        # Reverse-suck before peak (early noise rising).
        suck = hp(noise(), 0.98) * max(0.0, 1.0 - t * 8) * 0.15 if t < 0.12 else 0.0
        return (thump + pop + thunder + suck) * e * 0.9

    def fx(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.05, 0.2, 0.0, 0.16, dur, 0.45)
        # Bright 1/16-ish delay tap (~0.075s at ~120bpm feel).
        tap = 0.0
        if t > 0.075:
            tap = tone(1800, t - 0.075) * 0.08 * math.exp(-(t - 0.075) * 18)
        return (tap + hp(noise(), 0.98) * 0.06) * e

    return [base, crackle, motion, impact, fx]


def demon_layers():
    def base(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.02, 0.2, 0.05, 0.16, dur, 1.0)
        growl = tone(60, t) * 0.55 + tone(85, t) * 0.3 + fm(70, 30, 0.8, t) * 0.25
        return lp(growl, 0.1) * e * 0.9

    def corruption(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.01, 0.22, 0.0, 0.14, dur, 1.0)
        return soft_clip(bitcrush(noise(), 7) * 0.45 + pinkish(pink) * 0.2, 2.2) * e * 0.45

    def motion(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.015, 0.2, 0.0, 0.12, dur, 1.0)
        sweep = tone(120 + t * 900 + 80 * math.sin(t * 70), t) * 0.4
        return soft_clip(sweep + noise() * 0.15, 1.8) * e * 0.5

    def impact(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.0, 0.14, 0.0, 0.12, dur, 1.0)
        slam = tone(75, t) * math.exp(-t * 12) + tone(110, t) * 0.4 * math.exp(-t * 18)
        return soft_clip(slam + noise() * 0.25, 2.0) * e * 0.85

    def fx(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.05, 0.22, 0.0, 0.18, dur, 0.5)
        return soft_clip(pinkish(pink) * 0.2, 2.5) * e * 0.4

    return [base, corruption, motion, impact, fx]


def poison_layers():
    def base(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.012, 0.18, 0.05, 0.14, dur, 1.0)
        hiss = hp(lp(noise(), 0.45), 0.7)  # ~1–3 kHz band proxy
        return hiss * e * 0.7

    def toxin(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.01, 0.22, 0.0, 0.12, dur, 1.0)
        bubble = tone(180 + 40 * math.sin(t * 25), t) * 0.15 * (1 if int(t * 28) % 2 == 0 else 0.3)
        fizz = bitcrush(noise(), 11) * 0.2
        return (bubble + fizz) * e * 0.55

    def motion(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.02, 0.2, 0.0, 0.14, dur, 1.0)
        slither = pinkish(pink) * 0.35 * (0.6 + 0.4 * math.sin(t * 18))
        return slither * e * 0.45

    def impact(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.0, 0.12, 0.0, 0.12, dur, 1.0)
        splat = lp(noise(), 0.25) * math.exp(-t * 14) + tone(220, t) * 0.25 * math.exp(-t * 18)
        return splat * e * 0.75

    def fx(t, dur, noise, pinkish, pink, tone, fm, bitcrush, lp, hp, env):
        e = env(t, 0.06, 0.24, 0.0, 0.2, dur, 0.4)
        return lp(pinkish(pink), 0.15) * e * 0.25

    return [base, toxin, motion, impact, fx]


def main() -> None:
    schools = [
        ("spell_shadow.wav", 0.42, shadow_layers(), 101),
        ("spell_fire.wav", 0.40, fire_layers(), 202),
        ("spell_frost.wav", 0.44, frost_layers(), 303),
        ("spell_nature.wav", 0.40, nature_layers(), 404),
        ("spell_arcane.wav", 0.38, arcane_layers(), 505),
        ("spell_holy.wav", 0.46, holy_layers(), 606),
        ("spell_lightning.wav", 0.42, lightning_layers(), 707),
        ("spell_demon.wav", 0.44, demon_layers(), 808),
        ("spell_poison.wav", 0.42, poison_layers(), 909),
    ]
    for name, seconds, layers, seed in schools:
        write_buf(name, render(seconds, layers, seed), vol=0.40)


if __name__ == "__main__":
    main()
