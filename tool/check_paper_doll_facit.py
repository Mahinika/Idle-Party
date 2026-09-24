"""Facit gate: live armor stack must stay close to dressed _src.

Composites the shipped body + overlays (not a gitignored preview PNG), so
CI and a clean checkout actually check looks. See
.cursor/skills/character-paper-doll/SKILL.md.

Also gates the parts the looks facit cannot judge:
- t2 / rogue-mail / healer-plate overlays exist, are 128x128, and differ from
  their t0 peer without losing the silhouette;
- every shared weapon / shield has pixels under its declared grip point;
- gold-master idle classifies into exclusive labels (eyes beat skin);
- `tool/paper_doll_lock.json` pins a hash per shipped PNG, so a re-run of any
  generator that quietly reshapes art fails instead of shipping.

- every family folder holds exactly the manifest (`paper_doll_manifest.py`);
- only the body paints the face; short and broad styles are their own
  drawings, not t0 stretched.

Run with `--relock` after a deliberate art change. The gear build runs this
with `--no-lock` against its staging copy before publishing.
"""
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

from PIL import Image

from build_owned_gear_layers import (
    _chin_y,
    bbox as art_bbox,
    ensure_src,
    face_region,
    is_skin,
    load128,
    load128_pose,
    paint_undertunic,
    sample_face,
)
from paper_doll_classify import check_invariants, classify_src
from paper_doll_manifest import (
    FAMILIES,
    MATERIALS,
    SLOTS,
    STYLES,
    body_files,
    gear_files,
)
from paper_doll_paths import CHAR, REPO, TOOL

LOCK = TOOL / "paper_doll_lock.json"
GRIPS_DART = REPO / "lib" / "visual" / "owned_gear_grips.dart"

# Idle facit gate vs dressed _src. Walk/attack dungeon uses idle overlays on
# poser body clips — not a separate armor extract per anim.
MAX_HARD_DIFF_IDLE = 0.38
BODY_ANIMS = ("idle", "walk", "attack")
OVERLAY_ANIM = "idle"
PREVIEW_TINT = {
    "warrior": (176, 200, 240),  # Protection
    "healer": (112, 200, 255),   # Elemental
    "mage": (208, 128, 255),     # Arcane
    "rogue": (144, 224, 96),     # Beast Mastery
}


def hard_diff_ratio(src: Image.Image, prev: Image.Image) -> float:
    a = src.convert("RGBA").load()
    b = prev.convert("RGBA").load()
    opaque = 0
    hard = 0
    for y in range(128):
        for x in range(128):
            r, g, b_, aa = a[x, y]
            if aa < 40:
                continue
            opaque += 1
            rr, gg, bb, ab = b[x, y]
            if ab < 20:
                hard += 1
                continue
            if abs(r - rr) + abs(g - gg) + abs(b_ - bb) > 90:
                hard += 1
    return hard / max(1, opaque)


def must_exist_128(path: Path) -> str | None:
    if not path.exists():
        return f"missing {path.relative_to(REPO)}"
    im = Image.open(path)
    if im.size != (128, 128):
        return f"size {im.size} (want 128x128) {path.relative_to(REPO)}"
    return None


def armor_stack(
    family: str,
    body_anim: str = "idle",
    body_override: Image.Image | None = None,
) -> Image.Image:
    """Idle overlays on [body_anim] undertunic (facit idle uses body_idle)."""
    gear = CHAR / family / "gear"
    body = body_override or Image.open(
        CHAR / family / f"body_{body_anim}.png"
    ).convert("RGBA")
    layers = [
        Image.open(gear / f"cloak_t0_{OVERLAY_ANIM}.png").convert("RGBA"),
        body,
        Image.open(gear / f"legs_t0_{OVERLAY_ANIM}.png").convert("RGBA"),
        Image.open(gear / f"chest_t0_{OVERLAY_ANIM}.png").convert("RGBA"),
        Image.open(gear / f"hands_t0_{OVERLAY_ANIM}.png").convert("RGBA"),
    ]
    auth_helm = gear / "_authored" / f"helm_t0_{OVERLAY_ANIM}.png"
    if family in ("mage", "healer") or not auth_helm.exists():
        layers.append(Image.open(gear / f"helm_t0_{OVERLAY_ANIM}.png").convert("RGBA"))
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    for layer in layers:
        out = Image.alpha_composite(out, layer)
    return out


