"""Generate owned 128x128 weapon model variant overlays.

Creates per-item model variant PNGs for the visualSetId pipeline:
- sword_thunderfury_{idle,walk,attack}.png
- sword_warglaive_{idle,walk,attack}.png

Files are written to both:
- assets/custom/char/gear/
- assets/custom/char/gear/_authored/
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(r"d:\Projects\Personal\idle party\Idle-Party\assets\custom\char\gear")
AUTH = ROOT / "_authored"


def new_canvas() -> Image.Image:
    return Image.new("RGBA", (128, 128), (0, 0, 0, 0))


def shift(im: Image.Image, dx: int, dy: int) -> Image.Image:
    out = new_canvas()
    out.paste(im, (dx, dy), im)
    return out


def stroke(draw: ImageDraw.ImageDraw, points, color, width: int = 1) -> None:
    draw.line(points, fill=color, width=width, joint="curve")


def thunderfury_idle() -> Image.Image:
    im = new_canvas()
    d = ImageDraw.Draw(im)
    # Handle
    d.rectangle([84, 84, 90, 106], fill=(84, 54, 26, 255))
    d.rectangle([83, 92, 91, 96], fill=(156, 110, 52, 255))
    # Guard
    d.polygon([(77, 88), (83, 86), (92, 86), (97, 90), (90, 92), (80, 92)], fill=(196, 158, 64, 255))
    # Main jagged blade
    d.polygon(
        [(88, 16), (95, 24), (93, 30), (99, 40), (95, 46), (98, 56), (93, 64), (95, 74), (89, 84), (86, 84), (81, 76), (84, 66), (79, 58), (83, 50), (79, 42), (84, 34), (82, 26)],
        fill=(184, 214, 232, 255),
    )
    # Dark inlay
    d.polygon(
        [(88, 22), (92, 28), (90, 34), (94, 42), (90, 48), (92, 56), (89, 62), (90, 70), (87, 78), (86, 78), (84, 72), (86, 64), (83, 56), (86, 48), (83, 40), (87, 32)],
        fill=(48, 86, 112, 210),
    )
    # Lightning accents
    stroke(d, [(90, 24), (94, 22), (92, 28), (96, 30)], (122, 222, 255, 255), 2)
    stroke(d, [(90, 44), (96, 44), (92, 50), (97, 52)], (122, 222, 255, 255), 2)
    stroke(d, [(88, 64), (94, 66), (90, 72), (94, 74)], (122, 222, 255, 255), 2)
    return im


def warglaive_idle() -> Image.Image:
    im = new_canvas()
    d = ImageDraw.Draw(im)
    # Central grip + pommel
    d.rectangle([82, 78, 88, 102], fill=(74, 48, 24, 255))
    d.rectangle([81, 86, 89, 90], fill=(145, 104, 48, 255))
    d.ellipse([82, 101, 88, 108], fill=(66, 176, 94, 255))
    # Crescent blade silhouette
    d.polygon(
        [(48, 24), (60, 18), (76, 16), (91, 20), (102, 30), (107, 44), (104, 56), (96, 62), (84, 66), (72, 70), (64, 76), (58, 86), (54, 98), (50, 104), (44, 100), (46, 90), (50, 80), (56, 72), (64, 64), (78, 58), (90, 52), (96, 46), (96, 38), (92, 32), (82, 28), (68, 28), (56, 32)],
        fill=(168, 176, 188, 255),
    )
    # Inner fel energy channel
    d.polygon(
        [(58, 30), (68, 26), (80, 26), (90, 30), (95, 38), (93, 44), (86, 48), (76, 52), (66, 58), (60, 66), (56, 76), (53, 88), (50, 94), (48, 88), (51, 78), (56, 68), (64, 58), (75, 50), (86, 42), (89, 37), (86, 33), (78, 31), (68, 31)],
        fill=(68, 190, 98, 235),
    )
    # Spikes near grip
    d.polygon([(80, 72), (92, 68), (86, 80)], fill=(150, 160, 172, 255))
    d.polygon([(70, 76), (80, 72), (76, 84)], fill=(150, 160, 172, 255))
    return im


def write_set(set_id: str, idle: Image.Image) -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    AUTH.mkdir(parents=True, exist_ok=True)
    frames = {
        "idle": idle,
        "walk": shift(idle, 0, 1),
        "attack": shift(idle, 1, -1),
    }
    for anim, frame in frames.items():
        name = f"{set_id}_{anim}.png"
        frame.save(ROOT / name)
        frame.save(AUTH / name)
        print(f"wrote {name}")


def main() -> None:
    write_set("sword_thunderfury", thunderfury_idle())
    write_set("sword_warglaive", warglaive_idle())
    print("done: weapon model variants generated")


if __name__ == "__main__":
    main()
