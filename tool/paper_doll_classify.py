"""Exclusive semantic labels for the paper-doll bake.

Industry pattern (LayerForge / palette-swap / connected components):
classify every gold-master pixel into one label, *then* paint. Never recolor
while guessing. Eyes beat skin. Original RGB is kept for identity labels.

Labels are mutually exclusive. Downstream paint/extract only reads tags.
"""
from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from pathlib import Path

from PIL import Image

from build_owned_gear_layers import (
    ANIMS,
    FAMILIES,
    ROOT,
    TUNIC,
    bbox,
    despeckle_alpha,
    ensure_src,
    face_region,
    flat_undertunic_pixel,
    is_gold_pixel,
    is_hair_color,
    is_hat_lining,
    is_hat_or_hood,
    is_metal_or_trim,
    is_skin,
    load128,
    load128_pose,
    lum,
    recolor_to_cloth,
    sample_face,
    strip_equipped_helm_from_body,
    _chin_y,
)

# Exclusive tags. First-claim order is applied in classify(), not this numbering.
EMPTY = 0
EYE = 1
SKIN = 2
HAIR = 3
INK = 4
HELM = 5
ARMOR = 6
CLOTH = 7
UNSET = 255

IDENTITY = frozenset({EYE, SKIN, HAIR, INK})
GARMENT = frozenset({ARMOR, CLOTH})

LABEL_RGB = {
    EMPTY: (0, 0, 0, 0),
    EYE: (40, 220, 255, 255),
    SKIN: (232, 176, 140, 255),
    HAIR: (96, 64, 40, 255),
    INK: (28, 22, 48, 255),
    HELM: (80, 70, 200, 255),
    ARMOR: (196, 160, 64, 255),
    CLOTH: (160, 140, 110, 255),
}

N = 128
_NEIGH8 = (
    (-1, 0),
    (1, 0),
    (0, -1),
    (0, 1),
    (-1, -1),
    (1, -1),
    (-1, 1),
    (1, 1),
)


def rgb_to_ycc(r: int, g: int, b: int) -> tuple[float, float, float]:
    """BT.601 YCbCr — chroma independent of luma (skin stays stable in shade)."""
    y = 0.299 * r + 0.587 * g + 0.114 * b
    cb = 128.0 - 0.168736 * r - 0.331264 * g + 0.5 * b
    cr = 128.0 + 0.5 * r - 0.418688 * g - 0.081312 * b
    return y, cb, cr


def chroma_near_face(rgb: tuple[int, int, int], face: tuple[int, int, int], max_d: float = 26.0) -> bool:
    _, cb, cr = rgb_to_ycc(*rgb)
    _, fcb, fcr = rgb_to_ycc(*face)
    return (cb - fcb) ** 2 + (cr - fcr) ** 2 <= max_d * max_d


@dataclass(frozen=True)
class Classification:
    src: Image.Image
    family: str
    labels: list[list[int]]
    face: tuple[int, int, int]
    box: tuple[int, int, int, int]
    fx: float
    fy: float
    face_half: float
    chin_y: float
    anim: str = "idle"

    def at(self, x: int, y: int) -> int:
        return self.labels[y][x]

    def count(self, tag: int) -> int:
        return sum(1 for row in self.labels for v in row if v == tag)

    def dump_preview(self, path: Path) -> None:
        im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        px = im.load()
        for y in range(N):
            for x in range(N):
                px[x, y] = LABEL_RGB.get(self.labels[y][x], (255, 0, 255, 255))
        path.parent.mkdir(parents=True, exist_ok=True)
        im.save(path)


def _new_grid(fill: int) -> list[list[int]]:
    return [[fill] * N for _ in range(N)]


def _new_bool() -> list[list[bool]]:
    return [[False] * N for _ in range(N)]


def _flood(cand: list[list[bool]], seeds: list[tuple[int, int]], blocked: list[list[int]] | None = None) -> list[list[bool]]:
    """8-connected fill through cand, never into already-claimed IDENTITY/HELM."""
    out = _new_bool()
    seen = _new_bool()
    q: deque[tuple[int, int]] = deque(seeds)
    while q:
        x, y = q.popleft()
        if not (0 <= x < N and 0 <= y < N) or seen[y][x]:
            continue
        seen[y][x] = True
        if not cand[y][x]:
            continue
        if blocked is not None and blocked[y][x] not in (EMPTY, UNSET):
            continue
        out[y][x] = True
        for dx, dy in _NEIGH8:
            q.append((x + dx, y + dy))
    return out


