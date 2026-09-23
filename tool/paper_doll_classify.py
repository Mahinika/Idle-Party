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
    ROOT,
    is_gold_pixel,
    is_hair_color,
    is_hat_lining,
    is_hat_or_hood,
    is_metal_or_trim,
    is_rogue_cloak,
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
            # Sleeves sit on empty pixels beside the old armor. They are
            # still cloth, so the spec color has to reach them.
            if tag not in GARMENT and tag != EMPTY:
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


_CLOTH_STEPS = (0.52, 0.74, 0.96, 1.16)
_COVER_CACHE: dict[str, list[list[bool]]] = {}


def _load_alpha(path: Path) -> list[list[bool]] | None:
    if not path.exists():
        return None
    px = Image.open(path).convert("RGBA").load()
    return [[px[x, y][3] >= 40 for x in range(N)] for y in range(N)]


def _armor_cover(family: str) -> list[list[bool]]:
    """Chest, legs, and gloves. Cloth under this stays hidden once equipped."""
    if family in _COVER_CACHE:
        return _COVER_CACHE[family]
    gear = ROOT / family / "gear"
    masks = []
    for stem in ("chest_t0_idle", "legs_t0_idle", "hands_t0_idle"):
        mask = _load_alpha(gear / f"{stem}.png")
        if mask is not None:
            masks.append(mask)
    cover = _new_bool()
    for y in range(N):
        for x in range(N):
            cover[y][x] = any(m[y][x] for m in masks)
    _COVER_CACHE[family] = cover
    return cover


def _face_light_luma(clf: Classification, x: int, y: int) -> float:
    """Same hard light as the face, used where the master is only metal."""
    down = min(1.0, max(0.0, (y - clf.chin_y) / max(12.0, clf.face_half * 2.6)))
    side = min(1.0, abs(x - clf.fx) / max(8.0, clf.face_half * 1.15))
    neck = 0.78 if y < clf.chin_y + clf.face_half * 0.28 else 1.0
    raw = (1.06 - 0.36 * down - 0.2 * side) * neck
    return max(0.12, min(0.82, (raw - 0.45) / 0.85))


def _blur_cloth_luma(px, clf: Classification, radius: int = 3) -> list[list[float]]:
    """Fold-sized light. Gold trim and plate rivets do not steer the cloth."""
    acc = [[0.0] * N for _ in range(N)]
    wgt = [[0.0] * N for _ in range(N)]
    for y in range(N):
        for x in range(N):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            rgb = (r, g, b)
            # Trim, plate, and ink lines are not cloth folds.
            if is_gold_pixel(rgb) or is_metal_or_trim(rgb) or lum(rgb) < 0.22:
                continue
            sample = lum(rgb)
            for dy in range(-radius, radius + 1):
                yy = y + dy
                if yy < 0 or yy >= N:
                    continue
                for dx in range(-radius, radius + 1):
                    xx = x + dx
                    if xx < 0 or xx >= N:
                        continue
                    acc[yy][xx] += sample
                    wgt[yy][xx] += 1
    out = [[0.0] * N for _ in range(N)]
    for y in range(N):
        for x in range(N):
            if wgt[y][x] >= 4:
                out[y][x] = acc[y][x] / wgt[y][x]
            else:
                out[y][x] = _face_light_luma(clf, x, y)
    return out


_IDLE_ANCHOR: dict[str, tuple[float, float]] = {}


def _pose_shift(clf: Classification) -> tuple[int, int]:
    """How far this clip's chin sits from the idle clip. Armor art is idle."""
    if clf.anim == "idle":
        return 0, 0
    if clf.family not in _IDLE_ANCHOR:
        idle = classify_src(clf.family, "idle")
        _IDLE_ANCHOR[clf.family] = (idle.fx, idle.chin_y)
    ix, iy = _IDLE_ANCHOR[clf.family]
    return int(round(clf.fx - ix)), int(round(clf.chin_y - iy))


