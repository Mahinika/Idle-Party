"""Short and broad styles plus class marks, from authored masters only.

Styles: `gear/_authored/{slot}_{style}_idle.png`, drawn on the family's own
128 canvas. The build copies them; it never draws or rescales one.

Class marks: the family's cut in the class palette plus a small authored
emblem, `gear/_authored/{slot}_{mark}_mark_idle.png`, kept on the piece.
Identity comes from palette and emblem, never from stretching the piece.
"""
from __future__ import annotations

from PIL import Image, ImageEnhance

from paper_doll_manifest import CLASS_MARKS, CLASS_SLOTS, CUTS, SLOTS, STYLES
from paper_doll_paths import CHAR as ROOT


def _load_master(path) -> Image.Image:
    if not path.exists():
        raise SystemExit(
            f"missing authored master {path} — draw it on the family's 128 "
            "canvas; the build never invents a style"
        )
    im = Image.open(path).convert("RGBA")
    if im.size != (128, 128):
        raise SystemExit(f"authored master must be 128x128: {path}")
    return im


def write_styles(family: str) -> int:
    gear = ROOT / family / "gear"
    n = 0
    for slot in SLOTS:
        for style in STYLES:
            im = _load_master(gear / "_authored" / f"{slot}_{style}_idle.png")
            im.save(gear / f"{slot}_{style}_idle.png")
            n += 1
    return n


def _ramp(im: Image.Image, fn) -> Image.Image:
    out = im.copy()
    px = out.load()
    for y in range(128):
        for x in range(128):
            r, g, b, a = px[x, y]
            if a < 12:
                continue
            px[x, y] = (*fn(r, g, b), a)
    return out


def _gold(r: int, g: int, b: int) -> tuple[int, int, int]:
    return (
        min(255, int(r * 0.62 + 78)),
        min(255, int(g * 0.50 + 52)),
        min(255, int(b * 0.34 + 18)),
    )


def _dusk(r: int, g: int, b: int) -> tuple[int, int, int]:
    return (
        min(255, int(r * 0.28 + 18)),
        min(255, int(g * 0.30 + 16)),
        min(255, int(b * 0.42 + 28)),
    )


def _shadow(r: int, g: int, b: int) -> tuple[int, int, int]:
    return (
        min(255, int(r * 0.34 + 22)),
        min(255, int(g * 0.22 + 8)),
        min(255, int(b * 0.40 + 24)),
    )


PALETTE = {"paladin": _gold, "deathknight": _dusk, "warlock": _shadow}


def class_look(piece: Image.Image, emblem: Image.Image, mark: str) -> Image.Image:
    out = ImageEnhance.Contrast(_ramp(piece, PALETTE[mark])).enhance(1.1)
    op, ep, pp = out.load(), emblem.load(), piece.load()
    for y in range(128):
        for x in range(128):
            e = ep[x, y]
            if e[3] >= 40 and pp[x, y][3] >= 40:
                op[x, y] = e
    return out


def write_class_marks(family: str) -> int:
    gear = ROOT / family / "gear"
    n = 0
    for mark in CLASS_MARKS.get(family, ()):
        for slot in CLASS_SLOTS:
            emblem = _load_master(gear / "_authored" / f"{slot}_{mark}_mark_idle.png")
            for cut in CUTS:
                piece = Image.open(gear / f"{slot}_{cut}_idle.png").convert("RGBA")
                class_look(piece, emblem, mark).save(
                    gear / f"{slot}_{mark}_{cut}_idle.png"
                )
                n += 1
    return n
