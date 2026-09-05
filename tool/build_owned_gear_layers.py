"""Build undertunic + 128×128 overlays from dressed _src (gold master).

Rules (see .cursor/skills/character-paper-doll/SKILL.md):
- Never copy _src onto live body_*.png.
- Never invent helm/cape/chest with ImageDraw shapes.
- Extract armor pixels from _src; mage/healer hat from _src.
- Undertunic follows the _src silhouette (recolor metal → cloth). No capsules.
- Warrior/rogue helm = transparent until _authored exists; oversized authored
  icons are registered onto the head, not stamped as a full-canvas overlay.
- Authored overrides under gear/_authored/ win.
- Weapons may use shared overlays; prefer _authored when present.
"""
from __future__ import annotations

import math
import shutil
from collections import deque
from pathlib import Path

from PIL import Image, ImageEnhance

ROOT = Path(r"d:\Projects\Personal\idle party\Idle-Party\assets\custom\char")
TOOL = Path(r"d:\Projects\Personal\idle party\Idle-Party\tool")
FAMILIES = ("warrior", "healer", "mage", "rogue")
ANIMS = ("idle", "walk", "attack")

TUNIC = {
    "warrior": ((168, 132, 92), (112, 84, 58)),
    "healer": ((236, 228, 210), (214, 200, 178)),
    "mage": ((98, 88, 168), (72, 62, 128)),
    "rogue": ((62, 78, 56), (44, 54, 42)),
}
HAIR = {
    "warrior": (92, 62, 38),
    "healer": (210, 176, 88),
    "mage": (48, 48, 58),
    "rogue": (36, 28, 24),
}


def dist(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def lum(rgb: tuple[int, int, int]) -> float:
    return (0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]) / 255.0


def bbox(im: Image.Image) -> tuple[int, int, int, int]:
    # Ignore near-black crumbs so halo noise doesn't inflate to full 128.
    tight = Image.new("RGBA", im.size, (0, 0, 0, 0))
    sp, tp = im.load(), tight.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = sp[x, y]
            if a > 40 and lum((r, g, b)) >= 0.12:
                tp[x, y] = (r, g, b, a)
    box = tight.getbbox()
    return box if box else (32, 16, 96, 120)


def load128(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    if im.size != (128, 128):
        im = im.resize((128, 128), Image.Resampling.NEAREST)
    return despeckle_alpha(knock_out_backdrop(strip_ink_black(im)))


def load_authored(path: Path) -> Image.Image:
    """Authored overlays win as painted — do not strip ink / despeckle."""
    im = Image.open(path).convert("RGBA")
    if im.size != (128, 128):
        im = im.resize((128, 128), Image.Resampling.NEAREST)
    return im


def knock_out_backdrop(im: Image.Image) -> Image.Image:
    """Turn opaque-black canvas + JPEG dirt into alpha.

    Keep dark outline pixels that already touch real art (eyes, hair, plate).
    """
    out = im.copy()
    px = out.load()
    w, h = out.size

    def touches_art(x: int, y: int) -> bool:
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h):
                    continue
                nr, ng, nb, na = px[nx, ny]
                if na > 40 and lum((nr, ng, nb)) >= 0.14:
                    return True
        return False

    def is_bg(x: int, y: int) -> bool:
        r, g, b, a = px[x, y]
        if a < 10:
            return True
        l = lum((r, g, b))
        sat = max(r, g, b) - min(r, g, b)
        if l < 0.08 and sat < 18 and not touches_art(x, y):
            return True
        return False

    seen = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()
    for x in range(w):
        q.append((x, 0))
        q.append((x, h - 1))
    for y in range(h):
        q.append((0, y))
        q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        if not (0 <= x < w and 0 <= y < h) or seen[y][x]:
            continue
        seen[y][x] = True
        if not is_bg(x, y):
            continue
        px[x, y] = (0, 0, 0, 0)
        q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return peel_dark_fringe(out)


