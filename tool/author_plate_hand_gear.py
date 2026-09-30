"""Plate-density masters for the holy mace and aegis.

Armor is a painted bronze ramp with a dark edge, gold trim, and rivets.
These two were flat fills. This writes the same language into
gear/_authored and the live idle overlay plus the BAG icon.

Do not redraw them with the ellipse stubs in generate_weapon_model_variants.
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
GEAR = ROOT / "assets" / "custom" / "char" / "gear"
AUTH = GEAR / "_authored"

INK = (32, 18, 8, 255)
BRONZE = (
    (62, 42, 16, 255),
    (96, 68, 26, 255),
    (128, 96, 42, 255),
    (162, 126, 60, 255),
    (198, 162, 82, 255),
    (228, 198, 122, 255),
)
BLUE = (
    (18, 32, 64, 255),
    (32, 52, 96, 255),
    (46, 74, 128, 255),
    (64, 100, 158, 255),
    (88, 128, 184, 255),
)


def canvas() -> Image.Image:
    return Image.new("RGBA", (128, 128), (0, 0, 0, 0))


def mask() -> Image.Image:
    return Image.new("L", (128, 128), 0)


def stamp(im: Image.Image, shape: Image.Image, color: tuple[int, int, int, int]) -> None:
    px = im.load()
    sp = shape.load()
    for y in range(128):
        for x in range(128):
            if sp[x, y] > 128:
                px[x, y] = color


def shade(
    im: Image.Image,
    shape: Image.Image,
    ramp: tuple[tuple[int, int, int, int], ...],
    origin: tuple[float, float],
    light: tuple[float, float] = (-0.85, -0.7),
) -> None:
    """Three hard plate bands plus a top-left gold edge. Not a smooth ball."""
    px = im.load()
    sp = shape.load()
    ox, oy = origin
    length = (light[0] ** 2 + light[1] ** 2) ** 0.5
    lx, ly = light[0] / length, light[1] / length
    pts = [(x, y) for y in range(128) for x in range(128) if sp[x, y] > 128]
    if not pts:
        return
    shadow, mid, lit = ramp[0], ramp[len(ramp) // 2], ramp[-1]
    hi = BRONZE[-1]
    deep = BRONZE[0]
    for x, y in pts:
        dx, dy = x - ox, y - oy
        dist = (dx * dx + dy * dy) ** 0.5 or 1.0
        t = (dx / dist) * lx + (dy / dist) * ly
        px[x, y] = shadow if t < -0.25 else lit if t > 0.35 else mid
        # Hard trim on the lit rim, dark rim on the shadow side.
        lit_side = any(
            sp[x + dx2, y + dy2] <= 128
            for dx2, dy2 in ((-1, 0), (0, -1), (-1, -1))
            if 0 <= x + dx2 < 128 and 0 <= y + dy2 < 128
        )
        dark_side = any(
            sp[x + dx2, y + dy2] <= 128
            for dx2, dy2 in ((1, 0), (0, 1))
            if 0 <= x + dx2 < 128 and 0 <= y + dy2 < 128
        )
        if lit_side:
            px[x, y] = hi
        elif dark_side:
            px[x, y] = deep


def ink_edge(im: Image.Image) -> None:
    px = im.load()
    edge: list[tuple[int, int]] = []
    for y in range(128):
        for x in range(128):
            if px[x, y][3] == 0:
                continue
            if any(
                px[x + dx, y + dy][3] == 0
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                if 0 <= x + dx < 128 and 0 <= y + dy < 128
            ) or x in (0, 127) or y in (0, 127):
                edge.append((x, y))
    for x, y in edge:
        px[x, y] = INK


def poly(points: list[tuple[int, int]]) -> Image.Image:
    m = mask()
    ImageDraw.Draw(m).polygon(points, fill=255)
    return m


def disc(cx: int, cy: int, r: int) -> Image.Image:
    m = mask()
    ImageDraw.Draw(m).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    return m


def subtract(a: Image.Image, b: Image.Image) -> Image.Image:
    out = mask()
    ap, bp, op = a.load(), b.load(), out.load()
    for y in range(128):
        for x in range(128):
            if ap[x, y] > 128 and bp[x, y] <= 128:
                op[x, y] = 255
    return out


def rivet(im: Image.Image, x: int, y: int) -> None:
    px = im.load()
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            if dx * dx + dy * dy > 5:
                continue
            xx, yy = x + dx, y + dy
            if 0 <= xx < 128 and 0 <= yy < 128 and px[xx, yy][3]:
                px[xx, yy] = INK if dx * dx + dy * dy >= 4 else BRONZE[4]
    if 0 <= x < 128 and 0 <= y < 128:
        px[x, y] = BRONZE[5]
        if x > 0:
            px[x - 1, y] = BRONZE[5]


def paint_mace() -> Image.Image:
    im = canvas()
    # Grip stays on the shipped handle point (87, 105).
    shaft = poly([(82, 58), (95, 58), (95, 116), (82, 116)])
    shade(im, shaft, BRONZE[:4], (88, 90))
    wrap = poly([(83, 78), (94, 78), (94, 108), (83, 108)])
    shade(im, wrap, (BRONZE[0], BRONZE[1], BRONZE[2]), (88, 93))
    px = im.load()
    for y in range(80, 106, 4):
        for x in range(84, 94):
            if px[x, y][3]:
                px[x, y] = BRONZE[0]
    collars = [
        poly([(80, 56), (97, 56), (97, 64), (80, 64)]),
        poly([(80, 108), (97, 108), (97, 116), (80, 116)]),
    ]
    for collar in collars:
        shade(im, collar, BRONZE[2:], (88, 60))
    # Sun: metal disc plus eight plated rays.
    head = disc(88, 34, 16)
    shade(im, head, BRONZE[1:], (84, 28))
    inner = disc(88, 34, 10)
    shade(im, inner, BRONZE[3:], (84, 28))
    core = disc(88, 34, 4)
    shade(im, core, BRONZE[4:], (86, 32))
    for i in range(8):
        rad = math.radians(i * 45)
        c, s = math.cos(rad), math.sin(rad)
        tip = (88 + int(round(24 * c)), 34 + int(round(24 * s)))
        base = 15
        left = (88 + int(round(base * c - 4 * s)), 34 + int(round(base * s + 4 * c)))
        right = (88 + int(round(base * c + 4 * s)), 34 + int(round(base * s - 4 * c)))
        ray = poly([tip, left, right])
        shade(im, ray, BRONZE[2:], (88, 30))
    # Disc sits on the ray roots so the sun reads as a plate, not a blob.
    shade(im, head, BRONZE[1:], (84, 28))
    shade(im, inner, BRONZE[3:], (84, 28))
    shade(im, core, BRONZE[4:], (86, 32))
    ink_edge(im)
    rivet(im, 88, 112)
    return im


def paint_shield() -> Image.Image:
    im = canvas()
    # Boss stays on the shipped grip (71, 64).
    outer = poly(
        [(36, 30), (72, 18), (108, 30), (112, 70), (92, 104), (72, 118), (52, 104), (32, 70)]
    )
    shade(im, outer, BRONZE[1:], (70, 50))
    field = poly(
        [(44, 38), (72, 28), (100, 38), (102, 70), (86, 98), (72, 108), (58, 98), (42, 70)]
    )
    shade(im, field, BLUE, (70, 55))
    inner = poly(
        [(50, 46), (72, 38), (94, 46), (96, 70), (82, 92), (72, 100), (62, 92), (48, 70)]
    )
    shade(im, inner, BLUE[1:], (68, 58))
    rib = poly([(68, 40), (76, 40), (76, 96), (68, 96)])
    shade(im, rib, BRONZE[2:], (72, 60))
    boss = disc(71, 64, 10)
    shade(im, boss, BRONZE[1:], (68, 60))
    cap = disc(71, 64, 5)
    shade(im, cap, BRONZE[3:], (69, 62))
    ink_edge(im)
    for x, y in ((52, 48), (90, 48), (58, 88), (86, 88)):
        rivet(im, x, y)
    rivet(im, 71, 64)
    return im


def save_set(set_id: str, im: Image.Image) -> None:
    """Masters only. The gear build copies them onto the doll."""
    AUTH.mkdir(parents=True, exist_ok=True)
    im.save(AUTH / f"{set_id}_idle.png")
    print("wrote", set_id, "master")


def main() -> None:
    save_set("mace_lightbringer", paint_mace())
    save_set("shield_aegis", paint_shield())


if __name__ == "__main__":
    main()
