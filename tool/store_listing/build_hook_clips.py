#!/usr/bin/env python3
"""Cut 7 vertical FYP clips from A56 combat (hook batch 01/03/04/06/09/10/16).

Frame 0 = crawl. Hook ≤6 words. IDLE PARTY on screen by 3s.
End card text only (Idle Party · Google Play). Owned dungeon.mp3.

  py -3 tool/store_listing/build_hook_clips.py
"""

from __future__ import annotations

import json
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
    find_ffmpeg,
    load_font,
)
from build_shorts_feed import (
    CROP_Y,
    FEED_MUSIC,
    HEIGHT,
    OUT,
    SRC_H,
    WIDTH,
    crop_shot,
    draw_centered,
    load_bold_font,
    mux_audio,
    paint_shot_caption,
    run_ffmpeg,
)

GROWTH = Path(__file__).resolve().parent / "growth"
RECIPE = GROWTH / "hooks_batch.json"
DEST_DIR = OUT / "hooks"

# Fallback order: new hook captures, then existing shorts/combat raw.
DEFAULTS: list[dict[str, object]] = [
    {
        "id": "01",
        "file": "01_they_fight.mp4",
        "hook": "THEY FIGHT WITHOUT YOU",
        "raws": ["hook_sandy_raw.mp4", "hook_entered_raw.mp4", "gameplay_combat_raw.mp4"],
        "start": 0.8,
        "duration": 10.0,
    },
    {
        "id": "03",
        "file": "03_healer_saves.mp4",
        "hook": "HEALER SAVES THE TANK",
        "raws": ["hook_entered_raw.mp4", "gameplay_combat_raw.mp4"],
        "start": 2.0,
        "duration": 10.0,
    },
    {
        "id": "04",
        "file": "04_tap_to_help.mp4",
        "hook": "TAP THE CAVE TO HELP",
        "raws": ["hook_hell_raw.mp4", "gameplay_shorts_hell_raw.mp4"],
        "start": 0.5,
        "duration": 10.0,
    },
    {
        "id": "06",
        "file": "06_loot_walks.mp4",
        "hook": "LOOT WALKS TO YOU",
        "raws": ["hook_entered_raw.mp4", "gameplay_shorts_veil_raw.mp4"],
        "start": 4.0,
        "duration": 9.0,
    },
    {
        "id": "09",
        "file": "09_shield_healer_damage.mp4",
        "hook": "SHIELD HEALER DAMAGE",
        "raws": ["hook_sandy_raw.mp4", "hook_entered_raw.mp4", "gameplay_combat_raw.mp4"],
        "start": 1.5,
        "duration": 10.0,
    },
    {
        "id": "10",
        "file": "10_boss_tell.mp4",
        "hook": "BOSS HAS A TELL",
        "raws": ["hook_hell_raw.mp4", "gameplay_shorts_crystal_raw.mp4"],
        "start": 1.0,
        "duration": 10.0,
    },
    {
        "id": "16",
        "file": "16_crit_pack.mp4",
        "hook": "CRIT. PACK DROPS",
        "raws": ["gameplay_shorts_veil_raw.mp4", "hook_entered_raw.mp4"],
        "start": 1.2,
        "duration": 8.0,
    },
]


def paint_name_bar(path: Path) -> None:
    img = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    top, bottom = 48, 148
    draw.rectangle((0, top, WIDTH, bottom), fill=(*BG_RGB, 200))
    draw.rectangle((0, bottom, WIDTH, bottom + 5), fill=(220, 181, 102, 255))
    draw_centered(draw, "IDLE PARTY", load_bold_font(52), top + 18, (*CAPTION_FG, 255))
    img.save(path)


def paint_end_card(path: Path) -> None:
    img = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    band_top = HEIGHT - 280
    draw.rectangle((0, band_top, WIDTH, HEIGHT), fill=(*BG_RGB, 235))
    draw.rectangle((0, band_top, WIDTH, band_top + 6), fill=(220, 181, 102, 255))
    draw_centered(draw, "IDLE PARTY", load_bold_font(56), band_top + 28, (*CAPTION_FG, 255))
    draw_centered(
        draw,
        "Idle Party · Google Play",
        load_font(34),
        band_top + 110,
        (220, 181, 102, 255),
    )
    draw_centered(
        draw,
        "Search the name",
        load_font(26),
        band_top + 168,
        (220, 200, 170, 255),
    )
    img.save(path)