def peel_dark_fringe(im: Image.Image, rounds: int = 2) -> Image.Image:
    """Nibble 1–2px of near-black halo that sits against empty canvas."""
    out = im.copy()
    for _ in range(rounds):
        src = out.copy()
        sp = src.load()
        px = out.load()
        for y in range(128):
            for x in range(128):
                r, g, b, a = sp[x, y]
                if a < 10 or lum((r, g, b)) >= 0.12:
                    continue
                empty = False
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        if dx == 0 and dy == 0:
                            continue
                        nx, ny = x + dx, y + dy
                        if not (0 <= nx < 128 and 0 <= ny < 128):
                            empty = True
                            break
                        if sp[nx, ny][3] < 10:
                            empty = True
                            break
                    if empty:
                        break
                if empty:
                    px[x, y] = (0, 0, 0, 0)
    return out


def despeckle_alpha(im: Image.Image) -> Image.Image:
    """Drop isolated dirt pixels left by JPEG ringing."""
    src = im.copy()
    sp = src.load()
    out = im.copy()
    px = out.load()
    for y in range(1, 127):
        for x in range(1, 127):
            if sp[x, y][3] < 20:
                continue
            n = 0
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    if sp[x + dx, y + dy][3] > 20:
                        n += 1
            if n <= 1:
                px[x, y] = (0, 0, 0, 0)
    return soften_jpeg_specks(out)


def soften_jpeg_specks(im: Image.Image) -> Image.Image:
    """Lift isolated dark crumbs on light cloth (not pupils)."""
    src = im.copy()
    sp = src.load()
    out = im.copy()
    px = out.load()
    for y in range(1, 127):
        for x in range(1, 127):
            r, g, b, a = sp[x, y]
            if a < 40:
                continue
            if lum((r, g, b)) >= 0.22:
                continue
            bright: list[tuple[int, int, int]] = []
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    nr, ng, nb, na = sp[x + dx, y + dy]
                    if na > 40 and lum((nr, ng, nb)) > 0.45:
                        bright.append((nr, ng, nb))
            if len(bright) < 6:
                continue
            bright.sort(key=lum)
            nr, ng, nb = bright[len(bright) // 2]
            px[x, y] = (nr, ng, nb, a)
    return out


def strip_ink_black(im: Image.Image) -> Image.Image:
    """Clear true background halos — keep dark eye/hair outline pixels.

    Near-black next to real art (pupils, brows, hair gaps) must stay.
    Only wipe near-black that is isolated / only touching other near-black.
    """
    src = im.copy()
    sp = src.load()
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = sp[x, y]
            if a == 0 or lum((r, g, b)) >= 0.09:
                continue
            touches_art = False
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < out.width and 0 <= ny < out.height):
                        continue
                    nr, ng, nb, na = sp[nx, ny]
                    if na > 40 and lum((nr, ng, nb)) >= 0.12:
                        touches_art = True
                        break
                if touches_art:
                    break
            if not touches_art:
                px[x, y] = (0, 0, 0, 0)
    return out


def ensure_src(family: str, anim: str) -> Path:
    src_dir = ROOT / family / "_src"
    src_dir.mkdir(parents=True, exist_ok=True)
    src = src_dir / f"body_{anim}.png"
    live = ROOT / family / f"body_{anim}.png"
    if not src.exists() and live.exists():
        src.write_bytes(live.read_bytes())
    if not src.exists():
        raise FileNotFoundError(src)
    return src


def authored_path(family: str | None, set_id: str, anim: str) -> Path | None:
    if family:
        p = ROOT / family / "gear" / "_authored" / f"{set_id}_{anim}.png"
        if p.exists():
            return p
    p = ROOT / "gear" / "_authored" / f"{set_id}_{anim}.png"
    return p if p.exists() else None


def maybe_authored(family: str | None, set_id: str, anim: str, fallback: Image.Image) -> Image.Image:
    p = authored_path(family, set_id, anim)
    if p is None:
        return fallback
    return load_authored(p)


