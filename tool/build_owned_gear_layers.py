"""Build undertunic + 128×128 overlays from dressed _src (gold master).

Rules (see .cursor/skills/character-paper-doll/SKILL.md):
- Never copy _src onto live body_*.png.
- Never invent helm/cape/chest with ImageDraw shapes.
- Extract armor pixels from _src; mage/healer hat from _src.
- Undertunic follows the _src silhouette (recolor metal → cloth). No capsules.
- Warrior/rogue helm = transparent until _authored exists; oversized authored
  icons are registered onto the head, not stamped as a full-canvas overlay.
- Authored t0 overrides under gear/_authored/ win; live armor t2 is always
  derived from approved t0 so a stale t2 master cannot replace the silhouette
  or wash the whole doll orange.
- Weapons may use shared overlays; prefer _authored when present.
"""
from __future__ import annotations

import math
import shutil
import subprocess
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageEnhance

REPO = Path(__file__).resolve().parents[1]
ROOT = REPO / "assets" / "custom" / "char"
TOOL = REPO / "tool"
FAMILIES = ("warrior", "healer", "mage", "rogue")
ANIMS = ("idle", "walk", "attack")

TUNIC = {
    "warrior": ((168, 132, 92), (112, 84, 58)),
    "healer": ((236, 228, 210), (214, 200, 178)),
    "mage": ((98, 88, 168), (72, 62, 128)),
    "rogue": ((62, 78, 56), (44, 54, 42)),
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


def load128_pose(path: Path) -> Image.Image:
    """Full gold-master silhouette for undertunic bake.

    `load128` knocks out dark canvas — that also eats dark cape/plate folds and
    leaves half-bodies (rogue/mage). Undertunic needs every opaque pose pixel.
    """
    im = Image.open(path).convert("RGBA")
    if im.size != (128, 128):
        im = im.resize((128, 128), Image.Resampling.NEAREST)
    # Only clear pure black canvas that does not touch non-black art.
    px = im.load()
    out = im.copy()
    op = out.load()
    for y in range(128):
        for x in range(128):
            r, g, b, a = px[x, y]
            if a < 8:
                continue
            if r + g + b > 6:
                continue
            touches = False
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < 128 and 0 <= ny < 128):
                        continue
                    nr, ng, nb, na = px[nx, ny]
                    if na > 40 and nr + ng + nb > 12:
                        touches = True
                        break
                if touches:
                    break
            if not touches:
                op[x, y] = (0, 0, 0, 0)
    return out


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
    # Mage gold-master hat fills the top of the bbox — sample the real face.
    face_frac = 0.42 if family == "mage" else 0.22
    cy = y0 + max(8, int((y1 - y0) * face_frac))
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


def is_hat_lining(rgb: tuple[int, int, int]) -> bool:
    """Mage brim beige/yellow. Peach cheeks have more blue and a wider r-g."""
    r, g, b = rgb
    if b >= 132:
        return False
    if r < 160 or g < 140:
        return False
    if (g - b) < 60:
        return False
    if (r - g) > 40:
        return False
    return True


def is_skin(rgb: tuple[int, int, int], face: tuple[int, int, int]) -> bool:
    r, g, b = rgb
    if is_gold_pixel(rgb) or is_hat_lining(rgb):
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
    # Muted hat felt (red≈green) is not a cheek.
    if r < 200 and abs(r - g) < 18 and 90 < b < 140 and (r - b) < 55:
        return False
    return dist(rgb, face) < 72


def is_gold_pixel(rgb: tuple[int, int, int]) -> bool:
    r, g, b = rgb
    # Bright armor trim only — peach cheeks (high blue, small g-b) are not gold.
    if r < 180 or g < 140 or b >= 132:
        return False
    if (g - b) < 88:
        return False
    if (r - g) > 70:
        return False
    return r > b + 50


def is_hat_or_hood(family: str, rgb: tuple[int, int, int]) -> bool:
    r, g, b = rgb
    if family == "mage":
        # Warm face is not a hat. Indigo/blue folds + gold/beige brim + near-black
        # cone are. Dark hat was matching is_hair_color and surviving LOOK.
        if is_gold_pixel(rgb) or is_hat_lining(rgb):
            return True
        if r > 150 and g > 90 and b > 50 and r > b:
            return False
        if b >= r - 8 and (b > 28 or lum(rgb) < 0.14):
            return True
        return False
    if family == "healer":
        # Circlet gold + pale/black hood. Blonde hair is warmer (bigger r-b).
        if is_gold_pixel(rgb):
            return True
        if r > 170 and g > 155 and b > 130 and (r - b) < 55 and abs(r - g) < 35:
            return True
        # Authored black cowl around the face (not eye ink — callers gate by Y).
        if lum(rgb) < 0.20 and abs(r - g) < 18 and abs(g - b) < 18:
            return True
        return False
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
    """Legacy: remap armor luminance into cloth (keeps plate/robe detail)."""
    l = lum(rgb)
    s = max(0.42, min(1.22, 0.38 + l * 1.15))
    return (
        min(255, int(cloth[0] * s)),
        min(255, int(cloth[1] * s)),
        min(255, int(cloth[2] * s)),
        a,
    )


