#!/usr/bin/env python3
"""96×96 owned enemy sprites.

Replaces the 32×32 ellipse pass and the boss/brute pairs that shared a
thumbnail. One pixel outline, a light from the upper left, and a silhouette
that is not a circle. Deterministic. No foreign art.

    python3 tool/craft_pixel_enemies.py
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "assets" / "custom" / "enemies"
S = 96
# Warm ink, the same family as sandy_mite's contour. Two pixels, not a wire.
INK = (36, 18, 12, 255)
INK_OUTER = (52, 26, 16, 255)


def clamp_i(i: int, n: int) -> int:
    if i < 0:
        return 0
    if i >= n:
        return n - 1
    return i


class Pix:
    def __init__(self, w: int = S, h: int = S) -> None:
        self.w = w
        self.h = h
        self.px: list[tuple[int, int, int, int] | None] = [None] * (w * h)

    def put(self, x: int, y: int, c: tuple[int, int, int] | tuple[int, int, int, int] | None) -> None:
        if c is None or not (0 <= x < self.w and 0 <= y < self.h):
            return
        self.px[y * self.w + x] = c if len(c) == 4 else (*c, 255)

    def get(self, x: int, y: int) -> tuple[int, int, int, int] | None:
        if not (0 <= x < self.w and 0 <= y < self.h):
            return None
        return self.px[y * self.w + x]

    def tone(self, nx: float, ny: float, n: int, x: int, y: int) -> int:
        light = 0.12 - 0.92 * nx - 0.62 * ny
        # Hard bands, with a one-pixel dither on the step so it is not a poster.
        jitter = 0.07 if ((x * 3 + y * 5) & 3) == 0 else -0.03 if ((x + y) & 1) else 0.0
        t = (light + 1.15) / 2.25 + jitter
        return clamp_i(int(t * n), n)

    def disc(
        self,
        cx: float,
        cy: float,
        rx: float,
        ry: float,
        ramp: list[tuple[int, int, int]],
        y0: int | None = None,
        y1: int | None = None,
        x0: int | None = None,
        x1: int | None = None,
    ) -> None:
        n = len(ramp)
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            if y0 is not None and y < y0:
                continue
            if y1 is not None and y >= y1:
                continue
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if x0 is not None and x < x0:
                    continue
                if x1 is not None and x >= x1:
                    continue
                nx = (x - cx) / max(0.5, rx)
                ny = (y - cy) / max(0.5, ry)
                wob = 0.045 * math.sin(x * 0.85 + y * 0.35)
                if nx * nx + ny * ny > 1.0 + wob:
                    continue
                self.put(x, y, ramp[self.tone(nx, ny, n, x, y)])

    def box(
        self,
        x: int,
        y: int,
        w: int,
        h: int,
        ramp: list[tuple[int, int, int]] | tuple[int, int, int],
    ) -> None:
        if w <= 0 or h <= 0:
            return
        if isinstance(ramp[0], int):
            for yy in range(y, y + h):
                for xx in range(x, x + w):
                    self.put(xx, yy, ramp)  # type: ignore[arg-type]
            return
        n = len(ramp)
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                nx = (xx - x) / max(1, w - 1) * 2 - 1
                ny = (yy - y) / max(1, h - 1) * 2 - 1
                self.put(xx, yy, ramp[self.tone(nx * 0.8, ny * 0.45, n, xx, yy)])

    def poly(self, pts: list[tuple[float, float]], ramp: list[tuple[int, int, int]]) -> None:
        if len(pts) < 3:
            return
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        minx, maxx = int(min(xs)) - 1, int(max(xs)) + 2
        miny, maxy = int(min(ys)) - 1, int(max(ys)) + 2
        cx = sum(xs) / len(xs)
        cy = sum(ys) / len(ys)
        span = max(8.0, max(xs) - min(xs), max(ys) - min(ys))
        n = len(ramp)

        def inside(x: float, y: float) -> bool:
            hit = False
            j = len(pts) - 1
            for i, (xi, yi) in enumerate(pts):
                xj, yj = pts[j]
                if ((yi > y) != (yj > y)) and (
                    x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi
                ):
                    hit = not hit
                j = i
            return hit

        for y in range(miny, maxy):
            for x in range(minx, maxx):
                if not inside(x + 0.5, y + 0.5):
                    continue
                nx = (x - cx) / span
                ny = (y - cy) / span
                self.put(x, y, ramp[self.tone(nx * 1.4, ny * 1.1, n, x, y)])

    def _filled(self) -> list[bool]:
        return [p is not None for p in self.px]

    def outline(self, passes: int = 2) -> None:
        """Two-pixel warm contour. Inner pass is darker so the line has weight."""
        for step in range(passes):
            ink = INK if step == 0 else INK_OUTER
            filled = self._filled()
            add: list[tuple[int, int]] = []
            for y in range(self.h):
                row = y * self.w
                for x in range(self.w):
                    if filled[row + x]:
                        continue
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < self.w and 0 <= ny < self.h and filled[ny * self.w + nx]:
                            add.append((x, y))
                            break
            for x, y in add:
                self.px[y * self.w + x] = ink

    def enrich(self) -> None:
        """Upper-left light, plate seams, and a few interior marks.

        Flat ramps stay in the creature's own colors. Eyes and gems are
        left alone: a pixel that already disagrees with its neighbors is a
        feature, not a plate.
        """
        w, h = self.w, self.h
        src = list(self.px)
        mask = [p is not None for p in src]
        dist = [99] * (w * h)
        for y in range(h):
            row = y * w
            for x in range(w):
                i = row + x
                if not mask[i]:
                    dist[i] = 0
                    continue
                edge = False
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < w and 0 <= ny < h) or not mask[ny * w + nx]:
                        edge = True
                        break
                dist[i] = 1 if edge else 99
        for _ in range(6):
            nxt = list(dist)
            for y in range(h):
                row = y * w
                for x in range(w):
                    i = row + x
                    if not mask[i] or dist[i] <= 1:
                        continue
                    best = dist[i]
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h:
                            best = min(best, dist[ny * w + nx] + 1)
                    nxt[i] = best
            dist = nxt

        def feature(x: int, y: int) -> bool:
            c = src[y * w + x]
            if c is None:
                return False
            disagree = 0
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < w and 0 <= ny < h):
                        continue
                    o = src[ny * w + nx]
                    if o is None:
                        continue
                    if abs(c[0] - o[0]) + abs(c[1] - o[1]) + abs(c[2] - o[2]) > 150:
                        disagree += 1
            return disagree >= 2

        def shade(rgb: tuple[int, int, int, int], t: float) -> tuple[int, int, int, int]:
            r, g, b = rgb[0], rgb[1], rgb[2]
            if t >= 0:
                r = r + (248 - r) * t * 0.62
                g = g + (228 - g) * t * 0.5
                b = b + (186 - b) * t * 0.32
            else:
                k = -t
                r *= 1 - 0.78 * k
                g *= 1 - 0.8 * k
                b *= 1 - 0.74 * k
            return (
                clamp_i(int(r), 256),
                clamp_i(int(g), 256),
                clamp_i(int(b), 256),
                255,
            )

        cx = cy = n = 0
        for y in range(h):
            for x in range(w):
                if mask[y * w + x]:
                    cx += x
                    cy += y
                    n += 1
        if n == 0:
            return
        cx /= n
        cy /= n
        span = max(12.0, (n ** 0.5) * 0.55)

        for y in range(h):
            for x in range(w):
                i = y * w + x
                c = src[i]
                if c is None or feature(x, y):
                    continue
                d = dist[i]
                nx = (x - cx) / span
                ny = (y - cy) / span
                light = 0.2 - 0.9 * nx - 0.65 * ny
                light = max(-1.0, min(1.0, light))
                ao = min(1.0, d / 5.0)
                # Shell cuts, not a brick wall. A seam only crosses a wide
                # run, and it breaks so a leg stays a leg.
                seam = False
                if d > 2 and y % 8 == 3:
                    run = 0
                    for dx in range(-8, 9):
                        nx2 = x + dx
                        if 0 <= nx2 < w and mask[y * w + nx2]:
                            run += 1
                    if run >= 12 and ((x // 4) % 3) != 2:
                        seam = True
                # A short keel on the body's midline.
                if d > 3 and abs(x - cx) <= 1.2 and (y // 5) % 2 == 0:
                    seam = True
                bump = 0.18 if (not seam and d > 3 and (x + y * 3) % 17 == 0) else 0.0
                if seam:
                    self.px[i] = shade(c, -0.78)
                    continue
                t = max(-0.8, min(0.85, light * (0.4 + 0.6 * ao) + bump))
                t = round(t * 6) / 6
                self.px[i] = shade(c, t)

    def image(self) -> Image.Image:
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        im.putdata([p if p is not None else (0, 0, 0, 0) for p in self.px])
        return im


def eye(p: Pix, x: int, y: int, r: int, white: tuple[int, int, int], pupil: tuple[int, int, int]) -> None:
    p.disc(x, y, r, r - 0.4, [pupil, white, white, (255, 252, 236)])
    p.disc(x + 0.4, y + 0.2, max(1.2, r * 0.45), max(1.1, r * 0.42), [pupil, pupil])
    p.put(x - r // 2, y - r // 2, (255, 255, 255))


def leg(p: Pix, x: int, y: int, w: int, h: int, ramp: list[tuple[int, int, int]]) -> None:
    p.box(x, y, w, h, ramp)
    p.box(x - 1, y + h - 3, w + 3, 3, ramp)


def save(img: Image.Image, name: str) -> None:
    path = ROOT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)


def finish(p: Pix, name: str) -> None:
    p.enrich()
    p.outline()
    save(p.image(), name)


# Ramps, dark to light.
SAND = [(74, 48, 24), (120, 78, 36), (168, 116, 52), (206, 156, 78), (232, 196, 120), (248, 224, 168)]
SHELL = [(48, 32, 18), (86, 56, 28), (124, 82, 40), (158, 112, 58), (196, 150, 84)]
GOB = [(22, 58, 24), (36, 92, 34), (58, 128, 46), (92, 160, 64), (140, 190, 96), (186, 214, 140)]
LEATHER = [(48, 30, 16), (84, 52, 28), (120, 78, 42), (156, 112, 64), (196, 154, 96)]
STEEL = [(28, 36, 52), (48, 62, 86), (78, 98, 128), (118, 138, 166), (168, 186, 206), (214, 224, 232)]
GOLD = [(92, 64, 18), (140, 100, 28), (186, 142, 40), (220, 180, 64), (244, 214, 110)]
NAVY = [(16, 24, 48), (28, 40, 78), (42, 62, 112), (64, 90, 146), (96, 124, 176)]
VOID = [(28, 16, 48), (58, 28, 92), (96, 48, 140), (140, 78, 186), (186, 130, 220), (230, 190, 250)]
BONE = [(92, 84, 70), (140, 132, 112), (186, 178, 154), (220, 214, 196), (244, 240, 226)]
ROT = [(28, 48, 32), (48, 78, 46), (72, 112, 58), (110, 146, 72), (156, 186, 110)]
FIRE = [(64, 16, 12), (120, 28, 14), (176, 52, 16), (220, 96, 24), (248, 160, 40), (255, 214, 96)]
ASH = [(36, 22, 18), (64, 36, 28), (96, 54, 40), (132, 78, 56), (168, 112, 80)]
ICE = [(28, 64, 88), (56, 112, 140), (110, 168, 196), (176, 216, 232), (230, 246, 252), (255, 255, 255)]
CRYSTAL = [(20, 48, 110), (36, 84, 170), (64, 130, 210), (120, 186, 240), (190, 230, 255), (245, 252, 255)]
CORAL = [(28, 72, 78), (48, 112, 108), (78, 150, 132), (120, 186, 150), (176, 214, 176), (230, 160, 120)]
BARK = [(36, 24, 14), (64, 42, 22), (96, 64, 32), (128, 92, 48), (160, 124, 70), (86, 120, 48)]
MOSS = [(20, 48, 24), (36, 78, 32), (58, 112, 42), (90, 146, 58), (132, 176, 80)]
STORM = [(28, 24, 64), (52, 40, 110), (86, 64, 160), (130, 100, 200), (180, 160, 230), (230, 220, 255)]
BOLT = [(80, 70, 20), (160, 140, 30), (220, 200, 50), (255, 240, 120), (255, 255, 210)]
RIME = [(40, 70, 90), (80, 120, 140), (140, 180, 196), (200, 226, 234), (236, 246, 250)]
FEN = [(24, 48, 18), (48, 84, 22), (80, 120, 28), (120, 156, 40), (170, 190, 60), (210, 220, 90)]
BRASS = [(70, 46, 16), (112, 74, 22), (158, 108, 32), (196, 146, 48), (228, 186, 80), (248, 220, 140)]
VEIL = [(48, 36, 64), (90, 70, 110), (140, 110, 160), (186, 160, 200), (220, 200, 226), (245, 236, 246)]
SILK = [(90, 70, 100), (150, 120, 160), (200, 170, 200), (236, 214, 226)]


def sandy_tank() -> Image.Image:
    """Shellback: a wide beetle, the mite's cousin. Plates, not a flat oval."""
    p = Pix()
    # Six jointed legs, thicker than a wire, tucked under the shell.
    for i, x in enumerate((10, 20, 30, 58, 68, 78)):
        p.box(x, 58, 6, 8, SHELL)
        p.box(x + (3 if i < 3 else -3), 66, 6, 12, SAND)
        p.box(x - 1, 76, 10, 4, SHELL)
        p.put(x + 2, 70, (40, 22, 12))
        p.put(x + 3, 70, (40, 22, 12))
    p.disc(48, 50, 36, 20, SAND)
    p.disc(48, 46, 28, 13, SHELL)
    # Segment seams and a gold keel, the same job as the mite's shell cuts.
    for y in (34, 42, 50, 58):
        p.box(20, y, 56, 2, (48, 28, 14))
    p.box(46, 28, 4, 34, GOLD)
    for sx in (28, 38, 58, 68):
        p.disc(sx, 40, 3.2, 2.4, GOLD)
        p.disc(sx, 50, 2.4, 2.2, SHELL)
        p.put(sx, 46, (255, 236, 180))
    # Head, mandibles, antennae.
    p.disc(48, 26, 14, 11, SAND)
    p.poly([(34, 28), (18, 12), (30, 22), (24, 34)], SAND)
    p.poly([(62, 28), (78, 12), (66, 22), (72, 34)], SAND)
    p.box(22, 16, 3, 4, (40, 22, 12))
    p.box(72, 16, 3, 4, (40, 22, 12))
    p.box(40, 12, 2, 8, SHELL)
    p.box(54, 12, 2, 8, SHELL)
    eye(p, 42, 24, 3, (240, 220, 140), (40, 24, 12))
    eye(p, 54, 24, 3, (240, 220, 140), (40, 24, 12))
    p.box(44, 30, 8, 3, (60, 32, 16))
    p.put(46, 33, (240, 220, 160))
    p.put(50, 33, (240, 220, 160))
    finish(p, "sandy_tank.png")
    return p.image()


