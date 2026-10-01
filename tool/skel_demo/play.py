"""Play the warrior skeleton demo. Outside the game.

    py -3 tool/skel_demo/play.py

1 spring, 2 hopp, 3 sving, B shows the bones.
If a window cannot open, writes tool/out/skel_demo/warrior_skel.gif.
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
FRAME = (176, 176)
ORIGIN = (24, 40)
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
        local = float(angles.get(name, 0.0))
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
