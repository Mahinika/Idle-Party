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

from PIL import Image, ImageDraw

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



# --- Organic pass -------------------------------------------------------
# sandy_tank, king_tank, hell_brute, storm_brute, boss_brass, boss_rime.
# Overlapping anatomy, a 6-tone ramp per material, light from the upper
# left, contact shadow, and a 1px silhouette. Not stacked primitives.

CHITIN = [
    (90, 51, 19),
    (117, 70, 25),
    (141, 89, 33),
    (176, 119, 38),
    (208, 152, 48),
    (230, 183, 75),
    (248, 220, 140),
]
LIMB = [
    (69, 27, 17),
    (102, 58, 22),
    (138, 86, 28),
    (164, 107, 35),
    (196, 137, 42),
    (218, 165, 56),
    (238, 195, 87),
]
HORN = [
    (62, 40, 22),
    (98, 68, 36),
    (132, 96, 52),
    (168, 128, 74),
    (198, 160, 104),
    (226, 196, 142),
]
ORG_STEEL = [
    (20, 26, 40),
    (34, 46, 66),
    (54, 72, 98),
    (80, 102, 128),
    (112, 134, 156),
    (148, 168, 186),
    (188, 204, 216),
]
ORG_NAVY = [
    (16, 22, 44),
    (28, 36, 68),
    (42, 56, 96),
    (64, 82, 128),
    (96, 116, 158),
    (140, 158, 190),
]
ORG_GOLD = [
    (92, 64, 18),
    (140, 96, 28),
    (186, 138, 36),
    (220, 176, 58),
    (244, 210, 102),
    (255, 236, 170),
]
PLUME = [
    (92, 18, 24),
    (140, 28, 32),
    (176, 42, 44),
    (208, 64, 58),
    (232, 110, 96),
    (248, 170, 150),
]
CAPE = [
    (18, 16, 36),
    (32, 28, 58),
    (48, 42, 82),
    (70, 60, 108),
    (98, 86, 138),
    (140, 124, 170),
]
ORG_BRASS = [
    (78, 48, 16),
    (116, 72, 22),
    (156, 102, 30),
    (190, 136, 42),
    (214, 168, 64),
    (236, 198, 102),
    (252, 226, 156),
]
IRON = [
    (28, 24, 22),
    (52, 44, 38),
    (78, 66, 56),
    (108, 92, 78),
    (142, 122, 104),
    (176, 156, 136),
]
HIDE = [
    (72, 24, 18),
    (112, 36, 24),
    (148, 52, 32),
    (176, 74, 44),
    (204, 104, 64),
    (228, 142, 96),
    (246, 184, 140),
]
BELLY = [
    (96, 36, 28),
    (140, 56, 40),
    (172, 82, 56),
    (198, 112, 78),
    (220, 146, 108),
    (238, 180, 146),
]
ORG_BONE = [
    (48, 32, 26),
    (86, 64, 50),
    (124, 98, 76),
    (162, 134, 108),
    (196, 170, 142),
    (226, 206, 180),
]
ORG_STORM = [
    (22, 30, 48),
    (40, 54, 78),
    (62, 82, 112),
    (92, 114, 144),
    (132, 152, 176),
    (176, 194, 210),
    (214, 226, 234),
]
MANE = [
    (36, 48, 78),
    (58, 74, 112),
    (86, 108, 148),
    (124, 146, 182),
    (168, 186, 210),
    (214, 224, 236),
]
ORG_ICE = [
    (14, 40, 56),
    (26, 74, 98),
    (48, 118, 140),
    (86, 160, 176),
    (140, 198, 208),
    (196, 228, 232),
    (236, 248, 250),
]
DEEP = [
    (8, 22, 34),
    (14, 40, 56),
    (22, 64, 84),
    (36, 96, 116),
    (58, 128, 146),
    (92, 160, 174),
]
FROST = [
    (36, 86, 108),
    (72, 132, 152),
    (120, 176, 192),
    (170, 210, 220),
    (214, 234, 240),
    (246, 252, 255),
]
INK_SAND = (42, 16, 12)
INK_STEEL = (12, 14, 24)
INK_BRASS = (36, 20, 8)
INK_HELL = (28, 8, 8)
INK_STORM = (10, 14, 28)
INK_ICE = (8, 24, 36)
PATINA = (58, 108, 76)
SHADE = (18, 10, 8)


def clamp(v, a, b):
    return a if v < a else b if v > b else v


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def hsh(x, y, s=0):
    n = (int(x) * 374761393 + int(y) * 668265263 + s * 1442695041) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 255) / 255.0


def oval(cx, cy, rx, ry, n=18, rot=0.0, scallop=0.0, tooth=0.0):
    """Closed outline. Scallop pulls every other point in. Tooth pushes every third out."""
    c, s = math.cos(rot), math.sin(rot)
    pts = []
    for i in range(n):
        a = -math.pi / 2 + i * math.tau / n
        pull = 1.0
        if scallop and i % 2 == 0:
            pull -= scallop
        if tooth and i % 2 == 0:
            pull += tooth
        x = math.cos(a) * rx * pull
        y = math.sin(a) * ry * pull
        pts.append((cx + x * c - y * s, cy + x * s + y * c))
    return pts


def heater(cx, cy, rx, ry):
    """Shield: curved shoulders, long point. Not a rectangle."""
    return [
        (cx, cy - ry),
        (cx + rx * 0.72, cy - ry * 0.72),
        (cx + rx, cy - ry * 0.28),
        (cx + rx * 0.92, cy + ry * 0.18),
        (cx + rx * 0.55, cy + ry * 0.58),
        (cx + rx * 0.16, cy + ry * 0.86),
        (cx, cy + ry),
        (cx - rx * 0.16, cy + ry * 0.86),
        (cx - rx * 0.55, cy + ry * 0.58),
        (cx - rx * 0.92, cy + ry * 0.18),
        (cx - rx, cy - ry * 0.28),
        (cx - rx * 0.72, cy - ry * 0.72),
    ]


