#!/usr/bin/env python3
"""Build a vertical feed ad from A56 combat (not the Play listing trailer).

Ad shape: fast motion hook → three benefit-led combat cuts → Play Store CTA.
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
INTRO_DUR = 1.25
OUTRO_DUR = 2.4
GOLD = (220, 181, 102)
SHOT_COPY = (
    "BUILD YOUR PARTY",
    "PUSH ONE MORE FLOOR",
    "COME BACK STRONGER",
)
DEFAULT_SHOTS: list[dict[str, object]] = [
    {"raw": "gameplay_shorts_hell_raw.mp4", "start": 1.2, "duration": 3.0},
    {"raw": "gameplay_shorts_crystal_raw.mp4", "start": 1.2, "duration": 3.0},
    {"raw": "gameplay_shorts_veil_raw.mp4", "start": 1.2, "duration": 3.0},
]


def load_bold_font(size: int):
    for path in (
        Path(r"C:\Windows\Fonts\georgiab.ttf"),
        Path(r"C:\Windows\Fonts\arialbd.ttf"),
    ):
        if path.exists():
            from PIL import ImageFont

            return ImageFont.truetype(path, size)
    return load_font(size)


def draw_centered(draw: ImageDraw.ImageDraw, text: str, font, y: int, fill) -> None:
    bbox = draw.textbbox((0, 0), text, font=font)
    width = bbox[2] - bbox[0]
    draw.text(((WIDTH - width) / 2, y), text, font=font, fill=fill)


def paint_intro(path: Path) -> None:
    """Repair the source card's edge-clipped headline with ad-safe copy."""
    src = Image.open(INTRO_STILL).convert("RGB")
    if src.size != (WIDTH, HEIGHT):
        src = fit_canvas(src, WIDTH, HEIGHT)
    out = src.copy()
    draw = ImageDraw.Draw(out, "RGBA")
    draw.rectangle((0, 0, WIDTH, 420), fill=(*BG_RGB, 255))
    draw.rectangle((0, 416, WIDTH, 424), fill=(*GOLD, 255))
    draw_centered(draw, "IDLE RPG", load_bold_font(30), 52, (*GOLD, 255))
    draw_centered(
        draw, "YOUR PARTY FIGHTS", load_bold_font(70), 112, (*CAPTION_FG, 255)
    )
    draw_centered(
        draw, "EVEN WHILE YOU'RE AWAY", load_bold_font(54), 218, (*GOLD, 255)
    )
    out.convert("RGB").save(path)


def paint_shot_caption(path: Path, text: str) -> None:
    img = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    font = load_bold_font(46)
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    card_w = min(WIDTH - 96, text_w + 104)
    left = (WIDTH - card_w) // 2
    top, bottom = 350, 442
    draw.rounded_rectangle(
        (left, top, left + card_w, bottom),
        radius=18,
        fill=(*BG_RGB, 226),
        outline=(*GOLD, 230),
        width=3,
    )
    draw_centered(draw, text, font, top + 18, (*CAPTION_FG, 255))
    img.save(path)