def flat_undertunic_pixel(
    x: int,
    y: int,
    fx: float,
    mid_y: int,
    tunic: tuple[int, int, int],
    pants: tuple[int, int, int],
    a: int,
) -> tuple[int, int, int, int]:
    """Simple cloth shade from pose only — no plate rivets / robe folds."""
    cloth = tunic if y < mid_y else pants
    vy = 0.82 + 0.28 * (1.0 - min(1.0, abs(y - mid_y) / 48.0))
    hx = 0.90 + 0.14 * (1.0 - min(1.0, abs(x - fx) / 22.0))
    s = max(0.58, min(1.12, vy * hx))
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
) -> tuple[Image.Image, Image.Image]:
    """Build neutral body plus a cloth-only grayscale identity tint mask.

    Classify first (exclusive labels), then paint. Eyes never become skin.
    """
    from paper_doll_classify import HAIR, classify, paint_family_body

    clf = classify(src, family, face, box)
    if family in ("mage", "healer") and clf.count(HAIR) < 8:
        print(
            f"WARN {family}: no hair pixels in _src head region — body stays "
            f"bald. Add hair to _src/body_idle.png or "
            f"gear/_authored/, do not draw it here."
        )
    return paint_family_body(clf)


def strip_equipped_helm_from_body(family: str, body: Image.Image) -> None:
    """Mage/healer live body must not include the hat — that is the helm overlay."""
    helm_path = ROOT / family / "gear" / "helm_t0_idle.png"
    if not helm_path.exists():
        return
    helm = Image.open(helm_path).convert("RGBA")
    hp, bp = helm.load(), body.load()
    kill: set[tuple[int, int]] = set()
    for y in range(128):
        for x in range(128):
            if hp[x, y][3] >= 40:
                kill.add((x, y))
    extra: set[tuple[int, int]] = set()
    for x, y in kill:
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < 128 and 0 <= ny < 128:
                extra.add((nx, ny))
    for x, y in kill | extra:
        bp[x, y] = (0, 0, 0, 0)



def rarefy_cloak(cloak: Image.Image) -> Image.Image:
    """Rare cape: preserve its palette; grow so t2 reads thicker on the doll."""
    if cloak.getbbox() is None:
        return cloak
    return ImageEnhance.Contrast(thicken_cloak(cloak, passes=2)).enhance(1.08)


def rarefy_armor(im: Image.Image) -> Image.Image:
    """Rare armor: preserve item colors; grow the silhouette so t2 reads at phone size."""
    if im.getbbox() is None:
        return im
    return ImageEnhance.Contrast(thicken_cloak(im, passes=2)).enhance(1.08)


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
    from paper_doll_classify import IDENTITY, classify

    clf = classify(src, family, face, box)
    px = src.load()
    x0, y0, x1, y1 = box
    bh = y1 - y0
    bw = max(1, x1 - x0)
    fx, fy, face_half = clf.fx, clf.fy, clf.face_half
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
    chin = int(_chin_y(src, face, fx, fy, face_half))
    head_max = max(last_skin_row + 2, chin)
    mid_y = y0 + int(bh * 0.64)
    cx = (x0 + x1) / 2
    arm_top = head_max + 12
    rx_head = max(14.0, face_half * 1.65)
    ry_head = max(14.0, face_half * 1.55)

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
            if clf.at(x, y) in IDENTITY:
                continue
            # Only wipe true black crumbs — dark brown gorget must stay on chest.
            if lum(rgb) < 0.05:
                continue
            in_head = ((x - fx) / rx_head) ** 2 + ((y - fy) / ry_head) ** 2 <= 1.0
            if y <= head_max or (in_head and y <= chin + 4):
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


def strip_head_from_layer(
    layer: Image.Image,
    src: Image.Image,
    face: tuple[int, int, int],
    box: tuple[int, int, int, int],
) -> None:
    """Chest/robe must not carry a baked face — race undertunics show through."""
    fx, fy, face_half = face_region(src, face, box)
    chin = int(_chin_y(src, face, fx, fy, face_half))
    rx = max(14.0, face_half * 1.65)
    ry = max(14.0, face_half * 1.55)
    lp = layer.load()
    for y in range(0, min(128, chin + 5)):
        for x in range(128):
            if ((x - fx) / rx) ** 2 + ((y - fy) / ry) ** 2 > 1.0:
                continue
            lp[x, y] = (0, 0, 0, 0)


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
    hat: Image.Image,
    src: Image.Image,
    face: tuple[int, int, int],
    box: tuple[int, int, int, int],
) -> Image.Image:
    """Helm from gold master only. No invent stamp for warrior/rogue."""
    if family in ("mage", "healer") and hat.getbbox():
        out = hat.copy()
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


