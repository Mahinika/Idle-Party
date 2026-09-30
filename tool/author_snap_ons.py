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
        master = auth / f"{name}_master.png"
        if master.exists():
            out = _load(master)
        else:
            out = _helm_motif(out, name)
        live = gear / f"{name}_idle.png"
        out.save(live)
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


def _helm_motif(im: Image.Image, name: str) -> Image.Image:
    """A chunky crown, visor, or wings so the named helm is not a recolor."""
    out = im.copy()
    px = out.load()
    bb = out.getbbox()
    if bb is None:
        return out
    x0, y0, x1, y1 = bb
    cx = (x0 + x1) // 2
    color = (168, 156, 142, 255)

    def put(x: int, y: int) -> None:
        if 0 <= x < N and 0 <= y < N:
            px[x, y] = color

    if name == "helm_ironcrown":
        # Hoods already touch the top of the canvas, so the crown hangs
        # below the brim. Gaps cut into the hood get filled back in.
        for dx in (-20, 0, 20):
            left = max(2, min(N - 12, cx + dx - 4))
            for dy in range(22):
                for ox in range(8):
                    put(left + ox, min(N - 1, y1 - 2 + dy))
    elif name == "helm_visored":
        for side in (-1, 1):
            for dy in range(22):
                for ox in range(8):
                    put(cx + side * (16 + ox), y0 + 4 + dy)
        for x in range(x0 + 4, x1 - 4):
            if abs(x - cx) < 10:
                continue
            for dy in range(5):
                put(x, max(0, y0 - 2) + dy)
    elif name == "helm_wingcrest":
        # Feathers hang below the helm. Sideways wings fall off the canvas
        # on wide hoods.
        for side in (-1, 1):
            ox = x0 + 8 if side < 0 else x1 - 14
            ox = max(2, min(N - 16, ox))
            for dy in range(26):
                span = 8 if dy < 16 else 4
                for t in range(span):
                    put(ox + t, min(N - 1, y1 - 6 + dy))
    return out


def _grow_pauldron(im: Image.Image, passes: int) -> Image.Image:
    """Add a rim so the late pauldron is a bigger shape than the plain one."""
    out = im
    for _ in range(passes):
        alpha = out.split()[-1].filter(ImageFilter.MaxFilter(3))
        grown = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        gp, sp, ap = grown.load(), out.load(), alpha.load()
        for y in range(N):
            for x in range(N):
                if ap[x, y] == 0:
                    continue
                if sp[x, y][3] >= 40:
                    gp[x, y] = sp[x, y]
                    continue
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < N and 0 <= ny < N and sp[nx, ny][3] >= 40:
                        gp[x, y] = sp[nx, ny]
                        break
        out = grown
    return out


def write_shoulders(family: str) -> int:
    gear = ROOT / family / "gear"
    auth = gear / "_authored"
    auth.mkdir(parents=True, exist_ok=True)
    core = _load(gear / "chest_t0_idle.png")
    n = 0
    # Donor per cut: prefer matching chest cut, fall back to broad then t2.
    donors = {
        "t0": ["chest_t2_idle.png", "chest_broad_idle.png"],
        "t2": ["chest_t2_idle.png", "chest_broad_idle.png"],
        "short": ["chest_short_idle.png", "chest_broad_idle.png"],
        "broad": ["chest_broad_idle.png", "chest_t2_idle.png"],
    }
    for cut in CUTS:
        # t2 swells further, so the pauldron left outside the chest is a new shape.
        swollen = _swollen_core(core, radius=8 if cut == "t2" else 4)
        sp = swollen.load()
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
        if cut == "t2":
            out = _grow_pauldron(out, passes=5)
        elif cut == "short":
            # A one-pixel pauldron is only outline, so mail and leather vanish.
            out = _grow_pauldron(out, passes=4)
        stem = f"shoulder_{cut}"
        master = auth / f"{stem}_master.png"
        if master.exists():
            out = _load(master)
        out.save(gear / f"{stem}_idle.png")
        n += 1
        for mat in MATERIALS[family]:
            from gear_style import paint_material

            mat_im = paint_material(out, mat)
            mstem = f"shoulder_{mat}_{cut}"
            mat_im.save(gear / f"{mstem}_idle.png")
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