def sandy_brute() -> Image.Image:
    """Rock crab. Two open claws wider than the body."""
    p = Pix()
    for x in (28, 38, 54, 64):
        p.box(x, 66, 5, 10, SHELL)
        p.box(x - 2, 74, 9, 4, SAND)
    p.disc(48, 54, 20, 14, SAND)
    p.disc(48, 50, 12, 8, SHELL)
    # Open pincers, not closed balls.
    p.poly([(28, 48), (8, 28), (18, 48)], SAND)
    p.poly([(28, 52), (10, 62), (22, 50)], GOLD)
    p.box(20, 46, 14, 5, SHELL)
    p.poly([(68, 52), (88, 36), (78, 54)], SAND)
    p.poly([(68, 56), (86, 70), (74, 56)], GOLD)
    p.box(62, 52, 12, 5, SHELL)
    for sx, sy in ((36, 46), (46, 42), (58, 46)):
        p.disc(sx, sy, 2, 2, SHELL)
    eye(p, 42, 50, 3, (255, 230, 160), (30, 16, 8))
    eye(p, 54, 50, 3, (255, 230, 160), (30, 16, 8))
    finish(p, "sandy_brute.png")
    return p.image()


def sandy_ranged() -> Image.Image:
    """Cavern spitter. Long neck, a spit sac, thin legs. Not a bat."""
    p = Pix()
    leg(p, 34, 70, 6, 16, SAND)
    leg(p, 56, 68, 6, 18, SAND)
    p.disc(48, 62, 16, 12, SAND)
    # Sac on the back.
    p.disc(62, 52, 12, 14, [(120, 90, 30), (180, 140, 40), (220, 180, 70), (240, 210, 110)])
    p.disc(64, 48, 4, 4, [(240, 220, 120), (255, 245, 180)])
    # Neck and head with a tube.
    p.box(42, 28, 8, 26, SAND)
    p.disc(44, 22, 10, 8, SAND)
    p.box(28, 20, 16, 4, GOLD)
    p.disc(24, 22, 4, 3, [(200, 80, 40), (240, 120, 60), (255, 180, 90)])
    eye(p, 40, 20, 3, (255, 230, 170), (40, 20, 10))
    finish(p, "sandy_ranged.png")
    return p.image()