def sample_face(
    im: Image.Image, box: tuple[int, int, int, int], family: str
) -> tuple[int, int, int]:
    px = im.load()
    x0, y0, x1, y1 = box
    cx = (x0 + x1) // 2
    cy = y0 + max(8, int((y1 - y0) * 0.22))
    samples: list[tuple[int, int, int]] = []
    for dy in range(-8, 14):
        for dx in range(-10, 11):
            x, y = cx + dx, cy + dy
            if not (0 <= x < 128 and 0 <= y < 128):
                continue
            r, g, b, a = px[x, y]
            if a < 80:
                continue
            rgb = (r, g, b)
            if is_gold_pixel(rgb) or is_hat_or_hood(family, rgb):
                continue
            if r > 90 and g > 55 and b > 40 and r >= g - 8:
                samples.append(rgb)
    if not samples:
        return (210, 170, 140)
    bright = [s for s in samples if lum(s) > 0.55]
    if bright:
        samples = bright
    samples.sort()
    return samples[len(samples) // 2]


def is_skin(rgb: tuple[int, int, int], face: tuple[int, int, int]) -> bool:
    r, g, b = rgb
    if is_gold_pixel(rgb):
        return False
    if r < 90 or g < 50 or b < 40:
        return False
    if r + 8 < g or r < b:
        return False
    # Skip near-white cloth; keep light peach (warm red–blue gap).
    if r > 210 and g > 190 and b > 150 and (r - b) < 45:
        return False
    if r > 160 and g > 120 and b < 100 and r > b + 40:
        return False
    if abs(r - g) < 12 and abs(g - b) < 12:
        return False
    return dist(rgb, face) < 72


def is_gold_pixel(rgb: tuple[int, int, int]) -> bool:
    r, g, b = rgb
    # Bright armor trim only — peach cheeks (high blue, small g-b) are not gold.
    if r < 180 or g < 140 or b >= 120:
        return False
    if (g - b) < 88:
        return False
    if (r - g) > 70:
        return False
    return r > b + 50


def is_hat_or_hood(family: str, rgb: tuple[int, int, int]) -> bool:
    r, g, b = rgb
    if family == "mage":
        # Warm face is not a hat. Indigo/blue folds + gold brim are.
        if r > 150 and g > 90 and b > 50 and r > b:
            return False
        if is_gold_pixel(rgb):
            return True
        return b > 40 and b >= r - 12
    if family == "healer":
        # Neutral white hood — peach cheeks have a larger red–blue gap.
        if r > 200 and g > 195 and b > 180 and (r - b) < 40:
            return True
        return is_gold_pixel(rgb) or (
            r > 190 and g > 140 and b < 110 and r > b + 50
        )
    return False


def is_metal_or_trim(rgb: tuple[int, int, int]) -> bool:
    r, g, b = rgb
    if is_gold_pixel(rgb):
        return True
    if abs(r - g) < 22 and abs(g - b) < 22 and 0.16 < lum(rgb) < 0.72:
        return True
    return False


def is_hair_color(family: str, rgb: tuple[int, int, int]) -> bool:
    if is_metal_or_trim(rgb) or is_hat_or_hood(family, rgb):
        return False
    r, g, b = rgb
    l = lum(rgb)
    if family == "warrior":
        return r > g >= b - 6 and 35 < r < 170 and g < 120
    if family == "healer":
        return r > 110 and g > 80 and b < 160 and r > b + 8 and l > 0.25
    if family == "mage":
        return l < 0.28 and b <= r + 18 and abs(r - g) < 22
    return l < 0.38 and r >= g - 8 and r >= b - 8


def is_rogue_cloak(rgb: tuple[int, int, int]) -> bool:
    """Green/olive cape cloth on rogue gold masters (wide band)."""
    r, g, b = rgb
    # Broader than before — catch muted olive + darker cape folds.
    return g >= r and g > b - 4 and 18 < g < 140 and r < 105 and b < 100


def thicken_cloak(cloak: Image.Image, passes: int = 2) -> Image.Image:
    """Grow existing cape pixels (no new silhouette invented)."""
    if cloak.getbbox() is None:
        return cloak
    out = cloak.copy()
    for _ in range(passes):
        src = out.copy()
        sp, op = src.load(), out.load()
        for y in range(1, 127):
            for x in range(1, 127):
                if sp[x, y][3] > 40:
                    continue
                # Copy nearest opaque cape neighbor.
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, 1)):
                    r, g, b, a = sp[x + dx, y + dy]
                    if a > 80:
                        op[x, y] = (r, g, b, min(255, a - 20))
                        break
    return out


def alpha_count(im: Image.Image) -> int:
    px = im.load()
    return sum(1 for y in range(128) for x in range(128) if px[x, y][3] > 40)


