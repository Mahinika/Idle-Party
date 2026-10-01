"""Play the warrior skeleton demo. Outside the game.

    py -3 tool/skel_demo/play.py

1 spring, 2 hopp, 3 sving, B shows the bones.
If a window cannot open, writes tool/out/skel_demo/warrior_skel.gif.
py -3 tool/skel_demo/play.py --marks writes an 8x grip sheet and pixel counts.
"""

from __future__ import annotations

import json
import math
import sys
import time
from pathlib import Path

from PIL import Image, ImageDraw

from cut_warrior import OUT, build

CLIPS_PATH = Path(__file__).resolve().parent / "warrior_clips.json"
FRAME = (248, 208)
ORIGIN = (64, 48)
SCALE = 4
BG = (22, 16, 14, 255)
BONE = (232, 196, 92, 255)
CLIP_ORDER = ("run", "jump", "swing")
TITLES = {"run": "Spring", "jump": "Hopp", "swing": "Sving"}


def _rot_cw(dx: float, dy: float, deg: float) -> tuple[float, float]:
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return (c * dx - s * dy, s * dx + c * dy)


def _smooth(f: float) -> float:
    return f * f * (3.0 - 2.0 * f)


def _lerp(a: float, b: float, f: float) -> float:
    return a + (b - a) * f


def sample_clip(clip: dict, seconds: float) -> tuple[dict[str, float], tuple[float, float]]:
    length = float(clip["length"])
    if length <= 0:
        length = 0.01
    if clip.get("loop", True):
        u = (seconds % length) / length
    else:
        u = min(1.0, max(0.0, seconds / length))
    keys = clip["keys"]
    if u <= keys[0]["t"]:
        key = keys[0]
        return dict(key.get("bones", {})), tuple(key.get("root", (0, 0)))
    for i in range(len(keys) - 1):
        a, b = keys[i], keys[i + 1]
        if a["t"] <= u <= b["t"]:
            return _blend(a, b, u)
    if clip.get("loop", True) and keys[-1]["t"] < 1.0:
        return _blend(keys[-1], keys[0], u, wrap=True)
    last = keys[-1]
    return dict(last.get("bones", {})), tuple(last.get("root", (0, 0)))


def _blend(a: dict, b: dict, u: float, wrap: bool = False) -> tuple[dict[str, float], tuple[float, float]]:
    t0 = float(a["t"])
    t1 = float(b["t"]) + (1.0 if wrap else 0.0)
    span = t1 - t0
    f = 0.0 if span <= 0 else _smooth((u - t0) / span)
    bones_a = a.get("bones", {})
    bones_b = b.get("bones", {})
    names = set(bones_a) | set(bones_b)
    bones = {name: _lerp(float(bones_a.get(name, 0)), float(bones_b.get(name, 0)), f) for name in names}
    ra = a.get("root", (0, 0))
    rb = b.get("root", (0, 0))
    root = (_lerp(float(ra[0]), float(rb[0]), f), _lerp(float(ra[1]), float(rb[1]), f))
    return bones, root


def world_bones(meta: dict, angles: dict[str, float], root_off: tuple[float, float]) -> dict[str, tuple[float, float, float]]:
    bones = meta["bones"]
    memo: dict[str, tuple[float, float, float]] = {}

    def solve(name: str) -> tuple[float, float, float]:
        if name in memo:
            return memo[name]
        bone = bones[name]
        parent = bone["parent"]
        local = float(bone.get("restRot", 0.0)) + float(angles.get(name, 0.0))
        rx, ry = bone["rest"]
        if parent is None:
            memo[name] = (rx + root_off[0], ry + root_off[1], local)
            return memo[name]
        px, py, pr = solve(parent)
        p_rest = bones[parent]["rest"]
        dx, dy = _rot_cw(rx - p_rest[0], ry - p_rest[1], pr)
        memo[name] = (px + dx, py + dy, pr + local)
        return memo[name]

    return {name: solve(name) for name in bones}