def _claim(labels: list[list[int]], mask: list[list[bool]], tag: int) -> None:
    for y in range(N):
        row = labels[y]
        m = mask[y]
        for x in range(N):
            if m[x] and row[x] == UNSET:
                row[x] = tag


def _despeckle_labels(labels: list[list[int]], min_area: int = 3) -> None:
    """Merge tiny 8-connected blobs into the neighbor majority (ImageMagick-style)."""
    seen = _new_bool()
    for y0 in range(N):
        for x0 in range(N):
            tag = labels[y0][x0]
            if tag in (EMPTY, UNSET) or seen[y0][x0]:
                continue
            blob: list[tuple[int, int]] = []
            q: deque[tuple[int, int]] = deque([(x0, y0)])
            seen[y0][x0] = True
            while q:
                x, y = q.popleft()
                blob.append((x, y))
                for dx, dy in _NEIGH8:
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < N and 0 <= ny < N) or seen[ny][nx]:
                        continue
                    if labels[ny][nx] != tag:
                        continue
                    seen[ny][nx] = True
                    q.append((nx, ny))
            if len(blob) >= min_area:
                continue
            votes: dict[int, int] = {}
            for x, y in blob:
                for dx, dy in _NEIGH8:
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < N and 0 <= ny < N):
                        continue
                    ntag = labels[ny][nx]
                    if ntag in (EMPTY, UNSET, tag):
                        continue
                    votes[ntag] = votes.get(ntag, 0) + 1
            if not votes:
                continue
            winner = max(votes, key=votes.get)
            for x, y in blob:
                labels[y][x] = winner