def recolor_to_cloth(
    rgb: tuple[int, int, int], cloth: tuple[int, int, int], a: int
) -> tuple[int, int, int, int]:
    """Keep gold-master shading; swap armor chroma for undertunic cloth."""
    l = lum(rgb)
    s = max(0.42, min(1.22, 0.38 + l * 1.15))
    return (
        min(255, int(cloth[0] * s)),
        min(255, int(cloth[1] * s)),
        min(255, int(cloth[2] * s)),
        a,
    )


def face_region(
    src: Image.Image,
    face: tuple[int, int, int],
    box: tuple[int, int, int, int],
) -> tuple[float, float, float]:
    px = src.load()
    x0, y0, x1, y1 = box
    cx = (x0 + x1) / 2.0
    y_lim = y0 + int((y1 - y0) * 0.50)
    xs: list[int] = []
    ys: list[int] = []
    for y in range(max(0, y0), min(128, y_lim)):
        for x in range(max(0, x0), min(128, x1)):
            if abs(x - cx) > 18:
                continue
            r, g, b, a = px[x, y]
            if a > 80 and is_skin((r, g, b), face):
                xs.append(x)
                ys.append(y)
    if not xs:
        return cx, y0 + (y1 - y0) * 0.22, 12.0
    return (
        sum(xs) / len(xs),
        sum(ys) / len(ys),
        max(10.0, min(16.0, (max(xs) - min(xs)) / 2.0)),
    )


def _chin_y(
    src: Image.Image,
    face: tuple[int, int, int],
    fx: float,
    fy: float,
    face_half: float,
) -> float:
    px = src.load()
    last_skin_row = int(fy)
    for y in range(int(fy), min(128, int(fy + face_half * 1.55))):
        skin_n = 0
        tot = 0
        gold_n = 0
        for x in range(max(0, int(fx - face_half)), min(128, int(fx + face_half) + 1)):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            tot += 1
            rgb = (r, g, b)
            if is_gold_pixel(rgb):
                gold_n += 1
            if is_skin(rgb, face):
                skin_n += 1
        if tot >= 4 and skin_n / tot >= 0.30:
            last_skin_row = y
        elif tot >= 4 and skin_n == 0 and gold_n == 0 and y > fy + face_half * 0.35:
            break
    return float(last_skin_row + 2)


def paint_undertunic(
    src: Image.Image,
    family: str,
    face: tuple[int, int, int],
    box: tuple[int, int, int, int],
) -> Image.Image:
    """Keep the gold-master silhouette: face/hair/hands + cloth-recolored armor."""
    px = src.load()
    x0, y0, x1, y1 = box
    bh = max(1, y1 - y0)
    fx, fy, face_half = face_region(src, face, box)
    chin_y = _chin_y(src, face, fx, fy, face_half)
    head_max = int(chin_y)
    mid_y = y0 + int(bh * 0.62)
    tunic, pants = TUNIC[family]
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    op = out.load()
    rx = max(11.0, face_half * 1.35)
    ry = max(12.0, face_half * 1.28)

    for y in range(128):
        for x in range(128):
            r, g, b, a = px[x, y]
            if a < 16:
                continue
            rgb = (r, g, b)
            if is_skin(rgb, face):
                op[x, y] = (r, g, b, a)
                continue
            # Hat/hood only in the head band — mage robe / healer vestments stay.
            if y <= head_max + 6 and is_hat_or_hood(family, rgb):
                continue
            # Mage/healer: anything above the eyes that isn't skin/hair is hat.
            if family in ("mage", "healer") and y < fy - 1:
                if not is_hair_color(family, rgb):
                    continue
            if y <= head_max + 4 and is_hair_color(family, rgb):
                op[x, y] = (r, g, b, a)
                continue
            if family == "rogue" and is_rogue_cloak(rgb):
                continue
            in_head = ((x - fx) / rx) ** 2 + ((y - fy) / ry) ** 2 <= 1.0
            if in_head and y <= chin_y + 2 and not is_metal_or_trim(rgb):
                op[x, y] = (r, g, b, a)
                continue
            cloth = tunic if y < mid_y else pants
            op[x, y] = recolor_to_cloth(rgb, cloth, a)

    if family in ("mage", "healer"):
        from PIL import ImageDraw

        has_hair = False
        for y in range(max(0, int(fy - face_half * 2)), int(fy)):
            for x in range(
                max(0, int(fx - face_half * 1.5)), min(128, int(fx + face_half * 1.5))
            ):
                if op[x, y][3] > 40 and is_hair_color(family, op[x, y][:3]):
                    has_hair = True
                    break
            if has_hair:
                break
        if not has_hair:
            d = ImageDraw.Draw(out)
            hx = face_half * 1.12
            d.ellipse(
                [fx - hx, fy - face_half * 1.45, fx + hx, fy - face_half * 0.15],
                fill=(*HAIR[family], 255),
            )
    return out