def goblin_elite() -> Image.Image:
    p = Pix()
    leg(p, 34, 68, 8, 20, LEATHER)
    leg(p, 52, 68, 8, 20, LEATHER)
    p.box(34, 40, 28, 30, GOB)
    p.box(30, 42, 8, 16, LEATHER)
    p.box(58, 42, 8, 16, LEATHER)
    # Ears.
    p.poly([(30, 28), (16, 18), (30, 36)], GOB)
    p.poly([(66, 28), (80, 16), (66, 38)], GOB)
    p.disc(48, 26, 12, 11, GOB)
    # Club.
    p.box(70, 30, 5, 40, LEATHER)
    p.disc(72, 26, 8, 8, [(90, 60, 30), (130, 86, 40), (170, 120, 60)])
    eye(p, 43, 24, 3, (230, 240, 140), (16, 24, 10))
    eye(p, 54, 24, 3, (230, 240, 140), (16, 24, 10))
    p.box(44, 30, 8, 2, (40, 20, 16))
    finish(p, "goblin_elite.png")
    return p.image()


def goblin_tank() -> Image.Image:
    p = Pix()
    leg(p, 40, 70, 8, 18, LEATHER)
    leg(p, 54, 70, 8, 18, LEATHER)
    p.box(40, 44, 26, 28, GOB)
    # Scrap shield, left, almost as tall as the body.
    p.box(12, 28, 26, 48, LEATHER)
    p.box(16, 32, 18, 36, [(70, 64, 48), (110, 100, 70), (150, 136, 96)])
    p.disc(25, 50, 5, 5, GOLD)
    p.disc(48, 28, 11, 10, GOB)
    p.poly([(38, 24), (34, 12), (46, 22)], GOB)
    p.poly([(58, 24), (64, 12), (52, 22)], GOB)
    p.box(44, 18, 10, 6, STEEL)
    eye(p, 45, 28, 2, (240, 240, 140), (20, 20, 8))
    eye(p, 53, 28, 2, (240, 240, 140), (20, 20, 8))
    finish(p, "goblin_tank.png")
    return p.image()


def goblin_ranged() -> Image.Image:
    p = Pix()
    leg(p, 40, 70, 6, 18, GOB)
    leg(p, 52, 70, 6, 18, GOB)
    p.box(42, 40, 16, 30, GOB)
    p.disc(48, 26, 9, 9, GOB)
    p.poly([(40, 24), (30, 14), (42, 30)], GOB)
    p.poly([(56, 24), (66, 14), (54, 30)], GOB)
    # Sling pouch and a stone.
    p.box(62, 44, 4, 22, LEATHER)
    p.disc(70, 40, 7, 6, [(80, 70, 60), (120, 108, 90), (160, 146, 120)])
    p.disc(74, 36, 3, 3, STEEL)
    eye(p, 45, 25, 2, (240, 240, 150), (16, 20, 8))
    eye(p, 53, 25, 2, (240, 240, 150), (16, 20, 8))
    finish(p, "goblin_ranged.png")
    return p.image()


def king_guard() -> Image.Image:
    p = Pix()
    leg(p, 40, 68, 8, 20, STEEL)
    leg(p, 54, 68, 8, 20, STEEL)
    p.box(36, 36, 26, 34, NAVY)
    p.box(46, 40, 6, 26, GOLD)
    # Kite shield.
    p.poly([(18, 34), (34, 34), (34, 62), (26, 78), (18, 62)], STEEL)
    p.box(22, 42, 8, 12, GOLD)
    # Spear.
    p.box(70, 16, 3, 68, LEATHER)
    p.poly([(66, 22), (78, 22), (72, 8)], STEEL)
    p.disc(48, 24, 10, 9, STEEL)
    p.box(40, 14, 16, 6, GOLD)
    p.box(46, 8, 4, 8, (160, 30, 36))
    eye(p, 44, 24, 2, (40, 48, 70), (16, 20, 28))
    eye(p, 52, 24, 2, (40, 48, 70), (16, 20, 28))
    finish(p, "king_guard.png")
    return p.image()


def king_tank() -> Image.Image:
    """Gate knight. A kite shield and a helm, not a bottle with a cap."""
    p = Pix()
    # Greaves and sabatons.
    leg(p, 50, 68, 8, 16, STEEL)
    leg(p, 64, 68, 8, 16, STEEL)
    p.box(48, 82, 12, 5, GOLD)
    p.box(62, 82, 12, 5, GOLD)
    # Breastplate and a pauldron, beside the shield.
    p.box(48, 36, 22, 34, NAVY)
    p.box(54, 40, 6, 26, GOLD)
    p.disc(68, 38, 8, 6, STEEL)
    # Kite shield owns the left. Rivets and a crowned boss, not a flat panel.
    p.poly([(10, 28), (42, 24), (44, 58), (28, 86), (8, 60)], STEEL)
    p.poly([(16, 34), (36, 32), (36, 56), (26, 74), (14, 56)], NAVY)
    p.box(22, 40, 8, 18, GOLD)
    for sx, sy in ((16, 36), (34, 34), (18, 58), (32, 56)):
        p.disc(sx, sy, 1.6, 1.6, GOLD)
    p.disc(26, 48, 3, 3, [(170, 36, 40), (220, 70, 60)])
    # Greathelm with a cross slit and a red crest. A head, not a bottle cap.
    p.disc(62, 22, 12, 11, STEEL)
    p.box(52, 12, 20, 6, GOLD)
    p.poly([(58, 14), (62, 4), (66, 14)], [(140, 24, 28), (200, 48, 48)])
    p.box(54, 22, 16, 3, (12, 14, 20))
    p.box(61, 18, 3, 12, (12, 14, 20))
    # Sword hilt over the right shoulder.
    p.box(74, 30, 4, 28, LEATHER)
    p.box(70, 28, 12, 4, GOLD)
    p.poly([(72, 30), (80, 30), (76, 16)], STEEL)
    finish(p, "king_tank.png")
    return p.image()


def underworld_elite() -> Image.Image:
    """A beholder-kin eye with tentacles. Not a cyclops body."""
    p = Pix()
    for i, ang in enumerate(range(0, 360, 40)):
        rad = math.radians(ang)
        x2 = 48 + math.cos(rad) * 40
        y2 = 48 + math.sin(rad) * 34
        p.poly([(48, 48), (x2, y2), (x2 + 6 * math.sin(rad), y2 - 6 * math.cos(rad))], VOID)
        p.disc(x2, y2, 4, 3, [(180, 80, 220), (230, 160, 255)])
    p.disc(48, 46, 22, 20, VOID)
    p.disc(48, 46, 12, 11, [(240, 220, 80), (255, 245, 160), (255, 255, 220)])
    p.disc(48, 46, 5, 6, [(20, 8, 28), (40, 16, 48)])
    p.put(44, 42, (255, 255, 255))
    finish(p, "underworld_elite.png")
    return p.image()


def underworld_brute() -> Image.Image:
    p = Pix()
    leg(p, 28, 70, 10, 18, VOID)
    leg(p, 58, 70, 10, 18, VOID)
    p.box(26, 40, 44, 32, VOID)
    p.poly([(26, 40), (18, 16), (36, 36)], VOID)
    p.poly([(70, 40), (80, 14), (60, 36)], VOID)
    p.disc(48, 28, 14, 12, VOID)
    p.disc(48, 30, 6, 5, [(220, 80, 255), (255, 180, 255)])
    eye(p, 42, 26, 3, (230, 180, 255), (20, 8, 30))
    eye(p, 56, 26, 3, (230, 180, 255), (20, 8, 30))
    finish(p, "underworld_brute.png")
    return p.image()


