"""Generate owned 128x128 weapon model variant overlays.

Creates per-item model variant PNGs for the visualSetId pipeline:
- sword_thunderfury_{idle,walk,attack}.png
- sword_warglaive_{idle,walk,attack}.png

Files are written to both:
- assets/custom/char/gear/
- assets/custom/char/gear/_authored/
"""
from __future__ import annotations

import math
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


def rotate_grip(im: Image.Image, degrees: float, grip: tuple[int, int] = (88, 96)) -> Image.Image:
    """Rotate around the handle so walk/attack read as different poses."""
    rotated = im.rotate(
        degrees,
        resample=Image.Resampling.NEAREST,
        center=grip,
        fillcolor=(0, 0, 0, 0),
    )
    out = new_canvas()
    out.paste(rotated, (0, 0), rotated)
    return out


def pose_frames(idle: Image.Image) -> dict[str, Image.Image]:
    """Distinct clips — not 1px copies of idle."""
    return {
        "idle": idle,
        "walk": shift(rotate_grip(idle, -6), 0, 1),
        "attack": shift(rotate_grip(idle, -20), 2, -3),
    }


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


def dagger_shadowfang_idle() -> Image.Image:
    im = new_canvas()
    d = ImageDraw.Draw(im)
    d.rectangle([86, 78, 92, 104], fill=(52, 40, 58, 255))
    d.rectangle([85, 88, 93, 92], fill=(120, 72, 160, 255))
    d.polygon(
        [(88, 28), (96, 40), (94, 52), (97, 66), (92, 78), (88, 78), (84, 66), (86, 52), (83, 40)],
        fill=(168, 150, 190, 255),
    )
    d.polygon(
        [(89, 34), (93, 44), (91, 56), (93, 68), (90, 76), (88, 76), (87, 66), (88, 54), (86, 44)],
        fill=(90, 48, 130, 220),
    )
    return im


def staff_frostfire_idle() -> Image.Image:
    im = new_canvas()
    d = ImageDraw.Draw(im)
    d.line([(78, 110), (98, 22)], fill=(96, 64, 36, 255), width=7)
    d.line([(78, 110), (98, 22)], fill=(140, 96, 52, 200), width=3)
    # Crystal head
    d.polygon([(92, 10), (108, 22), (100, 36), (86, 28)], fill=(120, 200, 255, 255))
    d.polygon([(96, 14), (104, 22), (99, 30), (92, 24)], fill=(220, 120, 80, 230))
    stroke(d, [(94, 18), (102, 20), (98, 26)], (255, 255, 255, 255), 1)
    return im


def bow_eagle_idle() -> Image.Image:
    im = new_canvas()
    d = ImageDraw.Draw(im)
    # Recurve limbs
    d.arc([48, 18, 108, 108], start=200, end=340, fill=(120, 78, 40, 255), width=5)
    d.arc([52, 22, 104, 104], start=200, end=340, fill=(168, 118, 62, 255), width=3)
    # String
    stroke(d, [(58, 36), (62, 64), (58, 92)], (210, 210, 200, 255), 1)
    # Grip
    d.rectangle([58, 58, 66, 72], fill=(84, 52, 28, 255))
    d.ellipse([70, 28, 78, 36], fill=(196, 160, 64, 255))  # tip wrap
    return im


def axe_goreblade_idle() -> Image.Image:
    im = new_canvas()
    d = ImageDraw.Draw(im)
    d.rectangle([84, 70, 90, 112], fill=(70, 48, 28, 255))
    d.polygon(
        [(70, 28), (92, 22), (104, 36), (100, 52), (108, 64), (96, 70), (88, 68), (86, 52), (78, 40)],
        fill=(168, 48, 48, 255),
    )
    d.polygon(
        [(78, 34), (92, 30), (98, 40), (94, 52), (98, 60), (90, 64), (88, 52), (84, 42)],
        fill=(210, 90, 70, 230),
    )
    d.ellipse([82, 108, 92, 116], fill=(48, 48, 52, 255))
    return im


def mace_lightbringer_idle() -> Image.Image:
    im = new_canvas()
    d = ImageDraw.Draw(im)
    d.rectangle([84, 64, 90, 110], fill=(120, 96, 48, 255))
    d.ellipse([72, 24, 104, 56], fill=(220, 200, 120, 255))
    d.ellipse([78, 30, 98, 50], fill=(255, 240, 180, 255))
    for ang in range(0, 360, 45):
        rad = math.radians(ang)
        x = 88 + int(18 * math.cos(rad))
        y = 40 + int(18 * math.sin(rad))
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(255, 220, 100, 255))
    return im


def shield_aegis_idle() -> Image.Image:
    im = new_canvas()
    d = ImageDraw.Draw(im)
    # Heater shield + gold boss
    d.polygon(
        [(44, 36), (72, 28), (96, 36), (100, 70), (86, 98), (72, 108), (58, 98), (44, 70)],
        fill=(52, 72, 120, 255),
    )
    d.polygon(
        [(52, 44), (72, 38), (88, 44), (90, 68), (80, 90), (72, 96), (64, 90), (52, 68)],
        fill=(78, 110, 168, 255),
    )
    d.ellipse([64, 58, 80, 74], fill=(220, 180, 64, 255))
    d.ellipse([68, 62, 76, 70], fill=(255, 230, 140, 255))
    return im


