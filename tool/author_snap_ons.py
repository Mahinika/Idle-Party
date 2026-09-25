"""Snap-ons + cloth dye masks from owned gear pixels (no invented geometry).

Named helms: remaster existing short/broad/t0 masters with distinct ramps
and light compositing from owned art — same idea as sword_thunderfury, but
sourced from the family's helm masters.

Shoulders: pauldron tips = opaque pixels in chest_broad (or chest_t2) that
are outside a swollen chest_t0 core.

Dye masks: chroma cloth/trim on chest overlays (metal and gold stay clear).

Writes live `gear/*_idle.png` plus `_authored` copies so the gear build
keeps them. Called from build_owned_gear_layers after styles.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter

from paper_doll_manifest import CUTS, FAMILIES, MATERIALS, NAMED_HELMS
from paper_doll_paths import CHAR as ROOT

N = 128


def _load(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def _ramp(im: Image.Image, fn) -> Image.Image:
    out = im.copy()
    px = out.load()
    for y in range(N):
        for x in range(N):
            r, g, b, a = px[x, y]
            if a < 12:
                continue
            px[x, y] = (*fn(r, g, b), a)
    return out


def _bronze(r: int, g: int, b: int) -> tuple[int, int, int]:
    lum = (0.30 * r + 0.59 * g + 0.11 * b) / 255.0
    return (
        min(255, int(70 + lum * 140)),
        min(255, int(48 + lum * 95)),
        min(255, int(28 + lum * 55)),
    )


def _steel(r: int, g: int, b: int) -> tuple[int, int, int]:
    lum = (0.30 * r + 0.59 * g + 0.11 * b) / 255.0
    return (
        min(255, int(48 + lum * 150)),
        min(255, int(55 + lum * 155)),
        min(255, int(68 + lum * 165)),
    )


def _crimson(r: int, g: int, b: int) -> tuple[int, int, int]:
    lum = (0.30 * r + 0.59 * g + 0.11 * b) / 255.0
    return (
        min(255, int(90 + lum * 140)),
        min(255, int(28 + lum * 55)),
        min(255, int(36 + lum * 60)),
    )


def _composite_owned(base: Image.Image, accent: Image.Image, keep_face: bool) -> Image.Image:
    """Stack two owned helms; keep the base face window when asked."""
    out = base.copy()
    bp, ap, op = base.load(), accent.load(), out.load()
    for y in range(N):
        for x in range(N):
            ar, ag, ab, aa = ap[x, y]
            if aa < 40:
                continue
            br, bg, bb, ba = bp[x, y]
            if keep_face and ba < 40 and 40 < y < 60 and 45 < x < 85:
                continue
            # Outer silhouette only: prefer accent where base is empty or edge.
            if ba < 40 or x < 38 or x > 90 or y < 8:
                op[x, y] = (ar, ag, ab, aa)
    return out


def write_named_helms(family: str) -> int:
    gear = ROOT / family / "gear"
    auth = gear / "_authored"
    auth.mkdir(parents=True, exist_ok=True)
    masters = {
        "short": gear / "helm_short_idle.png",
        "broad": gear / "helm_broad_idle.png",
        "t0": gear / "helm_t0_idle.png",
        "t2": gear / "helm_t2_idle.png",
    }
    for p in masters.values():
        if not p.exists():
            raise SystemExit(f"missing helm master {p}")
    recipes = {
        "helm_ironcrown": ("broad", _bronze, "broad"),
        "helm_visored": ("short", _steel, "t0"),
        "helm_wingcrest": ("t2", _crimson, "broad"),
    }
    n = 0
    for name, (base_key, ramp, accent_key) in recipes.items():
        if name not in NAMED_HELMS:
            continue
        base = _load(masters[base_key])
        accent = _load(masters[accent_key])
        mixed = _composite_owned(base, accent, keep_face=True)
        out = ImageEnhance.Contrast(_ramp(mixed, ramp)).enhance(1.08)
        live = gear / f"{name}_idle.png"
        authored = auth / f"{name}_idle.png"
        out.save(live)
        out.save(authored)
        n += 1
    return n


def _swollen_core(core: Image.Image, radius: int = 3) -> Image.Image:
    """Alpha inflate so pauldron tips sit outside the plain chest."""
    a = core.split()[-1]
    for _ in range(radius):
        a = a.filter(ImageFilter.MaxFilter(3))
    out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    out.putalpha(a)
    return out


def write_shoulders(family: str) -> int:
    gear = ROOT / family / "gear"
    auth = gear / "_authored"
    auth.mkdir(parents=True, exist_ok=True)
    core = _load(gear / "chest_t0_idle.png")
    swollen = _swollen_core(core, radius=4)
    sp = swollen.load()
    n = 0
    # Donor per cut: prefer matching chest cut, fall back to broad then t2.
    donors = {
        "t0": ["chest_t2_idle.png", "chest_broad_idle.png"],
        "t2": ["chest_t2_idle.png", "chest_broad_idle.png"],
        "short": ["chest_short_idle.png", "chest_broad_idle.png"],
        "broad": ["chest_broad_idle.png", "chest_t2_idle.png"],
    }
    for cut in CUTS:
        donor = None
        for name in donors[cut]:
            p = gear / name
            if p.exists():
                donor = _load(p)
                break
        if donor is None:
            raise SystemExit(f"no shoulder donor for {family} {cut}")
        out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        dp, op = donor.load(), out.load()
        for y in range(N):
            for x in range(N):
                r, g, b, a = dp[x, y]
                if a < 40:
                    continue
                if sp[x, y][3] >= 40:
                    continue
                # Keep upper-side pauldrons; drop robe hem leftovers.
                if y > 78:
                    continue
                op[x, y] = (r, g, b, a)
        if out.getbbox() is None:
            # Fallback: side bands of the donor chest.
            for y in range(28, 72):
                for x in range(N):
                    r, g, b, a = dp[x, y]
                    if a < 40:
                        continue
                    if x < 28 or x > 99:
                        op[x, y] = (r, g, b, a)
        # Phone-readable snap-ons: thicken sparse pauldron tips.
        opaque = sum(1 for p in out.split()[-1].getdata() if p > 24)
        if opaque < 40:
            out = ImageEnhance.Contrast(out).enhance(1.0)
            # Grow alpha from donor sides more aggressively.
            for y in range(24, 76):
                for x in range(N):
                    r, g, b, a = dp[x, y]
                    if a < 50:
                        continue
                    if x < 34 or x > 93:
                        if op[x, y][3] < 40:
                            op[x, y] = (r, g, b, min(255, a))
            # One-pixel thicken.
            from derive_armor_material_variants import thicken

            out = thicken(out, passes=2)
        stem = f"shoulder_{cut}"
        out.save(gear / f"{stem}_idle.png")
        out.save(auth / f"{stem}_idle.png")
        n += 1
        for mat in MATERIALS[family]:
            # Material shoulders: ramp the native pauldron (shape first).
            from derive_armor_material_variants import CONVERTERS

            mat_im = CONVERTERS[mat](out)
            mstem = f"shoulder_{mat}_{cut}"
            mat_im.save(gear / f"{mstem}_idle.png")
            mat_im.save(auth / f"{mstem}_idle.png")
            n += 1
    return n


def _is_goldish(r: int, g: int, b: int) -> bool:
    return r > 110 and g > 70 and b < 90 and r >= g >= b


def dye_mask_from_chest(chest: Image.Image) -> Image.Image:
    """Cloth/trim mask: chroma fabric, not steel or gold trim."""
    mask = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    cp, mp = chest.load(), mask.load()
    for y in range(N):
        for x in range(N):
            r, g, b, a = cp[x, y]
            if a < 40:
                continue
            if _is_goldish(r, g, b):
                continue
            chroma = max(r, g, b) - min(r, g, b)
            if chroma < 28:
                continue
            shade = max(88, min(255, int(88 + (0.30 * r + 0.59 * g + 0.11 * b) * 0.9)))
            mp[x, y] = (shade, shade, shade, a)
    return mask


def write_dye_masks(family: str) -> int:
    gear = ROOT / family / "gear"
    n = 0
    looks = [""] + [f"{m}_" for m in MATERIALS[family]]
    for look in looks:
        for cut in CUTS:
            src = gear / f"chest_{look}{cut}_idle.png"
            if not src.exists():
                continue
            mask = dye_mask_from_chest(_load(src))
            if mask.getbbox() is None:
                continue
            dest = gear / f"chest_{look}{cut}_dye.png"
            mask.save(dest)
            n += 1
    return n


def write_family(family: str) -> dict[str, int]:
    return {
        "helms": write_named_helms(family),
        "shoulders": write_shoulders(family),
        "dyes": write_dye_masks(family),
    }


def write_all() -> dict[str, dict[str, int]]:
    return {family: write_family(family) for family in FAMILIES}


if __name__ == "__main__":
    for family, counts in write_all().items():
        print("ok", family, counts)