def paint_outro(path: Path) -> None:
    """Product shot + Play Store CTA — typical game-ad end card."""
    src = Image.open(OUTRO_STILL).convert("RGB")
    if src.size != (WIDTH, HEIGHT):
        src = fit_canvas(src, WIDTH, HEIGHT)
    out = src.copy()
    draw = ImageDraw.Draw(out, "RGBA")
    band_top = HEIGHT - 420
    draw.rectangle((0, band_top, WIDTH, HEIGHT), fill=(*BG_RGB, 255))
    draw.rectangle((0, band_top, WIDTH, band_top + 7), fill=(*GOLD, 255))
    title = load_bold_font(66)
    cta = load_bold_font(44)
    hint = load_bold_font(28)

    draw_centered(draw, "IDLE PARTY", title, band_top + 30, (*CAPTION_FG, 255))
    btn_w, btn_h = 760, 102
    btn_x = (WIDTH - btn_w) // 2
    btn_y = band_top + 126
    draw.rounded_rectangle(
        (btn_x, btn_y, btn_x + btn_w, btn_y + btn_h),
        radius=22,
        fill=(175, 96, 20, 255),
        outline=GOLD,
        width=4,
    )
    bbox = draw.textbbox((0, 0), "DOWNLOAD FREE", font=cta)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(
        (btn_x + (btn_w - tw) / 2, btn_y + (btn_h - th) / 2 - 4),
        "DOWNLOAD FREE",
        font=cta,
        fill=(*CAPTION_FG, 255),
    )
    draw_centered(draw, "ON GOOGLE PLAY", hint, band_top + 258, (*GOLD, 255))
    draw_centered(
        draw,
        'Search "Idle Party"',
        load_font(25),
        band_top + 314,
        (220, 200, 170, 255),
    )
    out.convert("RGB").save(path)


def make_motion_still(
    ffmpeg: str, png: Path, dest: Path, *, duration: float, zoom: float
) -> None:
    """Add a restrained push-in so ad cards do not feel like slides."""
    frames = max(1, round(duration * FPS))
    zoom_step = max(0.0001, (zoom - 1.0) / frames)
    vf = (
        f"zoompan=z='min(zoom+{zoom_step:.7f},{zoom:.4f})':"
        f"x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':"
        f"d=1:s={WIDTH}x{HEIGHT}:fps={FPS},"
        f"trim=duration={duration:.3f},setpts=PTS-STARTPTS,format=yuv420p"
    )
    run_ffmpeg(
        ffmpeg,
        [
            ffmpeg,
            "-y",
            "-loop",
            "1",
            "-i",
            str(png),
            "-vf",
            vf,
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
        f"motion still {png.name}",
    )


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
    caption_png: Path,
) -> None:
    crop_y = max(0, min(crop_y, SRC_H - HEIGHT))
    fc = (
        f"[0:v]trim=start={start:.3f}:duration={duration:.3f},"
        f"setpts=PTS-STARTPTS,fps={FPS},"
        f"crop={WIDTH}:{HEIGHT}:0:{crop_y},"
        f"eq=contrast=1.1:saturation=1.18:brightness=0.03,"
        f"format=yuv420p[base];"
        f"[1:v]format=rgba,"
        f"fade=t=in:st=0:d=0.16:alpha=1,"
        f"fade=t=out:st={max(0.0, duration - 0.25):.3f}:d=0.20:alpha=1[caption];"
        f"[base][caption]overlay=0:0:shortest=1,format=yuv420p[vout]"
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
            str(caption_png),
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
            (raw, float(shot.get("start", 1.0)), float(shot.get("duration", 3.0)))
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
        intro_png = tmp_path / "intro.png"
        intro_mp4 = tmp_path / "intro.mp4"
        paint_intro(intro_png)
        make_motion_still(
            ffmpeg, intro_png, intro_mp4, duration=INTRO_DUR, zoom=1.025
        )
        clips: list[Path] = [intro_mp4]
        for i, (raw, start, dur) in enumerate(resolved):
            dest = tmp_path / f"shot_{i:02d}.mp4"
            caption_png = tmp_path / f"caption_{i:02d}.png"
            copy = SHOT_COPY[min(i, len(SHOT_COPY) - 1)]
            paint_shot_caption(caption_png, copy)
            crop_shot(
                ffmpeg,
                raw,
                dest,
                start=start,
                duration=dur,
                crop_y=crop_y,
                caption_png=caption_png,
            )
            clips.append(dest)
        outro_png = tmp_path / "outro.png"
        outro_mp4 = tmp_path / "outro.mp4"
        paint_outro(outro_png)
        make_motion_still(
            ffmpeg, outro_png, outro_mp4, duration=OUTRO_DUR, zoom=1.015
        )
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