def _spin(im: Image.Image, pivot: tuple[float, float], deg_cw: float) -> tuple[Image.Image, tuple[float, float]]:
    if abs(deg_cw) < 0.05:
        return im, pivot
    a = math.radians(deg_cw)
    c, s = math.cos(a), math.sin(a)
    w, h = im.size
    px, py = pivot
    corners = []
    for x, y in ((0, 0), (w, 0), (w, h), (0, h)):
        dx, dy = x - px, y - py
        corners.append((c * dx - s * dy + px, s * dx + c * dy + py))
    minx = math.floor(min(p[0] for p in corners)) - 1
    miny = math.floor(min(p[1] for p in corners)) - 1
    maxx = math.ceil(max(p[0] for p in corners)) + 1
    maxy = math.ceil(max(p[1] for p in corners)) + 1
    nw, nh = maxx - minx, maxy - miny
    c0 = px + c * (minx - px) + s * (miny - py)
    f0 = py - s * (minx - px) + c * (miny - py)
    out = im.transform(
        (nw, nh),
        Image.Transform.AFFINE,
        (c, s, c0, -s, c, f0),
        resample=Image.Resampling.NEAREST,
    )
    return out, (px - minx, py - miny)


def _order(meta: dict, world: dict[str, tuple[float, float, float]]) -> list[str]:
    sides = sorted(("l", "r"), key=lambda s: world[f"foot_{s}"][1], reverse=True)
    names = []
    for side in sides:
        names.extend((f"thigh_{side}", f"shin_{side}", f"foot_{side}"))
    for name in meta["draw"]:
        if name.startswith(("thigh_", "shin_", "foot_")):
            continue
        names.append(name)
    return names


def _placed(
    meta: dict,
    images: dict[str, Image.Image],
    name: str,
    world: dict[str, tuple[float, float, float]],
) -> tuple[Image.Image, int, int]:
    part = next(p for p in meta["parts"] if p["name"] == name)
    im = images[name]
    wx, wy, rot = world[part["bone"]]
    spun, piv = _spin(im, (part["pivot"][0], part["pivot"][1]), rot)
    ox = int(round(ORIGIN[0] + wx - piv[0]))
    oy = int(round(ORIGIN[1] + wy - piv[1]))
    return spun, ox, oy


def _opaque(im: Image.Image, ox: int, oy: int) -> set[tuple[int, int]]:
    px = im.load()
    w, h = im.size
    out: set[tuple[int, int]] = set()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 80:
                out.add((ox + x, oy + y))
    return out


def render(
    meta: dict,
    images: dict[str, Image.Image],
    angles: dict[str, float],
    root_off: tuple[float, float] = (0.0, 0.0),
    bones: bool = False,
) -> Image.Image:
    world = world_bones(meta, angles, root_off)
    frame = Image.new("RGBA", FRAME, BG)
    by_name = {part["name"]: part for part in meta["parts"]}
    for name in _order(meta, world):
        part = by_name[name]
        im = images[name]
        wx, wy, rot = world[part["bone"]]
        spun, piv = _spin(im, (part["pivot"][0], part["pivot"][1]), rot)
        ox = int(round(ORIGIN[0] + wx - piv[0]))
        oy = int(round(ORIGIN[1] + wy - piv[1]))
        frame.paste(spun, (ox, oy), spun)
    _strip_slivers(frame)
    if bones:
        _draw_bones(frame, meta, world)
    return frame


def _strip_slivers(frame: Image.Image) -> None:
    """Drop 1px rotation debris. The plate stays one solid piece at rest."""
    px = frame.load()
    w, h = frame.size
    seen: set[tuple[int, int]] = set()

    def on(x: int, y: int) -> bool:
        color = px[x, y]
        return color[3] > 40 and color[:3] != BG[:3]

    kill: list[tuple[int, int]] = []
    for y in range(h):
        for x in range(w):
            if (x, y) in seen or not on(x, y):
                continue
            stack = [(x, y)]
            seen.add((x, y))
            cells: list[tuple[int, int]] = []
            while stack:
                cx, cy = stack.pop()
                cells.append((cx, cy))
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and on(nx, ny):
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            xs = [p[0] for p in cells]
            ys = [p[1] for p in cells]
            span = min(max(xs) - min(xs), max(ys) - min(ys))
            if span <= 4 and len(cells) < 40:
                kill.extend(cells)
    for x, y in kill:
        px[x, y] = BG


