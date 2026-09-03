"""Process mage/healer cape gens into 128 _authored cloak overlays."""
from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(r"d:\Projects\Personal\idle party\Idle-Party\assets\custom\char")
GEN = Path(
    r"C:\Users\Ropbe\.cursor\projects\d-Projects-Personal-idle-party-Idle-Party\assets"
)
TOOL = Path(r"d:\Projects\Personal\idle party\Idle-Party\tool")
CAPE_BOX = (12, 26, 116, 112)


def knockout(im: Image.Image, thresh: int = 28) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if r <= thresh and g <= thresh and b <= thresh:
                px[x, y] = (0, 0, 0, 0)
    return im


def is_skin(r: int, g: int, b: int) -> bool:
    return r > 150 and g > 100 and b > 80 and r > b + 20 and abs(r - g) < 70


def is_eye_dark(r: int, g: int, b: int) -> bool:
    return r < 55 and g < 45 and b < 40


def keep_mage_cape(r: int, g: int, b: int) -> bool:
    # deep / mid blue cloth
    if b > r + 15 and b > g and b > 60 and r < 120:
        return True
    # gold trim / clasps
    if r > 140 and g > 100 and b < 120 and r > b + 30:
        return True
    # dark navy folds
    if b > 40 and b >= g and b >= r and r < 70 and g < 80 and b < 140:
        return True
    return False


def keep_healer_cape(r: int, g: int, b: int) -> bool:
    # cream / yellow / gold cloth
    if r > 140 and g > 110 and b < 160 and r >= g - 10:
        return True
    if r > 180 and g > 150 and b > 80 and b < 180:
        return True
    # darker gold shadow
    if r > 100 and g > 70 and b < 90 and r > b + 20:
        return True
    return False


def extract_cape(gen: Image.Image, family: str) -> Image.Image:
    im = knockout(gen)
    keep = keep_mage_cape if family == "mage" else keep_healer_cape
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a < 20:
                continue
            if is_skin(r, g, b) or is_eye_dark(r, g, b):
                px[x, y] = (0, 0, 0, 0)
                continue
            # mage hat blue is brighter / higher — drop top hat dome
            if family == "mage" and y < im.height * 0.28 and b > 100:
                px[x, y] = (0, 0, 0, 0)
                continue
            # purple crystal / staff
            if b > 140 and r > 80 and g < 100 and b > r:
                px[x, y] = (0, 0, 0, 0)
                continue
            if not keep(r, g, b):
                px[x, y] = (0, 0, 0, 0)
                continue
            px[x, y] = (r, g, b, 255)
    return im


