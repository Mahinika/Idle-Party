"""Generate soft Idle Party background music loops (owned procedural pads + melody)."""

from __future__ import annotations

import math
import pathlib
import random
import struct
import wave

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "custom" / "audio" / "music"
RATE = 22050


def _fade_env(t: float, seconds: float, fade: float = 0.6) -> float:
    return min(1.0, t / fade, max(0.0, (seconds - t) / fade))


def _note_hz(midi: float) -> float:
    return 440.0 * (2.0 ** ((midi - 69.0) / 12.0))


def _pad_sample(t: float, base_hz: float, wobble: float = 0.08) -> float:
    w = math.sin(2 * math.pi * wobble * t) * 0.015
    hz = base_hz * (1.0 + w)
    s = math.sin(2 * math.pi * hz * t) * 0.42
    s += math.sin(2 * math.pi * hz * 1.5 * t) * 0.18
    s += math.sin(2 * math.pi * hz * 2.0 * t) * 0.08
    return s


def _melody_value(
    t: float,
    bpm: float,
    scale: list[float],
    pattern: list[int],
    beat_div: int = 2,
    octave: float = 0.0,
) -> float:
    beat = (t * bpm) / 60.0
    step = int(beat * beat_div) % len(pattern)
    idx = pattern[step]
    if idx < 0:
        return 0.0
    midi = scale[idx % len(scale)] + octave * 12.0
    hz = _note_hz(midi)
    local = (beat * beat_div) % 1.0
    env = min(1.0, local * 8.0) * max(0.0, 1.0 - local * 1.2)
    return math.sin(2 * math.pi * hz * t) * env * 0.28


def write_loop(
    path: pathlib.Path,
    seconds: float,
    bpm: float,
    root_midi: float,
    pattern: list[int],
    beat_div: int = 2,
    pad_hz: float | None = None,
    pad_noise: float = 0.008,
    vol: float = 0.55,
    octave: float = 0.0,
) -> None:
    """Pentatonic pad + sparse melody — no drums, seamless loop."""
    # Major pentatonic offsets from root.
    scale = [root_midi + o for o in (0, 2, 4, 7, 9, 12, 14, 16, 19, 21)]
    if pad_hz is None:
        pad_hz = _note_hz(root_midi - 12.0)

    n = int(RATE * seconds)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        rng = random.Random(42)
        for i in range(n):
            t = i / RATE
            env = _fade_env(t, seconds, fade=0.8)
            s = _pad_sample(t, pad_hz) * 0.55
            s += _melody_value(t, bpm, scale, pattern, beat_div, octave)
            s += (rng.random() * 2 - 1) * pad_noise
            v = int(max(-1.0, min(1.0, s * vol * env)) * 32767)
            frames += struct.pack("<h", v)
        w.writeframes(frames)
    print("wrote", path.relative_to(ROOT), f"{path.stat().st_size // 1024} KB")


def main() -> None:
    # 36s @ 80 BPM = 48 quarter beats — integer loop length.
    write_loop(
        OUT / "hub.wav",
        seconds=36.0,
        bpm=80.0,
        root_midi=57.0,  # A3 — warm hub
        pattern=[0, 2, 4, 2, 0, -1, 3, 4, 2, 0, -1, -1, 4, 3, 2, 0],
        beat_div=2,
        vol=0.48,
    )
    # dungeon.mp3: owned ElevenLabs loop — do not overwrite with procedural.
    print("done:", sorted(p.name for p in OUT.iterdir()))


if __name__ == "__main__":
    main()