def _shifted_cover(clf: Classification) -> list[list[bool]]:
    cover = _armor_cover(clf.family)
    dx, dy = _pose_shift(clf)
    if dx == 0 and dy == 0:
        return cover
    out = _new_bool()
    for y in range(N):
        sy = y - dy
        if sy < 0 or sy >= N:
            continue
        row = cover[sy]
        for x in range(N):
            sx = x - dx
            if 0 <= sx < N and row[sx]:
                out[y][x] = True
    return out


def _quantize_cloth(
    cloth: tuple[int, int, int], luma: float, *, bias: float = 1.0
) -> tuple[int, int, int, int]:
    t = max(0.0, min(1.0, (luma - 0.06) / 0.70))
    raw = (0.52 + t * 0.64) * bias
    tone = min(_CLOTH_STEPS, key=lambda step: abs(step - raw))
    return (
        min(255, int(cloth[0] * tone)),
        min(255, int(cloth[1] * tone)),
        min(255, int(cloth[2] * tone)),
        255,
    )


def _dilate_mask(mask: list[list[bool]], radius: int) -> list[list[bool]]:
    out = _new_bool()
    for y in range(N):
        for x in range(N):
            if not mask[y][x]:
                continue
            for dy in range(-radius, radius + 1):
                yy = y + dy
                if yy < 0 or yy >= N:
                    continue
                row = out[yy]
                for dx in range(-radius, radius + 1):
                    xx = x + dx
                    if 0 <= xx < N:
                        row[xx] = True
    return out


def _erode_mask(mask: list[list[bool]], radius: int) -> list[list[bool]]:
    out = _new_bool()
    for y in range(radius, N - radius):
        for x in range(radius, N - radius):
            if all(
                mask[y + dy][x + dx]
                for dy in range(-radius, radius + 1)
                for dx in range(-radius, radius + 1)
            ):
                out[y][x] = True
    return out


def _fill_enclosed(keep: list[list[bool]], allowed: list[list[bool]]) -> None:
    """Fill holes inside the silhouette. Filigree gaps are not polka dots."""
    outside = _new_bool()
    q: deque[tuple[int, int]] = deque()
    for x in range(N):
        q.append((x, 0))
        q.append((x, N - 1))
    for y in range(N):
        q.append((0, y))
        q.append((N - 1, y))
    while q:
        x, y = q.popleft()
        if not (0 <= x < N and 0 <= y < N) or outside[y][x] or keep[y][x]:
            continue
        outside[y][x] = True
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q.append((x + dx, y + dy))
    for y in range(N):
        for x in range(N):
            if keep[y][x] or outside[y][x] or not allowed[y][x]:
                continue
            keep[y][x] = True


def _drop_specks(mask: list[list[bool]], min_area: int = 80) -> None:
    """Gold crumbs and overlay dirt are not a second sleeve."""
    seen = _new_bool()
    for y0 in range(N):
        for x0 in range(N):
            if not mask[y0][x0] or seen[y0][x0]:
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
                    if not mask[ny][nx]:
                        continue
                    seen[ny][nx] = True
                    q.append((nx, ny))
            if len(blob) >= min_area:
                continue
            for x, y in blob:
                mask[y][x] = False


def _snap(width: float) -> int:
    """Stair-step the edge so the hem is pixels, not a smooth curve."""
    return max(4, int(round(width / 2.0)) * 2)


