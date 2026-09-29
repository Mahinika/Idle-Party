"""Small owned synth: oscillators, noise, a short room, and OGG export.

Used by the Idle Party audio generators. No samples from anywhere else.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from scipy.signal import lfilter

RATE = 44100


def midi_hz(note: float) -> float:
    return 440.0 * (2.0 ** ((note - 69.0) / 12.0))


def silence(seconds: float) -> np.ndarray:
    return np.zeros(int(seconds * RATE), dtype=np.float64)


def mix_at(buf: np.ndarray, start: float, clip: np.ndarray, amp: float = 1.0) -> None:
    if amp == 0 or clip.size == 0:
        return
    i0 = int(start * RATE)
    if i0 >= buf.size:
        return
    n = min(clip.size, buf.size - i0)
    if i0 < 0:
        clip = clip[-i0:]
        n = min(clip.size, buf.size)
        i0 = 0
    buf[i0 : i0 + n] += clip[:n] * amp


def env_exp(n: int, attack: float, decay: float) -> np.ndarray:
    t = np.arange(n, dtype=np.float64) / RATE
    att = np.minimum(1.0, t / max(attack, 1e-4))
    return att * np.exp(-t / max(decay, 1e-4))


def lowpass(x: np.ndarray, cutoff_hz: float) -> np.ndarray:
    cutoff = float(np.clip(cutoff_hz, 40.0, RATE * 0.45))
    a = 1.0 - np.exp(-2.0 * np.pi * cutoff / RATE)
    return lfilter([a], [1.0, a - 1.0], x)


def highpass(x: np.ndarray, cutoff_hz: float) -> np.ndarray:
    return x - lowpass(x, cutoff_hz)


def tone(
    seconds: float,
    hz: float,
    decay: float = 0.12,
    attack: float = 0.004,
    harmonics: tuple[float, ...] = (1.0, 0.35, 0.12),
) -> np.ndarray:
    n = max(1, int(seconds * RATE))
    t = np.arange(n, dtype=np.float64) / RATE
    e = env_exp(n, attack, decay)
    y = np.zeros(n, dtype=np.float64)
    for i, amp in enumerate(harmonics, start=1):
        y += amp * np.sin(2.0 * np.pi * hz * i * t)
    return y * e


def fm_bell(
    seconds: float,
    hz: float,
    ratio: float = 2.0,
    index: float = 2.4,
    decay: float = 0.2,
) -> np.ndarray:
    n = max(1, int(seconds * RATE))
    t = np.arange(n, dtype=np.float64) / RATE
    e = env_exp(n, 0.002, decay)
    mod = np.sin(2.0 * np.pi * hz * ratio * t) * index * e
    return np.sin(2.0 * np.pi * hz * t + mod) * e


def noise(seconds: float, rng: np.random.Generator, cutoff: float = 1800.0) -> np.ndarray:
    n = max(1, int(seconds * RATE))
    white = rng.standard_normal(n)
    return lowpass(white, cutoff)


def burst(
    seconds: float,
    rng: np.random.Generator,
    cutoff: float = 1600.0,
    decay: float = 0.05,
    attack: float = 0.001,
) -> np.ndarray:
    n = max(1, int(seconds * RATE))
    return noise(seconds, rng, cutoff) * env_exp(n, attack, decay)


def saturate(x: np.ndarray, drive: float = 1.35) -> np.ndarray:
    return np.tanh(x * drive)


def _echoes(x: np.ndarray, delay_s: float, gain: float, repeats: int = 8) -> np.ndarray:
    """Finite echoes. A long IIR comb overflows the Windows stack on a full bed."""
    delay = max(1, int(delay_s * RATE))
    out = np.zeros_like(x)
    amp = gain
    for _ in range(repeats):
        if delay >= x.size or abs(amp) < 0.02:
            break
        out[delay:] += x[:-delay] * amp
        delay += max(1, int(delay_s * RATE))
        amp *= gain
    return out


def reverb(x: np.ndarray, wet: float = 0.18, decay: float = 0.45) -> np.ndarray:
    if wet <= 0:
        return x
    taps = ((0.029, 0.62), (0.037, 0.55), (0.041, 0.5), (0.047, 0.46))
    room = np.zeros_like(x)
    for delay_s, gain in taps:
        room += _echoes(x, delay_s, gain * decay)
    room *= 0.25
    return x * (1.0 - wet) + room * wet


def normalize(x: np.ndarray, peak: float = 0.8, target_rms: float | None = None) -> np.ndarray:
    y = np.nan_to_num(x, copy=False)
    rms = float(np.sqrt(np.mean(y * y) + 1e-12))
    if target_rms is not None and rms > 0:
        y = y * (target_rms / rms)
    p = float(np.max(np.abs(y))) if y.size else 0.0
    if p > peak:
        y = y * (peak / p)
    return np.clip(y, -1.0, 1.0)


def seamless(x: np.ndarray, fade_s: float = 1.1) -> np.ndarray:
    fade = min(int(fade_s * RATE), x.size // 4)
    if fade < 8:
        return x
    ramp = np.linspace(0.0, 1.0, fade)
    y = x.copy()
    y[:fade] = x[:fade] * ramp + x[-fade:] * (1.0 - ramp)
    return y[:-fade]


def write_ogg(path, samples: np.ndarray, quality: int = 2) -> None:
    """OGG via ffmpeg. soundfile's vorbis writer overflows on long beds."""
    import subprocess
    import wave

    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    wav_path = path.with_suffix(".tmp.wav")
    pcm = np.clip(np.asarray(samples), -1.0, 1.0)
    frames = (pcm * 32767.0).astype(np.int16)
    with wave.open(str(wav_path), "w") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(frames.tobytes())
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-loglevel",
            "error",
            "-i",
            str(wav_path),
            "-c:a",
            "libvorbis",
            "-q:a",
            str(quality),
            str(path),
        ],
        check=True,
    )
    wav_path.unlink(missing_ok=True)