def goldify(im: Image.Image) -> Image.Image:
    out = im.copy()
    px = out.load()
    for y in range(128):
        for x in range(128):
            r, g, b, a = px[x, y]
            if a < 12:
                continue
            px[x, y] = (
                min(255, int(r * 0.72 + 70)),
                min(255, int(g * 0.62 + 45)),
                min(255, int(b * 0.40 + 12)),
                a,
            )
    return ImageEnhance.Contrast(out).enhance(1.08)


def rarefy_cloak(cloak: Image.Image) -> Image.Image:
    """Rare cape: gold tint + one thicken pass so t2 reads thicker than t0."""
    if cloak.getbbox() is None:
        return cloak
    return goldify(thicken_cloak(cloak, passes=1))


def rarefy_armor(im: Image.Image) -> Image.Image:
    """Rare chest/legs: gold tint + light grow so t2 silhouette beats t0."""
    if im.getbbox() is None:
        return im
    return goldify(thicken_cloak(im, passes=1))


def thicken_cape_to_target(
    cloak: Image.Image, target: int, max_passes: int = 6
) -> Image.Image:
    """Grow existing cape pixels until opaque count reaches target (or cap)."""
    out = cloak
    for _ in range(max_passes):
        if alpha_count(out) >= target:
            break
        out = thicken_cloak(out, passes=1)
    return out


def shift_layer(im: Image.Image, dx: int, dy: int) -> Image.Image:
    """Translate overlay on the 128 canvas (transparent fill)."""
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    out.paste(im, (dx, dy), im)
    return out