def underworld_tank() -> Image.Image:
    p = Pix()
    p.box(22, 28, 52, 56, VOID)
    p.box(30, 38, 36, 32, [(90, 40, 150), (140, 70, 200), (190, 120, 230)])
    p.disc(48, 52, 8, 8, [(230, 180, 255), (255, 230, 255)])
    p.poly([(22, 28), (14, 8), (34, 28)], VOID)
    p.poly([(74, 28), (82, 8), (62, 28)], VOID)
    p.box(18, 48, 8, 28, VOID)
    p.box(70, 48, 8, 28, VOID)
    eye(p, 42, 22, 2, (200, 140, 255), (20, 8, 28))
    eye(p, 54, 22, 2, (200, 140, 255), (20, 8, 28))
    finish(p, "underworld_tank.png")
    return p.image()


def underworld_support() -> Image.Image:
    p = Pix()
    p.poly([(48, 16), (70, 86), (26, 86)], VOID)
    p.disc(48, 22, 10, 9, VOID)
    p.box(62, 30, 4, 48, GOLD)
    p.disc(64, 26, 6, 6, [(220, 160, 255), (255, 220, 255)])
    eye(p, 44, 22, 2, (230, 190, 255), (30, 10, 40))
    eye(p, 52, 22, 2, (230, 190, 255), (30, 10, 40))
    finish(p, "underworld_support.png")
    return p.image()


def dead_swarm() -> Image.Image:
    p = Pix()
    for cx, cy, r in ((30, 40, 12), (58, 32, 11), (46, 62, 14)):
        p.disc(cx, cy, r, r - 1, BONE)
        eye(p, cx - 4, cy - 1, 2, (20, 24, 18), (20, 24, 18))
        eye(p, cx + 4, cy - 1, 2, (20, 24, 18), (20, 24, 18))
        p.box(cx - 3, cy + 4, 6, 2, (40, 36, 28))
    # Loose ribs.
    p.box(18, 70, 22, 3, BONE)
    p.box(54, 74, 18, 3, BONE)
    finish(p, "dead_swarm.png")
    return p.image()


def dead_support() -> Image.Image:
    p = Pix()
    p.poly([(48, 18), (74, 88), (22, 88)], [(28, 40, 34), (40, 62, 48), (58, 86, 64), (90, 120, 90)])
    p.disc(48, 20, 10, 9, BONE)
    p.box(70, 24, 3, 50, BONE)
    p.disc(72, 20, 5, 6, ROT)
    eye(p, 44, 20, 2, (140, 230, 120), (20, 40, 16))
    eye(p, 52, 20, 2, (140, 230, 120), (20, 40, 16))
    finish(p, "dead_support.png")
    return p.image()


def dead_tank() -> Image.Image:
    p = Pix()
    leg(p, 50, 70, 7, 16, BONE)
    leg(p, 62, 70, 7, 16, BONE)
    p.box(48, 36, 18, 36, BONE)
    p.disc(58, 24, 10, 10, BONE)
    # Round bone shield.
    p.disc(28, 52, 18, 22, BONE)
    p.disc(28, 52, 8, 8, ROT)
    eye(p, 54, 22, 2, (20, 24, 16), (20, 24, 16))
    eye(p, 62, 22, 2, (20, 24, 16), (20, 24, 16))
    p.box(54, 28, 8, 2, (40, 36, 28))
    finish(p, "dead_tank.png")
    return p.image()


def hell_elite() -> Image.Image:
    p = Pix()
    # Wings.
    p.poly([(30, 36), (6, 16), (10, 70), (30, 56)], FIRE)
    p.poly([(66, 36), (90, 16), (86, 70), (66, 56)], FIRE)
    leg(p, 38, 70, 8, 16, ASH)
    leg(p, 52, 70, 8, 16, ASH)
    p.box(36, 40, 26, 32, FIRE)
    p.disc(48, 26, 12, 11, ASH)
    p.poly([(36, 22), (28, 6), (42, 22)], FIRE)
    p.poly([(60, 22), (70, 6), (54, 22)], FIRE)
    p.poly([(40, 78), (34, 90), (46, 78)], FIRE)
    eye(p, 43, 26, 3, (255, 220, 60), (40, 12, 8))
    eye(p, 54, 26, 3, (255, 220, 60), (40, 12, 8))
    finish(p, "hell_elite.png")
    return p.image()


def hell_brute() -> Image.Image:
    p = Pix()
    leg(p, 22, 72, 14, 16, ASH)
    leg(p, 60, 72, 14, 16, ASH)
    # Barrel chest, not a brick slab.
    p.disc(48, 56, 30, 18, FIRE)
    p.poly([(34, 44), (48, 68), (62, 44), (48, 52)], ASH)
    p.disc(48, 28, 18, 14, ASH)
    p.poly([(30, 24), (22, 4), (40, 24)], FIRE)
    p.poly([(66, 24), (76, 4), (56, 24)], FIRE)
    # Fists, no wings. The elite has the wings.
    p.disc(12, 52, 10, 9, FIRE)
    p.disc(84, 52, 10, 9, FIRE)
    eye(p, 40, 28, 3, (255, 200, 40), (40, 10, 8))
    eye(p, 56, 28, 3, (255, 200, 40), (40, 10, 8))
    p.box(44, 36, 10, 3, (40, 12, 8))
    finish(p, "hell_brute.png")
    return p.image()


def hell_ranged() -> Image.Image:
    p = Pix()
    leg(p, 40, 70, 6, 16, ASH)
    leg(p, 52, 70, 6, 16, ASH)
    p.box(42, 38, 16, 32, FIRE)
    p.disc(48, 24, 9, 9, ASH)
    p.poly([(40, 20), (34, 8), (46, 20)], FIRE)
    # Bow of flame.
    p.poly([(70, 20), (86, 48), (70, 76)], FIRE)
    p.box(68, 46, 16, 3, GOLD)
    eye(p, 45, 24, 2, (255, 220, 80), (40, 12, 8))
    eye(p, 52, 24, 2, (255, 220, 80), (40, 12, 8))
    finish(p, "hell_ranged.png")
    return p.image()


def crystal_brute() -> Image.Image:
    p = Pix()
    # Faceted golem with arms, not a single diamond.
    p.poly([(48, 8), (70, 28), (62, 78), (34, 78), (26, 28)], CRYSTAL)
    p.poly([(26, 36), (8, 48), (22, 64)], CRYSTAL)
    p.poly([(70, 36), (88, 48), (74, 64)], CRYSTAL)
    p.box(40, 78, 8, 12, CRYSTAL)
    p.box(52, 78, 8, 12, CRYSTAL)
    p.box(46, 18, 4, 40, [(230, 246, 255), (255, 255, 255)])
    eye(p, 42, 36, 3, (220, 245, 255), (20, 40, 80))
    eye(p, 56, 36, 3, (220, 245, 255), (20, 40, 80))
    finish(p, "crystal_brute.png")
    return p.image()


def crystal_support() -> Image.Image:
    p = Pix()
    p.poly([(48, 14), (68, 88), (28, 88)], CRYSTAL)
    p.poly([(48, 10), (58, 24), (38, 24)], [(220, 240, 255), (255, 255, 255)])
    p.box(66, 36, 4, 40, CRYSTAL)
    p.disc(68, 32, 6, 6, [(180, 220, 255), (240, 250, 255)])
    eye(p, 44, 32, 2, (210, 240, 255), (20, 40, 90))
    eye(p, 54, 32, 2, (210, 240, 255), (20, 40, 90))
    finish(p, "crystal_support.png")
    return p.image()


def crystal_mite_sprite() -> Image.Image:
    """Shard spider. rime_mite.png stays the detailed cluster, so this is not it."""
    p = Pix()
    for x, y in ((16, 40), (18, 58), (22, 74), (74, 40), (78, 58), (72, 74)):
        p.poly([(48, 52), (x, y), (x + 8, y + 4)], CRYSTAL)
    p.disc(48, 48, 16, 14, CRYSTAL)
    p.disc(48, 46, 8, 7, [(200, 230, 255), (255, 255, 255)])
    eye(p, 44, 46, 2, (20, 40, 90), (10, 16, 40))
    eye(p, 52, 46, 2, (20, 40, 90), (10, 16, 40))
    p.poly([(48, 18), (56, 36), (40, 36)], [(220, 245, 255), (255, 255, 255)])
    finish(p, "crystal_mite.png")
    return p.image()