def place(src: Image.Image, dest_box: tuple[int, int, int, int]) -> Image.Image:
    bb = src.getbbox()
    if bb is None:
        return Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    crop = src.crop(bb)
    dx0, dy0, dx1, dy1 = dest_box
    dw, dh = max(1, dx1 - dx0), max(1, dy1 - dy0)
    cw, ch = crop.size
    scale = min(dw / cw, dh / ch)
    nw, nh = max(1, int(cw * scale)), max(1, int(ch * scale))
    resized = crop.resize((nw, nh), Image.Resampling.NEAREST)
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    out.paste(resized, (dx0 + (dw - nw) // 2, dy0 + (dh - nh) // 2), resized)
    return out


def punch_body_center(cape: Image.Image, body_path: Path, shrink: int = 4) -> Image.Image:
    """Clear cape ink that sits under the body silhouette so clasps/sides remain."""
    body = Image.open(body_path).convert("RGBA")
    # erode body mask slightly so cape peeks at edges
    occ = [[False] * 128 for _ in range(128)]
    bp = body.load()
    for y in range(128):
        for x in range(128):
            if bp[x, y][3] > 40:
                occ[y][x] = True
    eroded = [[False] * 128 for _ in range(128)]
    for y in range(shrink, 128 - shrink):
        for x in range(shrink, 128 - shrink):
            if not occ[y][x]:
                continue
            ok = True
            for dy in range(-shrink, shrink + 1):
                for dx in range(-shrink, shrink + 1):
                    if not occ[y + dy][x + dx]:
                        ok = False
                        break
                if not ok:
                    break
            eroded[y][x] = ok
    out = cape.copy()
    px = out.load()
    for y in range(128):
        for x in range(128):
            if eroded[y][x] and px[x, y][3] > 0:
                # keep shoulder clasps near top of torso
                if y < 42 and (x < 48 or x > 80):
                    continue
                px[x, y] = (0, 0, 0, 0)
    return out


def goldify(im: Image.Image) -> Image.Image:
    out = im.copy()
    px = out.load()
    for y in range(128):
        for x in range(128):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            if r > 120 and g > 90 and b < 140:
                px[x, y] = (min(255, r + 22), min(255, g + 14), max(0, b - 8), a)
    return out


def slight(im: Image.Image, dx: int, dy: int) -> Image.Image:
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    out.paste(im, (dx, dy), im)
    return out


def save_family(family: str, idle: Image.Image) -> None:
    auth = ROOT / family / "gear" / "_authored"
    auth.mkdir(parents=True, exist_ok=True)
    variants = {
        "idle": idle,
        "walk": slight(idle, 0, 1),
        "attack": slight(idle, 0, -1),
    }
    for anim, im in variants.items():
        path = auth / f"cloak_t0_{anim}.png"
        im.save(path)
        print("wrote", path.relative_to(ROOT))
        t2 = goldify(im)
        path2 = auth / f"cloak_t2_{anim}.png"
        t2.save(path2)
        print("wrote", path2.relative_to(ROOT))


def make_healer_cape() -> Image.Image:
    """Solid cream/gold side panels — gen extract was too sparse."""
    body = Image.open(ROOT / "healer" / "body_idle.png").convert("RGBA")
    bp = body.load()
    im = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    px = im.load()
    c1, c2, c3 = (210, 175, 70, 255), (190, 150, 50, 255), (230, 200, 110, 255)
    edge, clasp = (150, 115, 40, 255), (240, 210, 90, 255)
    for y in range(28, 108):
        flare = int((y - 28) * 0.12)
        for x in range(14, 34 + flare):
            shade = c2 if (x + y) % 3 == 0 else c1
            if x <= 16 or x >= 30 + flare:
                shade = edge
            if y > 95:
                shade = c3 if (x + y) % 2 else c1
            px[x, y] = shade
        for x in range(94 - flare, 114):
            shade = c2 if (x + y) % 3 == 0 else c1
            if x >= 112 or x <= 96 - flare:
                shade = edge
            if y > 95:
                shade = c3 if (x + y) % 2 else c1
            px[x, y] = shade
    for y in range(30, 40):
        for x in range(28, 40):
            if ((x - 34) / 7) ** 2 + ((y - 34) / 5) ** 2 <= 1:
                px[x, y] = clasp
        for x in range(88, 100):
            if ((x - 94) / 7) ** 2 + ((y - 34) / 5) ** 2 <= 1:
                px[x, y] = clasp
    for y in range(36, 100):
        for x in range(42, 86):
            if bp[x, y][3] > 40:
                px[x, y] = (0, 0, 0, 0)
    return im


def main() -> None:
    # Mage: extract from gen
    raw = Image.open(GEN / "mage_cape_gen.png")
    cape = extract_cape(raw, "mage")
    placed = place(cape, CAPE_BOX)
    body = ROOT / "mage" / "body_idle.png"
    mage = punch_body_center(placed, body, shrink=3)
    print("mage cape ink", sum(1 for y in range(128) for x in range(128) if mage.getpixel((x, y))[3] > 40))
    save_family("mage", mage)
    shutil.copyfile(GEN / "mage_cape_gen.png", TOOL / "mage_cape_gen.png")

    healer = make_healer_cape()
    print(
        "healer cape ink",
        sum(1 for y in range(128) for x in range(128) if healer.getpixel((x, y))[3] > 40),
    )
    save_family("healer", healer)

    bg = Image.new("RGBA", (128, 128), (30, 40, 48, 255))
    for family, cape_im in (("mage", mage), ("healer", healer)):
        under = Image.alpha_composite(
            cape_im, Image.open(ROOT / family / "body_idle.png").convert("RGBA")
        )
        for piece in ("legs_t0", "chest_t0", "hands_t0", "helm_t0"):
            p = ROOT / family / "gear" / f"{piece}_idle.png"
            if p.exists():
                under = Image.alpha_composite(under, Image.open(p).convert("RGBA"))
        Image.alpha_composite(bg, under).resize((384, 384), Image.Resampling.NEAREST).save(
            TOOL / f"_cape_preview_{family}.png"
        )
        Image.alpha_composite(bg, cape_im).resize((256, 256), Image.Resampling.NEAREST).save(
            TOOL / f"_lit_cloak_{family}.png"
        )
    print("mage/healer cloaks authored")


if __name__ == "__main__":
    main()