def sample_armor_colors(
    src: Image.Image,
    face: tuple[int, int, int],
    box: tuple[int, int, int, int],
) -> tuple[tuple[int, int, int], tuple[int, int, int]]:
    px = src.load()
    x0, y0, x1, y1 = box
    mid = y0 + int((y1 - y0) * 0.50)
    metals: list[tuple[int, int, int]] = []
    golds: list[tuple[int, int, int]] = []
    for y in range(y0 + int((y1 - y0) * 0.32), mid):
        for x in range(x0, x1):
            r, g, b, a = px[x, y]
            if a < 80:
                continue
            rgb = (r, g, b)
            if is_skin(rgb, face):
                continue
            if is_gold_pixel(rgb):
                golds.append(rgb)
            elif 0.12 < lum(rgb) < 0.62:
                metals.append(rgb)
    metals.sort(key=lum)
    golds.sort(key=lum)
    metal = metals[len(metals) // 2] if metals else (78, 86, 96)
    gold = golds[len(golds) // 2] if golds else (196, 158, 64)
    return metal, gold


def extract_bands(
    src: Image.Image,
    face: tuple[int, int, int],
    box: tuple[int, int, int, int],
    family: str,
):
    """Pixel extract from gold master — no invented shapes."""
    px = src.load()
    x0, y0, x1, y1 = box
    bh = y1 - y0
    bw = max(1, x1 - x0)
    fx, fy, face_half = face_region(src, face, box)
    # Chest must start under the jaw — same chin rule as paint_undertunic.
    last_skin_row = int(fy)
    for y in range(int(fy), min(128, int(fy + face_half * 1.55))):
        skin_n = 0
        tot = 0
        gold_n = 0
        for x in range(max(0, int(fx - face_half)), min(128, int(fx + face_half) + 1)):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            tot += 1
            rgb = (r, g, b)
            if is_gold_pixel(rgb):
                gold_n += 1
            if is_skin(rgb, face):
                skin_n += 1
        if tot >= 4 and skin_n / tot >= 0.30:
            last_skin_row = y
        elif tot >= 4 and skin_n == 0 and gold_n == 0 and y > fy + face_half * 0.35:
            break
    head_max = last_skin_row + 2
    mid_y = y0 + int(bh * 0.64)
    cx = (x0 + x1) / 2
    arm_top = head_max + 12

    chest = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    legs = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    cloak = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    hat = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    hands = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    cp, lp, kp, hp, gp = chest.load(), legs.load(), cloak.load(), hat.load(), hands.load()

    for y in range(128):
        for x in range(128):
            r, g, b, a = px[x, y]
            if a < 12:
                continue
            rgb = (r, g, b)
            if is_skin(rgb, face):
                continue
            # Only wipe true black crumbs — dark brown gorget must stay on chest.
            if lum(rgb) < 0.05:
                continue
            if y <= head_max:
                if family in ("mage", "healer") and (
                    is_hat_or_hood(family, rgb) or is_gold_pixel(rgb)
                ):
                    hp[x, y] = (r, g, b, a)
                continue
            dx = abs(x - cx)
            if family == "rogue" and is_rogue_cloak(rgb) and (
                dx > bw * 0.18 or (y > mid_y - 14 and dx > bw * 0.12)
            ):
                kp[x, y] = (r, g, b, a)
                continue
            if dx > bw * 0.20 and arm_top <= y < mid_y + 16:
                gp[x, y] = (r, g, b, a)
                continue
            if y < mid_y:
                cp[x, y] = (r, g, b, a)
            else:
                lp[x, y] = (r, g, b, a)

    return chest, legs, cloak, hat, hands


def punch_face_visor(
    helm: Image.Image,
    src: Image.Image,
    face: tuple[int, int, int],
    box: tuple[int, int, int, int],
) -> None:
    hp = helm.load()
    sp = src.load()
    fx, fy, face_half = face_region(src, face, box)
    for y in range(max(0, int(fy - face_half)), min(128, int(fy + face_half * 1.1))):
        for x in range(max(0, int(fx - face_half * 0.95)), min(128, int(fx + face_half * 0.95))):
            r, g, b, a = sp[x, y]
            if a > 80 and is_skin((r, g, b), face):
                hp[x, y] = (0, 0, 0, 0)


def make_helm(
    family: str,
    fancy: bool,
    hat: Image.Image,
    src: Image.Image,
    face: tuple[int, int, int],
    box: tuple[int, int, int, int],
) -> Image.Image:
    """Helm from gold master only. No invent stamp for warrior/rogue."""
    if family in ("mage", "healer") and hat.getbbox():
        out = goldify(hat) if fancy else hat.copy()
        punch_face_visor(out, src, face, box)
        return out
    # Warrior/rogue _src has no helm — leave transparent until _authored exists.
    return Image.new("RGBA", (128, 128), (0, 0, 0, 0))


def register_helm_to_head(
    helm: Image.Image,
    src: Image.Image,
    face: tuple[int, int, int],
    box: tuple[int, int, int, int],
) -> Image.Image:
    """Authored helm icons that fill the canvas get scaled onto the head."""
    bb = helm.getbbox()
    if bb is None:
        return helm
    hx0, hy0, hx1, hy1 = bb
    hh = hy1 - hy0
    hw = hx1 - hx0
    x0, y0, x1, y1 = box
    bh = max(1, y1 - y0)
    fx, fy, face_half = face_region(src, face, box)
    already_head = hh <= int(bh * 0.55) and hy1 <= int(fy + face_half * 2.8)
    if already_head:
        punch_face_visor(helm, src, face, box)
        return helm
    target_h = int(max(30, min(58, face_half * 3.4)))
    scale = target_h / max(1, hh)
    new_w = max(12, int(hw * scale))
    new_h = max(12, int(hh * scale))
    crop = helm.crop((hx0, hy0, hx1, hy1)).resize(
        (new_w, new_h), Image.Resampling.NEAREST
    )
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    px = int(round(fx - new_w / 2.0))
    py = int(round(fy - face_half * 2.2))
    px = max(0, min(128 - new_w, px))
    py = max(0, min(128 - new_h, py))
    out.paste(crop, (px, py), crop)
    punch_face_visor(out, src, face, box)
    op = out.load()
    for y in range(py, min(128, py + new_h)):
        for x in range(max(0, px), min(128, px + new_w)):
            r, g, b, a = op[x, y]
            if a > 20 and lum((r, g, b)) < 0.06:
                op[x, y] = (0, 0, 0, 0)
    return out


def hand_points(src: Image.Image, face: tuple[int, int, int], box: tuple[int, int, int, int]):
    px = src.load()
    x0, y0, x1, y1 = box
    mid = y0 + int((y1 - y0) * 0.50)
    left, right = [], []
    cx = (x0 + x1) / 2
    for y in range(mid, min(128, y1)):
        for x in range(x0, x1):
            r, g, b, a = px[x, y]
            if a > 80 and is_skin((r, g, b), face):
                (left if x < cx else right).append((x, y))

    def avg(pts, fallback):
        if not pts:
            return fallback
        return int(sum(p[0] for p in pts) / len(pts)), int(
            sum(p[1] for p in pts) / len(pts)
        )

    return avg(left, (int(cx - 22), int(y1 - 16))), avg(
        right, (int(cx + 22), int(y1 - 16))
    )


def ensure_shared_weapons(shared: Path, off: tuple[int, int], main: tuple[int, int], anim: str) -> None:
    """Keep existing shared weapon PNGs unless _authored replaces them.

    Does not invent new ImageDraw weapons each run when files already exist.
    First-time bootstrap still needs files for catalog tests — copy from any
    idle authored set or leave existing.
    """
    from PIL import ImageDraw

    names = (
        "sword_t0",
        "staff_t0",
        "dagger_t0",
        "mace_t0",
        "axe_t0",
        "bow_t0",
        "shield_t0",
        "frill_t0",
    )
    for name in names:
        dest = shared / f"{name}_{anim}.png"
        auth = authored_path(None, name, anim)
        if auth is not None:
            shutil.copyfile(auth, dest)
            continue
        if dest.exists():
            continue
        # Bootstrap only: thick placeholder so catalog paths exist.
        # Skill: replace with authored art — not a finished look.
        x, y = main
        sx, sy = off
        im = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        if name.startswith("sword"):
            d.polygon(
                [(x - 8, y + 10), (x + 2, y + 14), (x + 26, y - 40), (x + 14, y - 46)],
                fill=(198, 206, 218, 255),
            )
        elif name.startswith("shield"):
            d.ellipse([sx - 28, sy - 32, sx + 24, sy + 26], fill=(48, 56, 70, 255))
            d.ellipse([sx - 20, sy - 24, sx + 16, sy + 18], fill=(54, 108, 168, 255))
        elif name.startswith("staff"):
            d.line([(x - 2, y + 18), (x + 14, y - 46)], fill=(132, 86, 46, 255), width=9)
        else:
            d.line([(x, y + 10), (x + 14, y - 28)], fill=(180, 180, 190, 255), width=8)
        im.save(dest)


def process_family(family: str) -> dict:
    out = {}
    gear = ROOT / family / "gear"
    gear.mkdir(parents=True, exist_ok=True)
    (gear / "_authored").mkdir(parents=True, exist_ok=True)
    for anim in ANIMS:
        src = load128(ensure_src(family, anim))
        box = bbox(src)
        face = sample_face(src, box, family)
        body = paint_undertunic(src, family, face, box)
        body.save(ROOT / family / f"body_{anim}.png")

        chest, legs, cloak, hat, hands = extract_bands(src, face, box, family)
        if alpha_count(cloak) < 20:
            cloak = Image.new("RGBA", (128, 128), (0, 0, 0, 0))

        # Resolve cape. Rogue/mage: thicken for LIVE only to a stable target.
        # Never write thickened output into _authored (authored stays hand input).
        if family in ("rogue", "mage"):
            if family == "rogue":
                target = 3300 if anim == "idle" else (2400 if anim == "walk" else 1900)
            else:
                target = 3200 if anim == "idle" else (2600 if anim == "walk" else 2300)
            extract_ok = alpha_count(cloak) >= 20
            base = cloak if extract_ok else Image.new("RGBA", (128, 128), (0, 0, 0, 0))
            auth_p = authored_path(family, "cloak_t0", anim)
            if auth_p is not None:
                authored = load_authored(auth_p)
                ac = alpha_count(authored)
                if ac >= 20:
                    # Prefer authored. Only fall back to extract when authored ran away.
                    if ac > target + 800 and extract_ok:
                        base = cloak
                    else:
                        base = authored
            if alpha_count(base) >= 20:
                cloak0 = (
                    thicken_cape_to_target(base, target=target, max_passes=6)
                    if alpha_count(base) < target
                    else base.copy()
                )
            else:
                cloak0 = base
            # Mage attack extract is empty — authored often matches walk. Sway
            # live attack so the cape moves with the cast/swing pose.
            if family == "mage" and anim == "attack" and alpha_count(cloak0) >= 20:
                cloak0 = shift_layer(cloak0, -3, 2)
        else:
            cloak0 = maybe_authored(family, "cloak_t0", anim, cloak)

        def save_set(set_id: str, im: Image.Image) -> Image.Image:
            final = maybe_authored(family, set_id, anim, im)
            if set_id.startswith("helm_"):
                final = register_helm_to_head(final, src, face, box)
            final.save(gear / f"{set_id}_{anim}.png")
            return final

        # t2 must rarefy the *resolved* t0 (authored wins), not the raw extract.
        chest0 = save_set("chest_t0", chest)
        save_set("chest_t2", rarefy_armor(chest0))
        legs0 = save_set("legs_t0", legs)
        save_set("legs_t2", rarefy_armor(legs0))
        # Cape t0 already resolved/thickened above — write live only.
        cloak0.save(gear / f"cloak_t0_{anim}.png")
        cloak2 = rarefy_cloak(cloak0) if cloak0.getbbox() else cloak0
        auth_t2 = authored_path(family, "cloak_t2", anim)
        if auth_t2 is not None:
            loaded_t2 = load_authored(auth_t2)
            if alpha_count(loaded_t2) > alpha_count(cloak2) + 80:
                cloak2 = loaded_t2
        cloak2.save(gear / f"cloak_t2_{anim}.png")
        save_set("helm_t0", make_helm(family, False, hat, src, face, box))
        save_set("helm_t2", make_helm(family, True, hat, src, face, box))
        hands0 = save_set("hands_t0", hands)
        save_set("hands_t2", rarefy_armor(hands0) if hands0.getbbox() else hands0)

        out[anim] = (box, face, src, body, chest0, legs0, cloak0, hands0, hat)
        print(
            "ok",
            family,
            anim,
            "cloak_px",
            alpha_count(cloak0),
            "hat_px",
            alpha_count(hat),
        )
    return out


def write_armor_preview(family: str, frames: dict) -> None:
    """Armor stack vs gold master. Skip authored helm on facit preview (bare head)."""
    _box, _face, _src, body, chest, legs, cloak, hands, _hat = frames["idle"]
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    layers = [cloak, body, legs, chest, hands]
    auth_helm = ROOT / family / "gear" / "_authored" / "helm_t0_idle.png"
    if family in ("mage", "healer") or not auth_helm.exists():
        layers.append(
            Image.open(ROOT / family / "gear" / "helm_t0_idle.png").convert("RGBA")
        )
    for layer in layers:
        out = Image.alpha_composite(out, layer)
    out.save(TOOL / f"preview_doll_{family}.png")
    if family == "warrior":
        helm = Image.open(ROOT / family / "gear" / "helm_t0_idle.png").convert("RGBA")
        cape = Image.open(ROOT / family / "gear" / "cloak_t0_idle.png").convert("RGBA")
        sword = Image.open(ROOT / "gear" / "sword_t0_idle.png").convert("RGBA")
        shield = Image.open(ROOT / "gear" / "shield_t0_idle.png").convert("RGBA")
        kit = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        for layer in (cape, body, legs, chest, hands, helm, shield, sword):
            kit = Image.alpha_composite(kit, layer)
        kit.save(TOOL / "preview_doll_warrior_full.png")


def main() -> None:
    shared = ROOT / "gear"
    shared.mkdir(parents=True, exist_ok=True)
    (shared / "_authored").mkdir(parents=True, exist_ok=True)
    built = {}
    for family in FAMILIES:
        built[family] = process_family(family)
    for anim in ANIMS:
        box, face, src, *_ = built["warrior"][anim]
        off, main = hand_points(src, face, box)
        ensure_shared_weapons(shared, off, main, anim)
    for family in FAMILIES:
        write_armor_preview(family, built[family])
    # Slot icons = bbox crop of idle overlays (same art as the doll).
    import subprocess
    import sys

    subprocess.check_call(
        [sys.executable, str(TOOL / "make_gear_slot_icons.py")],
    )
    print("done — inspect tool/preview_doll_*.png then run check_paper_doll_facit.py")


if __name__ == "__main__":
    main()