def tide_brute() -> Image.Image:
    p = Pix()
    for x in (28, 40, 54, 66):
        leg(p, x, 66, 6, 16, CORAL)
    p.disc(48, 50, 24, 16, CORAL)
    p.disc(18, 42, 12, 9, CORAL)
    p.disc(80, 46, 12, 9, [(180, 90, 70), (220, 130, 90), (240, 170, 120)])
    p.box(20, 46, 18, 4, CORAL)
    p.box(62, 50, 16, 4, CORAL)
    # Barnacles.
    p.disc(40, 44, 3, 3, BONE)
    p.disc(56, 40, 3, 3, BONE)
    eye(p, 42, 48, 3, (180, 240, 220), (16, 40, 36))
    eye(p, 54, 48, 3, (180, 240, 220), (16, 40, 36))
    finish(p, "tide_brute.png")
    return p.image()


def ember_elite() -> Image.Image:
    p = Pix()
    leg(p, 36, 70, 8, 16, ASH)
    leg(p, 52, 70, 8, 16, ASH)
    p.box(34, 40, 28, 32, ASH)
    p.poly([(30, 36), (22, 8), (40, 32)], FIRE)
    p.poly([(66, 36), (74, 8), (56, 32)], FIRE)
    p.box(68, 28, 4, 40, STEEL)
    p.poly([(64, 28), (80, 22), (68, 40)], FIRE)
    p.disc(48, 26, 11, 10, ASH)
    eye(p, 44, 26, 2, (255, 180, 40), (40, 16, 8))
    eye(p, 53, 26, 2, (255, 180, 40), (40, 16, 8))
    finish(p, "ember_elite.png")
    return p.image()


def ember_brute() -> Image.Image:
    p = Pix()
    p.box(10, 48, 76, 28, ASH)
    p.box(16, 36, 64, 20, FIRE)
    p.disc(30, 40, 12, 10, ASH)
    p.disc(66, 40, 12, 10, ASH)
    leg(p, 18, 74, 12, 12, ASH)
    leg(p, 40, 74, 12, 12, ASH)
    leg(p, 64, 74, 12, 12, ASH)
    eye(p, 26, 40, 3, (255, 200, 60), (40, 12, 8))
    eye(p, 62, 40, 3, (255, 200, 60), (40, 12, 8))
    finish(p, "ember_brute.png")
    return p.image()


def grove_elite() -> Image.Image:
    p = Pix()
    leg(p, 34, 72, 10, 16, BARK)
    leg(p, 54, 72, 10, 16, BARK)
    p.box(32, 36, 32, 38, BARK)
    # Antlers of branches.
    p.poly([(32, 32), (12, 8), (28, 28)], MOSS)
    p.poly([(64, 32), (84, 6), (68, 28)], MOSS)
    p.poly([(40, 24), (36, 6), (48, 22)], MOSS)
    p.disc(48, 28, 12, 11, BARK)
    eye(p, 43, 28, 2, (180, 220, 80), (20, 36, 12))
    eye(p, 54, 28, 2, (180, 220, 80), (20, 36, 12))
    p.box(44, 36, 8, 3, (40, 24, 12))
    finish(p, "grove_elite.png")
    return p.image()


def grove_brute() -> Image.Image:
    p = Pix()
    leg(p, 26, 70, 12, 18, BARK)
    leg(p, 56, 70, 12, 18, BARK)
    p.box(24, 40, 40, 32, MOSS)
    p.disc(36, 28, 14, 12, BARK)
    # Log club.
    p.box(66, 24, 10, 48, BARK)
    p.disc(71, 22, 8, 6, MOSS)
    eye(p, 32, 28, 3, (200, 230, 90), (24, 36, 12))
    eye(p, 44, 28, 3, (200, 230, 90), (24, 36, 12))
    finish(p, "grove_brute.png")
    return p.image()


def grove_tank() -> Image.Image:
    p = Pix()
    leg(p, 48, 72, 8, 14, BARK)
    leg(p, 60, 72, 8, 14, BARK)
    p.box(46, 40, 22, 32, MOSS)
    p.disc(22, 52, 16, 20, BARK)
    p.disc(22, 52, 6, 6, MOSS)
    p.disc(62, 26, 10, 9, BARK)
    eye(p, 58, 26, 2, (190, 220, 80), (20, 32, 10))
    eye(p, 66, 26, 2, (190, 220, 80), (20, 32, 10))
    finish(p, "grove_tank.png")
    return p.image()


def grove_ranged() -> Image.Image:
    """Canopy spitter. A plant with a tube, not a bat."""
    p = Pix()
    p.box(44, 40, 8, 40, MOSS)
    p.disc(48, 36, 16, 12, MOSS)
    p.disc(34, 30, 8, 6, [(80, 140, 40), (140, 180, 60), (180, 210, 80)])
    p.disc(62, 28, 8, 6, [(160, 60, 70), (210, 90, 90), (240, 140, 120)])
    p.box(20, 34, 18, 4, BARK)
    p.disc(16, 36, 4, 3, [(180, 200, 60), (220, 230, 90)])
    eye(p, 44, 34, 2, (220, 240, 140), (20, 40, 10))
    eye(p, 54, 34, 2, (220, 240, 140), (20, 40, 10))
    finish(p, "grove_ranged.png")
    return p.image()


def grove_support() -> Image.Image:
    p = Pix()
    p.poly([(48, 16), (70, 88), (26, 88)], MOSS)
    p.disc(48, 20, 10, 9, BARK)
    p.poly([(36, 16), (28, 4), (42, 16)], MOSS)
    p.poly([(60, 16), (70, 4), (54, 16)], MOSS)
    p.box(68, 28, 4, 46, BARK)
    p.disc(70, 24, 5, 6, [(180, 80, 90), (230, 140, 130)])
    eye(p, 44, 20, 2, (200, 230, 100), (20, 36, 10))
    eye(p, 52, 20, 2, (200, 230, 100), (20, 36, 10))
    finish(p, "grove_support.png")
    return p.image()


def storm_wraith() -> Image.Image:
    p = Pix()
    # Bolt cloak, jagged, not a sheet.
    p.poly([(48, 6), (70, 28), (58, 28), (78, 56), (56, 48), (66, 90), (48, 60), (30, 90), (40, 48), (18, 56), (38, 28), (26, 28)], STORM)
    p.poly([(48, 18), (58, 36), (48, 48), (38, 36)], BOLT)
    eye(p, 43, 34, 2, (255, 255, 220), (40, 30, 80))
    eye(p, 53, 34, 2, (255, 255, 220), (40, 30, 80))
    finish(p, "storm_wraith.png")
    return p.image()


def storm_brute() -> Image.Image:
    """Storm bull. Wide shoulders and a lightning horn, not a stacked oval."""
    p = Pix()
    leg(p, 22, 72, 12, 16, STORM)
    leg(p, 62, 72, 12, 16, STORM)
    p.disc(48, 56, 32, 18, STORM)
    p.poly([(28, 46), (48, 64), (40, 48), (62, 70)], BOLT)
    p.disc(36, 30, 14, 12, STORM)
    p.poly([(24, 26), (8, 8), (30, 28)], BOLT)
    p.poly([(48, 24), (58, 6), (40, 28)], BONE)
    p.disc(8, 52, 8, 7, STORM)
    p.disc(88, 52, 8, 7, STORM)
    eye(p, 30, 30, 3, (255, 240, 140), (40, 24, 60))
    eye(p, 42, 30, 3, (255, 240, 140), (40, 24, 60))
    p.box(30, 38, 12, 3, (20, 12, 28))
    finish(p, "storm_brute.png")
    return p.image()


def storm_tank() -> Image.Image:
    p = Pix()
    leg(p, 48, 72, 8, 14, STORM)
    leg(p, 60, 72, 8, 14, STORM)
    p.box(46, 40, 22, 32, STORM)
    p.box(10, 24, 30, 52, STEEL)
    p.poly([(18, 30), (28, 48), (18, 66)], BOLT)
    p.disc(64, 28, 10, 9, STORM)
    eye(p, 60, 28, 2, (255, 240, 160), (30, 20, 50))
    eye(p, 68, 28, 2, (255, 240, 160), (30, 20, 50))
    finish(p, "storm_tank.png")
    return p.image()