def resolve_raw(names: list[str]) -> Path:
    for name in names:
        p = OUT / name
        if p.exists() and p.stat().st_size > 10_000:
            return p
    missing = ", ".join(names)
    raise SystemExit(f"missing raw footage ({missing}) — run capture_hook_clips.py")


def overlay_end(ffmpeg: str, src: Path, end_png: Path, dest: Path, duration: float) -> None:
    appear = max(0.0, duration - 1.8)
    fc = (
        f"[0:v]format=yuv420p[base];"
        f"[1:v]format=rgba,fade=t=in:st={appear:.3f}:d=0.25:alpha=1[end];"
        f"[base][end]overlay=0:0:shortest=1,format=yuv420p[vout]"
    )
    run_ffmpeg(
        ffmpeg,
        [
            ffmpeg,
            "-y",
            "-i",
            str(src),
            "-loop",
            "1",
            "-framerate",
            str(FPS),
            "-i",
            str(end_png),
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
        f"end card {src.name}",
    )


def overlay_name(ffmpeg: str, src: Path, name_png: Path, dest: Path, duration: float) -> None:
    fc = (
        f"[0:v]format=yuv420p[base];"
        f"[1:v]format=rgba,fade=t=in:st=0:d=0.12:alpha=1,"
        f"fade=t=out:st=2.85:d=0.25:alpha=1[name];"
        f"[base][name]overlay=0:0:shortest=1,format=yuv420p[vout]"
    )
    run_ffmpeg(
        ffmpeg,
        [
            ffmpeg,
            "-y",
            "-i",
            str(src),
            "-loop",
            "1",
            "-framerate",
            str(FPS),
            "-i",
            str(name_png),
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
        f"name bar {src.name}",
    )


def load_recipe() -> tuple[list[dict[str, object]], int]:
    crop_y = CROP_Y
    clips = list(DEFAULTS)
    if RECIPE.exists():
        data = json.loads(RECIPE.read_text(encoding="utf-8"))
        crop_y = int(data.get("crop_y", crop_y))
        if isinstance(data.get("clips"), list) and data["clips"]:
            clips = data["clips"]
    return clips, crop_y


def clamp_duration(raw: Path, start: float, duration: float) -> float:
    import subprocess

    probe = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(raw),
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    try:
        total = float(probe.stdout.strip())
    except ValueError:
        return duration
    remain = max(4.0, total - start - 0.15)
    return min(duration, remain)


def build() -> None:
    if not FEED_MUSIC.exists():
        raise SystemExit(f"missing owned music {FEED_MUSIC}")
    ffmpeg = find_ffmpeg()
    clips, crop_y = load_recipe()
    crop_y = max(0, min(crop_y, SRC_H - HEIGHT))
    DEST_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="idle_hooks_") as tmp:
        tmp_path = Path(tmp)
        name_png = tmp_path / "name.png"
        end_png = tmp_path / "end.png"
        paint_name_bar(name_png)
        paint_end_card(end_png)
        for spec in clips:
            raw = resolve_raw([str(n) for n in spec["raws"]])  # type: ignore[arg-type]
            start = float(spec.get("start", 0.8))
            duration = clamp_duration(raw, start, float(spec.get("duration", 10.0)))
            hook = str(spec["hook"])
            dest = DEST_DIR / str(spec["file"])
            cap = tmp_path / f"{spec['id']}_cap.png"
            paint_shot_caption(cap, hook)
            cut = tmp_path / f"{spec['id']}_cut.mp4"
            named = tmp_path / f"{spec['id']}_named.mp4"
            ended = tmp_path / f"{spec['id']}_ended.mp4"
            crop_shot(
                ffmpeg,
                raw,
                cut,
                start=start,
                duration=duration,
                crop_y=crop_y,
                caption_png=cap,
            )
            overlay_name(ffmpeg, cut, name_png, named, duration)
            overlay_end(ffmpeg, named, end_png, ended, duration)
            mux_audio(ffmpeg, ended, dest, duration)
            print("wrote", dest, dest.stat().st_size, f"~{duration:.1f}s from {raw.name}")


def main() -> int:
    build()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