def tinted_body_preview(family: str, anim: str = "idle") -> Image.Image:
    """Mirror Flutter's modulate filter on the cloth-only identity mask."""
    body = Image.open(CHAR / family / f"body_{anim}.png").convert("RGBA")
    mask = Image.open(CHAR / family / f"body_tint_{anim}.png").convert("RGBA")
    tr, tg, tb = PREVIEW_TINT[family]
    tinted = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    rim = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    mp, tp, rp = mask.load(), tinted.load(), rim.load()
    for y in range(128):
        for x in range(128):
            r, g, b, a = mp[x, y]
            if a:
                tp[x, y] = (r * tr // 255, g * tg // 255, b * tb // 255, a)
                rp[x, y] = (tr, tg, tb, int(a * 0.72))
    outlined = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2)):
        shifted = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        shifted.paste(rim, (dx, dy), rim)
        outlined = Image.alpha_composite(outlined, shifted)
    return Image.alpha_composite(Image.alpha_composite(outlined, body), tinted)


def high_gear_preview(family: str, material: str = "") -> Image.Image:
    """Equipped t2 stack. Cape behind the body, then armor, then helm."""
    gear = CHAR / family / "gear"
    suffix = f"_{material}" if material else ""
    layers = [
        Image.open(gear / f"cloak{suffix}_t2_idle.png").convert("RGBA"),
        tinted_body_preview(family),
        Image.open(gear / f"legs{suffix}_t2_idle.png").convert("RGBA"),
        Image.open(gear / f"chest{suffix}_t2_idle.png").convert("RGBA"),
        Image.open(gear / f"hands{suffix}_t2_idle.png").convert("RGBA"),
        Image.open(gear / f"helm{suffix}_t2_idle.png").convert("RGBA"),
    ]
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    for layer in layers:
        out = Image.alpha_composite(out, layer)
    return out


def helm_ok(family: str) -> tuple[bool, int]:
    helm = Image.open(CHAR / family / "gear" / "helm_t0_idle.png")
    hb = helm.getbbox()
    helm_w = (hb[2] - hb[0]) if hb else 0
    if family in ("mage", "healer"):
        return helm_w >= 40, helm_w
    auth = CHAR / family / "gear" / "_authored" / "helm_t0_idle.png"
    helm_h = (hb[3] - hb[1]) if hb else 0
    if auth.exists():
        return helm_w >= 20 and helm_h <= 72, helm_w
    return helm_w <= 8, helm_w


def check_classifier() -> list[str]:
    """Classify-then-paint contract on gold-master idle clips."""
    errors: list[str] = []
    for family in FAMILIES:
        clf = classify_src(family, "idle")
        errors.extend(check_invariants(clf, require_eyes=True))
    return errors


def check_files() -> list[str]:
    errors: list[str] = []
    armor = ("cloak_t0", "legs_t0", "chest_t0", "hands_t0", "helm_t0")
    for family in FAMILIES:
        for anim in BODY_ANIMS:
            errors.append(must_exist_128(CHAR / family / f"body_{anim}.png"))
            errors.append(
                must_exist_128(CHAR / family / f"body_tint_{anim}.png")
            )
            errors.append(must_exist_128(CHAR / family / "_src" / f"body_{anim}.png"))
        for stem in armor:
            errors.append(
                must_exist_128(
                    CHAR / family / "gear" / f"{stem}_{OVERLAY_ANIM}.png"
                )
            )
    shared = (
        "sword_t0",
        "staff_t0",
        "dagger_t0",
        "mace_t0",
        "axe_t0",
        "bow_t0",
        "shield_t0",
        "frill_t0",
    )
    for stem in shared:
        errors.append(must_exist_128(CHAR / "gear" / f"{stem}_{OVERLAY_ANIM}.png"))
    return [e for e in errors if e]