def torso(cx, cy, rx, ry):
    """Shoulders wider than the waist, hips rounding back out."""
    return [
        (cx - rx * 0.15, cy - ry),
        (cx + rx * 0.35, cy - ry * 0.92),
        (cx + rx, cy - ry * 0.55),
        (cx + rx * 0.78, cy - ry * 0.05),
        (cx + rx * 0.55, cy + ry * 0.35),
        (cx + rx * 0.72, cy + ry * 0.78),
        (cx + rx * 0.2, cy + ry),
        (cx - rx * 0.35, cy + ry * 0.9),
        (cx - rx * 0.7, cy + ry * 0.4),
        (cx - rx * 0.62, cy - ry * 0.05),
        (cx - rx * 0.85, cy - ry * 0.5),
        (cx - rx * 0.4, cy - ry * 0.9),
    ]


def scarab(cx, cy, rx, ry):
    """Wide elytra: flatter belly line, scalloped shoulders, a crown ridge."""
    return [
        (cx, cy - ry),
        (cx + rx * 0.28, cy - ry * 0.96),
        (cx + rx * 0.55, cy - ry * 0.78),
        (cx + rx * 0.82, cy - ry * 0.48),
        (cx + rx, cy - ry * 0.12),
        (cx + rx * 0.9, cy + ry * 0.22),
        (cx + rx * 0.62, cy + ry * 0.55),
        (cx + rx * 0.28, cy + ry * 0.78),
        (cx, cy + ry * 0.7),
        (cx - rx * 0.28, cy + ry * 0.78),
        (cx - rx * 0.62, cy + ry * 0.55),
        (cx - rx * 0.9, cy + ry * 0.22),
        (cx - rx, cy - ry * 0.12),
        (cx - rx * 0.82, cy - ry * 0.48),
        (cx - rx * 0.55, cy - ry * 0.78),
        (cx - rx * 0.28, cy - ry * 0.96),
    ]


def snout_head(cx, cy, rx, ry, face=1):
    """Skull with a brow shelf and a muzzle. face=1 pushes the muzzle down (toward the camera)."""
    return [
        (cx - rx * 0.2, cy - ry),
        (cx + rx * 0.45, cy - ry * 0.85),
        (cx + rx * 0.95, cy - ry * 0.35),
        (cx + rx, cy + ry * 0.05),
        (cx + rx * 0.7, cy + ry * 0.4),
        (cx + rx * 0.35, cy + ry * 0.72),
        (cx + rx * 0.1 * face, cy + ry),
        (cx - rx * 0.25, cy + ry * 0.78),
        (cx - rx * 0.7, cy + ry * 0.4),
        (cx - rx, cy + ry * 0.05),
        (cx - rx * 0.85, cy - ry * 0.4),
        (cx - rx * 0.4, cy - ry * 0.88),
    ]