def _hand_targets(clf: Classification) -> tuple[tuple[float, float], tuple[float, float]]:
    """Where each sleeve aims. Falls back to a short hang beside the ribs."""
    mask = _load_alpha(ROOT / clf.family / "gear" / "hands_t0_idle.png")
    dx, dy = _pose_shift(clf)
    fh = max(8.0, clf.face_half)
    found: dict[int, list[tuple[int, int]]] = {-1: [], 1: []}
    if mask is not None:
        for y in range(N):
            row = mask[y]
            for x in range(N):
                if not row[x]:
                    continue
                px_, py = x + dx, y + dy
                if not (0 <= px_ < N and 0 <= py < N):
                    continue
                found[-1 if px_ < clf.fx else 1].append((px_, py))
    out: list[tuple[float, float]] = []
    for sign in (-1, 1):
        pts = found[sign]
        if len(pts) < 12:
            out.append(
                (
                    clf.fx + sign * fh * 1.45,
                    clf.chin_y + fh * 1.25,
                )
            )
            continue
        out.append(
            (
                sum(p[0] for p in pts) / len(pts),
                sum(p[1] for p in pts) / len(pts),
            )
        )
    return out[0], out[1]


def _stamp_square(
    zones: list[list[str]],
    cx: float,
    cy: float,
    rad: int,
    zone: str,
    *,
    overwrite: bool = False,
) -> None:
    for y in range(int(cy) - rad, int(cy) + rad + 1):
        if y < 0 or y >= N:
            continue
        row = zones[y]
        for x in range(int(cx) - rad, int(cx) + rad + 1):
            if x < 0 or x >= N:
                continue
            if max(abs(x - int(cx)), abs(y - int(cy))) > rad:
                continue
            if row[x] and not overwrite:
                continue
            row[x] = zone


def _cloth_zones(clf: Classification) -> list[list[str]]:
    """Plain shirt, sleeves, pants, and shoes. Not the armor silhouette.

    Widths are stair-stepped and the light matches the face, so the cloth
    is the same kind of pixel picture as the head. Pauldrons, robes, gold,
    and plate stay on the overlays.
    """
    fh = max(8.0, clf.face_half)
    fx = clf.fx
    chin = clf.chin_y
    _x0, _y0, _x1, y1 = clf.box
    shoulder_y = chin + fh * 0.42
    waist_y = chin + fh * 1.85
    hip_y = chin + fh * 2.35
    hem = min(N - 3, max(int(chin + fh * 3.5), y1 - 6))
    neck_w = fh * 0.40
    chest_w = fh * 0.92
    hip_w = fh * 0.70
    zones = [[""] * N for _ in range(N)]

    def torso_half(y: int) -> int:
        if y < shoulder_y:
            span = max(1.0, shoulder_y - (chin - 1))
            t = min(1.0, max(0.0, (y - (chin - 1)) / span))
            return _snap(neck_w + (chest_w - neck_w) * t)
        if y < waist_y:
            return _snap(chest_w)
        span = max(1.0, hip_y - waist_y)
        t = min(1.0, max(0.0, (y - waist_y) / span))
        return _snap(chest_w + (hip_w - chest_w) * t)

    y_start = max(0, int(chin) - 1)
    for y in range(y_start, int(hip_y) + 1):
        if y >= N:
            break
        half = torso_half(y)
        for x in range(int(fx) - half, int(fx) + half + 1):
            if 0 <= x < N:
                zones[y][x] = "shirt"

    leg_w = _snap(fh * 0.30)
    gap = max(2, int(fh * 0.14))
    shoe_top = hem - 5
    for sign in (-1.0, 1.0):
        cx = int(round(fx + sign * (gap + leg_w)))
        for y in range(int(waist_y), hem + 1):
            if y < 0 or y >= N:
                continue
            extra = 1 if y >= shoe_top else 0
            half = leg_w + extra
            zone = "shoe" if y >= shoe_top else "pants"
            for x in range(cx - half, cx + half + 1):
                if 0 <= x < N and not zones[y][x]:
                    zones[y][x] = zone

    sleeve_r = max(3, int(fh * 0.22))
    left, right = _hand_targets(clf)
    for sign, (hx, hy) in ((-1, left), (1, right)):
        sx = fx + sign * (torso_half(int(shoulder_y)) - 1)
        sy = shoulder_y
        # Stop short of the glove so the cuff is cloth, not a gauntlet.
        ex = sx + (hx - sx) * 0.72
        ey = sy + (hy - sy) * 0.72
        steps = max(6, int(abs(ex - sx) + abs(ey - sy)))
        sag = fh * 0.42
        for i in range(steps + 1):
            t = i / steps
            _stamp_square(
                zones,
                sx + (ex - sx) * t,
                sy + (ey - sy) * t + sag * (4.0 * t * (1.0 - t)),
                sleeve_r,
                "cuff" if t > 0.78 else "shirt",
                overwrite=t > 0.78,
            )
    return zones


