"""Owned procedural score cues for Idle Party.

Do not overwrite:
  music/hub.ogg      — Heavenly Loop (isaiah658, CC0)
  music/dungeon.mp3  — owned ElevenLabs loop (“Deep Cave Hush”)

Writes:
  music/boss.wav     — unresolved boss bed (dominant pedal, loops)
  music/resolve.wav  — short consonant landing when a floor clears
  music/down.wav     — short falling phrase on a wipe
"""

from __future__ import annotations

import math
import pathlib
import random
import struct
import wave

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "custom" / "audio" / "music"
RATE = 22050


def _hz(note: float) -> float:
    """MIDI note number → Hz."""
    return 440.0 * (2.0 ** ((note - 69) / 12.0))


def _add(
    buf: list[float],
    start: float,
    dur: float,
    note: float,
    vol: float,
    harmonics: tuple[float, ...] = (1.0, 0.28, 0.08),
    attack: float = 0.03,
    release: float = 0.12,
) -> None:
    if dur <= 0 or vol <= 0:
        return
    i0 = int(start * RATE)
    n = int(dur * RATE)
    hz = _hz(note)
    # Tiny detune so stacked sines are not a pure dial tone.
    det = (1.0, 1.003, 0.997)
    for i in range(n):
        idx = i0 + i
        if idx < 0 or idx >= len(buf):
            continue
        t = i / RATE
        env = 1.0
        if t < attack:
            env = t / attack
        tail = dur - t
        if tail < release:
            env *= max(0.0, tail / release)
        s = 0.0
        for h_i, amp in enumerate(harmonics, start=1):
            s += amp * math.sin(2 * math.pi * hz * h_i * det[h_i % 3] * t)
        buf[idx] += s * vol * env


def _pulse(buf: list[float], t0: float, vol: float, rng: random.Random) -> None:
    """Soft tick, not a drum machine."""
    i0 = int(t0 * RATE)
    n = int(0.09 * RATE)
    for i in range(n):
        idx = i0 + i
        if idx < 0 or idx >= len(buf):
            continue
        env = math.exp(-i / (RATE * 0.028))
        noise = rng.random() * 2 - 1
        thump = math.sin(2 * math.pi * 78 * (i / RATE))
        buf[idx] += (thump * 0.75 + noise * 0.25) * vol * env


def _normalize(buf: list[float], peak: float = 0.82) -> None:
    m = max(1e-6, max(abs(s) for s in buf))
    g = peak / m
    for i, s in enumerate(buf):
        buf[i] = max(-1.0, min(1.0, s * g))


def _write(path: pathlib.Path, buf: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for s in buf:
            frames += struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767))
        w.writeframes(frames)


def _edge_dip(buf: list[float], seconds: float = 0.012) -> None:
    """Zero the join so a loop does not click. Lands on the downbeat."""
    n = int(RATE * seconds)
    for i in range(n):
        w = i / n
        buf[i] *= w
        buf[-1 - i] *= w


def write_boss(path: pathlib.Path) -> None:
    """20s at 96 BPM. Bass stays on E — the tonic never arrives."""
    seconds = 20.0
    buf = [0.0] * int(RATE * seconds)
    rng = random.Random(7)
    beat = 60.0 / 96.0
    # Em7 colour over an E pedal, then a leading tone that does not resolve.
    melody = [
        64, 67, 69, 71,  # E G A B
        72, 71, 69, 67,  # C B A G
        69, 71, 72, 74,  # A B C D
        72, 71, 69, 68,  # C B A G#
    ]
    for bar in range(2):
        for i, note in enumerate(melody):
            _add(
                buf,
                (bar * 16 + i) * beat,
                beat * 0.92,
                note,
                0.22,
                attack=0.04,
                release=0.18,
            )
    # Pedal and a suspended colour. No A in the bass.
    for bar in range(8):
        t = bar * 4 * beat
        _add(buf, t, 4 * beat * 0.98, 40, 0.34, harmonics=(1.0, 0.15), release=0.2)
        color = 52 if bar % 2 == 0 else 55  # E3 / G3
        _add(buf, t, 4 * beat * 0.98, color, 0.16, harmonics=(1.0, 0.2), release=0.25)
        _add(buf, t, 4 * beat * 0.98, 59, 0.10, harmonics=(1.0, 0.12), release=0.3)
    for b in range(32):
        accent = 0.16 if b % 4 == 0 else 0.07
        _pulse(buf, b * beat, accent, rng)
    _normalize(buf, 0.78)
    _edge_dip(buf)
    _write(path, buf)


def write_resolve(path: pathlib.Path) -> None:
    """Dominant, then a major landing. One shot, about 6.5s."""
    seconds = 6.5
    buf = [0.0] * int(RATE * seconds)
    # E major (the boss pedal) into A major.
    _add(buf, 0.0, 2.1, 40, 0.30, harmonics=(1.0, 0.2), release=0.35)
    _add(buf, 0.0, 2.0, 52, 0.16, release=0.3)
    _add(buf, 0.05, 1.7, 64, 0.20, release=0.25)
    _add(buf, 1.85, 4.4, 45, 0.32, harmonics=(1.0, 0.22, 0.06), release=1.4)
    _add(buf, 1.9, 4.2, 52, 0.18, release=1.3)
    _add(buf, 1.95, 4.0, 57, 0.16, release=1.2)
    _add(buf, 2.05, 3.6, 61, 0.14, release=1.1)
    _add(buf, 0.15, 1.15, 64, 0.24, release=0.2)
    _add(buf, 1.15, 0.85, 68, 0.22, release=0.18)
    _add(buf, 2.05, 3.8, 69, 0.26, release=1.3)
    _normalize(buf, 0.8)
    _write(path, buf)


def write_down(path: pathlib.Path) -> None:
    """Falling minor line into silence. One shot, about 4.8s."""
    seconds = 4.8
    buf = [0.0] * int(RATE * seconds)
    notes = [69, 67, 65, 64, 62]
    for i, note in enumerate(notes):
        vol = 0.28 * (1.0 - i * 0.14)
        _add(
            buf,
            0.12 + i * 0.72,
            1.05,
            note,
            vol,
            harmonics=(1.0, 0.18),
            attack=0.02,
            release=0.45,
        )
        _add(
            buf,
            0.12 + i * 0.72,
            1.15,
            note - 12,
            vol * 0.7,
            harmonics=(1.0, 0.1),
            attack=0.03,
            release=0.5,
        )
    _normalize(buf, 0.72)
    # Fade the tail so the file itself ends quiet.
    fade = int(RATE * 1.1)
    for i in range(fade):
        buf[-1 - i] *= i / fade
    _write(path, buf)


def main() -> None:
    write_boss(OUT / "boss.wav")
    write_resolve(OUT / "resolve.wav")
    write_down(OUT / "down.wav")
    kept = sorted(p.name for p in OUT.iterdir())
    print("music:", kept)


if __name__ == "__main__":
    main()