def check_race_bodies() -> list[str]:
    """Authored <race>_<m|f>_body_*.png must be 128×128 with a cloth tint."""
    errors: list[str] = []
    for family in FAMILIES:
        folder = CHAR / family
        if not folder.exists():
            continue
        for body in sorted(folder.glob("*_body_*.png")):
            if "_body_tint_" in body.name:
                continue
            errors.append(must_exist_128(body))
            tint_name = body.name.replace("_body_", "_body_tint_", 1)
            tint = folder / tint_name
            errors.append(must_exist_128(tint))
            if body.exists() and tint.exists():
                bp = Image.open(body).convert("RGBA").load()
                tp = Image.open(tint).convert("RGBA").load()
                outside = 0
                painted = 0
                for y in range(128):
                    for x in range(128):
                        if tp[x, y][3] < 40:
                            continue
                        painted += 1
                        if bp[x, y][3] < 40:
                            outside += 1
                if painted < 200:
                    errors.append(
                        f"race tint too sparse ({painted}px) "
                        f"{tint.relative_to(REPO)}"
                    )
                if outside:
                    errors.append(
                        f"race tint leaves body ({outside}px) "
                        f"{tint.relative_to(REPO)}"
                    )
    return [e for e in errors if e]


def check_body_tint_masks() -> list[str]:
    """Spec color may cover undertunic cloth, never face/hair or empty pixels."""
    errors: list[str] = []
    for family in FAMILIES:
        for anim in BODY_ANIMS:
            mask_path = CHAR / family / f"body_tint_{anim}.png"
            body_path = CHAR / family / f"body_{anim}.png"
            src_path = CHAR / family / "_src" / f"body_{anim}.png"
            if not (mask_path.exists() and body_path.exists() and src_path.exists()):
                continue
            mask = Image.open(mask_path).convert("RGBA")
            body = Image.open(body_path).convert("RGBA")
            src = load128(src_path)
            box = art_bbox(src)
            face = sample_face(src, box, family)
            fx, fy, face_half = face_region(src, face, box)
            chin_y = _chin_y(src, face, fx, fy, face_half)
            mp, bp, sp = mask.load(), body.load(), src.load()
            painted = 0
            outside_body = 0
            skin_overlap = 0
            head_overlap = 0
            for y in range(128):
                for x in range(128):
                    if mp[x, y][3] < 40:
                        continue
                    painted += 1
                    if bp[x, y][3] < 40:
                        outside_body += 1
                    r, g, b, a = sp[x, y]
                    if a >= 40 and is_skin((r, g, b), face):
                        skin_overlap += 1
                    if y <= chin_y + 8 and abs(x - fx) <= face_half * 2.4:
                        head_overlap += 1
            # Undertunic is a shirt and two legs, so attack poses are smaller
            # than the old full-robe mask. Still reject an empty crop.
            if painted < 320:
                errors.append(
                    f"body tint mask too sparse ({painted}px) "
                    f"{mask_path.relative_to(REPO)}"
                )
            if outside_body:
                errors.append(
                    f"body tint mask leaves body ({outside_body}px) "
                    f"{mask_path.relative_to(REPO)}"
                )
            if skin_overlap:
                errors.append(
                    f"body tint mask recolors skin ({skin_overlap}px) "
                    f"{mask_path.relative_to(REPO)}"
                )
            if head_overlap:
                errors.append(
                    f"body tint mask enters head/hair ({head_overlap}px) "
                    f"{mask_path.relative_to(REPO)}"
                )
    return errors