def _draw_bones(frame: Image.Image, meta: dict, world: dict[str, tuple[float, float, float]]) -> None:
    draw = ImageDraw.Draw(frame)
    for name, bone in meta["bones"].items():
        parent = bone["parent"]
        x, y, _ = world[name]
        sx, sy = ORIGIN[0] + x, ORIGIN[1] + y
        if parent is not None:
            px, py, _ = world[parent]
            draw.line(
                (ORIGIN[0] + px, ORIGIN[1] + py, sx, sy),
                fill=BONE,
                width=1,
            )
        draw.rectangle((sx - 1, sy - 1, sx + 1, sy + 1), fill=BONE)


def _scale(im: Image.Image) -> Image.Image:
    return im.resize((im.width * SCALE, im.height * SCALE), Image.Resampling.NEAREST)


def _load() -> tuple[dict, dict, dict[str, Image.Image]]:
    meta = build(quiet=True)
    clips = json.loads(CLIPS_PATH.read_text(encoding="utf-8"))
    rig = dict(meta)
    rig["clips"] = clips
    (OUT / "warrior_rig.json").write_text(json.dumps(rig, indent=2), encoding="utf-8")
    images = {}
    for part in meta["parts"]:
        images[part["name"]] = Image.open(OUT / part["file"]).convert("RGBA")
    return meta, clips, images


def _sheet(meta: dict, clips: dict, images: dict[str, Image.Image]) -> None:
    cols = 8
    cell = _scale(render(meta, images, {}, (0, 0))).size
    rows = []
    for clip_name in CLIP_ORDER:
        clip = clips[clip_name]
        frames = []
        steps = cols
        for i in range(steps):
            t = clip["length"] * i / steps
            angles, root = sample_clip(clip, t)
            frames.append(_scale(render(meta, images, angles, root)))
        row = Image.new("RGB", (cell[0] * cols, cell[1]), BG[:3])
        for i, fr in enumerate(frames):
            row.paste(fr.convert("RGB"), (i * cell[0], 0))
        rows.append(row)
    sheet = Image.new("RGB", (rows[0].width, sum(r.height for r in rows)), BG[:3])
    y = 0
    for row in rows:
        sheet.paste(row, (0, y))
        y += row.height
    path = OUT / "sheet.png"
    sheet.save(path)
    print(path)


def _gif(meta: dict, clips: dict, images: dict[str, Image.Image]) -> None:
    frames: list[Image.Image] = []
    for clip_name in CLIP_ORDER:
        clip = clips[clip_name]
        steps = max(8, int(round(clip["length"] * 16)))
        for i in range(steps):
            t = clip["length"] * i / steps
            angles, root = sample_clip(clip, t)
            big = _scale(render(meta, images, angles, root)).convert("RGB")
            frames.append(big.quantize(colors=64, dither=Image.Dither.NONE))
    path = OUT / "warrior_skel.gif"
    frames[0].save(
        path,
        save_all=True,
        append_images=frames[1:],
        duration=62,
        loop=0,
        disposal=2,
    )
    print(path)