def storm_ranged() -> Image.Image:
    p = Pix()
    leg(p, 40, 70, 6, 16, STORM)
    leg(p, 52, 70, 6, 16, STORM)
    p.box(42, 38, 16, 32, STORM)
    p.disc(48, 24, 9, 8, STORM)
    p.poly([(70, 22), (86, 48), (70, 74)], BOLT)
    p.box(66, 46, 14, 3, BONE)
    eye(p, 45, 24, 2, (255, 250, 180), (30, 20, 60))
    eye(p, 53, 24, 2, (255, 250, 180), (30, 20, 60))
    finish(p, "storm_ranged.png")
    return p.image()


def storm_support() -> Image.Image:
    p = Pix()
    p.poly([(48, 14), (72, 88), (24, 88)], STORM)
    p.disc(48, 20, 10, 9, [(200, 190, 230), (240, 236, 255)])
    p.box(70, 30, 3, 44, BOLT)
    p.disc(72, 26, 5, 5, BOLT)
    eye(p, 44, 20, 2, (255, 250, 200), (40, 30, 70))
    eye(p, 52, 20, 2, (255, 250, 200), (40, 30, 70))
    finish(p, "storm_support.png")
    return p.image()


def rime_wraith() -> Image.Image:
    p = Pix()
    p.poly([(48, 4), (58, 40), (48, 92), (38, 40)], ICE)
    p.poly([(38, 36), (8, 28), (20, 48)], RIME)
    p.poly([(58, 36), (88, 28), (76, 48)], RIME)
    p.box(44, 24, 8, 16, [(20, 36, 52), (40, 60, 80)])
    eye(p, 46, 30, 2, (10, 16, 28), (10, 16, 28))
    eye(p, 52, 30, 2, (10, 16, 28), (10, 16, 28))
    finish(p, "rime_wraith.png")
    return p.image()


def rime_brute() -> Image.Image:
    """Shaggy ice ape. Arms out, white, not the storm bull or the veil cocoon."""
    p = Pix()
    p.box(18, 36, 60, 40, RIME)
    p.disc(30, 28, 12, 11, ICE)
    p.box(8, 40, 14, 28, ICE)
    p.box(74, 40, 14, 28, ICE)
    p.disc(10, 70, 8, 6, RIME)
    p.disc(84, 70, 8, 6, RIME)
    leg(p, 28, 74, 12, 12, RIME)
    leg(p, 56, 74, 12, 12, RIME)
    eye(p, 26, 28, 2, (20, 40, 60), (10, 16, 28))
    eye(p, 36, 28, 2, (20, 40, 60), (10, 16, 28))
    p.box(26, 34, 10, 2, (20, 30, 40))
    finish(p, "rime_brute.png")
    return p.image()


def rime_tank() -> Image.Image:
    p = Pix()
    leg(p, 52, 72, 8, 14, RIME)
    leg(p, 64, 72, 8, 14, RIME)
    p.box(50, 40, 22, 32, ICE)
    p.box(12, 22, 32, 56, RIME)
    p.box(18, 30, 20, 36, ICE)
    p.disc(68, 28, 10, 9, ICE)
    p.box(62, 30, 12, 3, (20, 36, 48))
    finish(p, "rime_tank.png")
    return p.image()


def fen_elite() -> Image.Image:
    p = Pix()
    leg(p, 36, 72, 8, 14, FEN)
    leg(p, 52, 72, 8, 14, FEN)
    p.box(34, 40, 28, 32, FEN)
    # Mushroom cap instead of a slime dome.
    p.disc(48, 28, 20, 10, [(90, 40, 30), (140, 60, 40), (180, 90, 50), (220, 140, 70)])
    p.box(44, 28, 8, 12, FEN)
    p.disc(48, 40, 10, 8, FEN)
    eye(p, 44, 40, 2, (220, 230, 80), (20, 30, 10))
    eye(p, 52, 40, 2, (220, 230, 80), (20, 30, 10))
    finish(p, "fen_elite.png")
    return p.image()


def fen_brute() -> Image.Image:
    """Bog maw. Low crocodile, a tail, not the brass block."""
    p = Pix()
    p.disc(40, 56, 28, 14, FEN)
    p.poly([(64, 52), (90, 46), (88, 58), (64, 60)], FEN)
    p.box(16, 50, 22, 8, FEN)
    p.box(12, 46, 10, 6, [(40, 20, 16), (80, 30, 20)])
    for x in (28, 40, 52):
        leg(p, x, 66, 6, 12, FEN)
    eye(p, 30, 50, 3, (230, 220, 60), (20, 24, 8))
    p.box(18, 54, 8, 2, BONE)
    finish(p, "fen_brute.png")
    return p.image()


def fen_tank() -> Image.Image:
    p = Pix()
    leg(p, 50, 72, 8, 14, FEN)
    leg(p, 62, 72, 8, 14, FEN)
    p.box(48, 42, 22, 30, FEN)
    p.disc(24, 52, 16, 18, [(70, 48, 28), (110, 78, 36), (150, 110, 48)])
    p.disc(24, 48, 8, 4, FEN)
    p.disc(64, 28, 10, 9, FEN)
    eye(p, 60, 28, 2, (220, 230, 80), (20, 28, 8))
    eye(p, 68, 28, 2, (220, 230, 80), (20, 28, 8))
    finish(p, "fen_tank.png")
    return p.image()


def fen_ranged() -> Image.Image:
    p = Pix()
    p.disc(48, 58, 20, 12, FEN)
    leg(p, 30, 66, 8, 14, FEN)
    leg(p, 58, 66, 8, 14, FEN)
    p.disc(36, 40, 12, 10, FEN)
    # Bile sac and a spit tube.
    p.disc(64, 44, 12, 12, [(90, 110, 30), (140, 170, 40), (190, 210, 70)])
    p.box(18, 38, 16, 4, FEN)
    eye(p, 32, 38, 3, (230, 230, 80), (20, 28, 8))
    eye(p, 42, 38, 2, (230, 230, 80), (20, 28, 8))
    finish(p, "fen_ranged.png")
    return p.image()


def boss_fen() -> Image.Image:
    """Fen hydra. Three necks and open maws. The mite stays one slime."""
    p = Pix()
    p.disc(48, 74, 34, 14, FEN)
    for x in range(22, 76, 8):
        p.disc(x, 70, 3, 2, [(20, 40, 16), (40, 70, 24)])
    for cx, top, lean in ((22, 16, -6), (48, 6, 0), (74, 18, 6)):
        p.poly(
            [(cx - 5, top + 22), (cx + 5, top + 22), (cx + 4 + lean, 70), (cx - 4 + lean, 70)],
            FEN,
        )
        p.disc(cx, top + 14, 11, 10, FEN)
        # Open mouth, a dark wedge, so each head is a hydra and not a blob.
        p.poly([(cx - 6, top + 18), (cx + 6, top + 18), (cx, top + 26)], [(30, 16, 12), (50, 20, 14)])
        p.box(cx - 5, top + 17, 2, 2, BONE)
        p.box(cx + 3, top + 17, 2, 2, BONE)
        eye(p, cx - 4, top + 12, 2, (240, 230, 80), (20, 24, 8))
        eye(p, cx + 4, top + 12, 2, (240, 230, 80), (20, 24, 8))
    p.poly([(48, 58), (60, 40), (36, 40)], [(18, 36, 14), (36, 64, 20), (70, 100, 28)])
    finish(p, "boss_fen.png")
    return p.image()


def brass_mite_sprite() -> Image.Image:
    """Cog tick. Round brass with teeth, not a rat."""
    p = Pix()
    p.disc(48, 50, 22, 20, BRASS)
    for ang in range(0, 360, 30):
        rad = math.radians(ang)
        x = 48 + math.cos(rad) * 24
        y = 50 + math.sin(rad) * 22
        p.box(int(x) - 2, int(y) - 3, 5, 7, BRASS)
    p.disc(48, 50, 10, 9, [(40, 24, 12), (80, 40, 16), (200, 80, 30)])
    p.disc(48, 50, 4, 4, [(255, 180, 60), (255, 230, 140)])
    leg(p, 22, 68, 5, 12, BRASS)
    leg(p, 36, 70, 5, 12, BRASS)
    leg(p, 54, 70, 5, 12, BRASS)
    leg(p, 68, 68, 5, 12, BRASS)
    finish(p, "brass_mite.png")
    return p.image()