MATERIAL_BY_FAMILY = MATERIALS
ARMOR_STEMS = SLOTS
MIN_MATERIAL_SIL_DIFF = 0.12  # native vs cross-material opaque mask
MIN_SQUINT_SIL_DIFF = 0.08  # ~48 px thumbnail still reads different
# Native t2 must grow vs t0 so rare armor isn't a pixel-identical twin.
MIN_T2_GROW = 0.03


def shipped_pngs() -> list[Path]:
    """Every PNG pubspec bundles (registered dirs are non-recursive)."""
    dirs = [CHAR / fam for fam in FAMILIES]
    dirs += [CHAR / fam / "gear" for fam in FAMILIES]
    dirs.append(CHAR / "gear")
    out: list[Path] = []
    for d in dirs:
        if not d.exists():
            continue
        out += [p for p in sorted(d.iterdir()) if p.is_file() and p.suffix == ".png"]
    return out


def alpha_ratio(im: Image.Image) -> float:
    px = im.convert("RGBA").load()
    opaque = 0
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][3] >= 40:
                opaque += 1
    return opaque / float(im.width * im.height)


def silhouette_diff(a: Image.Image, b: Image.Image) -> float:
    """Share of pixels where exactly one of the two images is opaque."""
    if a.size != b.size:
        side = max(a.width, a.height, b.width, b.height)
        a = a.resize((side, side), Image.Resampling.NEAREST)
        b = b.resize((side, side), Image.Resampling.NEAREST)
    pa = a.convert("RGBA").load()
    pb = b.convert("RGBA").load()
    w, h = a.size
    union = 0
    only = 0
    for y in range(h):
        for x in range(w):
            oa = pa[x, y][3] >= 40
            ob = pb[x, y][3] >= 40
            if not (oa or ob):
                continue
            union += 1
            if oa != ob:
                only += 1
    return only / max(1, union)


def palette_diff(a: Image.Image, b: Image.Image) -> float:
    """Mean normalized RGB drift where both tier silhouettes have pixels."""
    pa = a.convert("RGBA").load()
    pb = b.convert("RGBA").load()
    compared = 0
    delta = 0
    for y in range(128):
        for x in range(128):
            ar, ag, ab, aa = pa[x, y]
            br, bg, bb, ba = pb[x, y]
            if aa < 40 or ba < 40:
                continue
            compared += 1
            delta += abs(ar - br) + abs(ag - bg) + abs(ab - bb)
    return delta / max(1, compared * 255 * 3)


def squint_silhouette_diff(a: Image.Image, b: Image.Image, size: int = 48) -> float:
    """Downscale opaque masks — material must still differ at phone icon scale."""
    ma = a.convert("RGBA").resize((size, size), Image.Resampling.NEAREST)
    mb = b.convert("RGBA").resize((size, size), Image.Resampling.NEAREST)
    return silhouette_diff(ma, mb)


def face_cutout_ok(helm: Image.Image, family: str) -> bool:
    """Mail/plate helms must leave a face window (not a solid stamp)."""
    px = helm.convert("RGBA").load()
    bb = helm.getbbox()
    if bb is None:
        return True
    hx0, hy0, hx1, hy1 = bb
    cx = (hx0 + hx1) // 2
    cy = hy0 + int((hy1 - hy0) * 0.55)
    clear = 0
    for y in range(max(0, cy - 10), min(128, cy + 14)):
        for x in range(max(0, cx - 14), min(128, cx + 14)):
            if px[x, y][3] < 40:
                clear += 1
    return clear >= 24