def classify(src: Image.Image, family: str, face: tuple[int, int, int] | None = None, box: tuple[int, int, int, int] | None = None, anim: str = "idle") -> Classification:
    """Tag every gold-master pixel. Does not paint."""
    if box is None:
        box = bbox(src)
    if face is None:
        face = sample_face(src, box, family)
    fx, fy, face_half = face_region(src, face, box)
    chin = float(_chin_y(src, face, fx, fy, face_half))
    px = src.load()
    x0, y0, x1, y1 = box
    labels = _new_grid(EMPTY)

    skin_c = _new_bool()
    eye_c = _new_bool()
    hair_c = _new_bool()
    ink_c = _new_bool()
    helm_c = _new_bool()
    armor_c = _new_bool()
    opaque = _new_bool()

    rx = max(11.0, face_half * 1.35)
    ry = max(12.0, face_half * 1.28)
    hat_band_mage = fy - 1
    hat_band_other = chin + 6

    for y in range(N):
        for x in range(N):
            r, g, b, a = px[x, y]
            if a < 16:
                continue
            opaque[y][x] = True
            labels[y][x] = UNSET
            rgb = (r, g, b)
            in_head = ((x - fx) / rx) ** 2 + ((y - fy) / ry) ** 2 <= 1.0
            gold = is_gold_pixel(rgb) or is_hat_lining(rgb)
            hat = is_hat_or_hood(family, rgb)

            # Skin: gold-master face heuristic, plus YCbCr only inside the head
            # (chroma on a cream robe would otherwise flood the whole healer).
            in_face_band = y <= chin + 10 and abs(x - fx) <= face_half * 2.2
            skinish = (not gold) and is_skin(rgb, face)
            if (
                not skinish
                and not gold
                and in_face_band
                and chroma_near_face(rgb, face)
            ):
                skinish = True
            if family == "healer" and y < fy - 8:
                skinish = False
            if skinish:
                skin_c[y][x] = True

            # Eyes before skin flood: bright face pixels in the eye band, off-center.
            if (
                skinish
                and lum(rgb) >= 0.78
                and abs(y - fy) <= 3.5
                and 3.0 <= abs(x - fx) <= face_half * 0.85
            ):
                eye_c[y][x] = True

            hair_ok = True if family != "warrior" else (
                in_head or abs(x - fx) <= face_half * 1.7
            )
            if family == "healer" and (gold or hat):
                hair_ok = False
            if (
                hair_ok
                and y <= chin + 4
                and is_hair_color(family, rgb)
                and not gold
            ):
                hair_c[y][x] = True

            if in_head and lum(rgb) < 0.22:
                if not (family == "healer" and hat):
                    ink_c[y][x] = True

            hat_band = hat_band_mage if family == "mage" else hat_band_other
            if y <= hat_band and hat:
                helm_c[y][x] = True
            if family == "mage" and y < fy - 1 and not hair_c[y][x] and not skinish:
                helm_c[y][x] = True
            if family == "healer" and y < fy - 6 and (gold or hat):
                helm_c[y][x] = True

            if (gold or is_metal_or_trim(rgb)) and not skinish and not hair_c[y][x]:
                if not (in_head and y <= chin + 2):
                    armor_c[y][x] = True

    # 1. Eyes win.
    _claim(labels, eye_c, EYE)

    # 2. Skin flood from the face ellipse — never into eyes.
    skin_seeds = [
        (x, y)
        for y in range(max(0, int(fy - face_half)), min(N, int(fy + face_half * 1.2)))
        for x in range(max(0, int(fx - face_half)), min(N, int(fx + face_half) + 1))
        if skin_c[y][x] and labels[y][x] == UNSET
    ]
    if not skin_seeds:
        skin_seeds = [
            (x, y)
            for y in range(N)
            for x in range(N)
            if skin_c[y][x] and labels[y][x] == UNSET
        ]
    _claim(labels, _flood(skin_c, skin_seeds, labels), SKIN)

    # 3. Hair flood from the scalp.
    hair_seeds = [
        (x, y)
        for y in range(max(0, int(fy - face_half * 2.2)), int(fy) + 1)
        for x in range(max(0, int(fx - face_half * 1.8)), min(N, int(fx + face_half * 1.8) + 1))
        if hair_c[y][x] and labels[y][x] == UNSET
    ]
    if not hair_seeds:
        hair_seeds = [
            (x, y)
            for y in range(N)
            for x in range(N)
            if hair_c[y][x] and labels[y][x] == UNSET
        ]
    _claim(labels, _flood(hair_c, hair_seeds, labels), HAIR)

    # 4. Face ink (eyes/brows/mouth) — leftover dark in the head.
    _claim(labels, ink_c, INK)

    # 5. Helm / hood / circlet.
    _claim(labels, helm_c, HELM)

    # 6. Metal / gold armor.
    _claim(labels, armor_c, ARMOR)

    # 7. Remaining opaque = cloth (robe, tunic, pants).
    for y in range(N):
        for x in range(N):
            if labels[y][x] == UNSET and opaque[y][x]:
                labels[y][x] = CLOTH

    _despeckle_labels(labels)

    # Any leftover UNSET (should be none) → EMPTY if transparent else CLOTH.
    for y in range(N):
        for x in range(N):
            if labels[y][x] == UNSET:
                labels[y][x] = CLOTH if opaque[y][x] else EMPTY

    clf = Classification(
        src=src,
        family=family,
        labels=labels,
        face=face,
        box=box,
        fx=fx,
        fy=fy,
        face_half=face_half,
        chin_y=chin,
        anim=anim,
    )
    _promote_helm_from_overlay(clf)
    return clf


def _promote_helm_from_overlay(clf: Classification) -> None:
    """Hat overlay is the ground truth for mage/healer helm pixels."""
    if clf.family not in ("mage", "healer"):
        return
    path = ROOT / clf.family / "gear" / "helm_t0_idle.png"
    if not path.exists():
        return
    hp = Image.open(path).convert("RGBA").load()
    extra: set[tuple[int, int]] = set()
    for y in range(N):
        for x in range(N):
            if hp[x, y][3] < 40:
                continue
            extra.add((x, y))
            for dx, dy in _NEIGH8:
                nx, ny = x + dx, y + dy
                if 0 <= nx < N and 0 <= ny < N:
                    extra.add((nx, ny))
    for x, y in extra:
        if clf.labels[y][x] in GARMENT:
            clf.labels[y][x] = HELM