def _hair_on_the_face(clf: Classification) -> set[tuple[int, int]]:
    """Haircut touching the face. Loose hood tufts are not hair."""
    fh = clf.face_half
    fx, fy, chin = clf.fx, clf.fy, clf.chin_y
    stack: list[tuple[int, int]] = []
    seen: set[tuple[int, int]] = set()
    for y in range(N):
        for x in range(N):
            tag = clf.at(x, y)
            if tag not in (EYE, SKIN):
                continue
            if abs(x - fx) > fh * 1.05 or not (fy - fh <= y <= chin + 2):
                continue
            if tag == SKIN and clf.family == "healer":
                r, g, b, _a = clf.src.getpixel((x, y))
                if lum((r, g, b)) < lum(clf.face) - 0.12:
                    continue
                if (
                    abs(r - clf.face[0])
                    + abs(g - clf.face[1])
                    + abs(b - clf.face[2])
                    > 90
                ):
                    continue
            stack.append((x, y))
            seen.add((x, y))
    keep: set[tuple[int, int]] = set()
    while stack:
        x, y = stack.pop()
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                nx, ny = x + dx, y + dy
                if (nx, ny) in seen or nx < 0 or ny < 0 or nx >= N or ny >= N:
                    continue
                if clf.at(nx, ny) != HAIR:
                    continue
                if abs(nx - fx) > fh * 1.45 or not (fy - fh * 1.15 <= ny <= chin + 2):
                    continue
                r, g, b, _a = clf.src.getpixel((nx, ny))
                if (
                    clf.family == "healer"
                    and lum((r, g, b)) > 0.42
                    and r > b + 8
                ):
                    continue
                seen.add((nx, ny))
                keep.add((nx, ny))
                stack.append((nx, ny))
    return keep


def drop_small_islands(im: Image.Image, min_size: int = 12) -> Image.Image:
    """Remove hood crumbs. The shirt and the face stay."""
    src = im.copy()
    sp = src.load()
    seen = [[False] * N for _ in range(N)]
    kill: list[tuple[int, int]] = []
    for y in range(N):
        for x in range(N):
            if seen[y][x] or sp[x, y][3] < 40:
                continue
            stack = [(x, y)]
            pix: list[tuple[int, int]] = []
            while stack:
                cx, cy = stack.pop()
                if cx < 0 or cy < 0 or cx >= N or cy >= N or seen[cy][cx]:
                    continue
                if sp[cx, cy][3] < 40:
                    continue
                seen[cy][cx] = True
                pix.append((cx, cy))
                stack.extend(((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)))
            if len(pix) < min_size:
                kill.extend(pix)
    if not kill:
        return im
    out = im.copy()
    op = out.load()
    for x, y in kill:
        op[x, y] = (0, 0, 0, 0)
    return out


def _face_oval(clf: Classification, x: int, y: int) -> bool:
    """Smooth cheek. The healer hood is not part of the face."""
    fh = max(8.0, clf.face_half)
    if y > clf.chin_y + 1:
        return False
    dx = (x - clf.fx) / (fh * 0.96)
    dy = (y - clf.fy) / (fh * 0.98)
    return dx * dx + dy * dy <= 1.0