def check_tiers_and_materials() -> list[str]:
    """t2 and material variants must exist and read as their own armor."""
    errors: list[str] = []
    for family in FAMILIES:
        gear = CHAR / family / "gear"
        materials = ("",) + MATERIAL_BY_FAMILY.get(family, ())
        for material in materials:
            var = f"_{material}" if material else ""
            for stem in ARMOR_STEMS:
                t0 = gear / f"{stem}{var}_t0_idle.png"
                t2 = gear / f"{stem}{var}_t2_idle.png"
                for path in (t0, t2):
                    err = must_exist_128(path)
                    if err:
                        errors.append(err)
                if not t0.exists() or not t2.exists():
                    continue
                im0 = Image.open(t0)
                im2 = Image.open(t2)
                if alpha_ratio(im2) < 0.002 and alpha_ratio(im0) >= 0.002:
                    errors.append(
                        f"empty t2 {t2.relative_to(REPO)} (t0 has pixels)"
                    )
                    continue
                if material and alpha_ratio(im0) < 0.002:
                    errors.append(f"empty material {t0.relative_to(REPO)}")
                    continue
                shift = silhouette_diff(im0, im2)
                if shift > 0.62:
                    errors.append(
                        f"t2 silhouette drifted {shift:.2f} "
                        f"{t2.relative_to(REPO)} (want <= 0.62)"
                    )
                if (
                    not material
                    and alpha_ratio(im0) >= 0.01
                    and shift < MIN_T2_GROW
                ):
                    errors.append(
                        f"t2 matches t0 {shift:.2f} "
                        f"{t2.relative_to(REPO)} (want >= {MIN_T2_GROW})"
                    )
                palette = palette_diff(im0, im2)
                if palette > 0.16:
                    errors.append(
                        f"t2 palette drifted {palette:.2f} "
                        f"{t2.relative_to(REPO)} (want <= 0.16)"
                    )
                if material:
                    native = gear / f"{stem}_t0_idle.png"
                    if native.exists():
                        nat = Image.open(native)
                        sil = silhouette_diff(nat, im0)
                        if sil < MIN_MATERIAL_SIL_DIFF:
                            errors.append(
                                f"material silhouette matches native {sil:.2f} "
                                f"{t0.relative_to(REPO)} (want >= "
                                f"{MIN_MATERIAL_SIL_DIFF})"
                            )
                        squint = squint_silhouette_diff(nat, im0)
                        if squint < MIN_SQUINT_SIL_DIFF:
                            errors.append(
                                f"material squint matches native {squint:.2f} "
                                f"{t0.relative_to(REPO)} (want >= "
                                f"{MIN_SQUINT_SIL_DIFF})"
                            )
                if stem == "helm" and alpha_ratio(im0) >= 0.01:
                    if not face_cutout_ok(im0, family):
                        errors.append(
                            f"helm face cutout missing "
                            f"{t0.relative_to(REPO)}"
                        )
    return errors


MIN_STYLE_SIL_DIFF = 0.12


