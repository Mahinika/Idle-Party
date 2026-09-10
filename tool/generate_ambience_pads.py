"""Generate soft Idle Party ambience loops (owned procedural pads)."""

from __future__ import annotations

import math
import pathlib
import random
import struct
import wave

ROOT = pathlib.Path(__file__).resolve().parents[1]
CUSTOM_AMB = ROOT / "assets" / "custom" / "audio" / "ambience"


def write_pad(
    path: pathlib.Path,
    seconds: float,
    bases: list[float],
    noise: float = 0.012,
    vol: float = 0.055,
) -> None:
    rate = 22050
    n = int(rate * seconds)
    path.parent.mkdir(parents=True, exist_ok=True)
    rng = random.Random(path.name)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        frames = bytearray()
        for i in range(n):
            t = i / rate
            # Seamless-ish: fade ends, slow LFO on pads.
            env = min(1.0, t * 0.4, (seconds - t) * 0.4)
            lfo = 0.92 + 0.08 * math.sin(2 * math.pi * 0.07 * t)
            s = 0.0
            for j, hz in enumerate(bases):
                wobble = 1.0 + 0.01 * math.sin(2 * math.pi * (0.05 + j * 0.03) * t)
                s += math.sin(2 * math.pi * hz * wobble * t) * (0.45 / (j + 1))
            s += (rng.random() * 2 - 1) * noise
            v = int(max(-1.0, min(1.0, s * vol * env * lfo)) * 32767)
            frames += struct.pack("<h", v)
        w.writeframes(frames)


def main() -> None:
    # Warm camp / sanctuary bed.
    write_pad(
        CUSTOM_AMB / "hub.wav",
        16.0,
        bases=[82.0, 123.0, 164.0],
        noise=0.008,
        vol=0.05,
    )
    # Darker cave bed under dungeon music.
    write_pad(
        CUSTOM_AMB / "dungeon.wav",
        18.0,
        bases=[55.0, 82.0, 110.0],
        noise=0.018,
        vol=0.055,
    )
    print("wrote", sorted(p.name for p in CUSTOM_AMB.iterdir()))


if __name__ == "__main__":
    main()
