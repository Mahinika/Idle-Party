"""Process generated warrior art into 128×128 _authored overlays."""
from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image, ImageEnhance

ROOT = Path(r"d:\Projects\Personal\idle party\Idle-Party\assets\custom\char")
GEN = Path(
    r"C:\Users\Ropbe\.cursor\projects\d-Projects-Personal-idle-party-Idle-Party\assets"
)
ANIMS = ("idle", "walk", "attack")
W_AUTH = ROOT / "warrior" / "gear" / "_authored"
G_AUTH = ROOT / "gear" / "_authored"


def to_rgba_knockout(im: Image.Image, thresh: int = 28) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if r <= thresh and g <= thresh and b <= thresh:
                px[x, y] = (0, 0, 0, 0)
    return im


def content_bbox(im: Image.Image) -> tuple[int, int, int, int]:
    box = im.getbbox()
    return box if box else (0, 0, im.width, im.height)


def place_scaled(
    src: Image.Image,
    dest_box: tuple[int, int, int, int],
    canvas: int = 128,
    *,
    cover: bool = False,
) -> Image.Image:
    """Scale content to fit (or cover) dest_box on a 128 canvas (nearest)."""
    src = to_rgba_knockout(src)
    bb = content_bbox(src)
    crop = src.crop(bb)
    dx0, dy0, dx1, dy1 = dest_box
    dw, dh = max(1, dx1 - dx0), max(1, dy1 - dy0)
    cw, ch = crop.size
    scale = max(dw / cw, dh / ch) if cover else min(dw / cw, dh / ch)
    nw, nh = max(1, int(cw * scale)), max(1, int(ch * scale))
    resized = crop.resize((nw, nh), Image.Resampling.NEAREST)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    ox = dx0 + (dw - nw) // 2
    oy = dy0 + (dh - nh) // 2
    if cover:
        # Prefer top-aligned helm so crest covers hair spikes.
        oy = dy0
    out.paste(resized, (ox, oy), resized)
    return out


def goldify(im: Image.Image) -> Image.Image:
    """Boost warm highlights for t2."""
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            # Push mid greys toward gold trim
            if abs(r - g) < 25 and abs(g - b) < 25 and 40 < r < 160:
                px[x, y] = (
                    min(255, int(r * 1.15 + 20)),
                    min(255, int(g * 1.05 + 10)),
                    max(0, int(b * 0.7)),
                    a,
                )
            elif r > 150 and g > 100 and b < 140:
                px[x, y] = (
                    min(255, r + 20),
                    min(255, g + 15),
                    max(0, b - 5),
                    a,
                )
    return out


def slight_offset(im: Image.Image, dx: int, dy: int) -> Image.Image:
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    out.paste(im, (dx, dy), im)
    return out


def save_set(folder: Path, set_id: str, idle: Image.Image, fancy: bool = False) -> None:
    folder.mkdir(parents=True, exist_ok=True)
    variants = {
        "idle": idle,
        "walk": slight_offset(idle, 0, 1),
        "attack": slight_offset(idle, 1 if "sword" in set_id or "shield" in set_id else 0, -1),
    }
    for anim, im in variants.items():
        final = goldify(im) if fancy else im
        path = folder / f"{set_id}_{anim}.png"
        final.save(path)
        print("wrote", path.relative_to(ROOT))


def cover_hair_with_helm(helm: Image.Image, body_path: Path) -> Image.Image:
    """Paint opaque plate over brown hair spikes that poke past the helm."""
    body = Image.open(body_path).convert("RGBA")
    out = helm.copy()
    bp = body.load()
    hp = out.load()
    plate = (55, 58, 62, 255)
    for y in range(0, 58):
        for x in range(18, 110):
            r, g, b, a = bp[x, y]
            if a < 40:
                continue
            # brown hair (exclude gold / skin)
            if not (55 < r < 145 and 25 < g < 95 and b < 75 and r > g + 8):
                continue
            if hp[x, y][3] >= 40:
                continue
            # keep face window clear (center eyes/skin)
            if 48 <= x <= 80 and 28 <= y <= 52:
                continue
            hp[x, y] = plate
            # soft rim gold on outer spikes
            if x <= 28 or x >= 100 or y <= 6:
                hp[x, y] = (198, 150, 48, 255)
    return out


def main() -> None:
    helm_src = Image.open(GEN / "warrior_helm_gen.png")
    cape_src = Image.open(GEN / "warrior_cape_gen.png")
    sword_src = Image.open(GEN / "warrior_sword_gen.png")
    shield_src = Image.open(GEN / "warrior_shield_gen.png")

    # Dest boxes aligned to warrior 128 body origin (from _src proportions).
    # Helm uses cover+top so brown hair spikes under the body PNG stay hidden.
    helm = place_scaled(helm_src, (18, 0, 110, 66), cover=True)
    helm = cover_hair_with_helm(helm, ROOT / "warrior" / "_src" / "body_idle.png")
    cape = place_scaled(cape_src, (14, 30, 114, 108))
    sword = place_scaled(sword_src, (68, 48, 124, 118))
    shield = place_scaled(shield_src, (4, 48, 62, 118))

    save_set(W_AUTH, "helm_t0", helm, fancy=False)
    save_set(W_AUTH, "helm_t2", helm, fancy=True)
    save_set(W_AUTH, "cloak_t0", cape, fancy=False)
    save_set(W_AUTH, "cloak_t2", cape, fancy=True)
    save_set(G_AUTH, "sword_t0", sword, fancy=False)
    save_set(G_AUTH, "shield_t0", shield, fancy=False)

    # Keep gens for reference under tool/
    tool = Path(r"d:\Projects\Personal\idle party\Idle-Party\tool")
    for name in (
        "warrior_helm_gen.png",
        "warrior_cape_gen.png",
        "warrior_sword_gen.png",
        "warrior_shield_gen.png",
    ):
        src = GEN / name
        if src.exists():
            shutil.copyfile(src, tool / name)
    print("authored overlays ready")


if __name__ == "__main__":
    main()
