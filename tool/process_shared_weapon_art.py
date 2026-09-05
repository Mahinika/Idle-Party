"""Process generated shared weapons + rogue helm into 128 _authored overlays."""
from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(r"d:\Projects\Personal\idle party\Idle-Party\assets\custom\char")
GEN = Path(
    r"C:\Users\Ropbe\.cursor\projects\d-Projects-Personal-idle-party-Idle-Party\assets"
)
G_AUTH = ROOT / "gear" / "_authored"
R_AUTH = ROOT / "rogue" / "gear" / "_authored"
TOOL = Path(r"d:\Projects\Personal\idle party\Idle-Party\tool")

# Main-hand lower-right; off-hand lower-left (matches sword/shield sockets).
MAIN_BOX = (68, 40, 124, 118)
OFF_BOX = (4, 48, 62, 118)
BOW_BOX = (62, 28, 124, 118)
STAFF_BOX = (70, 20, 124, 120)
HELM_BOX = (22, 0, 106, 62)


def to_rgba_knockout(im: Image.Image, thresh: int = 32) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if r <= thresh and g <= thresh and b <= thresh:
                px[x, y] = (0, 0, 0, 0)
    return im


def place_scaled(
    src: Image.Image,
    dest_box: tuple[int, int, int, int],
    *,
    cover: bool = False,
    top_align: bool = False,
) -> Image.Image:
    src = to_rgba_knockout(src)
    bb = src.getbbox() or (0, 0, src.width, src.height)
    crop = src.crop(bb)
    dx0, dy0, dx1, dy1 = dest_box
    dw, dh = max(1, dx1 - dx0), max(1, dy1 - dy0)
    cw, ch = crop.size
    scale = max(dw / cw, dh / ch) if cover else min(dw / cw, dh / ch)
    nw, nh = max(1, int(cw * scale)), max(1, int(ch * scale))
    resized = crop.resize((nw, nh), Image.Resampling.NEAREST)
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    ox = dx0 + (dw - nw) // 2
    oy = dy0 if top_align or cover else dy0 + (dh - nh) // 2
    out.paste(resized, (ox, oy), resized)
    return out


def slight_offset(im: Image.Image, dx: int, dy: int) -> Image.Image:
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    out.paste(im, (dx, dy), im)
    return out


def save_set(folder: Path, set_id: str, idle: Image.Image) -> None:
    folder.mkdir(parents=True, exist_ok=True)
    variants = {
        "idle": idle,
        "walk": slight_offset(idle, 0, 1),
        "attack": slight_offset(idle, 1, -1),
    }
    for anim, im in variants.items():
        path = folder / f"{set_id}_{anim}.png"
        im.save(path)
        print("wrote", path.relative_to(ROOT))


def cover_hair_with_helm(helm: Image.Image, body_path: Path) -> Image.Image:
    body = Image.open(body_path).convert("RGBA")
    out = helm.copy()
    bp = body.load()
    hp = out.load()
    plate = (42, 36, 32, 255)
    for y in range(0, 56):
        for x in range(18, 110):
            r, g, b, a = bp[x, y]
            if a < 40:
                continue
            # brown / dark hair
            if not (
                (40 < r < 150 and 20 < g < 100 and b < 80 and r > g + 5)
                or (r < 70 and g < 60 and b < 55 and a > 40)
            ):
                continue
            if hp[x, y][3] >= 40:
                continue
            if 48 <= x <= 80 and 26 <= y <= 52:
                continue
            hp[x, y] = plate
    return out


def main() -> None:
    jobs = [
        ("weapon_staff_gen.png", "staff_t0", STAFF_BOX, False),
        ("weapon_dagger_gen.png", "dagger_t0", MAIN_BOX, False),
        ("weapon_bow_gen.png", "bow_t0", BOW_BOX, False),
        ("weapon_axe_gen.png", "axe_t0", MAIN_BOX, False),
        ("weapon_mace_gen.png", "mace_t0", MAIN_BOX, False),
        ("weapon_frill_gen.png", "frill_t0", OFF_BOX, False),
    ]
    for fname, set_id, box, _ in jobs:
        src = Image.open(GEN / fname)
        im = place_scaled(src, box)
        save_set(G_AUTH, set_id, im)
        shutil.copyfile(GEN / fname, TOOL / fname)

    helm = make_rogue_leather_cowl()
    save_set(R_AUTH, "helm_t0", helm)
    helm_t2 = helm.copy()
    px = helm_t2.load()
    for y in range(128):
        for x in range(128):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            if r > 100:
                px[x, y] = (min(255, r + 18), min(255, g + 10), b, a)
    save_set(R_AUTH, "helm_t2", helm_t2)
    print("shared weapons + rogue helm authored")


def make_rogue_leather_cowl() -> Image.Image:
    """Opaque leather cowl (authored). Gen portraits were unusable fog+face."""
    body = Image.open(ROOT / "rogue" / "_src" / "body_idle.png").convert("RGBA")
    bp = body.load()
    im = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    px = im.load()
    l1, l2, l3 = (40, 30, 24, 255), (55, 40, 30, 255), (72, 52, 36, 255)
    edge, brz, hi = (28, 20, 16, 255), (170, 122, 48, 255), (198, 148, 64, 255)
    for y in range(0, 52):
        for x in range(22, 106):
            if 46 <= x <= 82 and 26 <= y <= 48:
                if ((x - 64) / 16) ** 2 + ((y - 36) / 9) ** 2 < 1.0:
                    continue
            if ((x - 64) / 38) ** 2 + ((y - 26) / 28) ** 2 > 1.05:
                continue
            shade = l3 if y < 12 else l2
            if x <= 30 or x >= 98:
                shade = edge
            if (x + y * 3) % 7 == 0:
                shade = l1
            px[x, y] = shade
    for y in range(22, 56):
        for x in range(20, 36):
            if ((x - 28) / 10) ** 2 + ((y - 38) / 16) ** 2 <= 1:
                px[x, y] = l1 if y % 2 else l2
        for x in range(92, 108):
            if ((x - 100) / 10) ** 2 + ((y - 38) / 16) ** 2 <= 1:
                px[x, y] = l1 if y % 2 else l2
    for x in range(44, 84):
        for y in range(18, 23):
            px[x, y] = brz if (x + y) % 3 else hi
    for y in range(18, 24):
        for x in range(60, 68):
            px[x, y] = hi
    for y in range(0, 50):
        for x in range(20, 108):
            if 46 <= x <= 82 and 26 <= y <= 48:
                continue
            r, g, b, a = bp[x, y]
            if a < 40:
                continue
            if r < 100 and g < 80 and b < 70 and px[x, y][3] < 40:
                px[x, y] = l1
    return im


if __name__ == "__main__":
    main()
