"""Generate soft Idle Party ambience loops (owned procedural pads)."""

from __future__ import annotations

import math
import pathlib
import random
import struct
import wave

ROOT = pathlib.Path(__file__).resolve().parents[1]
CUSTOM_AMB = ROOT / "assets" / "custom" / "audio" / "ambience"
KENNEY_AMB = ROOT / "assets" / "kenney" / "audio" / "ambience"


def write_pad(
    path: pathlib.Path,
    seconds: float,
    base_hz: float,
    noise: float = 0.02,
    vol: float = 0.08,
) -> None:
    rate = 22050
    n = int(rate * seconds)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        frames = bytearray()
        for i in range(n):
            t = i / rate
            env = min(1.0, t * 0.5, (seconds - t) * 0.5)
            s = math.sin(2 * math.pi * base_hz * t) * 0.55
            s += math.sin(2 * math.pi * (base_hz * 1.5) * t) * 0.25
            s += (random.random() * 2 - 1) * noise
            v = int(max(-1.0, min(1.0, s * vol * env)) * 32767)
            frames += struct.pack("<h", v)
        w.writeframes(frames)


def main() -> None:
    write_pad(CUSTOM_AMB / "hub.wav", 12.0, 110.0, noise=0.015, vol=0.06)
    write_pad(CUSTOM_AMB / "dungeon.wav", 14.0, 70.0, noise=0.03, vol=0.07)
    if KENNEY_AMB.exists():
        for p in KENNEY_AMB.glob("_src_*.ogg"):
            p.unlink(missing_ok=True)
    print("wrote", sorted(p.name for p in CUSTOM_AMB.iterdir()))


if __name__ == "__main__":
    main()