class Form:
    def __init__(self):
        n = S * S
        self.a = [0] * n
        self.z = [0.0] * n
        self.pri = [-1] * n
        self.mat = [0] * n
        self.mode = [0] * n  # 0 dome, 1 tube, 2 facet
        self.nx = [0.0] * n
        self.ny = [0.0] * n
        self.nz = [1.0] * n
        self.edge = [0.0] * n
        self.along = [0.0] * n
        self.cx = [0.0] * n
        self.cy = [0.0] * n
        self.kind = [""] * n
        self.seams = [0] * n
        self.pid = [0] * n
        self._seq = 1

    def _i(self, x, y):
        return y * S + x

    def _put(self, x, y, h, mat, pri, mode, nx, ny, nz, edge, along, cx, cy, kind, seams, pid):
        if not (0 <= x < S and 0 <= y < S):
            return
        i = self._i(x, y)
        if pri > self.pri[i] or (pri == self.pri[i] and h >= self.z[i]):
            self.a[i] = 1
            self.z[i] = h
            self.pri[i] = pri
            self.mat[i] = mat
            self.mode[i] = mode
            self.nx[i] = nx
            self.ny[i] = ny
            self.nz[i] = nz
            self.edge[i] = edge
            self.along[i] = along
            self.cx[i] = cx
            self.cy[i] = cy
            self.kind[i] = kind
            self.seams[i] = 1 if seams else 0
            self.pid[i] = pid

    def blob(self, pts, mat, pri, height=1.0, mode="dome", kind="plain", seams=False, normal=None, bevel=7.0):
        mask = Image.new("L", (S, S), 0)
        ImageDraw.Draw(mask).polygon([(int(round(x)), int(round(y))) for x, y in pts], fill=255)
        pix = mask.load()
        dist = [[0.0] * S for _ in range(S)]
        for y in range(S):
            for x in range(S):
                dist[y][x] = 0.0 if not pix[x, y] else 99.0
        for y in range(S):
            for x in range(S):
                d = dist[y][x]
                if x:
                    d = min(d, dist[y][x - 1] + 1)
                if y:
                    d = min(d, dist[y - 1][x] + 1)
                if x and y:
                    d = min(d, dist[y - 1][x - 1] + 1.4)
                dist[y][x] = d
        for y in range(S - 1, -1, -1):
            for x in range(S - 1, -1, -1):
                d = dist[y][x]
                if x < S - 1:
                    d = min(d, dist[y][x + 1] + 1)
                if y < S - 1:
                    d = min(d, dist[y + 1][x] + 1)
                if x < S - 1 and y < S - 1:
                    d = min(d, dist[y + 1][x + 1] + 1.4)
                dist[y][x] = d
        cx = sum(p[0] for p in pts) / len(pts)
        cy = sum(p[1] for p in pts) / len(pts)
        self._seq += 1
        pid = self._seq
        mode_i = {"dome": 0, "tube": 1, "facet": 2}[mode]
        fnx, fny, fnz = normal if normal else (0.0, -0.75, 0.55)
        if normal:
            L = math.hypot(fnx, fny, fnz) or 1
            fnx, fny, fnz = fnx / L, fny / L, fnz / L
        for y in range(S):
            for x in range(S):
                if not pix[x, y]:
                    continue
                d = dist[y][x]
                if mode == "dome":
                    h = height * (1.0 - math.exp(-d / bevel))
                    self._put(x, y, h, mat, pri, 0, 0, 0, 1, d, 0, cx, cy, kind, seams, pid)
                else:
                    h = height * min(1.0, d / 3.2)
                    self._put(x, y, h, mat, pri, mode_i, fnx, fny, fnz, d, 0, cx, cy, kind, seams, pid)

    def limb(self, pts, r0, r1, mat, pri, height=0.9, mode="tube", kind="plain", seams=False):
        samples = []
        total = 0.0
        spans = []
        for i in range(len(pts) - 1):
            ax, ay = pts[i]
            bx, by = pts[i + 1]
            d = math.hypot(bx - ax, by - ay)
            spans.append((ax, ay, bx, by, total, d))
            total += d
        if total < 0.5:
            return
        steps = max(2, int(total * 2))
        for s in range(steps + 1):
            dist = total * s / steps
            for ax, ay, bx, by, acc, d in spans:
                if dist <= acc + d or spans[-1][4] == acc:
                    t = 0 if d == 0 else (dist - acc) / d
                    t = clamp(t, 0, 1)
                    x = ax + (bx - ax) * t
                    y = ay + (by - ay) * t
                    tx, ty = (bx - ax) / d if d else 1, (by - ay) / d if d else 0
                    samples.append((x, y, dist / total, tx, ty))
                    break
        xs = [p[0] for p in samples]
        ys = [p[1] for p in samples]
        pad = int(max(r0, r1) + 3)
        x0 = max(0, int(min(xs)) - pad)
        x1 = min(S, int(max(xs)) + pad + 1)
        y0 = max(0, int(min(ys)) - pad)
        y1 = min(S, int(max(ys)) + pad + 1)
        mode_i = 2 if mode == "facet" else 1
        self._seq += 1
        pid = self._seq
        cx = sum(xs) / len(xs)
        cy = sum(ys) / len(ys)
        for y in range(y0, y1):
            for x in range(x0, x1):
                best = 1e9
                pick = samples[0]
                for smp in samples:
                    dd = (x + 0.5 - smp[0]) ** 2 + (y + 0.5 - smp[1]) ** 2
                    if dd < best:
                        best = dd
                        pick = smp
                dist = math.sqrt(best)
                along, tx, ty = pick[2], pick[3], pick[4]
                rad = r0 + (r1 - r0) * along
                if rad < 0.4 or dist > rad:
                    continue
                vx = (x + 0.5 - pick[0]) / dist if dist > 0.15 else -ty
                vy = (y + 0.5 - pick[1]) / dist if dist > 0.15 else tx
                edge = rad - dist
                if mode == "facet":
                    px, py = -ty, tx
                    if vx * px + vy * py < 0:
                        px, py = -px, -py
                    nz = 0.85 if edge < 1.5 else 0.28
                    h = height * (0.45 + 0.55 * min(1.0, edge / 2.2))
                    self._put(x, y, h, mat, pri, mode_i, px, py, nz, edge, along, cx, cy, kind, seams, pid)
                else:
                    nz = math.sqrt(max(0.05, 1.0 - (dist / rad) ** 2))
                    h = height * nz
                    self._put(x, y, h, mat, pri, mode_i, vx, vy, nz, edge, along, cx, cy, kind, seams, pid)

    def bake(self, ramps, ink, highlight):
        light = (-0.48, -0.72, 0.50)
        ll = math.sqrt(sum(c * c for c in light))
        light = tuple(c / ll for c in light)
        img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        px = img.load()
        tone_at = [-1] * (S * S)
        for y in range(S):
            for x in range(S):
                i = self._i(x, y)
                if not self.a[i]:
                    continue
                if self.mode[i] == 0:
                    def zz(xx, yy, i=i):
                        if 0 <= xx < S and 0 <= yy < S and self.a[yy * S + xx] and self.pid[yy * S + xx] == self.pid[i]:
                            return self.z[yy * S + xx]
                        return self.z[i]
                    dzdx = (zz(x + 1, y) - zz(x - 1, y)) * 0.5
                    dzdy = (zz(x, y + 1) - zz(x, y - 1)) * 0.5
                    nx, ny, nz = -dzdx * 11.0, -dzdy * 11.0, 0.72
                else:
                    nx, ny, nz = self.nx[i], self.ny[i], self.nz[i]
                L = math.sqrt(nx * nx + ny * ny + nz * nz) or 1
                nx, ny, nz = nx / L, ny / L, nz / L
                nd = nx * light[0] + ny * light[1] + nz * light[2]
                nd = clamp(nd, 0.0, 1.0)
                # A facet that faces the lamp must not flood the whole face white.
                if self.mode[i] == 2:
                    nd = 0.16 + 0.46 * nd
                # Contact shadow from a part sitting up-light of this pixel.
                ao = 0.0
                my = self.pid[i]
                for ox, oy, w in ((-1, -1, 0.9), (-2, -1, 0.7), (-1, -2, 0.7), (-2, -2, 0.55), (-3, -2, 0.4), (-2, -3, 0.4), (-3, -3, 0.28)):
                    xx, yy = x + ox, y + oy
                    if not (0 <= xx < S and 0 <= yy < S):
                        continue
                    j = self._i(xx, yy)
                    if self.a[j] and self.pid[j] != my and self.z[j] > self.z[i] - 0.02:
                        ao = max(ao, w)
                edge = self.edge[i]
                # Bevel on facets: bright lip on the lit side, dark lip on the shadow side.
                if self.mode[i] == 2 and edge < 2.0:
                    up = self.edge[self._i(x - 1, y)] if x else 0
                    left = self.edge[self._i(x, y - 1)] if y else 0
                    if (x and self.a[self._i(x - 1, y)] and up > edge) or (y and self.a[self._i(x, y - 1)] and left > edge):
                        nd = min(1.0, nd + 0.38)
                    if x < S - 1 and self.a[self._i(x + 1, y)] and self.edge[self._i(x + 1, y)] > edge:
                        nd *= 0.62
                kind = self.kind[i]
                ramp = ramps[self.mat[i]]
                if kind == "shield":
                    ramp = ORG_STEEL if edge < 2.6 else ORG_NAVY
                steps = len(ramp) - 1
                ti = int(nd * steps + 0.5)
                # Material texture. Seams follow the form, not the screen.
                if self.seams[i] and kind == "chitin" and edge > 2.2 and int(edge) % 5 == 3:
                    ti -= 2
                if kind == "chitin" and abs(x - self.cx[i]) <= 0.6 and edge > 3 and self.seams[i]:
                    ti -= 1
                if kind == "chitin" and self.seams[i] and edge > 4 and hsh(x, y, 11) > 0.94:
                    ti -= 1
                if kind == "horn" and int(self.along[i] * 16) % 4 == 0 and edge < 2.4:
                    ti -= 1
                if kind == "hide" and hsh(x // 2, y // 2, 3) > 0.84:
                    ti -= 1
                if kind == "hide" and edge > 3 and abs(math.sin((y - self.cy[i]) * 0.55 + x * 0.04)) < 0.13 and hsh(x, y, 5) > 0.55:
                    ti -= 1
                if kind == "brass" and self.seams[i] and edge > 2.5 and abs((edge * 0.55) % 1 - 0.5) < 0.06:
                    ti -= 1
                if kind == "ice" and abs(math.sin(math.atan2(y - self.cy[i], x - self.cx[i]) * 3.0 + self.pid[i])) < 0.10 and edge > 1.4:
                    ti -= 1
                if kind == "steel" and self.seams[i] and abs((edge * 0.7) % 1 - 0.5) < 0.05 and edge > 2:
                    ti -= 1
                if kind == "cloth" and int((x * 0.15 + y) / 4) % 3 == 0 and hsh(x, y, 8) > 0.6:
                    ti -= 1
                if kind == "mane" and int(self.along[i] * 8 + x) % 3 == 0:
                    ti += 1
                # Specular cluster only where the surface faces the lamp.
                if self.mode[i] != 2 and nd > 0.91 and kind not in ("cloth", "shield") and ramp[-1][0] > 90:
                    ti = steps
                ti = int(clamp(ti, 0, steps))
                col = ramp[ti]
                ao_q = 0.0 if ao < 0.22 else (0.42 if ao < 0.55 else 0.7)
                if ao_q:
                    col = mix(col, mix(ramp[0], SHADE, 0.55), ao_q)
                if kind == "brass" and y > self.cy[i] + 3 and edge < 5 and hsh(x // 3, y // 3, 9) > 0.78:
                    col = mix(col, PATINA, 0.55)
                if kind == "ice" and nd > 0.75 and edge > 3 and hsh(x, y, 4) > 0.72:
                    col = mix(col, (255, 255, 255), 0.35)
                if kind == "ice" and edge > 2 and hsh(x, y, 6) > 0.9:
                    col = mix(col, (8, 28, 42), 0.5)
                tone_at[i] = ti
                px[x, y] = (*col, 255)
        # Inner rim, just inside the top-left contour.
        rim = highlight
        for y in range(1, S - 1):
            for x in range(1, S - 1):
                i = self._i(x, y)
                if not self.a[i]:
                    continue
                if px[x, y][3] == 0:
                    continue
                edge_l = self.a[i] and (not self.a[self._i(x - 1, y)] or not self.a[self._i(x, y - 1)])
                if edge_l:
                    continue
                near = (not self.a[self._i(x - 2, y)] or not self.a[self._i(x - 1, y - 1)] or not self.a[self._i(x, y - 2)])
                if near and (not self.a[self._i(x - 1, y)] or not self.a[self._i(x, y - 1)] or not self.a[self._i(x - 1, y - 1)]):
                    px[x, y] = (*mix(px[x, y][:3], rim, 0.62), 255)
        # 1px silhouette ink. Lit corner stays a breath lighter so the rim reads.
        for y in range(S):
            for x in range(S):
                i = self._i(x, y)
                if not self.a[i]:
                    continue
                transparent = 0
                up_left = 0
                for ox, oy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    xx, yy = x + ox, y + oy
                    if not (0 <= xx < S and 0 <= yy < S) or not self.a[self._i(xx, yy)]:
                        transparent += 1
                        if ox < 0 or oy < 0:
                            up_left += 1
                if transparent:
                    if up_left and transparent == 1:
                        px[x, y] = (*mix(ink, highlight, 0.28), 255)
                    else:
                        px[x, y] = (*ink, 255)
        return img


def put_if(im, x, y, c):
    if 0 <= x < S and 0 <= y < S:
        p = im.getpixel((x, y))
        if p[3] > 0:
            im.putpixel((x, y), (*c, 255))


def paint_eye(im, x, y, iris, pupil, socket, glint=(255, 252, 236), r=3):
    for dy in range(-r - 1, r + 2):
        for dx in range(-r - 1, r + 2):
            if dx * dx + dy * dy <= (r + 1) * (r + 1):
                put_if(im, x + dx, y + dy, socket)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r:
                put_if(im, x + dx, y + dy, iris)
    put_if(im, x + 1, y, pupil)
    put_if(im, x + 1, y + 1, pupil)
    put_if(im, x, y + 1, pupil)
    put_if(im, x - 1, y - 1, glint)
    if r >= 3:
        put_if(im, x - 2, y - 1, glint)


def rivet(im, x, y, hi, lo):
    put_if(im, x, y, hi)
    put_if(im, x - 1, y - 1, hi)
    put_if(im, x + 1, y + 1, lo)


def glint(im, x, y, c):
    for dx, dy in ((0, 0), (1, 0), (0, 1), (2, 0), (1, -1)):
        put_if(im, x + dx, y + dy, c)


def stroke(im, pts, col, side):
    def plot(x0, y0, x1, y1):
        dx, dy = abs(x1 - x0), abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx - dy
        x, y = x0, y0
        while True:
            put_if(im, x, y, col)
            put_if(im, x + 1, y + 1, side)
            if x == x1 and y == y1:
                break
            e2 = 2 * err
            if e2 > -dy:
                err -= dy
                x += sx
            if e2 < dx:
                err += dx
                y += sy

    for i in range(len(pts) - 1):
        plot(int(pts[i][0]), int(pts[i][1]), int(pts[i + 1][0]), int(pts[i + 1][1]))


def save_organic(im, name):
    im.save(ROOT / name)
    cols = len({p[:3] for p in im.getdata() if p[3] > 20})
    xs, ys = [], []
    pix = im.load()
    for y in range(S):
        for x in range(S):
            if pix[x, y][3] > 20:
                xs.append(x)
                ys.append(y)
    print(f"{name:20} colors {cols:4}  bbox {min(xs):2},{min(ys):2} {max(xs):2},{max(ys):2}")


def sandy_tank():
    f = Form()
    # Legs first, tucked under the shell. Joints are their own bulges.
    legs = [
        ([(30, 50), (16, 40), (8, 24)], 4.4, 1.3),
        ([(33, 56), (14, 60), (6, 74)], 4.6, 1.4),
        ([(38, 62), (22, 74), (18, 90)], 4.8, 1.6),
    ]
    for pts, r0, r1 in legs:
        f.limb(pts, r0, r1, 1, 1, height=0.85, kind="chitin")
        f.blob(oval(pts[1][0], pts[1][1], r0 * 0.85, r0 * 0.7, n=10, scallop=0.12), 1, 2, height=0.8, kind="chitin")
        mx = [(96 - x, y) for x, y in pts]
        f.limb(mx, r0, r1, 1, 1, height=0.85, kind="chitin")
        f.blob(oval(mx[1][0], mx[1][1], r0 * 0.85, r0 * 0.7, n=10, scallop=0.12), 1, 2, height=0.8, kind="chitin")
        # Hooked claw.
        tip = pts[-1]
        f.limb([tip, (tip[0] - 3, tip[1] + 3)], 1.7, 0.5, 2, 3, kind="horn")
        f.limb([(96 - tip[0], tip[1]), (96 - tip[0] + 3, tip[1] + 3)], 1.7, 0.5, 2, 3, kind="horn")
    # Belly shadow under the shell, between the legs.
    f.blob(oval(48, 66, 16, 9, n=12, scallop=0.1), 1, 2, height=0.55, kind="chitin")
    # Elytra. Scalloped, with a raised keel.
    f.blob(scarab(48, 40, 32, 24), 0, 4, height=1.05, kind="chitin", seams=True, bevel=8.5)
    # Each scute is its own dome, so the shell reads as plates rather than one egg.
    for cx, cy, rx, ry in (
        (30, 30, 9, 5.5),
        (48, 28, 7, 6),
        (66, 30, 9, 5.5),
        (26, 42, 10, 5.5),
        (48, 40, 8, 5),
        (70, 42, 10, 5.5),
        (34, 52, 9, 4.5),
        (58, 52, 9, 4.5),
    ):
        f.blob(oval(cx, cy, rx, ry, n=10, scallop=0.1), 0, 5, height=0.72, kind="chitin", bevel=3.2)
    f.blob(oval(48, 36, 5, 16, n=12, scallop=0.06), 0, 6, height=1.2, kind="chitin", seams=True, bevel=4)
    # Head tucked under the front lip, mandibles in front of it.
    f.blob(snout_head(48, 64, 13, 10), 0, 6, height=0.95, kind="chitin", bevel=5.5)
    f.limb([(40, 70), (32, 80), (26, 90)], 3.6, 1.0, 2, 7, kind="horn")
    f.limb([(56, 70), (64, 80), (70, 90)], 3.6, 1.0, 2, 7, kind="horn")
    f.limb([(44, 72), (42, 80)], 1.8, 0.6, 2, 8, kind="horn")
    f.limb([(52, 72), (54, 80)], 1.8, 0.6, 2, 8, kind="horn")
    # Antennae.
    f.limb([(38, 58), (26, 46), (18, 32), (14, 22)], 1.6, 0.55, 2, 7, kind="horn")
    f.limb([(58, 58), (70, 46), (78, 32), (82, 22)], 1.6, 0.55, 2, 7, kind="horn")
    im = f.bake({0: CHITIN, 1: LIMB, 2: HORN}, INK_SAND, (255, 236, 190))
    paint_eye(im, 41, 62, (255, 186, 48), (48, 16, 8), (42, 18, 10), r=3)
    paint_eye(im, 55, 62, (255, 186, 48), (48, 16, 8), (42, 18, 10), r=3)
    # Brow and a mouth between the mandibles.
    for dx in range(-4, 5):
        put_if(im, 48 + dx, 57, (62, 32, 14))
    put_if(im, 46, 68, (36, 14, 8))
    put_if(im, 47, 69, (36, 14, 8))
    put_if(im, 48, 69, (36, 14, 8))
    put_if(im, 49, 69, (36, 14, 8))
    put_if(im, 50, 68, (36, 14, 8))
    put_if(im, 47, 71, (230, 200, 140))
    put_if(im, 49, 71, (230, 200, 140))
    glint(im, 30, 26, (255, 236, 196))
    glint(im, 34, 34, (248, 214, 130))
    for x, y in ((28, 28), (38, 26), (60, 27), (24, 40), (68, 39), (34, 48), (62, 47), (44, 24)):
        put_if(im, x, y, (90, 51, 19))
        put_if(im, x + 1, y + 1, (117, 70, 25))
    save_organic(im, "sandy_tank.png")
    return im


def king_tank():
    f = Form()
    # Cape behind the body, one side longer.
    cape = oval(52, 60, 20, 26, n=16, rot=0.15, scallop=0.16)
    f.blob(cape, 5, 0, height=0.7, kind="cloth", bevel=6)
    f.limb([(58, 74), (68, 84), (60, 92)], 8, 2.4, 5, 0, kind="cloth")
    # Legs and sabatons.
    f.limb([(44, 64), (40, 76), (38, 86)], 5.2, 3.4, 0, 1, kind="steel")
    f.limb([(60, 64), (64, 76), (66, 86)], 5.0, 3.2, 0, 1, kind="steel")
    f.blob(oval(38, 87, 6.5, 3.0, n=10), 0, 2, height=0.6, kind="steel")
    f.blob(oval(66, 87, 6.2, 2.8, n=10), 0, 2, height=0.6, kind="steel")
    f.blob(oval(41, 78, 4.2, 3.4, n=10, scallop=0.1), 0, 2, height=0.75, kind="steel")
    f.blob(oval(63, 78, 4.0, 3.2, n=10, scallop=0.1), 0, 2, height=0.75, kind="steel")
    # Torso, pauldrons, helm.
    f.blob(torso(52, 52, 15, 18), 0, 3, height=1.0, kind="steel", seams=True, bevel=6.5)
    f.blob(oval(34, 42, 9, 6.5, n=12, rot=-0.5, scallop=0.14), 0, 4, height=1.05, kind="steel")
    f.blob(oval(68, 40, 8, 6, n=12, rot=0.4, scallop=0.14), 0, 4, height=1.0, kind="steel")
    f.blob(oval(52, 28, 12, 13, n=14, scallop=0.06), 0, 5, height=1.15, kind="steel", bevel=5.5)
    # Crest.
    f.limb([(52, 18), (60, 8), (70, 12), (74, 18)], 2.6, 0.8, 4, 6, kind="plain")
    # Sword arm on the right, partly behind the shield's opposite side.
    f.limb([(64, 48), (76, 58), (82, 70)], 4.6, 2.6, 0, 4, kind="steel")
    f.blob(oval(82, 72, 4.2, 4.6, n=10, scallop=0.12), 0, 5, height=0.8, kind="steel")
    f.limb([(78, 36), (86, 22), (88, 14)], 1.5, 0.7, 0, 3, kind="steel")
    f.blob(oval(78, 36, 5, 1.6, n=8, rot=0.4), 3, 4, height=0.5, kind="plain")
    # Shield in front. Heater, gold boss, overlaps the torso.
    f.blob(heater(24, 54, 15, 24), 0, 7, height=0.85, mode="facet", kind="shield", seams=False, normal=(-0.2, -0.25, 0.95))
    f.limb([(52, 62), (40, 64)], 1.7, 1.4, 3, 4, kind="plain")
    f.blob(oval(24, 50, 5.2, 5.2, n=12), 3, 8, height=1.1, kind="plain")
    f.limb([(24, 40), (24, 62)], 1.5, 1.5, 3, 8, kind="plain")
    # Visor slit. Dark, then the eyes punch through it.
    f.blob(oval(52, 30, 8, 3.2, n=10), 6, 8, height=0.3, mode="facet", kind="plain", normal=(0, 0, 1))
    im = f.bake(
        {0: ORG_STEEL, 3: ORG_GOLD, 4: PLUME, 5: CAPE, 6: [(8, 10, 16), (14, 16, 26), (20, 24, 36)]},
        INK_STEEL,
        (236, 242, 248),
    )
    paint_eye(im, 48, 30, (255, 196, 64), (40, 18, 8), (8, 10, 16), r=2)
    paint_eye(im, 56, 30, (255, 196, 64), (40, 18, 8), (8, 10, 16), r=2)
    for x, y in ((16, 40), (32, 38), (14, 64), (30, 66), (24, 78)):
        rivet(im, x, y, (244, 214, 120), (40, 28, 16))
    for x, y in ((46, 44), (58, 46), (52, 60)):
        rivet(im, x, y, (244, 214, 120), (20, 24, 36))
    glint(im, 42, 20, (240, 246, 252))
    glint(im, 14, 40, (220, 230, 240))
    save_organic(im, "king_tank.png")
    return im


def boss_brass():
    """A boiler on wheels. Gear teeth, a short stack, a level cannon. No legs."""
    f = Form()
    # Gear center sits inside the boiler, so only the teeth show on the left.
    f.blob(oval(22, 54, 12, 12, n=16, tooth=0.26), 0, 1, height=0.8, kind="brass", seams=True, bevel=4)
    f.blob(oval(22, 54, 3.4, 3.4, n=8), 1, 2, height=0.3, mode="facet", kind="plain", normal=(0, 0, 1))
    # The boiler covers the gear's right half.
    f.blob(oval(52, 50, 20, 16, n=16, scallop=0.06), 0, 3, height=1.15, kind="brass", seams=True, bevel=8)
    f.blob(oval(52, 60, 15, 9, n=12, scallop=0.05), 0, 3, height=1.0, kind="brass", seams=True, bevel=5)
    # Face on the front of the pot, below the stack.
    f.blob(oval(46, 42, 9, 8, n=12, scallop=0.08), 0, 5, height=1.0, kind="brass", bevel=4.5)
    # Short stack rising from the top of the boiler, behind the face. A cap, not a fist.
    f.limb([(58, 32), (58, 22), (58, 16)], 5.0, 4.2, 0, 4, kind="brass", seams=True)
    f.blob(oval(58, 15, 8, 3.4, n=12), 0, 5, height=0.45, kind="brass")
    f.blob(oval(58, 14, 3.0, 1.6, n=8), 1, 6, height=0.2, mode="facet", kind="plain", normal=(0, -0.15, 0.5))
    # Level cannon out of the belly.
    f.limb([(66, 58), (78, 58), (86, 59)], 5.4, 4.4, 0, 5, kind="brass")
    f.blob(oval(76, 58, 6.4, 6.4, n=12), 0, 6, height=0.55, kind="brass")
    f.blob(oval(86, 59, 5.2, 5.2, n=12), 0, 6, height=0.5, kind="brass")
    f.blob(oval(89, 59, 2.6, 2.6, n=8), 1, 7, height=0.2, mode="facet", kind="plain", normal=(0.5, 0.05, 0.35))
    # Axle and two spoked wheels. Not a pair of legs.
    f.limb([(32, 74), (68, 74)], 2.4, 2.4, 1, 4, kind="plain")
    for wx in (32, 68):
        f.blob(oval(wx, 82, 8, 8, n=14), 1, 4, height=0.55, kind="plain", bevel=3)
        f.blob(oval(wx, 82, 3.2, 3.2, n=8), 0, 5, height=0.7, kind="brass")
        f.limb([(wx, 75), (wx, 89)], 1.15, 1.15, 0, 6, kind="brass")
        f.limb([(wx - 6, 82), (wx + 6, 82)], 1.15, 1.15, 0, 6, kind="brass")
    # Valve on the belly.
    f.blob(oval(52, 52, 3.4, 3.4, n=10), 1, 6, height=0.45, kind="plain")
    f.limb([(48, 52), (56, 52)], 1.0, 1.0, 0, 7, kind="brass")
    f.limb([(52, 48), (52, 56)], 1.0, 1.0, 0, 7, kind="brass")
    im = f.bake({0: ORG_BRASS, 1: IRON}, INK_BRASS, (255, 236, 180))
    paint_eye(im, 46, 42, (120, 220, 210), (16, 40, 42), (48, 28, 12), glint=(230, 255, 250), r=3)
    for a in range(0, 360, 40):
        rad = math.radians(a)
        rivet(im, int(52 + math.cos(rad) * 13), int(52 + math.sin(rad) * 11), (255, 228, 160), (60, 32, 12))
    for x, y in ((74, 58), (82, 58), (56, 20)):
        rivet(im, x, y, (255, 228, 160), (60, 32, 12))
    glint(im, 40, 36, (255, 232, 170))
    glint(im, 52, 18, (255, 236, 190))
    save_organic(im, "boss_brass.png")
    return im


def boss_rime():
    """A frost beast with a real head. Three back-spires, not a spike ball."""
    f = Form()
    # Body has volume. A deeper belly, one crystal plate on the haunch.
    f.blob(oval(62, 64, 22, 13, n=14, scallop=0.08), 0, 1, height=1.05, kind="ice", bevel=7)
    f.blob(oval(60, 72, 13, 6, n=10), 1, 2, height=0.7, kind="ice", bevel=4)
    f.blob(oval(46, 58, 8, 6, n=10), 0, 4, height=0.8, kind="ice", bevel=4)
    f.blob(oval(76, 56, 9, 7, n=8, rot=0.45, scallop=0.1), 2, 2, mode="facet", kind="ice", normal=(0.45, -0.45, 0.6), height=0.9)
    # Large head in front of the thicket, so the face wins any overlap.
    f.blob(snout_head(32, 50, 15, 13), 0, 5, height=1.15, kind="ice", bevel=6)
    f.blob(oval(16, 54, 8, 5.5, n=10, rot=0.15, scallop=0.08), 0, 6, height=0.85, kind="ice")
    f.blob(oval(28, 40, 9, 4.2, n=8), 0, 6, height=0.75, kind="ice")
    # Three spires, different heights, growing from the back.
    f.limb([(56, 52), (52, 30), (46, 14)], 5.2, 1.0, 2, 3, mode="facet", kind="ice")
    f.limb([(68, 54), (78, 32), (86, 16)], 4.6, 1.1, 2, 3, mode="facet", kind="ice")
    f.limb([(62, 48), (66, 28), (72, 16)], 3.2, 0.7, 2, 4, mode="facet", kind="ice")
    # Legs and a short tail.
    f.limb([(44, 70), (38, 80), (36, 88)], 4.2, 2.1, 0, 3, kind="ice")
    f.limb([(58, 72), (60, 82), (62, 88)], 4.0, 2.0, 0, 3, kind="ice")
    f.limb([(74, 70), (82, 80), (86, 88)], 3.6, 1.7, 0, 3, kind="ice")
    f.blob(oval(35, 89, 4.2, 2.0, n=8), 0, 4, height=0.4, kind="ice")
    f.blob(oval(62, 89, 4.0, 2.0, n=8), 0, 4, height=0.4, kind="ice")
    f.blob(oval(87, 89, 3.6, 1.8, n=8), 0, 4, height=0.35, kind="ice")
    f.limb([(80, 62), (88, 58), (90, 50)], 2.8, 0.7, 2, 3, mode="facet", kind="ice")
    # Two jaw icicles, different lengths.
    f.limb([(18, 60), (14, 72), (12, 82)], 2.1, 0.4, 2, 7, mode="facet", kind="ice")
    f.limb([(24, 62), (22, 74), (22, 80)], 1.7, 0.35, 2, 7, mode="facet", kind="ice")
    im = f.bake({0: ORG_ICE, 1: DEEP, 2: FROST}, INK_ICE, (240, 252, 255))
    paint_eye(im, 26, 48, (186, 236, 255), (16, 44, 64), (8, 24, 36), glint=(255, 255, 255), r=3)
    paint_eye(im, 36, 46, (186, 236, 255), (16, 44, 64), (8, 24, 36), glint=(255, 255, 255), r=2)
    for dx in range(-4, 5):
        put_if(im, 30 + dx, 42, (10, 32, 48))
    put_if(im, 12, 54, (8, 24, 36))
    put_if(im, 14, 55, (8, 24, 36))
    put_if(im, 13, 57, (220, 240, 248))
    glint(im, 22, 38, (255, 255, 255))
    glint(im, 50, 20, (230, 248, 255))
    save_organic(im, "boss_rime.png")
    return im


def hell_brute():
    f = Form()
    # Tail, behind.
    f.limb([(64, 64), (80, 56), (90, 66), (84, 80)], 4.2, 1.6, 0, 0, kind="hide")
    f.blob(oval(82, 82, 5.5, 4.2, n=8, scallop=0.2, rot=0.4), 0, 1, height=0.6, kind="hide")
    # Legs and hooves.
    f.limb([(38, 66), (32, 78), (30, 90)], 6.4, 3.6, 0, 1, kind="hide")
    f.limb([(58, 68), (66, 80), (70, 90)], 6.0, 3.4, 0, 1, kind="hide")
    f.blob(oval(28, 91, 6.5, 3.0, n=8), 2, 2, height=0.45, kind="horn")
    f.blob(oval(72, 91, 6.2, 2.8, n=8), 2, 2, height=0.45, kind="horn")
    # Belly, chest, shoulders. Overlapping masses, not one circle.
    f.blob(oval(48, 60, 18, 13, n=14, scallop=0.1), 1, 2, height=1.05, kind="hide", bevel=6)
    f.blob(torso(46, 46, 16, 14), 0, 3, height=1.15, kind="hide", bevel=6.5)
    f.blob(oval(28, 40, 10, 8, n=12, rot=-0.4, scallop=0.16), 0, 4, height=1.05, kind="hide")
    f.blob(oval(66, 42, 9, 7.5, n=12, rot=0.35, scallop=0.16), 0, 4, height=1.0, kind="hide")
    # Arms into clawed hands. The hand is smaller than the forearm.
    f.limb([(26, 48), (14, 58), (10, 70)], 6.0, 3.4, 0, 4, kind="hide")
    f.blob(oval(10, 74, 5, 4.5, n=10, scallop=0.15), 0, 5, height=0.8, kind="hide")
    f.limb([(8, 76), (6, 82), (6, 88)], 1.8, 0.45, 2, 6, kind="horn")
    f.limb([(12, 78), (12, 86), (14, 90)], 1.8, 0.45, 2, 6, kind="horn")
    f.limb([(14, 74), (18, 82)], 1.6, 0.4, 2, 6, kind="horn")
    f.limb([(68, 50), (80, 58), (86, 68)], 5.4, 3.2, 0, 4, kind="hide")
    f.blob(oval(88, 72, 4.6, 4.2, n=10, scallop=0.15), 0, 5, height=0.75, kind="hide")
    f.limb([(90, 74), (92, 80)], 1.6, 0.4, 2, 6, kind="horn")
    f.limb([(86, 76), (84, 84), (82, 90)], 1.6, 0.4, 2, 6, kind="horn")
    # Head, brow, muzzle. Horns are uneven: one tall, one broken.
    f.blob(snout_head(48, 30, 13, 12), 0, 6, height=1.15, kind="hide", bevel=5.5)
    f.blob(oval(48, 22, 10, 4.5, n=10, rot=0.05), 0, 7, height=0.85, kind="hide")
    f.blob(oval(48, 36, 8, 5.5, n=10, scallop=0.12), 0, 7, height=0.8, kind="hide")
    f.limb([(38, 20), (26, 10), (18, 8)], 3.6, 0.9, 2, 8, kind="horn")
    f.limb([(58, 20), (70, 12), (78, 16)], 3.2, 1.3, 2, 8, kind="horn")
    # A short spine ridge.
    f.limb([(48, 40), (46, 28), (44, 18)], 2.2, 0.6, 2, 5, kind="horn")
    im = f.bake({0: HIDE, 1: BELLY, 2: ORG_BONE}, INK_HELL, (255, 214, 170))
    paint_eye(im, 42, 28, (255, 150, 30), (40, 8, 4), (28, 8, 8), r=2)
    paint_eye(im, 54, 28, (255, 150, 30), (40, 8, 4), (28, 8, 8), r=2)
    for dx in range(-5, 6):
        put_if(im, 48 + dx, 23, (48, 14, 10))
    for x, y in ((45, 38), (46, 39), (47, 39), (48, 40), (49, 39), (50, 39), (51, 38)):
        put_if(im, x, y, (24, 6, 6))
    put_if(im, 46, 41, (230, 210, 170))
    put_if(im, 50, 41, (230, 210, 170))
    glint(im, 34, 36, (255, 200, 150))
    save_organic(im, "hell_brute.png")
    return im


def storm_brute():
    f = Form()
    # Mane tufts behind the skull, each its own lock.
    for cx, cy, rx, ry, rot in (
        (30, 34, 8, 11, -0.4),
        (64, 32, 8, 12, 0.5),
        (46, 22, 11, 8, 0.1),
        (22, 44, 6, 8, -0.6),
        (70, 44, 6, 8, 0.7),
    ):
        f.blob(oval(cx, cy, rx, ry, n=10, rot=rot, scallop=0.22), 2, 1, height=0.75, kind="mane")
    # Body under the head. A bull's head is the mass.
    f.blob(oval(48, 70, 18, 11, n=12, scallop=0.1), 0, 1, height=0.9, kind="hide", bevel=6)
    f.blob(oval(48, 60, 16, 7, n=10, scallop=0.08), 0, 2, height=1.0, kind="hide")
    f.limb([(34, 70), (30, 80), (28, 88)], 5.4, 3.0, 0, 2, kind="hide")
    f.limb([(62, 70), (66, 80), (68, 88)], 5.4, 3.0, 0, 2, kind="hide")
    f.blob(oval(26, 89, 5.5, 2.4, n=8), 1, 3, height=0.4, kind="horn")
    f.blob(oval(70, 89, 5.5, 2.4, n=8), 1, 3, height=0.4, kind="horn")
    # Chest and shoulders so the torso is not one oval under the skull.
    f.blob(oval(36, 62, 8, 6, n=10, rot=-0.3, scallop=0.14), 0, 3, height=0.95, kind="hide")
    f.blob(oval(60, 62, 8, 6, n=10, rot=0.3, scallop=0.14), 0, 3, height=0.95, kind="hide")
    # Skull, brow, muzzle.
    f.blob(snout_head(48, 42, 16, 13), 0, 4, height=1.2, kind="hide", bevel=6)
    f.blob(oval(48, 32, 12, 5, n=10), 0, 5, height=0.9, kind="hide")
    f.blob(oval(48, 52, 10, 6.5, n=12, scallop=0.1), 0, 5, height=0.85, kind="hide")
    # Ears.
    f.blob(oval(24, 38, 5, 3.5, n=8, rot=-0.6), 0, 4, height=0.6, kind="hide")
    f.blob(oval(72, 36, 5, 3.5, n=8, rot=0.6), 0, 4, height=0.6, kind="hide")
    # Horns sweep out, then hook. The wide span is the silhouette.
    f.limb([(32, 30), (16, 18), (6, 26)], 4.2, 1.2, 1, 6, kind="horn")
    f.limb([(64, 30), (80, 14), (92, 20)], 4.4, 1.1, 1, 6, kind="horn")
    # Beard tuft.
    f.limb([(48, 58), (48, 66), (46, 72)], 2.4, 0.8, 2, 5, kind="mane")
    im = f.bake({0: ORG_STORM, 1: ORG_BONE, 2: MANE}, INK_STORM, (230, 240, 255))
    paint_eye(im, 40, 40, (255, 230, 70), (30, 20, 8), (10, 14, 28), r=2)
    paint_eye(im, 56, 40, (255, 230, 70), (30, 20, 8), (10, 14, 28), r=2)
    for dx in range(-6, 7):
        put_if(im, 48 + dx, 34, (12, 16, 32))
    put_if(im, 44, 52, (8, 10, 20))
    put_if(im, 45, 53, (8, 10, 20))
    put_if(im, 52, 52, (8, 10, 20))
    put_if(im, 53, 53, (8, 10, 20))
    stroke(
        im,
        [(30, 62), (36, 54), (33, 50), (42, 44), (38, 40), (46, 36)],
        (255, 236, 120),
        (70, 50, 16),
    )
    glint(im, 34, 30, (230, 240, 255))
    save_organic(im, "storm_brute.png")
    return im


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
