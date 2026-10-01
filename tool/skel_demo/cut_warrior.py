"""Cut the dressed warrior into rigid parts for the skeleton demo.

Reads assets/custom/char/warrior/_src/body_idle.png. Writes only under
tool/out/skel_demo/. Does not touch live doll art.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "custom" / "char" / "warrior" / "_src" / "body_idle.png"
SWORD_SRC = ROOT / "assets" / "custom" / "char" / "gear" / "sword_t0_idle.png"
SHIELD_SRC = ROOT / "assets" / "custom" / "char" / "gear" / "shield_t0_idle.png"
# Grip on the weapon picture, and the clockwise rest turn, from OwnedGearGrips.
SWORD_GRIP = (0.7422 * 128, 0.6797 * 128)
SHIELD_GRIP = (0.2188 * 128, 0.4766 * 128)
SWORD_REST_DEG = 1.1289 * 180.0 / 3.141592653589793
OUT = ROOT / "tool" / "out" / "skel_demo"
PARTS = OUT / "parts"

# Head stays the face. Shoulders are the outer plate above the dangling arms.
HEAD_Y = 40
HEAD_CHIN_Y = 48
HEAD_CHIN_X0 = 36
HEAD_CHIN_X1 = 92
ARM_Y = 66
PAULDRON_X_L = 36
PAULDRON_X_R = 92
LEG_Y = 94
LEG_SPLIT_X = 64
THIGH_Y = 107
SHIN_Y = 118

# How far a limb borrows pixels across the joint so a bend does not flash a hole.
PAD = 2

DRAW = [
    "thigh_l",
    "thigh_r",
    "shin_l",
    "shin_r",
    "foot_l",
    "foot_r",
    "torso",
    "pauldron_l",
    "pauldron_r",
    "upper_l",
    "upper_r",
    "fore_l",
    "fore_r",
    "hand_l",
    "hand_r",
    "head",
]

# Child part, parent bone, and the step (dx, dy) that points at the parent joint.
LIMB_PARENT = {
    "head": ("torso", (0, 1)),
    "pauldron_l": ("torso", (1, 0)),
    "pauldron_r": ("torso", (-1, 0)),
    "upper_l": ("pauldron_l", (0, -1)),
    "upper_r": ("pauldron_r", (0, -1)),
    "fore_l": ("upper_l", (0, -1)),
    "fore_r": ("upper_r", (0, -1)),
    "hand_l": ("fore_l", (0, -1)),
    "hand_r": ("fore_r", (0, -1)),
    "thigh_l": ("root", (0, -1)),
    "thigh_r": ("root", (0, -1)),
    "shin_l": ("thigh_l", (0, -1)),
    "shin_r": ("thigh_r", (0, -1)),
    "foot_l": ("shin_l", (0, -1)),
    "foot_r": ("shin_r", (0, -1)),
}


def _runs(px, y: int, w: int) -> list[tuple[int, int]]:
    segs: list[tuple[int, int]] = []
    start = None
    for x in range(w):
        on = px[x, y][3] > 20
        if on and start is None:
            start = x
        elif not on and start is not None:
            segs.append((start, x - 1))
            start = None
    if start is not None:
        segs.append((start, w - 1))
    return segs


def _arm_name(side: str, y: int) -> str:
    if y < 76:
        return f"upper_{side}"
    if y < 86:
        return f"fore_{side}"
    return f"hand_{side}"


def _leg_name(side: str, y: int) -> str:
    if y < THIGH_Y:
        return f"thigh_{side}"
    if y < SHIN_Y:
        return f"shin_{side}"
    return f"foot_{side}"


def assign(px, w: int, h: int) -> dict[str, set[tuple[int, int]]]:
    runs = [_runs(px, y, w) for y in range(h)]
    parts: dict[str, set[tuple[int, int]]] = {name: set() for name in DRAW}
    for y in range(h):
        segs = runs[y]
        for x in range(w):
            if px[x, y][3] <= 20:
                continue
            name = _name_at(x, y, segs)
            parts[name].add((x, y))
    return parts


def _name_at(x: int, y: int, segs: list[tuple[int, int]]) -> str:
    if y >= LEG_Y:
        return _leg_name("l" if x < LEG_SPLIT_X else "r", y)
    if y >= ARM_Y and len(segs) >= 3:
        if x <= segs[0][1]:
            return _arm_name("l", y)
        if x >= segs[-1][0]:
            return _arm_name("r", y)
    if y <= HEAD_Y or (y <= HEAD_CHIN_Y and HEAD_CHIN_X0 <= x <= HEAD_CHIN_X1):
        return "head"
    if y < ARM_Y and x < PAULDRON_X_L:
        return "pauldron_l"
    if y < ARM_Y and x > PAULDRON_X_R:
        return "pauldron_r"
    return "torso"


def _top_center(pts: set[tuple[int, int]]) -> tuple[float, float]:
    top = min(y for _, y in pts)
    xs = [x for x, y in pts if y <= top + 1]
    return (sum(xs) / len(xs), float(top))


def _bottom_center(pts: set[tuple[int, int]]) -> tuple[float, float]:
    bot = max(y for _, y in pts)
    xs = [x for x, y in pts if y >= bot - 1]
    return (sum(xs) / len(xs), float(bot))


def bone_rests(parts: dict[str, set[tuple[int, int]]]) -> dict[str, tuple[float, float]]:
    torso_bot = _bottom_center(parts["torso"])
    waist = (64.0, torso_bot[1])
    rests = {
        "root": waist,
        "torso": waist,
        "head": _bottom_center(parts["head"]),
        "pauldron_l": _top_center(parts["upper_l"]),
        "pauldron_r": _top_center(parts["upper_r"]),
        "upper_l": _top_center(parts["upper_l"]),
        "upper_r": _top_center(parts["upper_r"]),
        "fore_l": _top_center(parts["fore_l"]),
        "fore_r": _top_center(parts["fore_r"]),
        "hand_l": _top_center(parts["hand_l"]),
        "hand_r": _top_center(parts["hand_r"]),
        "thigh_l": _top_center(parts["thigh_l"]),
        "thigh_r": _top_center(parts["thigh_r"]),
        "shin_l": _top_center(parts["shin_l"]),
        "shin_r": _top_center(parts["shin_r"]),
        "foot_l": _top_center(parts["foot_l"]),
        "foot_r": _top_center(parts["foot_r"]),
        "shield": _fist(parts["hand_l"], 10, -4),
        "sword": _fist(parts["hand_r"], -2, 1),
    }
    return rests


def _fist(pts: set[tuple[int, int]], dx: float = 0, dy: float = 0) -> tuple[float, float]:
    """Center of the gauntlet, where the grip sits."""
    xs = [x for x, _ in pts]
    ys = [y for _, y in pts]
    return (sum(xs) / len(xs) + dx, sum(ys) / len(ys) + dy)


def _extrude(
    src: Image.Image,
    parts: dict[str, set[tuple[int, int]]],
    rests: dict[str, tuple[float, float]],
) -> dict[str, dict[tuple[int, int], tuple[int, int, int, int]]]:
    """Borrow a few pixels across each joint. Opaque borrows keep the original color."""
    px = src.load()
    extra: dict[str, dict[tuple[int, int], tuple[int, int, int, int]]] = {}
    w, h = src.size
    for name, (dx, dy) in ((n, LIMB_PARENT[n][1]) for n in DRAW if n in LIMB_PARENT):
        gained: dict[tuple[int, int], tuple[int, int, int, int]] = {}
        edge = []
        pts = parts[name]
        px_j, py_j = rests[name if name != "torso" else "torso"]
        for x, y in pts:
            if (x - px_j) ** 2 + (y - py_j) ** 2 > 25:
                continue
            nx, ny = x + dx, y + dy
            if (nx, ny) not in pts:
                edge.append((x, y))
        for x, y in edge:
            for step in range(1, PAD + 1):
                qx, qy = x + dx * step, y + dy * step
                if not (0 <= qx < w and 0 <= qy < h):
                    break
                if (qx, qy) in pts or (qx, qy) in gained:
                    break
                sample = px[qx, qy]
                if sample[3] <= 20:
                    break
                gained[(qx, qy)] = sample
        extra[name] = gained
    return extra


def _write_part(
    src: Image.Image,
    pts: set[tuple[int, int]],
    extra: dict[tuple[int, int], tuple[int, int, int, int]],
    path: Path,
) -> None:
    im = Image.new("RGBA", src.size, (0, 0, 0, 0))
    out = im.load()
    sp = src.load()
    for x, y in pts:
        out[x, y] = sp[x, y]
    for (x, y), color in extra.items():
        out[x, y] = color
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)


def _copy_weapon(src: Path, dest: Path) -> None:
    im = Image.open(src).convert("RGBA")
    if im.size != (128, 128):
        raise SystemExit(f"weapon must be 128x128: {src}")
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.save(dest)


def _debug(parts: dict[str, set[tuple[int, int]]], path: Path) -> None:
    colors = {
        "head": (240, 180, 140, 255),
        "torso": (70, 90, 120, 255),
        "pauldron_l": (180, 80, 70, 255),
        "pauldron_r": (180, 120, 60, 255),
        "upper_l": (90, 160, 90, 255),
        "upper_r": (60, 140, 90, 255),
        "fore_l": (70, 110, 190, 255),
        "fore_r": (50, 80, 170, 255),
        "hand_l": (230, 200, 80, 255),
        "hand_r": (200, 170, 50, 255),
        "thigh_l": (140, 90, 160, 255),
        "thigh_r": (120, 70, 150, 255),
        "shin_l": (80, 150, 160, 255),
        "shin_r": (50, 120, 140, 255),
        "foot_l": (160, 110, 70, 255),
        "foot_r": (140, 90, 50, 255),
    }
    im = Image.new("RGBA", (128, 128), (20, 16, 14, 255))
    px = im.load()
    for name, pts in parts.items():
        for x, y in pts:
            px[x, y] = colors[name]
    big = im.resize((128 * 4, 128 * 4), Image.Resampling.NEAREST)
    big.save(path)


def build(quiet: bool = False) -> dict:
    src = Image.open(SRC).convert("RGBA")
    w, h = src.size
    if (w, h) != (128, 128):
        raise SystemExit(f"expected 128 master, got {w}x{h}")
    px = src.load()
    parts = assign(px, w, h)
    owned: set[tuple[int, int]] = set()
    missing = 0
    for y in range(h):
        for x in range(w):
            if px[x, y][3] <= 20:
                continue
            hit = [name for name, pts in parts.items() if (x, y) in pts]
            if len(hit) != 1:
                missing += 1
            else:
                owned.add((x, y))
    if missing:
        raise SystemExit(f"cut does not cover the master ({missing} pixels)")
    rests = bone_rests(parts)
    extra = _extrude(src, parts, rests)
    PARTS.mkdir(parents=True, exist_ok=True)
    for name in DRAW:
        _write_part(src, parts[name], extra.get(name, {}), PARTS / f"{name}.png")
    _debug(parts, OUT / "parts_debug.png")

    parents = {
        "root": None,
        "torso": "root",
        "head": "torso",
        "pauldron_l": "torso",
        "pauldron_r": "torso",
        "upper_l": "pauldron_l",
        "upper_r": "pauldron_r",
        "fore_l": "upper_l",
        "fore_r": "upper_r",
        "hand_l": "fore_l",
        "hand_r": "fore_r",
        "thigh_l": "root",
        "thigh_r": "root",
        "shin_l": "thigh_l",
        "shin_r": "thigh_r",
        "foot_l": "shin_l",
        "foot_r": "shin_r",
        "shield": "hand_l",
        "sword": "hand_r",
    }
    bones = {
        name: {"parent": parents[name], "rest": [round(rests[name][0], 2), round(rests[name][1], 2)]}
        for name in parents
    }
    bones["sword"]["restRot"] = round(SWORD_REST_DEG, 2)
    part_rows = []
    for name in DRAW:
        bone = "torso" if name == "torso" else name
        pivot = bones[bone]["rest"]
        part_rows.append(
            {
                "name": name,
                "file": f"parts/{name}.png",
                "bone": bone,
                "pivot": pivot,
            }
        )
    _copy_weapon(SWORD_SRC, PARTS / "sword.png")
    _copy_weapon(SHIELD_SRC, PARTS / "shield.png")
    part_rows.append(
        {
            "name": "shield",
            "file": "parts/shield.png",
            "bone": "shield",
            "pivot": [round(SHIELD_GRIP[0], 2), round(SHIELD_GRIP[1], 2)],
        }
    )
    part_rows.append(
        {
            "name": "sword",
            "file": "parts/sword.png",
            "bone": "sword",
            "pivot": [round(SWORD_GRIP[0], 2), round(SWORD_GRIP[1], 2)],
        }
    )
    draw = [*DRAW, "shield", "sword"]
    meta = {
        "canvas": [128, 128],
        "source": "assets/custom/char/warrior/_src/body_idle.png",
        "bones": bones,
        "parts": part_rows,
        "draw": draw,
    }
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "parts_meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    if not quiet:
        counts = {name: len(pts) for name, pts in parts.items()}
        print("parts", counts)
        print("rest", {k: bones[k]["rest"] for k in bones})
    return meta


def main() -> None:
    build()


if __name__ == "__main__":
    main()