def brass_elite() -> Image.Image:
    p = Pix()
    leg(p, 36, 70, 8, 16, BRASS)
    leg(p, 52, 70, 8, 16, BRASS)
    p.box(34, 36, 28, 36, BRASS)
    p.disc(28, 40, 10, 10, STEEL)
    p.disc(68, 40, 10, 10, STEEL)
    p.disc(48, 24, 11, 10, BRASS)
    # Key on the back.
    p.box(46, 8, 4, 14, GOLD)
    p.box(42, 8, 12, 4, GOLD)
    eye(p, 44, 24, 2, (255, 220, 120), (40, 20, 8))
    eye(p, 53, 24, 2, (255, 220, 120), (40, 20, 8))
    finish(p, "brass_elite.png")
    return p.image()


def brass_brute() -> Image.Image:
    p = Pix()
    p.box(14, 36, 68, 40, BRASS)
    p.disc(28, 28, 12, 10, STEEL)
    p.disc(68, 28, 12, 10, STEEL)
    p.box(44, 16, 8, 16, GOLD)
    leg(p, 22, 74, 12, 12, BRASS)
    leg(p, 62, 74, 12, 12, BRASS)
    eye(p, 24, 28, 2, (255, 210, 80), (30, 16, 8))
    eye(p, 64, 28, 2, (255, 210, 80), (30, 16, 8))
    finish(p, "brass_brute.png")
    return p.image()


def brass_ranged() -> Image.Image:
    p = Pix()
    leg(p, 40, 70, 6, 16, BRASS)
    leg(p, 52, 70, 6, 16, BRASS)
    p.box(42, 38, 16, 32, BRASS)
    p.disc(48, 24, 9, 8, BRASS)
    # Spring bow.
    p.poly([(68, 18), (86, 48), (68, 78)], STEEL)
    for y in (28, 40, 52, 64):
        p.disc(78, y, 3, 3, GOLD)
    eye(p, 45, 24, 2, (255, 220, 120), (30, 16, 8))
    eye(p, 53, 24, 2, (255, 220, 120), (30, 16, 8))
    finish(p, "brass_ranged.png")
    return p.image()


def brass_glass() -> Image.Image:
    p = Pix()
    p.disc(48, 48, 26, 26, BRASS)
    p.disc(48, 48, 10, 10, [(30, 18, 10), (60, 30, 14)])
    for ang in range(0, 360, 45):
        rad = math.radians(ang)
        x = 48 + math.cos(rad) * 30
        y = 48 + math.sin(rad) * 30
        p.poly([(48, 48), (x, y), (x + 8 * math.sin(rad), y - 8 * math.cos(rad))], STEEL)
    eye(p, 48, 48, 3, (255, 200, 60), (40, 16, 8))
    finish(p, "brass_glass.png")
    return p.image()


def brass_support() -> Image.Image:
    p = Pix()
    p.poly([(48, 18), (70, 88), (26, 88)], BRASS)
    p.disc(48, 22, 12, 8, STEEL)
    # Gear halo.
    p.disc(48, 12, 8, 4, GOLD)
    p.box(66, 36, 4, 40, STEEL)
    p.disc(68, 32, 5, 5, GOLD)
    eye(p, 44, 24, 2, (255, 220, 140), (30, 16, 8))
    eye(p, 52, 24, 2, (255, 220, 140), (30, 16, 8))
    finish(p, "brass_support.png")
    return p.image()


def veil_elite() -> Image.Image:
    p = Pix()
    # Four moth wings.
    p.poly([(48, 40), (8, 16), (16, 48), (40, 44)], VEIL)
    p.poly([(48, 48), (10, 56), (20, 86), (44, 60)], SILK)
    p.poly([(48, 40), (88, 16), (80, 48), (56, 44)], VEIL)
    p.poly([(48, 48), (86, 56), (76, 86), (52, 60)], SILK)
    p.box(44, 28, 8, 40, [(40, 28, 36), (70, 48, 60)])
    p.disc(48, 24, 8, 7, VEIL)
    p.box(40, 12, 16, 4, GOLD)
    eye(p, 45, 24, 2, (40, 20, 30), (20, 10, 16))
    eye(p, 52, 24, 2, (40, 20, 30), (20, 10, 16))
    finish(p, "veil_elite.png")
    return p.image()


def veil_brute() -> Image.Image:
    """Cocoon that is tearing open. Tall, not the storm bull."""
    p = Pix()
    p.disc(48, 50, 18, 32, SILK)
    p.box(40, 22, 16, 52, VEIL)
    # A tear with an arm coming out.
    p.poly([(36, 40), (16, 56), (28, 70)], VEIL)
    p.poly([(60, 44), (82, 36), (70, 64)], VEIL)
    p.disc(48, 24, 10, 9, VEIL)
    eye(p, 44, 24, 2, (255, 220, 180), (40, 16, 28))
    eye(p, 53, 24, 2, (255, 220, 180), (40, 16, 28))
    # Silk threads.
    p.box(30, 16, 1, 20, SILK)
    p.box(66, 14, 1, 22, SILK)
    finish(p, "veil_brute.png")
    return p.image()


def veil_tank() -> Image.Image:
    p = Pix()
    leg(p, 52, 72, 7, 14, VEIL)
    leg(p, 62, 72, 7, 14, VEIL)
    p.box(50, 40, 18, 32, VEIL)
    p.disc(26, 52, 16, 22, SILK)
    p.box(18, 40, 16, 4, GOLD)
    p.disc(66, 26, 9, 8, VEIL)
    eye(p, 62, 26, 2, (255, 220, 190), (40, 16, 24))
    eye(p, 70, 26, 2, (255, 220, 190), (40, 16, 24))
    finish(p, "veil_tank.png")
    return p.image()


def veil_ranged() -> Image.Image:
    p = Pix()
    p.poly([(48, 36), (16, 20), (22, 48)], VEIL)
    p.poly([(48, 36), (80, 20), (74, 48)], VEIL)
    p.box(44, 36, 8, 36, VEIL)
    p.disc(48, 28, 8, 7, SILK)
    p.box(20, 40, 16, 3, GOLD)
    p.disc(16, 42, 3, 3, [(200, 160, 80), (240, 200, 120)])
    eye(p, 45, 28, 2, (40, 16, 24), (20, 8, 12))
    eye(p, 52, 28, 2, (40, 16, 24), (20, 8, 12))
    finish(p, "veil_ranged.png")
    return p.image()


def veil_support() -> Image.Image:
    p = Pix()
    p.poly([(48, 30), (20, 18), (28, 46)], SILK)
    p.poly([(48, 30), (76, 18), (68, 46)], SILK)
    p.poly([(48, 20), (64, 88), (32, 88)], VEIL)
    p.disc(48, 18, 8, 7, VEIL)
    p.box(66, 36, 3, 36, GOLD)
    eye(p, 45, 18, 2, (255, 220, 190), (40, 16, 24))
    eye(p, 52, 18, 2, (255, 220, 190), (40, 16, 24))
    finish(p, "veil_support.png")
    return p.image()


def veil_mite_sprite() -> Image.Image:
    """Dust moth. Wings, not the combat bat."""
    p = Pix()
    p.poly([(48, 44), (12, 24), (20, 52), (44, 48)], VEIL)
    p.poly([(48, 44), (84, 24), (76, 52), (52, 48)], VEIL)
    p.poly([(48, 50), (18, 70), (28, 84), (48, 60)], SILK)
    p.poly([(48, 50), (78, 70), (68, 84), (48, 60)], SILK)
    p.box(45, 36, 6, 28, [(50, 36, 48), (80, 60, 70)])
    eye(p, 46, 34, 2, (40, 16, 24), (16, 8, 12))
    eye(p, 52, 34, 2, (40, 16, 24), (16, 8, 12))
    p.box(47, 22, 2, 10, SILK)
    finish(p, "veil_mite.png")
    return p.image()


