"""Build undertunic + 128×128 overlays from dressed _src (gold master).

Rules (see .cursor/skills/character-paper-doll/SKILL.md):
- Never copy _src onto live body_*.png.
- Never invent helm/cape/chest with ImageDraw shapes.
- Extract armor pixels from _src; mage/healer hat from _src.
- Warrior/rogue helm = hair mask stamped with metal sampled from same _src.
- Authored overrides under gear/_authored/ win.
- Weapons may use shared overlays; prefer _authored when present.
"""
from __future__ import annotations

import math
import shutil
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
    return strip_ink_black(im)


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
    return load128(p)


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
    if r > 210 and g > 190 and b > 150:
        return False
    if r > 160 and g > 120 and b < 100 and r > b + 40:
        return False
    if abs(r - g) < 12 and abs(g - b) < 12:
        return False
    return dist(rgb, face) < 72


def is_gold_pixel(rgb: tuple[int, int, int]) -> bool:
    r, g, b = rgb
    # Bright armor trim only — warm jaw/cheek browns are not gold.
    if r < 180 or g < 140 or b >= 140:
        return False
    if (g - b) < 78:
        return False
    if (r - g) > 70:
        return False
    return r > b + 40


def is_hat_or_hood(family: str, rgb: tuple[int, int, int]) -> bool:
    r, g, b = rgb
    if family == "mage":
        return b > r + 12 and b > 70
    if family == "healer":
        return (r > 185 and g > 175 and b > 140) or (
            r > 175 and g > 130 and b < 100 and r > b + 40
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
    r, g, b = rgb
    return g > r + 6 and g > b and 25 < g < 120 and r < 90


def alpha_count(im: Image.Image) -> int:
    px = im.load()
    return sum(1 for y in range(128) for x in range(128) if px[x, y][3] > 40)


def shade_cloth(
    cloth: tuple[int, int, int], x: float, y: float, cx: float, y0: float, y1: float
) -> tuple[int, int, int, int]:
    t = (y - y0) / max(1.0, y1 - y0)
    dx = abs(x - cx) / 36.0
    s = max(0.55, min(1.18, 1.06 - t * 0.22 - dx * 0.14))
    return (
        min(255, int(cloth[0] * s)),
        min(255, int(cloth[1] * s)),
        min(255, int(cloth[2] * s)),
        255,
    )


def erode(mask: list[list[bool]], n: int) -> list[list[bool]]:
    out = [row[:] for row in mask]
    for _ in range(n):
        nxt = [row[:] for row in out]
        for y in range(1, 127):
            for x in range(1, 127):
                if not out[y][x]:
                    continue
                if not (
                    out[y - 1][x]
                    and out[y + 1][x]
                    and out[y][x - 1]
                    and out[y][x + 1]
                ):
                    nxt[y][x] = False
        out = nxt
    return out


def dilate(mask: list[list[bool]], n: int) -> list[list[bool]]:
    out = [row[:] for row in mask]
    for _ in range(n):
        nxt = [row[:] for row in out]
        for y in range(1, 127):
            for x in range(1, 127):
                if out[y][x]:
                    continue
                if (
                    out[y - 1][x]
                    or out[y + 1][x]
                    or out[y][x - 1]
                    or out[y][x + 1]
                ):
                    nxt[y][x] = True
        out = nxt
    return out


def slim_spans(mask: list[list[bool]], ratio: float) -> list[list[bool]]:
    out = [[False] * 128 for _ in range(128)]
    for y in range(128):
        x = 0
        while x < 128:
            while x < 128 and not mask[y][x]:
                x += 1
            if x >= 128:
                break
            start = x
            while x < 128 and mask[y][x]:
                x += 1
            end = x - 1
            width = end - start + 1
            keep = max(7, int(width * ratio))
            inset = max(0, (width - keep) // 2)
            for xx in range(start + inset, end - inset + 1):
                out[y][xx] = True
    return out


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


def body_occupancy(
    src: Image.Image,
    family: str,
    box: tuple[int, int, int, int],
) -> list[list[bool]]:
    """Solid undertunic silhouette (capsule torso + arms + legs).

    Do not derive cloth from eroded armor panels — that makes brown shreds.
    """
    x0, y0, x1, y1 = box
    bh = max(1, y1 - y0)
    bw = max(1, x1 - x0)
    cx = (x0 + x1) / 2.0
    face = sample_face(src, box, family)
    fx, fy, face_half = face_region(src, face, box)
    chin = int(fy + face_half * 0.95)
    mid_y = y0 + int(bh * 0.62)
    foot_y = y1 - 6
    # Widths in px — warrior a bit broader.
    torso_r = bw * (0.22 if family == "warrior" else 0.20)
    hip_r = bw * 0.18
    arm_r = max(5.0, bw * 0.09)
    leg_r = max(6.0, bw * 0.11)
    arm_top = chin + int(bh * 0.06)
    arm_bot = mid_y + 4
    split = [[False] * 128 for _ in range(128)]
    for y in range(chin, min(128, foot_y + 1)):
        t = (y - chin) / max(1.0, foot_y - chin)
        if y < mid_y:
            # Torso capsule (slightly tapers)
            tw = torso_r * (1.05 - t * 0.25)
            for x in range(128):
                if abs(x - cx) <= tw:
                    split[y][x] = True
            # Arms
            if arm_top <= y <= arm_bot:
                at = (y - arm_top) / max(1.0, arm_bot - arm_top)
                reach = bw * (0.34 + 0.06 * at)
                for side in (-1.0, 1.0):
                    ax = cx + side * reach
                    for x in range(128):
                        if abs(x - ax) <= arm_r:
                            split[y][x] = True
        else:
            # Two legs — leave crotch gap
            gap = max(2.0, bw * 0.04)
            lw = leg_r * (1.0 - (y - mid_y) / max(1.0, foot_y - mid_y) * 0.15)
            for side in (-1.0, 1.0):
                lx = cx + side * (hip_r * 0.55 + gap)
                for x in range(128):
                    if abs(x - lx) <= lw:
                        split[y][x] = True
    return split


def paint_undertunic(
    src: Image.Image,
    family: str,
    face: tuple[int, int, int],
    box: tuple[int, int, int, int],
) -> Image.Image:
    """Cloth occupancy + clean face/hair/hands from _src — never armor luminance."""
    px = src.load()
    x0, y0, x1, y1 = box
    bh = max(1, y1 - y0)
    fx, fy, face_half = face_region(src, face, box)
    head_max = int(fy + face_half * 1.05)
    mid_y = y0 + int(bh * 0.62)
    foot_y = y1 - 14
    cx = (x0 + x1) / 2.0
    tunic, pants = TUNIC[family]
    mask = body_occupancy(src, family, box)
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    op = out.load()

    # Head first: stamp from gold master. Warm skin must NOT go through
    # is_gold_pixel — peach cheeks match that helper and used to vanish.
    # Chin: last mostly-skin row, then keep jaw shade (often <30% skin / gold-adjacent).
    chin_y = fy + face_half * 0.55
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
            chin_y = float(y)
        elif tot >= 4 and skin_n == 0 and gold_n == 0 and y > fy + face_half * 0.35:
            break
    # Jaw shade + lip sit 1–2 rows under the last cheek row (was cut off → tan gap).
    chin_y = float(last_skin_row + 2)
    hair_top = max(0, int(fy - face_half * 2.45))
    head_x0 = max(0, int(fx - face_half * 2.15))
    head_x1 = min(128, int(fx + face_half * 2.15))
    rx = max(11.0, face_half * 1.28)
    ry = max(12.0, face_half * 1.22)
    for y in range(hair_top, min(128, int(chin_y) + 3)):
        for x in range(head_x0, head_x1):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            rgb = (r, g, b)
            if is_hat_or_hood(family, rgb):
                continue
            in_oval = ((x - fx) / rx) ** 2 + ((y - fy) / ry) ** 2 <= 1.0
            # Face oval: always stamp from _src (jaw browns ≠ armor gold).
            if in_oval and y <= chin_y:
                op[x, y] = (r, g, b, a)
                continue
            if y > chin_y:
                if is_skin(rgb, face):
                    op[x, y] = (r, g, b, a)
                continue
            # Hair beside the oval — skip plate/gold pauldrons only.
            if is_metal_or_trim(rgb) or is_gold_pixel(rgb):
                continue
            if is_hair_color(family, rgb) or lum(rgb) < 0.42:
                op[x, y] = (r, g, b, a)

    # Fill holes inside the face oval from _src.
    for y in range(max(0, int(fy - ry)), min(128, int(chin_y) + 1)):
        for x in range(max(0, int(fx - rx)), min(128, int(fx + rx) + 1)):
            if ((x - fx) / rx) ** 2 + ((y - fy) / ry) ** 2 > 1.0:
                continue
            if op[x, y][3] > 40:
                continue
            r, g, b, a = px[x, y]
            if a < 40 or is_hat_or_hood(family, (r, g, b)):
                continue
            op[x, y] = (r, g, b, a)

    if family in ("mage", "healer"):
        from PIL import ImageDraw

        has_hair = False
        for y in range(max(0, int(fy - face_half * 2)), int(fy)):
            for x in range(max(0, int(fx - face_half * 1.5)), min(128, int(fx + face_half * 1.5))):
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

    # Cloth under the jaw. Narrow neck column so unequipped body isn't head-floating;
    # leave shoulder collar zone for chest gorget.
    cloth_y0 = int(chin_y) + 1
    collar_until = int(chin_y) + 10
    # Neck skin / cloth bridge from jaw
    for y in range(int(chin_y), min(128, collar_until + 1)):
        for x in range(max(0, int(fx - face_half * 0.9)), min(128, int(fx + face_half * 0.9))):
            if op[x, y][3] > 40:
                continue
            r, g, b, a = px[x, y]
            if a > 40 and is_skin((r, g, b), face):
                op[x, y] = (r, g, b, a)
            elif abs(x - fx) < face_half * 0.72:
                op[x, y] = shade_cloth(tunic, x, y, cx, chin_y, mid_y)

    for y in range(cloth_y0, min(128, y1 + 1)):
        cloth = tunic if y < mid_y else pants
        y_a, y_b = (cloth_y0, mid_y) if y < mid_y else (mid_y, foot_y)
        for x in range(128):
            if not mask[y][x]:
                continue
            if op[x, y][3] > 40:
                continue  # keep copied face/neck
            if ((x - fx) / max(1.0, face_half * 1.28)) ** 2 + (
                (y - fy) / max(1.0, face_half * 1.22)
            ) ** 2 <= 1.0 and y <= chin_y:
                continue
            # Wide collar zone: only keep arm cloth, not a tan slab under the chin.
            if y <= collar_until and abs(x - fx) < face_half * 1.55:
                if abs(x - fx) < face_half * 0.85:
                    continue
            op[x, y] = shade_cloth(cloth, x, y, cx, y_a, y_b)

    shoe = tuple(max(0, c - 28) for c in pants)
    for y in range(max(0, foot_y), min(128, y1 + 1)):
        for x in range(128):
            if not mask[y][x]:
                continue
            r, g, b, a = px[x, y]
            if a > 20 and is_skin((r, g, b), face):
                op[x, y] = (r, g, b, a)
            elif op[x, y][3] < 40:
                op[x, y] = (*shoe, 255)

    # Skin hands from dressed pose.
    for y in range(head_max + 4, min(128, y1)):
        for x in range(x0, x1):
            r, g, b, a = px[x, y]
            if a > 80 and is_skin((r, g, b), face):
                op[x, y] = (r, g, b, a)

    # Outline below the neck only — never black scratches on the face.
    outline = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    ox = outline.load()
    for y in range(max(1, head_max), 127):
        for x in range(1, 127):
            if op[x, y][3] < 40:
                continue
            if (
                op[x - 1, y][3] < 40
                or op[x + 1, y][3] < 40
                or op[x, y - 1][3] < 40
                or op[x, y + 1][3] < 40
            ):
                ox[x, y] = (24, 20, 18, 210)
    return Image.alpha_composite(out, outline)


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
                dx > bw * 0.28 or (y > mid_y - 10 and dx > bw * 0.20)
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
        # Cape: extract only — never draw a trapezoid.
        if alpha_count(cloak) < 40:
            cloak = Image.new("RGBA", (128, 128), (0, 0, 0, 0))

        def save_set(set_id: str, im: Image.Image) -> None:
            final = maybe_authored(family, set_id, anim, im)
            final.save(gear / f"{set_id}_{anim}.png")

        save_set("chest_t0", chest)
        save_set("chest_t2", goldify(chest))
        save_set("legs_t0", legs)
        save_set("legs_t2", goldify(legs))
        save_set("cloak_t0", cloak)
        save_set("cloak_t2", goldify(cloak) if cloak.getbbox() else cloak)
        save_set("helm_t0", make_helm(family, False, hat, src, face, box))
        save_set("helm_t2", make_helm(family, True, hat, src, face, box))
        save_set("hands_t0", hands)

        out[anim] = (box, face, src, body, chest, legs, cloak, hands, hat)
        print(
            "ok",
            family,
            anim,
            "cloak_px",
            alpha_count(cloak),
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
