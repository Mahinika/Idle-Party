"""One-time authoring of short/broad style masters and class emblems.

Writes hand inputs under gear/_authored/, composed from owned pixels only:
- short = the family's own piece cut at a new line (vest, breeches, capelet,
  cuff, brow band). No rescale.
- broad = the family's own piece on top of a wider piece from another family,
  moved by body landmarks and repainted in this family's palette.
- class emblems = a small crop of owned trim, placed on the family's chest
  centre or brow.

Existing masters are never overwritten (pass --force to redo one family's
set). A hand-drawn PNG with the same name replaces any of these.
"""
from __future__ import annotations

import sys

from PIL import Image

from build_owned_gear_layers import body_landmarks, register_to_body
from paper_doll_classify import drop_small_islands
from paper_doll_manifest import CLASS_MARKS, FAMILIES, SLOTS
from paper_doll_paths import CHAR as ROOT

# Wider donor per slot, with a second choice when the family is the donor.
BROAD_DONOR = {
    "helm": ("healer", "mage"),
    "chest": ("warrior", "healer"),
    "legs": ("healer", "mage"),
    "cloak": ("mage", "warrior"),
    "hands": ("warrior", "rogue"),
}


def load(family: str, stem: str) -> Image.Image:
    return Image.open(ROOT / family / "gear" / f"{stem}_idle.png").convert("RGBA")


def keep_rows(im: Image.Image, top: float, bottom: float) -> Image.Image:
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    ip, op = im.load(), out.load()
    for y in range(max(0, int(top)), min(128, int(bottom) + 1)):
        for x in range(128):
            op[x, y] = ip[x, y]
    return out


def short(family: str, slot: str) -> Image.Image:
    piece = load(family, f"{slot}_t0")
    x0, y0, x1, y1 = piece.getbbox()
    h = y1 - y0
    if slot == "helm":
        return keep_rows(piece, y0 + h * 0.45, y1)
    if slot == "chest":
        return keep_rows(piece, y0, y0 + h * 0.62)
    if slot == "legs":
        return keep_rows(piece, y0, y0 + h * 0.5)
    if slot == "cloak":
        return keep_rows(piece, y0, y0 + h * 0.42)
    return keep_rows(piece, y0 + h * 0.5, y1)


def lum(p: tuple[int, int, int, int]) -> float:
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def repaint(donor: Image.Image, palette_from: Image.Image) -> Image.Image:
    """Donor shading, family colours: match by brightness rank."""
    pal = sorted(
        (p for p in palette_from.get_flattened_data() if p[3] >= 40), key=lum
    )
    out = donor.copy()
    op = out.load()
    pix = [
        (x, y)
        for y in range(128)
        for x in range(128)
        if op[x, y][3] >= 12
    ]
    if not pal or not pix:
        return out
    pix.sort(key=lambda xy: lum(op[xy]))
    n = len(pix)
    for i, (x, y) in enumerate(pix):
        r, g, b, _ = pal[min(len(pal) - 1, i * len(pal) // n)]
        op[x, y] = (r, g, b, op[x, y][3])
    return out


def donor_band(donor: str, slot: str) -> Image.Image:
    piece = load(donor, f"{slot}_t0")
    fx, fy, half, chin, x0, y0, x1, y1 = body_landmarks(donor)
    if slot == "helm":
        # Crown only: side flaps would hang beside the face like loose hair.
        return keep_rows(piece, 0, fy - half * 0.9)
    if slot == "chest" and donor == "warrior":
        return keep_rows(piece, chin - 4, chin + (y1 - chin) * 0.28)
    return piece


# The rogue cowl already frames the face and hides a crown, so rogue takes
# the whole healer hood; everyone else takes only the crown.
FULL_HOOD = {"rogue"}


def broad(family: str, slot: str) -> Image.Image:
    first, second = BROAD_DONOR[slot]
    donor = second if family == first else first
    own = load(family, f"{slot}_t0")
    band = (
        load(donor, "helm_t0")
        if slot == "helm" and family in FULL_HOOD
        else donor_band(donor, slot)
    )
    moved = register_to_body(band, donor, family, slot)
    under = repaint(drop_small_islands(moved, min_size=24), own)
    return Image.alpha_composite(under, own)


def emblem(family: str, slot: str, mark: str) -> Image.Image:
    """Small owned trim crop on this family's chest centre or brow."""
    source = {"paladin": "healer", "deathknight": "warrior", "warlock": "mage"}[mark]
    sfx, sfy, shalf, schin, *_ = body_landmarks(source)
    tfx, tfy, thalf, tchin, *_ = body_landmarks(family)
    if slot == "chest":
        piece = load(source, "chest_t0")
        scx, scy = sfx, schin + shalf * 0.9
        tcx, tcy = tfx, tchin + thalf * 0.9
    else:
        piece = load(source, "helm_t0")
        scx, scy = sfx, sfy - shalf * 1.05
        tcx, tcy = tfx, tfy - thalf * 1.05
    r = 6
    crop = piece.crop((int(scx - r), int(scy - r), int(scx + r + 1), int(scy + r + 1)))
    if mark == "deathknight":
        crop = tint(crop, (120, 200, 255))
    elif mark == "warlock":
        crop = tint(crop, (120, 255, 90))
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    out.paste(crop, (int(tcx - r), int(tcy - r)), crop)
    return out


def tint(im: Image.Image, rgb: tuple[int, int, int]) -> Image.Image:
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a < 12:
                continue
            l = lum((r, g, b, a)) / 255.0
            px[x, y] = tuple(min(255, int(c * (0.35 + l))) for c in rgb) + (a,)
    return out


def save(path, im: Image.Image, force: bool) -> bool:
    if path.exists() and not force:
        return False
    im.save(path)
    return True


def main() -> None:
    force = "--force" in sys.argv
    wanted = [f for f in FAMILIES if f in sys.argv] or list(FAMILIES)
    n = 0
    for family in wanted:
        auth = ROOT / family / "gear" / "_authored"
        for slot in SLOTS:
            n += save(
                auth / f"{slot}_short_idle.png",
                drop_small_islands(short(family, slot)),
                force,
            )
            n += save(auth / f"{slot}_broad_idle.png", broad(family, slot), force)
        for mark in CLASS_MARKS.get(family, ()):
            for slot in ("helm", "chest"):
                n += save(
                    auth / f"{slot}_{mark}_mark_idle.png", emblem(family, slot, mark), force
                )
    print(f"wrote {n} masters")


if __name__ == "__main__":
    main()