def frill_prism_idle() -> Image.Image:
    im = new_canvas()
    d = ImageDraw.Draw(im)
    # Off-hand tome / prism focus
    d.rectangle([48, 52, 86, 96], fill=(88, 56, 128, 255))
    d.rectangle([52, 56, 82, 92], fill=(140, 96, 190, 255))
    d.polygon([(56, 48), (76, 48), (66, 34)], fill=(180, 220, 255, 255))
    d.polygon([(60, 48), (72, 48), (66, 40)], fill=(255, 200, 120, 230))
    stroke(d, [(58, 64), (78, 64), (78, 84), (58, 84), (58, 64)], (220, 200, 255, 255), 1)
    return im


def sword_runebound_idle() -> Image.Image:
    im = new_canvas()
    d = ImageDraw.Draw(im)
    d.rectangle([84, 86, 90, 110], fill=(60, 44, 72, 255))
    d.rectangle([83, 94, 91, 98], fill=(160, 90, 210, 255))
    d.polygon(
        [(88, 18), (96, 28), (94, 44), (97, 60), (93, 78), (89, 86), (85, 78), (82, 60), (84, 44), (81, 28)],
        fill=(150, 140, 190, 255),
    )
    d.polygon(
        [(88, 24), (93, 32), (91, 48), (93, 64), (90, 78), (87, 78), (85, 64), (87, 48), (85, 32)],
        fill=(90, 48, 140, 220),
    )
    # Rune glyphs
    stroke(d, [(86, 36), (92, 36), (89, 42), (86, 36)], (200, 140, 255, 255), 1)
    stroke(d, [(86, 54), (92, 54), (89, 60), (86, 54)], (200, 140, 255, 255), 1)
    return im


def staff_nethercore_idle() -> Image.Image:
    im = new_canvas()
    d = ImageDraw.Draw(im)
    d.line([(76, 112), (96, 24)], fill=(48, 36, 64, 255), width=7)
    d.line([(76, 112), (96, 24)], fill=(110, 70, 160, 200), width=3)
    d.ellipse([86, 8, 110, 32], fill=(70, 30, 120, 255))
    d.ellipse([92, 14, 104, 26], fill=(180, 90, 255, 255))
    d.ellipse([95, 17, 101, 23], fill=(255, 220, 255, 255))
    stroke(d, [(90, 20), (84, 14), (88, 10)], (200, 140, 255, 255), 2)
    stroke(d, [(106, 20), (112, 14), (108, 10)], (200, 140, 255, 255), 2)
    return im


def bow_windpierce_idle() -> Image.Image:
    im = new_canvas()
    d = ImageDraw.Draw(im)
    d.arc([44, 16, 112, 112], start=195, end=345, fill=(70, 110, 150, 255), width=5)
    d.arc([48, 20, 108, 108], start=195, end=345, fill=(140, 190, 220, 255), width=3)
    stroke(d, [(54, 34), (70, 64), (54, 94)], (230, 240, 255, 255), 1)
    d.rectangle([56, 56, 66, 74], fill=(50, 70, 90, 255))
    d.polygon([(66, 60), (78, 64), (66, 68)], fill=(180, 220, 255, 255))  # wind fletch cue
    return im


def axe_bloodhowl_idle() -> Image.Image:
    im = new_canvas()
    d = ImageDraw.Draw(im)
    d.rectangle([84, 72, 90, 114], fill=(52, 32, 28, 255))
    d.polygon(
        [(64, 24), (90, 18), (108, 34), (102, 52), (112, 66), (94, 74), (88, 70), (86, 50), (76, 36)],
        fill=(140, 28, 40, 255),
    )
    d.polygon(
        [(74, 30), (92, 26), (100, 38), (96, 52), (102, 62), (90, 68), (88, 52), (82, 40)],
        fill=(210, 50, 60, 230),
    )
    # Howling notch
    d.polygon([(96, 40), (108, 36), (104, 48)], fill=(40, 10, 14, 255))
    return im


def mace_dawnbreak_idle() -> Image.Image:
    im = new_canvas()
    d = ImageDraw.Draw(im)
    d.rectangle([84, 66, 90, 112], fill=(90, 70, 40, 255))
    d.polygon([(72, 28), (88, 16), (104, 28), (100, 52), (88, 58), (76, 52)], fill=(255, 200, 90, 255))
    d.polygon([(78, 30), (88, 22), (98, 30), (94, 48), (88, 52), (82, 48)], fill=(255, 240, 180, 255))
    stroke(d, [(88, 18), (88, 8), (92, 14), (84, 14), (88, 8)], (255, 255, 220, 255), 2)
    return im