def ensure_shared_weapons(shared: Path, anim: str) -> None:
    """Keep existing shared weapon PNGs unless _authored replaces them.

    Missing files copy from authored idle, then from another anim — never
    invent ImageDraw swords so the catalog cannot silently ship placeholders.
    """
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
        idle_auth = authored_path(None, name, "idle")
        if idle_auth is not None:
            shutil.copyfile(idle_auth, dest)
            continue
        idle_live = shared / f"{name}_idle.png"
        if anim != "idle" and idle_live.exists():
            shutil.copyfile(idle_live, dest)
            continue
        raise SystemExit(
            f"missing shared weapon {dest.relative_to(REPO)} — "
            "drop authored art under char/gear/_authored/, do not invent"
        )


def save_idle_armor_overlays(
    family: str,
    anim: str,
    src: Image.Image,
    box: tuple[int, int, int, int],
    face: tuple[int, int, int],
    gear: Path,
) -> tuple:
    """Extract armor from gold master — idle only (walk/attack use these layers)."""
    chest, legs, cloak, hat, hands = extract_bands(src, face, box, family)
    if alpha_count(cloak) < 20:
        cloak = Image.new("RGBA", (128, 128), (0, 0, 0, 0))

    # Resolve cape. Rogue/mage: thicken for LIVE only to a stable target.
    # Never write thickened output into _authored (authored stays hand input).
    if family in ("rogue", "mage"):
        target = 3300 if family == "rogue" else 3200
        extract_ok = alpha_count(cloak) >= 20
        base = cloak if extract_ok else Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        auth_p = authored_path(family, "cloak_t0", anim)
        if auth_p is not None:
            authored = load_authored(auth_p)
            ac = alpha_count(authored)
            if ac >= 20:
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
    else:
        cloak0 = maybe_authored(family, "cloak_t0", anim, cloak)

    def save_set(set_id: str, im: Image.Image) -> Image.Image:
        final = maybe_authored(family, set_id, anim, im)
        if set_id.startswith("helm_"):
            final = register_helm_to_head(final, src, face, box)
        final.save(gear / f"{set_id}_{anim}.png")
        return final

    chest0 = save_set("chest_t0", chest)
    rarefy_armor(chest0).save(gear / f"chest_t2_{anim}.png")
    legs0 = save_set("legs_t0", legs)
    rarefy_armor(legs0).save(gear / f"legs_t2_{anim}.png")
    cloak0.save(gear / f"cloak_t0_{anim}.png")
    cloak2 = rarefy_cloak(cloak0) if cloak0.getbbox() else cloak0
    cloak2.save(gear / f"cloak_t2_{anim}.png")
    helm0 = save_set("helm_t0", make_helm(family, hat, src, face, box))
    rarefy_armor(helm0).save(gear / f"helm_t2_{anim}.png")
    hands0 = save_set("hands_t0", hands)
    (rarefy_armor(hands0) if hands0.getbbox() else hands0).save(
        gear / f"hands_t2_{anim}.png"
    )
    return chest0, legs0, cloak0, hands0, hat


def process_family(family: str) -> dict:
    out = {}
    gear = ROOT / family / "gear"
    gear.mkdir(parents=True, exist_ok=True)
    (gear / "_authored").mkdir(parents=True, exist_ok=True)
    idle_armor = None
    for anim in ANIMS:
        # Undertunic needs the full pose silhouette; armor extract keeps the
        # cleaned load128 so overlays stay free of canvas dirt.
        pose = load128_pose(ensure_src(family, anim))
        box = bbox(pose)
        face = sample_face(pose, box, family)
        body, tint_mask = paint_undertunic(pose, family, face, box)
        cleaned = load128(ensure_src(family, anim))
        cbox = bbox(cleaned)
        cface = sample_face(cleaned, cbox, family)
        cfx, _cfy, cfh = face_region(cleaned, cface, cbox)
        cchin = _chin_y(cleaned, cface, cfx, _cfy, cfh)
        mp = tint_mask.load()
        for y in range(128):
            for x in range(128):
                if y <= cchin + 8 and abs(x - cfx) <= cfh * 2.4:
                    mp[x, y] = (0, 0, 0, 0)
        body.save(ROOT / family / f"body_{anim}.png")
        tint_mask.save(ROOT / family / f"body_tint_{anim}.png")

        if anim == "idle":
            src = load128(ensure_src(family, anim))
            src_box = bbox(src)
            src_face = sample_face(src, src_box, family)
            chest0, legs0, cloak0, hands0, hat = save_idle_armor_overlays(
                family, anim, src, src_box, src_face, gear
            )
            idle_armor = (chest0, legs0, cloak0, hands0, hat)
            out[anim] = (box, face, pose, body, chest0, legs0, cloak0, hands0, hat)
            print(
                "ok",
                family,
                anim,
                "cloak_px",
                alpha_count(cloak0),
                "hat_px",
                alpha_count(hat),
            )
        else:
            assert idle_armor is not None
            chest0, legs0, cloak0, hands0, hat = idle_armor
            out[anim] = (box, face, pose, body, chest0, legs0, cloak0, hands0, hat)
            print("ok", family, anim, "body_only overlays=idle")
    return out


