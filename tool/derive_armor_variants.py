"""20 armor cuts per slot, from pixels we already own.

No new geometry. Five widths times four palettes. Class sets (paladin,
death knight, warlock) keep that class color and vary width and shade.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageEnhance

REPO = Path(__file__).resolve().parents[1]
ROOT = REPO / "assets" / "custom" / "char"
SLOTS = ("helm", "chest", "legs", "cloak", "hands")
SCALES = (0.70, 0.84, 1.0, 1.16, 1.32)
COUNT = 20

# family -> extra material stems that already exist as extracts
MATERIALS = {
    "warrior": ("leather",),
    "rogue": ("mail",),
    "healer": ("plate", "mail", "leather"),
    "mage": ("mail", "leather"),
}

# class mark, family folder, materials to vary (native plus these)
CLASSES = (
    ("paladin", "warrior", ("leather",)),
    ("deathknight", "warrior", ("leather",)),
    ("warlock", "mage", ("mail", "leather")),
)


def load(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    if im.size != (128, 128):
        raise SystemExit(f"expected 128: {path}")
    return im


def scale_wider(im: Image.Image, sx: float) -> Image.Image:
    if abs(sx - 1.0) < 0.01:
        return im.copy()
    box = im.getbbox()
    if box is None:
        return im.copy()
    crop = im.crop(box)
    width = max(1, min(128, int(round(crop.width * sx))))
    scaled = crop.resize((width, crop.height), Image.Resampling.NEAREST)
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    cx = (box[0] + box[2]) // 2
    x = max(0, min(128 - width, cx - width // 2))
    out.paste(scaled, (x, box[1]), scaled)
    return out


def ramp(im: Image.Image, fn) -> Image.Image:
    if fn is None:
        return im
    out = im.copy()
    px = out.load()
    for y in range(128):
        for x in range(128):
            r, g, b, a = px[x, y]
            if a < 12:
                continue
            px[x, y] = (*fn(r, g, b), a)
    return out


def steel(r, g, b):
    return (min(255, int(r * 0.55 + 12)), min(255, int(g * 0.68 + 22)), min(255, int(b * 0.82 + 36)))


def brass(r, g, b):
    return (min(255, int(r * 0.78 + 36)), min(255, int(g * 0.62 + 18)), min(255, int(b * 0.48 + 8)))


def crimson(r, g, b):
    return (min(255, int(r * 0.70 + 48)), min(255, int(g * 0.38 + 8)), min(255, int(b * 0.40 + 12)))


def verdant(r, g, b):
    return (min(255, int(r * 0.45 + 10)), min(255, int(g * 0.72 + 28)), min(255, int(b * 0.42 + 10)))


def gold(r, g, b):
    return (min(255, int(r * 0.62 + 78)), min(255, int(g * 0.50 + 52)), min(255, int(b * 0.34 + 18)))


def dusk(r, g, b):
    return (min(255, int(r * 0.28 + 18)), min(255, int(g * 0.30 + 16)), min(255, int(b * 0.42 + 28)))


def shadow(r, g, b):
    return (min(255, int(r * 0.34 + 22)), min(255, int(g * 0.22 + 8)), min(255, int(b * 0.40 + 24)))


def darker(r, g, b):
    return (int(r * 0.72), int(g * 0.72), int(b * 0.72))


def brighter(r, g, b):
    return (min(255, int(r * 1.12 + 8)), min(255, int(g * 1.12 + 8)), min(255, int(b * 1.12 + 8)))


def punch(r, g, b):
    return (
        min(255, int((r - 128) * 1.25 + 128)),
        min(255, int((g - 128) * 1.25 + 128)),
        min(255, int((b - 128) * 1.25 + 128)),
    )


PALETTES = (None, steel, brass, crimson)
SHADES = (darker, None, brighter, punch)
CLASS_RAMP = {"paladin": gold, "deathknight": dusk, "warlock": shadow}


def write(folder: Path, stem: str, im: Image.Image) -> None:
    path = folder / f"{stem}_idle.png"
    im.save(path)


def variants(src: Image.Image, shades) -> list[Image.Image]:
    out = []
    for scale in SCALES:
        shaped = scale_wider(src, scale)
        for shade in shades:
            out.append(ramp(shaped, shade))
    if len(out) != COUNT:
        raise SystemExit(f"expected {COUNT}, got {len(out)}")
    return out


def emit(folder: Path, stem_for, src: Image.Image, shades) -> None:
    for i, im in enumerate(variants(src, shades)):
        write(folder, stem_for(f"{i:02d}"), im)


def main() -> None:
    n = 0
    for family, mats in MATERIALS.items():
        folder = ROOT / family / "gear"
        for slot in SLOTS:
            native = load(folder / f"{slot}_t0_idle.png")
            emit(folder, lambda nn, slot=slot: f"{slot}_v{nn}", native, PALETTES)
            n += COUNT
            for mat in mats:
                src = load(folder / f"{slot}_{mat}_t0_idle.png")
                emit(
                    folder,
                    lambda nn, slot=slot, mat=mat: f"{slot}_{mat}_v{nn}",
                    src,
                    PALETTES,
                )
                n += COUNT
    for mark, family, mats in CLASSES:
        folder = ROOT / family / "gear"
        base_ramp = CLASS_RAMP[mark]
        for slot in SLOTS:
            native = ramp(load(folder / f"{slot}_t0_idle.png"), base_ramp)
            emit(
                folder,
                lambda nn, slot=slot, mark=mark: f"{slot}_{mark}_v{nn}",
                native,
                SHADES,
            )
            n += COUNT
            for mat in mats:
                src = ramp(load(folder / f"{slot}_{mat}_t0_idle.png"), base_ramp)
                emit(
                    folder,
                    lambda nn, slot=slot, mark=mark, mat=mat: f"{slot}_{mark}_{mat}_v{nn}",
                    src,
                    SHADES,
                )
                n += COUNT
    # Rogue has no extra class, but leather is its native look (already emitted).
    print(f"wrote {n} variants")


if __name__ == "__main__":
    main()
