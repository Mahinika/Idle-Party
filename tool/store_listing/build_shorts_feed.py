#!/usr/bin/env python3
"""Build a vertical feed Short from A56 combat (not the Play listing trailer).

Full-bleed 1080x1920 crop of 1080x2340 gameplay. Frame one is combat.
Owned hub.ogg only. Output is gitignored.

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

# Reuse trailer ffmpeg lookup + parchment tokens — do not import BEATS.
from build_preview_video import (
    BG_RGB,
    CAPTION_FG,
    FPS,
    LISTING,
    MUSIC,
    OUT,
    find_ffmpeg,
    load_font,
)

RAW = OUT / "gameplay_shorts_raw.mp4"
DEST = OUT / "idle_party_shorts_feed.mp4"

WIDTH = 1080
HEIGHT = 1920
SRC_H = 2340
DURATION = 15.0
TRIM_START = 0.45
# Keep combat / party; drop the bottom tab bar (420 px).
CROP_Y = 0
HOOK = "They fight without you"
LOCKUP = "Idle Party"


def make_caption(path: Path, text: str, *, lockup: bool) -> None:
    img = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    font = load_font(70 if not lockup else 84)
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    pad_x, pad_y = 48, 26
    box_w = tw + pad_x * 2
    box_h = th + pad_y * 2
    box_x = (WIDTH - box_w) // 2
    # Sit in the dungeon sky under FARM/PUSH, above the party.
    box_y = 248
    draw.rounded_rectangle(
        (box_x, box_y, box_x + box_w, box_y + box_h),
        radius=26,
        fill=(*BG_RGB, 230),
        outline=(220, 181, 102, 220),
        width=3,
    )
    tx = (WIDTH - tw) / 2
    ty = box_y + pad_y - bbox[1]
    draw.text((tx, ty), text, font=font, fill=(*CAPTION_FG, 255))
    img.save(path)


def mux_audio(ffmpeg: str, video: Path, dest: Path, total: float) -> None:
    fade_out_start = max(0.0, total - 1.4)
    af = (
        f"afade=t=in:st=0:d=0.8,afade=t=out:st={fade_out_start:.2f}:d=1.4,"
        f"volume=0.30"
    )
    cmd = [
        ffmpeg,
        "-y",
        "-i",
        str(video),
        "-stream_loop",
        "-1",
        "-i",
        str(MUSIC),
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


def build(
    *,
    raw: Path,
    dest: Path,
    start: float,
    duration: float,
    crop_y: int,
) -> None:
    if not raw.exists():
        raise SystemExit(f"missing {raw} — capture A56 combat first")
    if not MUSIC.exists():
        raise SystemExit(f"missing owned music {MUSIC}")
    ffmpeg = find_ffmpeg()
    crop_y = max(0, min(crop_y, SRC_H - HEIGHT))
    hook_until = max(duration - 1.8, duration * 0.85)
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="idle_shorts_") as tmp:
        tmp_path = Path(tmp)
        hook_png = tmp_path / "hook.png"
        lock_png = tmp_path / "lockup.png"
        silent = tmp_path / "silent.mp4"
        make_caption(hook_png, HOOK, lockup=False)
        make_caption(lock_png, LOCKUP, lockup=True)
        fc = (
            f"[0:v]trim=start={start:.3f}:duration={duration:.3f},"
            f"setpts=PTS-STARTPTS,fps={FPS},"
            f"crop={WIDTH}:{HEIGHT}:0:{crop_y},format=yuv420p[base];"
            f"[base][1:v]overlay=0:0:enable='lte(t,{hook_until:.2f})'[v1];"
            f"[v1][2:v]overlay=0:0:enable='gt(t,{hook_until:.2f})',"
            f"format=yuv420p[vout]"
        )
        cmd = [
            ffmpeg,
            "-y",
            "-i",
            str(raw),
            "-loop",
            "1",
            "-i",
            str(hook_png),
            "-loop",
            "1",
            "-i",
            str(lock_png),
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
            str(silent),
        ]
        print("+ crop + captions", raw.name)
        subprocess.run(cmd, check=True, capture_output=True)
        mux_audio(ffmpeg, silent, dest, duration)
    print("wrote", dest, dest.stat().st_size)


def trim_defaults() -> dict[str, float]:
    cfg = OUT / "shorts_feed.json"
    data = {"start": TRIM_START, "duration": DURATION, "crop_y": CROP_Y}
    if cfg.exists():
        data.update(json.loads(cfg.read_text(encoding="utf-8")))
    return data


def main() -> int:
    defaults = trim_defaults()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--raw", type=Path, default=RAW)
    parser.add_argument("--out", type=Path, default=DEST)
    parser.add_argument("--start", type=float, default=float(defaults["start"]))
    parser.add_argument("--duration", type=float, default=float(defaults["duration"]))
    parser.add_argument("--crop-y", type=int, default=int(defaults["crop_y"]))
    args = parser.parse_args()
    raw = args.raw if args.raw.exists() else LISTING / args.raw
    dest = (
        args.out
        if args.out.is_absolute() or args.out.parent != Path()
        else LISTING / args.out
    )
    build(
        raw=raw,
        dest=dest,
        start=args.start,
        duration=args.duration,
        crop_y=args.crop_y,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