def write_tint_masks_only() -> None:
    """Refresh identity masks without rewriting approved body/gear PNGs."""
    for family in FAMILIES:
        for anim in ANIMS:
            src = load128_pose(ensure_src(family, anim))
            box = bbox(src)
            face = sample_face(src, box, family)
            _body, tint_mask = paint_undertunic(src, family, face, box)
            tint_mask.save(ROOT / family / f"body_tint_{anim}.png")
            print("ok", family, anim, "tint_mask_px", alpha_count(tint_mask))
    print("done — tint masks only; run check_paper_doll_facit.py")


def write_t2_only() -> None:
    """Rebuild approved t2 silhouettes from live t0 without touching sources."""
    for family in FAMILIES:
        gear = ROOT / family / "gear"
        for stem in ("helm", "chest", "legs", "cloak", "hands"):
            src = gear / f"{stem}_t0_idle.png"
            if not src.exists():
                raise FileNotFoundError(src)
            base = Image.open(src).convert("RGBA")
            out = rarefy_cloak(base) if stem == "cloak" else rarefy_armor(base)
            out.save(gear / f"{stem}_t2_idle.png")
            print("ok", family, f"{stem}_t2", "palette=t0")
    subprocess.check_call(
        [sys.executable, str(TOOL / "derive_armor_material_variants.py"), "--t2-only"],
    )
    print("done — t2 tiers only; inspect high previews then relock")


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


def write_bodies_only(families: tuple[str, ...]) -> None:
    """Rebuild undertunic + tint; keep live gear overlays (hat stays on helm)."""
    for family in families:
        for anim in ANIMS:
            pose = load128_pose(ensure_src(family, anim))
            box = bbox(pose)
            face = sample_face(pose, box, family)
            body, tint_mask = paint_undertunic(pose, family, face, box)
            # Facit measures the head band on load128(_src) — clear tint there too.
            cleaned = load128(ensure_src(family, anim))
            cbox = bbox(cleaned)
            cface = sample_face(cleaned, cbox, family)
            cfx, cfy, cfh = face_region(cleaned, cface, cbox)
            cchin = _chin_y(cleaned, cface, cfx, cfy, cfh)
            mp = tint_mask.load()
            for y in range(128):
                for x in range(128):
                    if y <= cchin + 8 and abs(x - cfx) <= cfh * 2.4:
                        mp[x, y] = (0, 0, 0, 0)
            body.save(ROOT / family / f"body_{anim}.png")
            tint_mask.save(ROOT / family / f"body_tint_{anim}.png")
            print("ok", family, anim, "body_only")
    print("done — bodies only; run paint_race_bodies.py then facit --relock")


def main() -> None:
    if "--tint-masks-only" in sys.argv:
        write_tint_masks_only()
        return
    if "--t2-only" in sys.argv:
        write_t2_only()
        return
    if "--bodies-only" in sys.argv:
        wanted = tuple(a for a in sys.argv if a in FAMILIES)
        write_bodies_only(wanted or FAMILIES)
        return
    shared = ROOT / "gear"
    shared.mkdir(parents=True, exist_ok=True)
    (shared / "_authored").mkdir(parents=True, exist_ok=True)
    built = {}
    for family in FAMILIES:
        built[family] = process_family(family)
    for anim in ("idle",):
        ensure_shared_weapons(shared, anim)
    for family in FAMILIES:
        write_armor_preview(family, built[family])
    # Material variants + slot icons are part of one repeatable build. Leaving
    # them as a second manual command let native and cross-material t2 drift.
    subprocess.check_call(
        [sys.executable, str(TOOL / "derive_armor_material_variants.py")],
    )
    print("done — inspect tool/preview_doll_*.png then run check_paper_doll_facit.py")


if __name__ == "__main__":
    main()