def dagger_nightbite_idle() -> Image.Image:
    im = new_canvas()
    d = ImageDraw.Draw(im)
    d.rectangle([86, 80, 92, 108], fill=(28, 28, 40, 255))
    d.rectangle([85, 90, 93, 94], fill=(40, 160, 120, 255))
    d.polygon(
        [(88, 24), (98, 42), (94, 56), (98, 70), (92, 80), (88, 80), (84, 70), (86, 56), (82, 42)],
        fill=(80, 100, 110, 255),
    )
    d.polygon(
        [(89, 30), (94, 42), (92, 56), (94, 70), (90, 78), (88, 78), (87, 68), (88, 54), (86, 42)],
        fill=(30, 180, 140, 220),
    )
    return im


def shield_ironwall_idle() -> Image.Image:
    im = new_canvas()
    d = ImageDraw.Draw(im)
    d.rectangle([46, 34, 98, 100], fill=(90, 96, 104, 255))
    d.rectangle([52, 40, 92, 94], fill=(130, 138, 148, 255))
    d.rectangle([58, 46, 86, 88], fill=(70, 76, 84, 255))
    # Rivets
    for y in (48, 64, 80):
        for x in (60, 74):
            d.ellipse([x, y, x + 4, y + 4], fill=(200, 180, 90, 255))
    d.rectangle([68, 56, 76, 78], fill=(180, 160, 70, 255))
    return im


def frill_soulcodex_idle() -> Image.Image:
    im = new_canvas()
    d = ImageDraw.Draw(im)
    d.rectangle([46, 48, 88, 100], fill=(36, 28, 48, 255))
    d.rectangle([50, 52, 84, 96], fill=(70, 48, 96, 255))
    d.rectangle([54, 58, 80, 90], fill=(28, 20, 36, 255))
    # Soul flame bookmark
    d.polygon([(64, 40), (72, 52), (64, 48), (56, 52)], fill=(120, 220, 255, 255))
    d.polygon([(64, 44), (68, 52), (64, 50), (60, 52)], fill=(220, 255, 255, 255))
    stroke(d, [(58, 66), (76, 66), (76, 84), (58, 84), (58, 66)], (160, 120, 200, 255), 1)
    return im


def write_set(set_id: str, idle: Image.Image, *, force: bool) -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    AUTH.mkdir(parents=True, exist_ok=True)
    idle_auth = AUTH / f"{set_id}_idle.png"
    if idle_auth.exists() and not force:
        # Sync authored → live only; never clobber hand-tuned masters.
        for anim in ("idle", "walk", "attack"):
            src = AUTH / f"{set_id}_{anim}.png"
            if src.exists():
                (ROOT / src.name).write_bytes(src.read_bytes())
                print(f"sync {src.name}")
        return
    for anim, frame in pose_frames(idle).items():
        name = f"{set_id}_{anim}.png"
        frame.save(ROOT / name)
        frame.save(AUTH / name)
        print(f"wrote {name}")


def opaque(im: Image.Image) -> int:
    return sum(1 for px in im.getdata() if px[3] > 32)


def main() -> None:
    import argparse

    ap = argparse.ArgumentParser(
        description="Generate named weapon/off-hand model overlays."
    )
    ap.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing _authored masters (default: sync only).",
    )
    args = ap.parse_args()
    force = bool(args.force)

    models = [
        ("sword_thunderfury", thunderfury_idle),
        ("sword_warglaive", warglaive_idle),
        ("sword_runebound", sword_runebound_idle),
        ("staff_frostfire", staff_frostfire_idle),
        ("staff_nethercore", staff_nethercore_idle),
        ("bow_eagle", bow_eagle_idle),
        ("bow_windpierce", bow_windpierce_idle),
        ("axe_goreblade", axe_goreblade_idle),
        ("axe_bloodhowl", axe_bloodhowl_idle),
        ("mace_lightbringer", mace_lightbringer_idle),
        ("mace_dawnbreak", mace_dawnbreak_idle),
        ("dagger_shadowfang", dagger_shadowfang_idle),
        ("dagger_nightbite", dagger_nightbite_idle),
        ("shield_aegis", shield_aegis_idle),
        ("shield_ironwall", shield_ironwall_idle),
        # frill_prism / frill_soulcodex: use tool/derive_frill_variants.py
        # (recolor of frill_t0) — never ImageDraw stubs.
    ]
    for set_id, fn in models:
        write_set(set_id, fn(), force=force)
    # Sanity: walk/attack must differ from idle when files exist.
    for set_id, _ in models:
        idle_p = ROOT / f"{set_id}_idle.png"
        walk_p = ROOT / f"{set_id}_walk.png"
        atk_p = ROOT / f"{set_id}_attack.png"
        if not (idle_p.exists() and walk_p.exists() and atk_p.exists()):
            continue
        idle = Image.open(idle_p)
        walk = Image.open(walk_p)
        atk = Image.open(atk_p)
        assert list(idle.getdata()) != list(walk.getdata()), set_id
        assert list(idle.getdata()) != list(atk.getdata()), set_id
        print(f"ok poses {set_id} idle={opaque(idle)} walk={opaque(walk)} atk={opaque(atk)}")
    print("done: weapon model variants generated")


if __name__ == "__main__":
    main()