def stretched_to(im: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    """[im]'s opaque shape resized onto [box] — what a lazy rescale would be."""
    bb = im.getbbox()
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    if bb is None:
        return out
    w, h = max(1, box[2] - box[0]), max(1, box[3] - box[1])
    crop = im.crop(bb).resize((w, h), Image.Resampling.NEAREST)
    out.paste(crop, (box[0], box[1]), crop)
    return out


def check_styles() -> list[str]:
    """Short and broad are drawings of their own that sit where the piece sits."""
    errors: list[str] = []
    for family in FAMILIES:
        gear = CHAR / family / "gear"
        for slot in SLOTS:
            t0 = Image.open(gear / f"{slot}_t0_idle.png").convert("RGBA")
            t0_box = t0.getbbox()
            for style in STYLES:
                path = gear / f"{slot}_{style}_idle.png"
                err = must_exist_128(path)
                if err:
                    errors.append(err)
                    continue
                im = Image.open(path).convert("RGBA")
                box = im.getbbox()
                if box is None or alpha_ratio(im) < 0.004:
                    errors.append(f"empty style {path.relative_to(REPO)}")
                    continue
                rel = path.relative_to(REPO)
                plain = silhouette_diff(im, t0)
                if plain < MIN_STYLE_SIL_DIFF:
                    errors.append(f"style matches t0 {plain:.2f} {rel}")
                stretch = silhouette_diff(im, stretched_to(t0, box))
                if stretch < MIN_STYLE_SIL_DIFF:
                    errors.append(f"style is t0 stretched {stretch:.2f} {rel}")
                if t0_box is None:
                    continue
                x0, y0, x1, y1 = t0_box
                pad = 18
                px = im.load()
                total = inside = 0
                for y in range(128):
                    for x in range(128):
                        if px[x, y][3] < 40:
                            continue
                        total += 1
                        if x0 - pad <= x < x1 + pad and y0 - pad <= y < y1 + pad:
                            inside += 1
                if inside < total * 0.85:
                    errors.append(
                        f"style sits off its slot ({inside}/{total} near t0) {rel}"
                    )
    return errors


def check_manifest() -> list[str]:
    """Family folders hold exactly the manifest — no orphans, no gaps."""
    errors: list[str] = []
    for family in FAMILIES:
        for folder, want in (
            (CHAR / family, body_files(family)),
            (CHAR / family / "gear", gear_files(family)),
        ):
            have = {p.name for p in folder.glob("*.png")}
            for name in sorted(want - have):
                errors.append(f"missing {folder.relative_to(CHAR).as_posix()}/{name}")
            for name in sorted(have - want):
                errors.append(f"orphan {folder.relative_to(CHAR).as_posix()}/{name}")
    return errors


def face_mask(family: str, *, window: bool = False) -> set[tuple[int, int]]:
    """Idle face pixels the body owns: skin, eyes, and ink, never hair.

    [window] narrows it to the face oval a helm must leave open.
    """
    from build_owned_gear_layers import idle_classification
    from paper_doll_classify import HAIR, _face_oval, is_head_identity

    clf = idle_classification(family)
    return {
        (x, y)
        for y in range(128)
        for x in range(128)
        if is_head_identity(clf, x, y)
        and clf.at(x, y) != HAIR
        and (not window or _face_oval(clf, x, y))
    }


def check_face_ownership() -> list[str]:
    """Only the body paints the face. Helms keep a window over it."""
    errors: list[str] = []
    for family in FAMILIES:
        mask = face_mask(family)
        window = face_mask(family, window=True)
        if len(window) < 60:
            errors.append(f"{family} face window too small ({len(window)}px)")
            continue
        body = Image.open(CHAR / family / "body_idle.png").convert("RGBA").load()
        bare = sum(1 for x, y in mask if body[x, y][3] < 40)
        if bare > len(mask) // 20:
            errors.append(f"{family} body is missing {bare}px of its face")
        for path in sorted((CHAR / family / "gear").glob("*_idle.png")):
            stem = path.name.split("_", 1)[0]
            if stem not in ARMOR_STEMS:
                continue
            px = Image.open(path).convert("RGBA").load()
            owned = window if stem == "helm" else mask
            hit = sum(1 for x, y in owned if px[x, y][3] >= 40)
            if hit:
                where = "face window" if stem == "helm" else "face"
                errors.append(f"{path.relative_to(REPO)} covers {hit}px of the {where}")
    return errors


def pixels_differ(a: Image.Image, b: Image.Image) -> int:
    if a.size != b.size:
        return 10**9
    pa, pb = a.convert("RGBA").load(), b.convert("RGBA").load()
    n = 0
    for y in range(a.height):
        for x in range(a.width):
            if pa[x, y] != pb[x, y]:
                n += 1
    return n


def check_draw_order() -> list[str]:
    """Phone stack must keep the cape behind the body, like this gate."""
    path = REPO / "lib" / "visual" / "character_layer.dart"
    text = path.read_text(encoding="utf-8")
    match = re.search(
        r"kOwnedLayerOrder = <CharacterLayerId>\[(.*?)\]",
        text,
        re.S,
    )
    if match is None:
        return ["could not parse kOwnedLayerOrder"]
    ids = re.findall(r"CharacterLayerId\.(\w+)", match.group(1))
    need = ("cape", "body", "legs", "torso", "gloves", "head")
    try:
        pos = [ids.index(name) for name in need]
    except ValueError as exc:
        return [f"owned draw order missing a layer: {exc}"]
    if pos != sorted(pos):
        return ["owned cape/body/armor order drifted: " + ", ".join(ids)]
    return []


def check_pose_bodies() -> list[str]:
    """Every body clip must match a fresh bake of that gold-master anim."""
    errors: list[str] = []
    for family in FAMILIES:
        for anim in BODY_ANIMS:
            src = load128_pose(ensure_src(family, anim))
            box = art_bbox(src)
            face = sample_face(src, box, family)
            body, tint = paint_undertunic(src, family, face, box, anim=anim)
            live_body = Image.open(CHAR / family / f"body_{anim}.png").convert("RGBA")
            live_tint = Image.open(
                CHAR / family / f"body_tint_{anim}.png"
            ).convert("RGBA")
            body_px = pixels_differ(body, live_body)
            tint_px = pixels_differ(tint, live_tint)
            if body_px:
                errors.append(
                    f"{family} {anim} body drifted {body_px}px from gold-master bake"
                )
            if tint_px:
                errors.append(
                    f"{family} {anim} tint drifted {tint_px}px from gold-master bake"
                )
    return errors


def check_race_bake() -> list[str]:
    """Race LOOK clips must match a fresh bake of the current gold master."""
    from paint_race_bodies import RACES, paint_undertunic_body

    errors: list[str] = []
    for family in FAMILIES:
        for look in RACES:
            for sex, female in (("m", False), ("f", True)):
                for anim in BODY_ANIMS:
                    body, tint = paint_undertunic_body(
                        family, anim, look, female=female
                    )
                    body_path = CHAR / family / f"{look.key}_{sex}_body_{anim}.png"
                    tint_path = (
                        CHAR / family / f"{look.key}_{sex}_body_tint_{anim}.png"
                    )
                    if not body_path.exists() or not tint_path.exists():
                        errors.append(
                            f"missing race clip {family}/{look.key}_{sex}_{anim}"
                        )
                        continue
                    body_px = pixels_differ(
                        body, Image.open(body_path).convert("RGBA")
                    )
                    tint_px = pixels_differ(
                        tint, Image.open(tint_path).convert("RGBA")
                    )
                    if body_px or tint_px:
                        errors.append(
                            f"race drift {family} {look.key} {sex} {anim} "
                            f"body={body_px}px tint={tint_px}px"
                        )
    return errors


def parse_grips() -> dict[str, tuple[float, float]]:
    text = GRIPS_DART.read_text(encoding="utf-8")
    out: dict[str, tuple[float, float]] = {}
    for m in re.finditer(
        r"'([a-z0-9_]+)':\s*Offset\(([0-9.]+),\s*([0-9.]+)\)", text
    ):
        out[m.group(1)] = (float(m.group(2)), float(m.group(3)))
    return out


def check_hand_items() -> list[str]:
    """Each weapon/shield needs pixels where the code grabs it."""
    errors: list[str] = []
    grips = parse_grips()
    if not grips:
        return ["no grips parsed from owned_gear_grips.dart"]
    for set_id, (gx, gy) in sorted(grips.items()):
        path = CHAR / "gear" / f"{set_id}_idle.png"
        err = must_exist_128(path)
        if err:
            errors.append(err)
            continue
        im = Image.open(path).convert("RGBA")
        px = im.load()
        cx, cy = int(gx * 128), int(gy * 128)
        near = 0
        for y in range(max(0, cy - 6), min(128, cy + 7)):
            for x in range(max(0, cx - 6), min(128, cx + 7)):
                if px[x, y][3] >= 40:
                    near += 1
        if near == 0:
            errors.append(
                f"grip ({gx:.3f},{gy:.3f}) hits empty pixels in "
                f"{path.relative_to(REPO)}"
            )
    return errors


def check_lock(relock: bool) -> list[str]:
    """Pin art bytes so a stray generator run cannot ship silently."""
    current = {
        str(p.relative_to(REPO)).replace("\\", "/"): hashlib.sha256(
            p.read_bytes()
        ).hexdigest()
        for p in shipped_pngs()
    }
    if relock or not LOCK.exists():
        LOCK.write_text(
            json.dumps(current, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        print(f"{'relocked' if relock else 'wrote'} {LOCK.relative_to(REPO)} "
              f"({len(current)} files)")
        return []
    locked = json.loads(LOCK.read_text(encoding="utf-8"))
    errors: list[str] = []
    for name, digest in sorted(locked.items()):
        if name not in current:
            errors.append(f"art removed: {name}")
        elif current[name] != digest:
            errors.append(f"art changed without --relock: {name}")
    for name in sorted(set(current) - set(locked)):
        errors.append(f"art added without --relock: {name}")
    return errors


def main() -> int:
    relock = "--relock" in sys.argv
    failed = 0
    for msg in check_files():
        print("FAIL", msg)
        failed += 1
    for msg in check_classifier():
        print("FAIL", msg)
        failed += 1
    for msg in check_race_bodies():
        print("FAIL", msg)
        failed += 1
    for msg in check_body_tint_masks():
        print("FAIL", msg)
        failed += 1
    for msg in check_pose_bodies():
        print("FAIL", msg)
        failed += 1
    for msg in check_race_bake():
        print("FAIL", msg)
        failed += 1
    for msg in check_draw_order():
        print("FAIL", msg)
        failed += 1
    for msg in check_tiers_and_materials():
        print("FAIL", msg)
        failed += 1
    for msg in check_face_ownership():
        print("FAIL", msg)
        failed += 1
    for msg in check_styles():
        print("FAIL", msg)
        failed += 1
    for msg in check_manifest():
        print("FAIL", msg)
        failed += 1
    for msg in check_hand_items():
        print("FAIL", msg)
        failed += 1
    if "--no-lock" not in sys.argv:
        for msg in check_lock(relock):
            print("FAIL", msg)
            failed += 1

    print("IDLE (gated)")
    for family in FAMILIES:
        src_path = CHAR / family / "_src" / "body_idle.png"
        if not src_path.exists():
            continue
        try:
            stack = armor_stack(family, "idle")
        except FileNotFoundError as exc:
            print("FAIL", family, "stack", exc)
            failed += 1
            continue
        TOOL.mkdir(parents=True, exist_ok=True)
        stack.save(TOOL / f"preview_doll_{family}.png")
        armor_stack(
            family,
            "idle",
            body_override=tinted_body_preview(family),
        ).save(TOOL / f"preview_doll_{family}_identity.png")
        high_gear_preview(family).save(
            TOOL / f"preview_doll_{family}_high.png"
        )
        for mat in MATERIAL_BY_FAMILY.get(family, ()):
            high_gear_preview(family, mat).save(
                TOOL / f"preview_doll_{family}_{mat}_high.png"
            )
        src = Image.open(src_path)
        ratio = hard_diff_ratio(src, stack)
        ok_helm, helm_w = helm_ok(family)
        status = "ok" if ratio <= MAX_HARD_DIFF_IDLE and ok_helm else "FAIL"
        print(
            status,
            family,
            f"diff={ratio:.3f}",
            f"helm_w={helm_w}",
            f"limit={MAX_HARD_DIFF_IDLE}",
        )
        if status == "FAIL":
            failed += 1

    if failed:
        print(f"{failed} facit check(s) failed")
        return 1
    print("facit ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