def cloth_tint_from_labels(clf: Classification, body: Image.Image) -> Image.Image:
    """Cloth-only grayscale mask. Never covers identity or the facit head band."""
    tint = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    tp = tint.load()
    bp = body.load()
    sp = clf.src.load()
    head_x = clf.face_half * 2.4
    chin = clf.chin_y
    fx = clf.fx
    for y in range(N):
        for x in range(N):
            tag = clf.labels[y][x]
            r, g, b, a = bp[x, y]
            if a < 40:
                continue
            if tag not in GARMENT:
                continue
            if undertunic_zone(clf, x, y) not in ("shirt", "pants"):
                continue
            if y <= chin + 8 and abs(x - fx) <= head_x:
                continue
            sr, sg, sb, sa = sp[x, y]
            if sa >= 40 and is_skin((sr, sg, sb), clf.face):
                continue
            shade = max(88, min(255, int(88 + lum((r, g, b)) * 220)))
            tp[x, y] = (shade, shade, shade, a)
    return _punch_facit_head_band(clf, tint)


def _punch_facit_head_band(clf: Classification, tint: Image.Image) -> Image.Image:
    """Facit measures the head band on load128(_src), not the pose loader."""
    src_path = ROOT / clf.family / "_src" / f"body_{clf.anim}.png"
    if not src_path.exists():
        src_path = ensure_src(clf.family, clf.anim)
    cleaned = load128(src_path)
    box = bbox(cleaned)
    face = sample_face(cleaned, box, clf.family)
    fx, _fy, fh = face_region(cleaned, face, box)
    chin = _chin_y(cleaned, face, fx, _fy, fh)
    mp = tint.load()
    for y in range(N):
        for x in range(N):
            if y <= chin + 8 and abs(x - fx) <= fh * 2.4:
                mp[x, y] = (0, 0, 0, 0)
    return tint


def _column_half(clf: Classification, y: int) -> float:
    """Neck under the jaw, wider chest, narrower legs. Not the robe's box."""
    chin = clf.chin_y
    fh = max(8.0, clf.face_half)
    neck = fh * 0.58
    chest = fh * 1.18
    hip = fh * 0.92
    shoulder_y = chin + fh * 0.75
    hip_y = chin + fh * 2.15
    if y < chin - 1:
        return 0.0
    if y < shoulder_y:
        t = (y - (chin - 1)) / max(1.0, shoulder_y - (chin - 1))
        return neck + (chest - neck) * t
    if y < hip_y:
        t = (y - shoulder_y) / max(1.0, hip_y - shoulder_y)
        return chest + (hip - chest) * t
    t = min(1.0, (y - hip_y) / max(8.0, fh * 3.0))
    return hip * (1.0 - 0.16 * t)


def undertunic_zone(clf: Classification, x: int, y: int) -> str:
    """Neck, hanging arms, shirt, and two pant legs. Robe wings and hat drop.

    Anchored on the face, not the gold-master bbox — a robe fills the whole
    canvas, and using that box paints the hat tip and the robe wings as cloth.
    """
    _x0, _y0, _x1, y1 = clf.box
    fh = max(8.0, clf.face_half)
    half = _column_half(clf, y)
    chin = clf.chin_y
    waist_y = chin + fh * 2.05
    # No synthesized arms. The gold master has no bare arm to copy, and a
    # filled block next to the painted face reads as a different picture.
    if half > 0 and y < waist_y and abs(x - clf.fx) <= half:
        return "shirt"
    if waist_y <= y <= y1:
        t = min(1.0, (y - waist_y) / max(8.0, fh * 2.2))
        leg_w = fh * (0.40 - 0.08 * t)
        gap = fh * 0.16
        for sign in (-1.0, 1.0):
            cx = clf.fx + sign * (gap + leg_w)
            if abs(x - cx) <= leg_w:
                return "pants"
    return "skip"