def boss_veil() -> Image.Image:
    """Pale monarch. A crowned moth that fills the frame, not a ghost sheet."""
    p = Pix()
    p.poly([(48, 42), (2, 8), (6, 28), (22, 36), (40, 42)], VEIL)
    p.poly([(48, 42), (94, 8), (90, 28), (74, 36), (56, 42)], VEIL)
    p.poly([(48, 52), (4, 52), (8, 78), (24, 88), (44, 62)], SILK)
    p.poly([(48, 52), (92, 52), (88, 78), (72, 88), (52, 62)], SILK)
    # Wing veins and eye-spots. A sheet ghost has neither.
    for x in (16, 28):
        p.box(x, 22, 1, 16, (90, 60, 110))
    for x in (68, 80):
        p.box(x, 22, 1, 16, (90, 60, 110))
    p.disc(20, 30, 6, 5, [(40, 16, 28), (140, 50, 70), (240, 180, 90)])
    p.disc(76, 30, 6, 5, [(40, 16, 28), (140, 50, 70), (240, 180, 90)])
    p.disc(18, 68, 5, 4, [(80, 40, 70), (180, 100, 120)])
    p.disc(78, 68, 5, 4, [(80, 40, 70), (180, 100, 120)])
    p.box(44, 30, 8, 42, [(36, 22, 32), (80, 52, 64), (120, 86, 96)])
    p.box(46, 36, 4, 28, GOLD)
    p.disc(48, 22, 10, 9, VEIL)
    # Antennae and a three-point crown.
    p.box(40, 8, 2, 12, GOLD)
    p.box(54, 8, 2, 12, GOLD)
    p.poly([(34, 16), (40, 6), (46, 16)], GOLD)
    p.poly([(46, 14), (48, 2), (50, 14)], GOLD)
    p.poly([(50, 16), (56, 6), (62, 16)], GOLD)
    eye(p, 44, 22, 2, (20, 8, 14), (10, 4, 8))
    eye(p, 52, 22, 2, (20, 8, 14), (10, 4, 8))
    finish(p, "boss_veil.png")
    return p.image()


def boss_brass() -> Image.Image:
    """The Mainspring. A boiler, a gear, and a cannon. Not the golem's outline."""
    p = Pix()
    # Thin piston legs and anvil feet. A golem's legs are thick columns.
    p.box(26, 68, 7, 16, STEEL)
    p.box(58, 68, 7, 16, STEEL)
    p.box(20, 82, 18, 6, BRASS)
    p.box(52, 82, 18, 6, BRASS)
    p.box(24, 84, 4, 4, (40, 24, 12))
    p.box(64, 84, 4, 4, (40, 24, 12))
    # Rectangular boiler. Shoulders do not round into arms.
    p.box(22, 30, 44, 40, BRASS)
    p.box(28, 36, 32, 28, ASH)
    p.box(38, 42, 12, 16, (40, 22, 14))
    p.box(42, 46, 4, 8, GOLD)
    for y in (34, 48, 62):
        for x in (26, 36, 56, 62):
            p.disc(x, y, 1.5, 1.5, GOLD)
    # Chimney stack, offset, with a lip.
    p.box(26, 8, 12, 24, STEEL)
    p.box(24, 6, 16, 5, BRASS)
    p.box(30, 12, 4, 6, (20, 16, 12))
    # Gear for a head, left of the stack, with teeth. Not a rocky skull.
    p.disc(18, 28, 11, 11, GOLD)
    p.disc(18, 28, 4, 4, ASH)
    for ang in range(0, 360, 45):
        rad = math.radians(ang)
        p.box(int(18 + math.cos(rad) * 12) - 1, int(28 + math.sin(rad) * 12) - 1, 3, 3, STEEL)
    # Cannon barrel sticks out to the right. A golem has a fist here.
    p.box(66, 42, 24, 9, STEEL)
    p.box(66, 44, 24, 2, GOLD)
    p.disc(90, 46, 5, 6, BRASS)
    p.disc(90, 46, 2, 2, [(20, 12, 8), (80, 40, 20)])
    # Gear saw on the left hip, below the head gear.
    p.disc(12, 56, 9, 9, STEEL)
    p.disc(12, 56, 3, 3, GOLD)
    finish(p, "boss_brass.png")
    return p.image()


def boss_rime() -> Image.Image:
    """Rime colossus. A crowned ice spire. No ape arms, no golem legs."""
    p = Pix()
    # Icicle roots for a base, wide and jagged.
    p.poly([(48, 64), (6, 90), (22, 74)], ICE)
    p.poly([(48, 64), (90, 88), (72, 72)], RIME)
    p.poly([(48, 70), (34, 92), (62, 92)], ICE)
    p.poly([(30, 78), (18, 92), (36, 84)], RIME)
    p.poly([(66, 76), (80, 92), (60, 84)], ICE)
    # The spire itself. A triangle, not a torso.
    p.poly([(48, 8), (74, 72), (22, 72)], ICE)
    p.poly([(48, 16), (64, 68), (32, 68)], RIME)
    # Hanging icicles. They point down. They are not elbows.
    p.poly([(24, 36), (4, 68), (20, 46)], ICE)
    p.poly([(72, 32), (92, 62), (76, 42)], RIME)
    p.poly([(18, 48), (8, 78), (22, 54)], RIME)
    # Crown of three shards.
    p.poly([(48, 4), (40, 18), (56, 18)], [(200, 236, 248), (255, 255, 255)])
    p.poly([(30, 18), (22, 4), (38, 20)], ICE)
    p.poly([(66, 18), (76, 2), (58, 20)], ICE)
    # A vertical face crack with a cold light. Not two golem eyes.
    p.box(45, 28, 6, 22, (18, 48, 78))
    p.box(47, 32, 2, 8, (220, 244, 255))
    p.box(36, 40, 1, 22, (16, 40, 64))
    p.box(58, 36, 1, 26, (16, 40, 64))
    finish(p, "boss_rime.png")
    return p.image()


def snake() -> Image.Image:
    p = Pix()
    # Coils.
    p.disc(50, 70, 26, 12, [(40, 90, 36), (60, 130, 48), (90, 160, 64), (140, 190, 90)])
    p.disc(58, 58, 18, 10, [(30, 70, 28), (50, 110, 40), (80, 146, 56)])
    p.disc(40, 50, 14, 8, [(50, 110, 40), (80, 150, 56), (120, 180, 80)])
    # Raised neck and hood.
    p.box(34, 22, 10, 30, [(36, 80, 32), (56, 120, 44), (90, 156, 60)])
    p.poly([(28, 28), (44, 16), (50, 36), (24, 40)], [(40, 100, 40), (70, 140, 56), (120, 176, 80)])
    p.disc(38, 18, 8, 7, [(50, 120, 44), (90, 160, 64), (150, 196, 100)])
    eye(p, 36, 16, 2, (240, 200, 40), (20, 16, 8))
    p.put(34, 22, (220, 60, 50))
    p.put(40, 22, (220, 60, 50))
    # Scale marks.
    for y in (64, 70, 76):
        p.put(40, y, (20, 50, 24))
        p.put(52, y, (20, 50, 24))
        p.put(64, y, (20, 50, 24))
    finish(p, "snake.png")
    return p.image()


def main() -> None:
    painters = [
        sandy_tank,
        sandy_brute,
        sandy_ranged,
        goblin_elite,
        goblin_tank,
        goblin_ranged,
        king_guard,
        king_tank,
        underworld_elite,
        underworld_brute,
        underworld_tank,
        underworld_support,
        dead_swarm,
        dead_support,
        dead_tank,
        hell_elite,
        hell_brute,
        hell_ranged,
        crystal_brute,
        crystal_support,
        crystal_mite_sprite,
        tide_brute,
        ember_elite,
        ember_brute,
        grove_elite,
        grove_brute,
        grove_tank,
        grove_ranged,
        grove_support,
        storm_wraith,
        storm_brute,
        storm_tank,
        storm_ranged,
        storm_support,
        rime_wraith,
        rime_brute,
        rime_tank,
        fen_elite,
        fen_brute,
        fen_tank,
        fen_ranged,
        boss_fen,
        brass_mite_sprite,
        brass_elite,
        brass_brute,
        brass_ranged,
        brass_glass,
        brass_support,
        veil_elite,
        veil_brute,
        veil_tank,
        veil_ranged,
        veil_support,
        veil_mite_sprite,
        boss_veil,
        boss_brass,
        boss_rime,
        snake,
    ]
    for fn in painters:
        fn()
    print(f"pixel enemies: {len(painters)} sprites at 96")


if __name__ == "__main__":
    main()
