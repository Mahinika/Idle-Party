#!/usr/bin/env python3
"""Build Idle Party Play Store preview videos (16:9 + 9:16).

Shot list from docs/TRAILER.md. Uses owned marketing stills + hub.ogg.
Requires ffmpeg on PATH (or FFMPEG_BIN). Captions are burned with Pillow
(Windows-safe) before ffmpeg assemble.

  py -3 tool/store_listing/build_preview_video.py
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
LISTING = Path(__file__).resolve().parent
OUT = LISTING / "preview"
MUSIC = ROOT / "assets" / "custom" / "audio" / "music" / "hub.ogg"

# Gameplay clips are A56 screen recordings in preview/ (gitignored). If they
# are absent, tracked marketing cards keep the builder reproducible.
# duration, gameplay, fallback still, caption, source trim start
# Play Help: show the fight in the first 10s (muted autoplay).
BEATS: list[tuple[float, str | None, str, str, float]] = [
    (
        10.0,
        "preview/gameplay_combat_raw.mp4",
        "marketing/03_party_fights_1080x1920.png",
        "Your party keeps fighting",
        0.6,
    ),
    (
        5.0,
        None,
        "marketing/07_afk_progress_1080x1920.png",
        "Progress while you're away",
        0.0,
    ),
    (
        4.0,
        "preview/gameplay_hub_raw.mp4",
        "marketing/02_todays_chase_1080x1920.png",
        "Always know today's chase",
        0.0,
    ),
    (
        5.0,
        "preview/gameplay_gear_raw.mp4",
        "marketing/05_build_party_1080x1920.png",
        "Build and equip your party",
        0.0,
    ),
    (
        6.0,
        None,
        "marketing/01_feature_graphic_1024x500.png",
        "Idle Party",
        0.0,
    ),
]

FPS = 30
XFADE = 0.55
BG_RGB = (26, 20, 16)  # charcoal parchment
CAPTION_FG = (245, 230, 200)
BAND_H = 120


def find_ffmpeg() -> str:
    env = os.environ.get("FFMPEG_BIN")
    if env and Path(env).exists():
        return env
    which = shutil.which("ffmpeg")
    if which:
        return which
    candidates = list(
        Path(os.environ.get("LOCALAPPDATA", "")).glob(
            "Microsoft/WinGet/Packages/Gyan.FFmpeg*/ffmpeg-*/bin/ffmpeg.exe"
        )
    )
    if candidates:
        return str(sorted(candidates)[-1])
    raise SystemExit(
        "ffmpeg not found. Install with: winget install --id Gyan.FFmpeg -e"
    )


def run(cmd: list[str]) -> None:
    print("+", " ".join(str(c) for c in cmd[:6]), "…")
    subprocess.run(cmd, check=True, capture_output=True)


def load_font(size: int) -> ImageFont.ImageFont:
    for path in (
        r"C:\Windows\Fonts\georgia.ttf",
        r"C:\Windows\Fonts\segoeui.ttf",
        r"C:\Windows\Fonts\arial.ttf",
    ):
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def fit_canvas(src: Image.Image, width: int, height: int) -> Image.Image:
    img = src.convert("RGB")
    cover_scale = max(width / img.width, height / img.height)
    cover_size = (
        max(1, int(img.width * cover_scale)),
        max(1, int(img.height * cover_scale)),
    )
    backdrop = img.resize(cover_size, Image.Resampling.LANCZOS)
    left = max(0, (backdrop.width - width) // 2)
    top = max(0, (backdrop.height - height) // 2)
    backdrop = backdrop.crop((left, top, left + width, top + height))
    backdrop = backdrop.filter(ImageFilter.GaussianBlur(radius=28))
    backdrop = ImageEnhance.Brightness(backdrop).enhance(0.35)
    canvas = backdrop.convert("RGB")
    scale = min(width / img.width, height / img.height)
    nw, nh = max(1, int(img.width * scale)), max(1, int(img.height * scale))
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas.paste(img, ((width - nw) // 2, (height - nh) // 2))
    return canvas


def burn_caption(canvas: Image.Image, caption: str) -> Image.Image:
    out = canvas.copy()
    draw = ImageDraw.Draw(out, "RGBA")
    w, h = out.size
    band_top = h - BAND_H
    draw.rectangle((0, band_top, w, h), fill=(26, 20, 16, 190))
    font = load_font(44 if w >= 1600 else 36)
    bbox = draw.textbbox((0, 0), caption, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(
        ((w - tw) / 2, band_top + (BAND_H - th) / 2 - 4),
        caption,
        fill=CAPTION_FG,
        font=font,
    )
    return out.convert("RGB")


def prepare_frame(
    src: Path, *, width: int, height: int, caption: str, burn: bool
) -> Image.Image:
    canvas = fit_canvas(Image.open(src), width, height)
    if burn:
        return burn_caption(canvas, caption)
    return canvas


def make_video_caption(
    path: Path, *, width: int, height: int, caption: str
) -> None:
    overlay = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay, "RGBA")
    if width > height:
        box = (70, 330, 1070, 720)
        font = load_font(64)
        small = load_font(30)
        draw.rounded_rectangle(box, radius=30, fill=(20, 16, 13, 205))
        draw.text((130, 400), "IDLE PARTY", font=small, fill=(220, 181, 102, 255))
        bbox = draw.textbbox((0, 0), caption, font=font)
        text_y = 515 - (bbox[3] - bbox[1]) / 2
        draw.text((130, text_y), caption, font=font, fill=(*CAPTION_FG, 255))
    else:
        box = (70, height - 145, width - 70, height - 25)
        font = load_font(40)
        draw.rounded_rectangle(box, radius=24, fill=(20, 16, 13, 220))
        bbox = draw.textbbox((0, 0), caption, font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        draw.text(
            ((width - tw) / 2, height - 88 - th / 2),
            caption,
            font=font,
            fill=(*CAPTION_FG, 255),
        )
    overlay.save(path)


def make_gameplay_mp4(
    ffmpeg: str,
    src: Path,
    caption_png: Path,
    dest: Path,
    *,
    width: int,
    height: int,
    duration: float,
    start: float,
) -> None:
    if width > height:
        fg_h = 980
        fg_w = 452
        fg_x = 1320
        fg_y = (height - fg_h) // 2
    else:
        fg_h = 1760
        fg_w = 812
        fg_x = (width - fg_w) // 2
        fg_y = 0
    fc = (
        f"[0:v]trim=start={start}:duration={duration},setpts=PTS-STARTPTS,"
        f"fps={FPS},tpad=stop_mode=clone:stop_duration=1,split=2[bg][fg];"
        f"[bg]scale={width}:{height}:force_original_aspect_ratio=increase,"
        f"crop={width}:{height},gblur=sigma=24,eq=brightness=-0.25:saturation=0.65[bg2];"
        f"[fg]scale={fg_w}:{fg_h}:force_original_aspect_ratio=decrease[fg2];"
        f"[bg2][fg2]overlay={fg_x}:{fg_y}[base];"
        f"[base][1:v]overlay=0:0:shortest=1,format=yuv420p[vout]"
    )
    cmd = [
        ffmpeg,
        "-y",
        "-i",
        str(src),
        "-loop",
        "1",
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
        "20",
        "-an",
        str(dest),
    ]
    print("+ gameplay", src.name)
    subprocess.run(cmd, check=True, capture_output=True)


def make_still_mp4(
    ffmpeg: str,
    png: Path,
    dest: Path,
    *,
    duration: float,
) -> None:
    run(
        [
            ffmpeg,
            "-y",
            "-loop",
            "1",
            "-i",
            str(png),
            "-t",
            f"{duration:.3f}",
            "-r",
            str(FPS),
            "-pix_fmt",
            "yuv420p",
            "-c:v",
            "libx264",
            "-preset",
            "veryfast",
            "-crf",
            "20",
            "-an",
            str(dest),
        ]
    )


def concat_xfade(
    ffmpeg: str, clips: list[Path], dest: Path, durations: list[float]
) -> None:
    if len(clips) == 1:
        shutil.copy(clips[0], dest)
        return
    inputs: list[str] = []
    for c in clips:
        inputs.extend(["-i", str(c)])
    parts: list[str] = []
    offset = durations[0] - XFADE
    prev = "[0:v]"
    for i in range(1, len(clips)):
        out = f"[v{i}]" if i < len(clips) - 1 else "[vout]"
        parts.append(
            f"{prev}[{i}:v]xfade=transition=fade:duration={XFADE}:offset={offset:.3f}{out}"
        )
        prev = out
        if i < len(clips) - 1:
            offset += durations[i] - XFADE
    fc = ";".join(parts)
    cmd = [
        ffmpeg,
        "-y",
        *inputs,
        "-filter_complex",
        fc,
        "-map",
        "[vout]",
        "-r",
        str(FPS),
        "-pix_fmt",
        "yuv420p",
        "-c:v",
        "libx264",
        "-preset",
        "veryfast",
        "-crf",
        "20",
        "-an",
        str(dest),
    ]
    print("+ xfade", len(clips), "clips")
    subprocess.run(cmd, check=True, capture_output=True)


def mux_audio(
    ffmpeg: str, video: Path, music: Path, dest: Path, total: float
) -> None:
    fade_out_start = max(0.0, total - 1.5)
    af = (
        f"afade=t=in:st=0:d=1.2,afade=t=out:st={fade_out_start:.2f}:d=1.5,"
        f"volume=0.28"
    )
    cmd = [
        ffmpeg,
        "-y",
        "-i",
        str(video),
        "-stream_loop",
        "-1",
        "-i",
        str(music),
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


def build_aspect(ffmpeg: str, *, width: int, height: int, label: str) -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="idle_preview_") as tmp:
        tmp_path = Path(tmp)
        clips: list[Path] = []
        durs: list[float] = []
        sources: list[dict[str, object]] = []
        for i, (dur, video_rel, fallback_rel, caption, start) in enumerate(BEATS):
            clip_dur = dur + (XFADE if i < len(BEATS) - 1 else 0)
            dest = tmp_path / f"beat_{i:02d}.mp4"
            video = LISTING / video_rel if video_rel else None
            if video is not None and video.exists():
                caption_png = tmp_path / f"caption_{i:02d}.png"
                make_video_caption(
                    caption_png, width=width, height=height, caption=caption
                )
                make_gameplay_mp4(
                    ffmpeg,
                    video,
                    caption_png,
                    dest,
                    width=width,
                    height=height,
                    duration=clip_dur,
                    start=start,
                )
                sources.append(
                    {"kind": "gameplay", "src": video_rel, "caption": caption}
                )
            else:
                src = LISTING / fallback_rel
                if not src.exists():
                    raise SystemExit(f"missing still: {src}")
                # Marketing cards carry captions; feature graphic does not.
                burn = "feature_graphic" in fallback_rel
                framed = prepare_frame(
                    src, width=width, height=height, caption=caption, burn=burn
                )
                png = tmp_path / f"beat_{i:02d}.png"
                framed.save(png, optimize=True)
                make_still_mp4(ffmpeg, png, dest, duration=clip_dur)
                sources.append(
                    {"kind": "still", "src": fallback_rel, "caption": caption}
                )
            clips.append(dest)
            durs.append(clip_dur)

        silent = tmp_path / f"silent_{label}.mp4"
        concat_xfade(ffmpeg, clips, silent, durs)
        total = sum(durs) - XFADE * (len(durs) - 1)
        final = OUT / f"idle_party_preview_{label}.mp4"
        if MUSIC.exists():
            mux_audio(ffmpeg, silent, MUSIC, final, total)
        else:
            shutil.copy(silent, final)
            print(f"WARN: no music at {MUSIC}")

        meta = {
            "file": final.name,
            "width": width,
            "height": height,
            "approx_seconds": round(total, 2),
            "beats": sources,
            "music": str(MUSIC.relative_to(ROOT)) if MUSIC.exists() else None,
            "bytes": final.stat().st_size,
        }
        (OUT / f"idle_party_preview_{label}.json").write_text(
            json.dumps(meta, indent=2), encoding="utf-8"
        )
        print(f"Wrote {final} (~{total:.1f}s, {final.stat().st_size // 1024} KB)")
        return final


def main() -> int:
    ffmpeg = find_ffmpeg()
    print("ffmpeg:", ffmpeg)
    build_aspect(ffmpeg, width=1920, height=1080, label="16x9")
    build_aspect(ffmpeg, width=1080, height=1920, label="9x16")
    print("Done ->", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