def _match_face_shade(
    px,
    x: int,
    y: int,
    clf: Classification,
    cloth: tuple[int, int, int],
    a: int,
) -> tuple[int, int, int, int]:
    """Four hard light steps, the same way the face is shaded. No robe ornaments.

    Brighter under the chin's light, darker toward the sides and the hem.
    """
    del px
    down = min(1.0, max(0.0, (y - clf.chin_y) / max(12.0, clf.face_half * 2.6)))
    side = min(1.0, abs(x - clf.fx) / max(8.0, clf.face_half * 1.15))
    neck = 0.78 if y < clf.chin_y + clf.face_half * 0.28 else 1.0
    raw = (1.06 - 0.36 * down - 0.2 * side) * neck
    steps = (0.52, 0.74, 0.96, 1.16)
    tone = min(steps, key=lambda step: abs(step - raw))
    return (
        min(255, int(cloth[0] * tone)),
        min(255, int(cloth[1] * tone)),
        min(255, int(cloth[2] * tone)),
        a,
    )


def _face_ink(clf: Classification) -> tuple[int, int, int]:
    total = [0, 0, 0]
    n = 0
    px = clf.src.load()
    for y in range(N):
        if y > clf.chin_y + 2:
            break
        for x in range(N):
            if clf.labels[y][x] != INK:
                continue
            if abs(x - clf.fx) > clf.face_half * 1.8:
                continue
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            total[0] += r
            total[1] += g
            total[2] += b
            n += 1
    if n < 8:
        return (36, 22, 28)
    return (total[0] // n, total[1] // n, total[2] // n)


def _ink_the_cut_edge(clf: Classification, out: Image.Image) -> None:
    """The crop through the robe is a hard cut. Rim it with the face's ink."""
    ink = _face_ink(clf)
    op = out.load()
    edge: list[tuple[int, int]] = []
    for y in range(N):
        for x in range(N):
            if op[x, y][3] < 40:
                continue
            tag = clf.labels[y][x]
            if tag in (EYE, SKIN, HAIR):
                continue
            if y < clf.chin_y and abs(x - clf.fx) <= clf.face_half * 1.4:
                continue
            cut = False
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if nx < 0 or ny < 0 or nx >= N or ny >= N or op[nx, ny][3] < 40:
                    cut = True
                    break
            if cut:
                edge.append((x, y))
    for x, y in edge:
        r, g, b, a = op[x, y]
        op[x, y] = (
            (r + ink[0] * 2) // 3,
            (g + ink[1] * 2) // 3,
            (b + ink[2] * 2) // 3,
            a,
        )


def paint_family_body(
    clf: Classification,
    tunic: tuple[int, int, int] | None = None,
    pants: tuple[int, int, int] | None = None,
) -> tuple[Image.Image, Image.Image]:
    """Undertunic: face, hair, a shaded shirt, and pants. No plate, robe, or hat.

    The shirt uses the same hard light steps and ink edge as the face.
    Costume pixels outside that column are dropped. Armor overlays cover
    the footprint when a slot is filled.
    """
    px = clf.src.load()
    if tunic is None or pants is None:
        tunic, pants = TUNIC[clf.family]
    out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    op = out.load()
    fx = clf.fx
    for y in range(N):
        for x in range(N):
            tag = clf.labels[y][x]
            if tag == EMPTY or tag == HELM:
                continue
            r, g, b, a = px[x, y]
            # Hat cone and hood point sit above the brow. They are not hair.
            if y < clf.fy - clf.face_half * 0.85 and tag != EYE:
                continue
            if clf.family in ("mage", "healer") and is_hat_or_hood(clf.family, (r, g, b)):
                if tag != EYE and y < clf.chin_y + 4:
                    continue
            if tag in (EYE, SKIN, HAIR) or (
                tag == INK and y < clf.chin_y and abs(x - fx) <= clf.face_half * 1.35
            ):
                op[x, y] = (r, g, b, a)
                continue
            zone = undertunic_zone(clf, x, y)
            if zone == "skip":
                continue
            if zone == "arm":
                op[x, y] = _match_face_shade(px, x, y, clf, clf.face, a)
                continue
            cloth = tunic if zone == "shirt" else pants
            op[x, y] = _match_face_shade(px, x, y, clf, cloth, a)
    out = despeckle_alpha(out)
    _ink_the_cut_edge(clf, out)
    if clf.family in ("mage", "healer"):
        strip_equipped_helm_from_body(clf.family, out)
    return out, cloth_tint_from_labels(clf, out)


def paint_canonical_body(
    clf: Classification,
    *,
    tunic: tuple[int, int, int],
    pants: tuple[int, int, int],
    sleeveless: bool,
) -> Image.Image:
    """LOOK body: identity from tags, garment is a flat tunic + shorts.

    Sleeveless drops upper-garment pixels outside the torso column so robe
    sleeves / pauldrons do not survive as family clothing. Face/hair/eyes
    are never flattened because they are not GARMENT.
    """
    px = clf.src.load()
    x0, y0, x1, y1 = clf.box
    mid_y = y0 + int((y1 - y0) * 0.62)
    torso_half = max(11.0, clf.face_half * 1.25)
    out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    op = out.load()
    fx = clf.fx
    for y in range(N):
        for x in range(N):
            tag = clf.labels[y][x]
            if tag == EMPTY or tag == HELM:
                continue
            r, g, b, a = px[x, y]
            if tag in IDENTITY:
                op[x, y] = (r, g, b, a)
                continue
            if sleeveless and y < mid_y and abs(x - fx) > torso_half:
                continue
            op[x, y] = flat_undertunic_pixel(x, y, fx, mid_y, tunic, pants, a)
    out = despeckle_alpha(out)
    if clf.family in ("mage", "healer"):
        strip_equipped_helm_from_body(clf.family, out)
    return out


def classify_src(family: str, anim: str) -> Classification:
    src = load128_pose(ROOT / family / "_src" / f"body_{anim}.png")
    box = bbox(src)
    face = sample_face(src, box, family)
    return classify(src, family, face, box, anim=anim)


def check_invariants(clf: Classification, *, require_eyes: bool) -> list[str]:
    """Hard rules for the classify-then-paint contract."""
    errors: list[str] = []
    skin_n = clf.count(SKIN)
    eye_n = clf.count(EYE)
    hair_n = clf.count(HAIR)
    unset = sum(1 for row in clf.labels for v in row if v == UNSET)
    if unset:
        errors.append(f"{clf.family}: {unset} unlabeled pixels")
    if skin_n < 40:
        errors.append(f"{clf.family}: too little skin ({skin_n}px)")
    if require_eyes and eye_n < 2:
        errors.append(f"{clf.family}: eyes missing ({eye_n}px)")
    if require_eyes and hair_n < 8 and clf.family != "mage":
        # Mage hat often covers hair on _src; bake may still be bald (warned).
        # Walk/attack clips are allowed to lose the bob — idle is the gate.
        errors.append(f"{clf.family}: too little hair ({hair_n}px)")
    # Mutual exclusion is structural (one int per pixel). Check eye∩skin via
    # source: every EYE pixel must have been a skin-chroma candidate, never armor.
    px = clf.src.load()
    for y in range(N):
        for x in range(N):
            if clf.labels[y][x] != EYE:
                continue
            r, g, b, a = px[x, y]
            if is_gold_pixel((r, g, b)):
                errors.append(f"{clf.family}: eye tagged on gold at {x},{y}")
                return errors
    return errors


def dump_all_idle(out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    for family in FAMILIES:
        clf = classify_src(family, "idle")
        clf.dump_preview(out_dir / f"labels_{family}_idle.png")
        print(
            family,
            "skin", clf.count(SKIN),
            "eye", clf.count(EYE),
            "hair", clf.count(HAIR),
            "ink", clf.count(INK),
            "helm", clf.count(HELM),
            "armor", clf.count(ARMOR),
            "cloth", clf.count(CLOTH),
        )


if __name__ == "__main__":
    import sys

    repo = Path(__file__).resolve().parents[1]
    dump_all_idle(repo / "tool" / "out" / "labels")
    failed = 0
    for family in FAMILIES:
        for anim in ANIMS:
            clf = classify_src(family, anim)
            for msg in check_invariants(clf, require_eyes=(anim == "idle")):
                print("FAIL", msg)
                failed += 1
    sys.exit(1 if failed else 0)
