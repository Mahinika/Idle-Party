#!/usr/bin/env python3
"""Build a vertical feed Short from A56 combat (not the Play listing trailer).

Hard-cuts 3 zone shots (hell / crystal / mothveil) so the feed is not one
gold corridor. Full-bleed 1080x1920. Owned dungeon.mp3 only.

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
    load_font,
)

RAW = OUT / "gameplay_shorts_raw.mp4"
DEST = OUT / "idle_party_shorts_feed.mp4"
FEED_MUSIC = MUSIC.with_name("dungeon.mp3")

WIDTH = 1080
HEIGHT = 1920
SRC_H = 2340
# Cut the FARM row; keep the chamber art (no punch-in on floor tiles).
CROP_Y = 150
HOOK = "They fight without you"
LOCKUP = "Idle Party"
HOOK_FROM = 1.4
DEFAULT_SHOTS: list[dict[str, object]] = [
    {"raw": "gameplay_shorts_hell_raw.mp4", "start": 1.2, "duration": 3.7},
    {"raw": "gameplay_shorts_crystal_raw.mp4", "start": 1.2, "duration": 3.7},
    {"raw": "gameplay_shorts_veil_raw.mp4", "start": 1.2, "duration": 3.7},
]


def make_caption(path: Path, text: str, *, lockup: bool) -> None:
    img = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    font = load_font(64 if not lockup else 80)
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    pad_x, pad_y = 36, 18
    box_w = tw + pad_x * 2
    box_h = th + pad_y * 2
    box_x = (WIDTH - box_w) // 2
    box_y = HEIGHT - 220
    draw.rounded_rectangle(
        (box_x, box_y, box_x + box_w, box_y + box_h),
        radius=22,
        fill=(*BG_RGB, 210),
        outline=(220, 181, 102, 200),
        width=2,
    )
    tx = (WIDTH - tw) / 2
    ty = box_y + pad_y - bbox[1]
    draw.text((tx, ty), text, font=font, fill=(*CAPTION_FG, 255))
    img.save(path)


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


def overlay_captions(
    ffmpeg: str,
    video: Path,
    dest: Path,
    *,
    total: float,
    hook_png: Path,
    lock_png: Path,
) -> None:
    hook_until = max(total - 1.5, total * 0.86)
    hook_from = min(HOOK_FROM, max(0.4, total - 2.2))
    fc = (
        f"[0:v][1:v]overlay=0:0:enable='between(t,{hook_from:.2f},{hook_until:.2f})'[v1];"
        f"[v1][2:v]overlay=0:0:enable='gt(t,{hook_until:.2f})',"
        f"format=yuv420p[vout]"
    )
    run_ffmpeg(
        ffmpeg,
        [
            ffmpeg,
            "-y",
            "-i",
            str(video),
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
            f"{total:.3f}",
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
        "captions",
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
    total = sum(d for _, _, d in resolved)
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="idle_shorts_") as tmp:
        tmp_path = Path(tmp)
        clips: list[Path] = []
        for i, (raw, start, dur) in enumerate(resolved):
            dest = tmp_path / f"shot_{i:02d}.mp4"
            crop_shot(
                ffmpeg, raw, dest, start=start, duration=dur, crop_y=crop_y
            )
            clips.append(dest)
        silent = tmp_path / "silent.mp4"
        concat_shots(ffmpeg, clips, silent)
        hook_png = tmp_path / "hook.png"
        lock_png = tmp_path / "lockup.png"
        make_caption(hook_png, HOOK, lockup=False)
        make_caption(lock_png, LOCKUP, lockup=True)
        captioned = tmp_path / "captioned.mp4"
        overlay_captions(
            ffmpeg,
            silent,
            captioned,
            total=total,
            hook_png=hook_png,
            lock_png=lock_png,
        )
        mux_audio(ffmpeg, captioned, DEST, total)
    print("wrote", DEST, DEST.stat().st_size, f"~{total:.1f}s", len(resolved), "shots")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    build()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