def _cal(meta: dict, images: dict[str, Image.Image]) -> None:
    poses: list[tuple[str, dict[str, float]]] = [
        ("rest", {}),
        ("thighL+30", {"thigh_l": 30}),
        ("thighL-30", {"thigh_l": -30}),
        ("shinL+40", {"shin_l": 40}),
        ("shinL-40", {"shin_l": -40}),
        ("upperR+40", {"upper_r": 40}),
        ("upperR-40", {"upper_r": -40}),
        ("foreR+50", {"fore_r": 50}),
        ("foreR-50", {"fore_r": -50}),
        ("paulR+30", {"pauldron_r": 30}),
        ("paulR-30", {"pauldron_r": -30}),
        ("tuck", {"thigh_l": 28, "thigh_r": -28, "shin_l": -40, "shin_r": 40}),
    ]
    cell = render(meta, images, {}, (0, 0))
    cols = 4
    rows = math.ceil(len(poses) / cols)
    sheet = Image.new("RGB", (cell.width * cols, cell.height * rows), BG[:3])
    for i, (label, angles) in enumerate(poses):
        im = render(meta, images, angles, (0, 0), bones=True).convert("RGB")
        draw = ImageDraw.Draw(im)
        draw.rectangle((0, 0, 70, 10), fill=(0, 0, 0))
        draw.text((2, 0), label, fill=(255, 220, 140))
        x = (i % cols) * cell.width
        y = (i // cols) * cell.height
        sheet.paste(im, (x, y))
    path = OUT / "cal.png"
    sheet.save(path)
    src = Image.open(
        Path(__file__).resolve().parents[2] / "assets" / "custom" / "char" / "warrior" / "_src" / "body_idle.png"
    ).convert("RGBA")
    rest = render(meta, images, {}, (0, 0))
    sp, rp = src.load(), rest.load()
    extra = 0
    missing = 0
    for y in range(128):
        for x in range(128):
            sx, sy = x + ORIGIN[0], y + ORIGIN[1]
            sa = sp[x, y][3] > 20
            ra = rp[sx, sy][3] > 20
            if ra and not sa:
                extra += 1
            if sa and not ra:
                missing += 1
    print(f"rest extra {extra} missing {missing}")
    print(path)


def _marks(meta: dict, images: dict[str, Image.Image]) -> None:
    """8x sheet: grip cross, fist box, and how many pixels actually touch."""
    world = world_bones(meta, {}, (0.0, 0.0))
    masks = {name: _opaque(*_placed(meta, images, name, world)) for name in ("hand_l", "hand_r", "fore_l", "fore_r", "sword", "shield")}
    sword_on_hand = len(masks["sword"] & masks["hand_r"])
    shield_on_arm = len(masks["shield"] & (masks["hand_l"] | masks["fore_l"]))
    hand_bottom = max(y for _, y in masks["hand_r"])
    pommel_below = sum(1 for _, y in masks["sword"] if y > hand_bottom)
    gap = _rim_gap(masks["shield"], masks["fore_l"] | masks["hand_l"])
    lines = [
        f"sword pixels inside the right fist: {sword_on_hand}",
        f"sword pixels below the fist: {pommel_below}",
        f"shield pixels on the left arm: {shield_on_arm}",
        f"open pixels between shield rim and left arm: {gap}",
        f"sword grip: {world['sword'][0]:.1f}, {world['sword'][1]:.1f}",
        f"shield grip: {world['shield'][0]:.1f}, {world['shield'][1]:.1f}",
    ]
    zoom = 8
    crops = [
        _mark_crop(meta, images, world, masks, "hand_r", "sword", zoom),
        _mark_crop(meta, images, world, masks, "hand_l", "shield", zoom),
    ]
    pad = 8
    sheet = Image.new("RGB", (crops[0].width + crops[1].width + pad * 3, crops[0].height + 78), (22, 16, 14))
    draw = ImageDraw.Draw(sheet)
    sheet.paste(crops[0], (pad, 8))
    sheet.paste(crops[1], (crops[0].width + pad * 2, 8))
    for i, line in enumerate(lines):
        draw.text((pad, crops[0].height + 14 + i * 10), line, fill=(232, 215, 176))
    path = OUT / "marks.png"
    sheet.save(path)
    (OUT / "marks.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))
    print(path)


def _rim_gap(weapon: set[tuple[int, int]], arm: set[tuple[int, int]]) -> int:
    """Widest empty run, in pixels, between the weapon and the arm on one row."""
    if not weapon or not arm:
        return -1
    rows_w: dict[int, tuple[int, int]] = {}
    rows_a: dict[int, tuple[int, int]] = {}
    for x, y in weapon:
        lo, hi = rows_w.get(y, (x, x))
        rows_w[y] = (min(lo, x), max(hi, x))
    for x, y in arm:
        lo, hi = rows_a.get(y, (x, x))
        rows_a[y] = (min(lo, x), max(hi, x))
    worst = 0
    for y, (a0, a1) in rows_a.items():
        span = rows_w.get(y)
        if span is None:
            continue
        w0, w1 = span
        if w1 < a0:
            worst = max(worst, a0 - w1 - 1)
        elif a1 < w0:
            worst = max(worst, w0 - a1 - 1)
    return worst


def _mark_crop(
    meta: dict,
    images: dict[str, Image.Image],
    world: dict[str, tuple[float, float, float]],
    masks: dict[str, set[tuple[int, int]]],
    hand: str,
    bone: str,
    zoom: int,
) -> Image.Image:
    frame = render(meta, images, {}, (0, 0))
    hx0 = min(x for x, _ in masks[hand])
    hy0 = min(y for _, y in masks[hand])
    hx1 = max(x for x, _ in masks[hand])
    hy1 = max(y for _, y in masks[hand])
    x0 = hx0 - 18
    y0 = hy0 - 22
    x1 = hx1 + 19
    y1 = hy1 + 23
    crop = frame.crop((x0, y0, x1, y1)).resize(((x1 - x0) * zoom, (y1 - y0) * zoom), Image.Resampling.NEAREST)
    draw = ImageDraw.Draw(crop)
    _box(draw, masks[hand], x0, y0, zoom, (80, 220, 120))
    gx = int(round(ORIGIN[0] + world[bone][0]))
    gy = int(round(ORIGIN[1] + world[bone][1]))
    cx, cy = (gx - x0) * zoom + zoom // 2, (gy - y0) * zoom + zoom // 2
    arm = 10
    draw.line((cx - arm, cy, cx + arm, cy), fill=(255, 210, 60), width=2)
    draw.line((cx, cy - arm, cx, cy + arm), fill=(255, 210, 60), width=2)
    return crop.convert("RGB")


def _box(draw: ImageDraw.ImageDraw, pts: set[tuple[int, int]], x0: int, y0: int, zoom: int, color: tuple[int, int, int]) -> None:
    left = (min(x for x, _ in pts) - x0) * zoom
    top = (min(y for _, y in pts) - y0) * zoom
    right = (max(x for x, _ in pts) - x0 + 1) * zoom - 1
    bottom = (max(y for _, y in pts) - y0 + 1) * zoom - 1
    draw.rectangle((left, top, right, bottom), outline=color)


def _window(meta: dict, clips: dict, images: dict[str, Image.Image]) -> None:
    import tkinter as tk

    state = {"clip": "run", "t0": time.perf_counter(), "bones": False}

    root = tk.Tk()
    root.title("Krigare — skelettprov")
    root.configure(bg="#16110f")
    sample = _scale(render(meta, images, {}, (0, 0)))
    photo = tk.PhotoImage(data=_png_bytes(sample))
    view = tk.Label(root, image=photo, bg="#16110f", bd=0)
    view.pack()
    caption = tk.Label(
        root,
        text="1 spring    2 hopp    3 sving    B ben",
        fg="#e8d7b0",
        bg="#16110f",
        font=("Segoe UI", 12),
    )
    caption.pack(pady=(0, 8))

    def select(name: str) -> None:
        state["clip"] = name
        state["t0"] = time.perf_counter()

    root.bind("1", lambda _e: select("run"))
    root.bind("2", lambda _e: select("jump"))
    root.bind("3", lambda _e: select("swing"))
    root.bind("b", lambda _e: state.__setitem__("bones", not state["bones"]))
    root.bind("B", lambda _e: state.__setitem__("bones", not state["bones"]))

    def tick() -> None:
        clip = clips[state["clip"]]
        angles, root_off = sample_clip(clip, time.perf_counter() - state["t0"])
        frame = _scale(render(meta, images, angles, root_off, bones=state["bones"]))
        img = tk.PhotoImage(data=_png_bytes(frame))
        view.configure(image=img)
        view.image = img
        mark = "  · ben på" if state["bones"] else ""
        caption.configure(text=f"{TITLES[state['clip']]}{mark}     1 spring   2 hopp   3 sving   B ben")
        root.after(33, tick)

    root.after(33, tick)
    root.mainloop()


def _png_bytes(im: Image.Image) -> bytes:
    import io

    buf = io.BytesIO()
    im.save(buf, format="PNG")
    return buf.getvalue()


def main() -> None:
    meta, clips, images = _load()
    if "--cal" in sys.argv:
        _cal(meta, images)
        return
    if "--sheet" in sys.argv:
        _sheet(meta, clips, images)
        return
    if "--gif" in sys.argv:
        _gif(meta, clips, images)
        return
    if "--marks" in sys.argv:
        _marks(meta, images)
        return
    try:
        import tkinter as tk
    except ImportError:
        _gif(meta, clips, images)
        return
    try:
        _window(meta, clips, images)
    except tk.TclError:
        _gif(meta, clips, images)


if __name__ == "__main__":
    main()
