#!/usr/bin/env python3
"""Build a vertical feed Short from A56 combat (not the Play listing trailer).

Ad shape: 1.8s hook card → three zone gameplay cuts → store CTA end card.
Owned marketing stills + dungeon.mp3. No trending audio.

  py -3 tool/store_listing/build_shorts_feed.py
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

_LISTING = Path(__file__).resolve().parent
if str(_LISTING) not in sys.path:
    sys.path.insert(0, str(_LISTING))

from build_preview_video import (
    BG_RGB,
    CAPTION_FG,
    FPS,
    LISTING,
    MUSIC,
    OUT,
    find_ffmpeg,
    fit_canvas,
    load_font,
    make_still_mp4,
)

RAW = OUT / "gameplay_shorts_raw.mp4"
DEST = OUT / "idle_party_shorts_feed.mp4"
FEED_MUSIC = MUSIC.with_name("dungeon.mp3")
MARKETING = LISTING / "marketing"
INTRO_STILL = MARKETING / "03_party_fights_1080x1920.png"
OUTRO_STILL = MARKETING / "07_afk_progress_1080x1920.png"

WIDTH = 1080
HEIGHT = 1920
SRC_H = 2340
CROP_Y = 150
INTRO_DUR = 1.8
OUTRO_DUR = 2.6
GOLD = (220, 181, 102)
DEFAULT_SHOTS: list[dict[str, object]] = [
    {"raw": "gameplay_shorts_hell_raw.mp4", "start": 1.2, "duration": 3.7},
    {"raw": "gameplay_shorts_crystal_raw.mp4", "start": 1.2, "duration": 3.7},
    {"raw": "gameplay_shorts_veil_raw.mp4", "start": 1.2, "duration": 3.7},
]


def paint_outro(path: Path) -> None:
    """Product shot + Play Store CTA — typical game-ad end card."""
    src = Image.open(OUTRO_STILL).convert("RGB")
    if src.size != (WIDTH, HEIGHT):
        src = fit_canvas(src, WIDTH, HEIGHT)
    out = src.copy()
    draw = ImageDraw.Draw(out, "RGBA")
    band_top = HEIGHT - 400
    draw.rectangle((0, band_top, WIDTH, HEIGHT), fill=(*BG_RGB, 255))
    title = load_font(70)
    cta = load_font(40)
    hint = load_font(28)

    def center(text: str, font, y: int, fill) -> None:
        bbox = draw.textbbox((0, 0), text, font=font)
        tw = bbox[2] - bbox[0]
        draw.text(((WIDTH - tw) / 2, y), text, font=font, fill=fill)

    center("Idle Party", title, band_top + 36, (*CAPTION_FG, 255))
    btn_w, btn_h = 720, 92
    btn_x = (WIDTH - btn_w) // 2
    btn_y = band_top + 132
    draw.rounded_rectangle(
        (btn_x, btn_y, btn_x + btn_w, btn_y + btn_h),
        radius=22,
        fill=(159, 92, 28, 255),
        outline=GOLD,
        width=3,
    )
    bbox = draw.textbbox((0, 0), "Free on Google Play", font=cta)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(
        (btn_x + (btn_w - tw) / 2, btn_y + (btn_h - th) / 2 - 4),
        "Free on Google Play",
        font=cta,
        fill=(*CAPTION_FG, 255),
    )
    center("Open the store page to download", hint, band_top + 248, (220, 200, 170, 255))
    out.convert("RGB").save(path)


def mux_audio(ffmpeg: str, video: Path, dest: Path, total: float) -> None:
    fade_out_start = max(0.0, total - 1.2)
    af = (
        f"afade=t=in:st=0:d=0.25,afade=t=out:st={fade_out_start:.2f}:d=1.1,"
        f"volume=0.55"
    )
    cmd = [
        ffmpeg,
        "-y",
        "-i",
        str(video),
        "-stream_loop",
        "-1",
        "-i",
        str(FEED_MUSIC),
        "-filter_complex",
        f"[1:a]{af}[a]",
        "-map",
        "0:v",
        "-map",
        "[a]",
        "-c:v",
        "copy",
        "-c:a",
        "aac",
        "-b:a",
        "160k",
        "-shortest",
        "-movflags",
        "+faststart",
        str(dest),
    ]
    print("+ mux audio")
    subprocess.run(cmd, check=True, capture_output=True)


def run_ffmpeg(ffmpeg: str, cmd: list[str], label: str) -> None:
    print("+", label)
    proc = subprocess.run(cmd, capture_output=True)
    if proc.returncode != 0:
        err = proc.stderr.decode("utf-8", errors="replace")[-2000:]
        raise SystemExit(f"ffmpeg failed ({label}):\n{err}")


def crop_shot(
    ffmpeg: str,
    src: Path,
    dest: Path,
    *,
    start: float,
    duration: float,
    crop_y: int,
) -> None:
    crop_y = max(0, min(crop_y, SRC_H - HEIGHT))
    fc = (
        f"[0:v]trim=start={start:.3f}:duration={duration:.3f},"
        f"setpts=PTS-STARTPTS,fps={FPS},"
        f"crop={WIDTH}:{HEIGHT}:0:{crop_y},"
        f"eq=contrast=1.1:saturation=1.18:brightness=0.03,"
        f"format=yuv420p[vout]"
    )
    run_ffmpeg(
        ffmpeg,
        [
            ffmpeg,
            "-y",
            "-i",
            str(src),
            "-filter_complex",
            fc,
            "-map",
            "[vout]",
            "-t",
            f"{duration:.3f}",
            "-r",
            str(FPS),
            "-c:v",
            "libx264",
            "-preset",
            "veryfast",
            "-crf",
            "19",
            "-an",
            str(dest),
        ],
        f"crop {src.name}",
    )


def concat_shots(ffmpeg: str, clips: list[Path], dest: Path) -> None:
    if len(clips) == 1:
        dest.write_bytes(clips[0].read_bytes())
        return
    inputs: list[str] = []
    for c in clips:
        inputs.extend(["-i", str(c)])
    parts = "".join(f"[{i}:v]" for i in range(len(clips)))
    fc = f"{parts}concat=n={len(clips)}:v=1:a=0[vout]"
    run_ffmpeg(
        ffmpeg,
        [
            ffmpeg,
            "-y",
            *inputs,
            "-filter_complex",
            fc,
            "-map",
            "[vout]",
            "-r",
            str(FPS),
            "-c:v",
            "libx264",
            "-preset",
            "veryfast",
            "-crf",
            "19",
            "-an",
            str(dest),
        ],
        f"concat {len(clips)} shots",
    )


def resolve_raw(name: str) -> Path:
    p = Path(name)
    if p.exists():
        return p
    cand = OUT / p.name
    if cand.exists():
        return cand
    cand = LISTING / p
    if cand.exists():
        return cand
    return OUT / p.name


def load_shots() -> tuple[list[dict[str, object]], int]:
    cfg = OUT / "shorts_feed.json"
    crop_y = CROP_Y
    shots = list(DEFAULT_SHOTS)
    if cfg.exists():
        data = json.loads(cfg.read_text(encoding="utf-8"))
        crop_y = int(data.get("crop_y", crop_y))
        if isinstance(data.get("shots"), list) and data["shots"]:
            shots = data["shots"]
        elif "raw" in data or "start" in data:
            shots = [
                {
                    "raw": data.get("raw", RAW.name),
                    "start": data.get("start", 0.8),
                    "duration": data.get("duration", 11.0),
                }
            ]
    return shots, crop_y


def build() -> None:
    if not FEED_MUSIC.exists():
        raise SystemExit(f"missing owned music {FEED_MUSIC}")
    ffmpeg = find_ffmpeg()
    shots, crop_y = load_shots()
    resolved: list[tuple[Path, float, float]] = []
    for shot in shots:
        raw = resolve_raw(str(shot.get("raw", RAW.name)))
        if not raw.exists():
            raise SystemExit(f"missing {raw} — capture that zone first")
        resolved.append(
            (raw, float(shot.get("start", 1.0)), float(shot.get("duration", 3.7)))
        )
    if not INTRO_STILL.exists():
        raise SystemExit(f"missing intro still {INTRO_STILL}")
    if not OUTRO_STILL.exists():
        raise SystemExit(f"missing outro still {OUTRO_STILL}")
    play_dur = sum(d for _, _, d in resolved)
    total = INTRO_DUR + play_dur + OUTRO_DUR
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="idle_shorts_") as tmp:
        tmp_path = Path(tmp)
        intro_mp4 = tmp_path / "intro.mp4"
        make_still_mp4(ffmpeg, INTRO_STILL, intro_mp4, duration=INTRO_DUR)
        clips: list[Path] = [intro_mp4]
        for i, (raw, start, dur) in enumerate(resolved):
            dest = tmp_path / f"shot_{i:02d}.mp4"
            crop_shot(
                ffmpeg, raw, dest, start=start, duration=dur, crop_y=crop_y
            )
            clips.append(dest)
        outro_png = tmp_path / "outro.png"
        outro_mp4 = tmp_path / "outro.mp4"
        paint_outro(outro_png)
        make_still_mp4(ffmpeg, outro_png, outro_mp4, duration=OUTRO_DUR)
        clips.append(outro_mp4)
        silent = tmp_path / "silent.mp4"
        concat_shots(ffmpeg, clips, silent)
        mux_audio(ffmpeg, silent, DEST, total)
    print(
        "wrote",
        DEST,
        DEST.stat().st_size,
        f"~{total:.1f}s",
        f"intro+{len(resolved)} shots+outro",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    build()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