def _fill_face_oval(clf: Classification, op) -> None:
    fr, fg, fb = clf.face
    fh = clf.face_half
    for y in range(N):
        for x in range(N):
            if not _face_oval(clf, x, y):
                continue
            shade = 1.0 if y < clf.fy + fh * 0.2 else 0.82
            dx = abs(x - clf.fx) / max(8.0, fh)
            if dx > 0.72 or (y - clf.fy) / max(8.0, fh) > 0.7:
                shade = 0.7
            op[x, y] = (
                min(255, int(fr * shade)),
                min(255, int(fg * shade)),
                min(255, int(fb * shade)),
                255,
            )


def _restore_healer_face(clf: Classification, body: Image.Image) -> None:
    """Put a plain face back after the hood overlay is stripped off."""
    _fill_face_oval(clf, body.load())
    op = body.load()
    px = clf.src.load()
    fx = clf.fx
    for y in range(N):
        for x in range(N):
            if not _face_oval(clf, x, y):
                continue
            tag = clf.at(x, y)
            r, g, b, a = px[x, y]
            if a < 16:
                continue
            if tag == EYE or (
                tag == INK and abs(x - fx) <= clf.face_half * 0.7
            ):
                op[x, y] = (r, g, b, a)


def _paint_cloth_pixel(
    zone: str,
    luma: float,
    tunic: tuple[int, int, int],
    pants: tuple[int, int, int],
) -> tuple[int, int, int, int]:
    if zone == "shirt":
        return _quantize_cloth(tunic, luma)
    if zone == "cuff":
        return _quantize_cloth(tunic, luma, bias=0.72)
    if zone == "shoe":
        return _quantize_cloth(pants, luma, bias=0.58)
    return _quantize_cloth(pants, luma)


def paint_family_body(
    clf: Classification,
    tunic: tuple[int, int, int] | None = None,
    pants: tuple[int, int, int] | None = None,
) -> tuple[Image.Image, Image.Image]:
    """Undertunic: the face from the master, and a plain shirt under the armor.

    Sleeves, pants, and shoes use the face's hard light and ink. They are
    narrower than plate, robes, and capes, so those stay off until equipped.
    """
    px = clf.src.load()
    if tunic is None or pants is None:
        tunic, pants = TUNIC[clf.family]
    zones = _cloth_zones(clf)
    hair_keep = _hair_on_the_face(clf)
    out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    op = out.load()
    fx = clf.fx
    for y in range(N):
        for x in range(N):
            tag = clf.labels[y][x]
            r, g, b, a = px[x, y]
            # Hat cone and hood point sit above the brow. They are not hair.
            if y < clf.fy - clf.face_half * 0.85 and tag != EYE:
                continue
            if a > 16 and clf.family in ("mage", "healer") and is_hat_or_hood(
                clf.family, (r, g, b)
            ):
                if tag != EYE and y < clf.chin_y + 4:
                    continue
            # Hoods and hat fringes are tagged as hair. Keep only the
            # haircut on the head so a naked hero is not still wearing one.
            # Healer gold fringe is the hood, not a haircut.
            hair_on_head = (x, y) in hair_keep
            # Healer cheeks are the filled oval. Source "skin" is the hood.
            skin_on_face = tag == SKIN and clf.family != "healer"
            if a > 16 and (
                tag == EYE
                or skin_on_face
                or hair_on_head
                or (
                    tag == INK
                    and y < clf.chin_y
                    and abs(x - fx) <= clf.face_half * 1.35
                )
            ):
                op[x, y] = (r, g, b, a)
                continue
            zone = zones[y][x]
            if not zone or tag == HELM:
                continue
            op[x, y] = _paint_cloth_pixel(
                zone, _face_light_luma(clf, x, y), tunic, pants
            )
    out = despeckle_alpha(out)
    out = drop_small_islands(out)
    _ink_the_cut_edge(clf, out)
    if clf.family in ("mage", "healer"):
        strip_equipped_helm_from_body(clf.family, out)
    if clf.family == "healer":
        _restore_healer_face(clf, out)
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
