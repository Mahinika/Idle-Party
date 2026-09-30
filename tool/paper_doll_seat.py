"""Slide a gear piece onto the body when it is drawn out in the air.

Shoulders and short gloves are same-origin overlays. A cut that keeps the
wrong half, or a pauldron pasted beside the head, fails the lookbook.
Each opaque island shifts toward the body until half of it touches.
"""

from __future__ import annotations

from collections import deque

from PIL import Image

N = 128
ALPHA = 40
REACH = 2


def _opaque(im: Image.Image) -> list[tuple[int, int]]:
    px = im.load()
    return [
        (x, y)
        for y in range(N)
        for x in range(N)
        if px[x, y][3] >= ALPHA
    ]


def _islands(pts: list[tuple[int, int]]) -> list[list[tuple[int, int]]]:
    left = set(pts)
    islands: list[list[tuple[int, int]]] = []
    while left:
        start = left.pop()
        island = [start]
        queue = deque([start])
        while queue:
            x, y = queue.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nxt = (x + dx, y + dy)
                if nxt in left:
                    left.discard(nxt)
                    island.append(nxt)
                    queue.append(nxt)
        islands.append(island)
    return islands


def _body_mask(body: Image.Image) -> list[list[bool]]:
    """Pixels within REACH of the body, so a touch test is one lookup."""
    px = body.load()
    near = [[False] * N for _ in range(N)]
    for y in range(N):
        for x in range(N):
            if px[x, y][3] < ALPHA:
                continue
            for dy in range(-REACH, REACH + 1):
                yy = y + dy
                if yy < 0 or yy >= N:
                    continue
                row = near[yy]
                for dx in range(-REACH, REACH + 1):
                    xx = x + dx
                    if 0 <= xx < N:
                        row[xx] = True
    return near


def _touches(pts: list[tuple[int, int]], near: list[list[bool]]) -> int:
    return sum(1 for x, y in pts if near[y][x])


def seat_on_body(piece: Image.Image, body: Image.Image) -> Image.Image:
    """Return [piece] with floating islands pulled onto [body]."""
    return seat_on_bodies(piece, [body])


def seat_rigid(piece: Image.Image, body: Image.Image) -> Image.Image:
    """Move the whole piece by one shift, so leather rows stay leather rows."""
    pts = _opaque(piece)
    if not pts:
        return piece
    dx, dy = _best_shift(pts, [_body_mask(body)])
    if dx == 0 and dy == 0:
        return piece
    src = piece.load()
    out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    op = out.load()
    for y in range(N):
        for x in range(N):
            if src[x, y][3] < ALPHA:
                continue
            xx, yy = x + dx, y + dy
            if 0 <= xx < N and 0 <= yy < N:
                op[xx, yy] = src[x, y]
    return out


def seat_on_bodies(piece: Image.Image, bodies: list[Image.Image]) -> Image.Image:
    """Seat [piece] where it touches every clip, so walk and attack keep it."""
    src = piece.load()
    pts = _opaque(piece)
    if not pts or not bodies:
        return piece
    masks = [_body_mask(body) for body in bodies]
    out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    op = out.load()
    for island in _islands(pts):
        dx, dy = _best_shift(island, masks)
        for x, y in island:
            xx, yy = x + dx, y + dy
            if 0 <= xx < N and 0 <= yy < N:
                op[xx, yy] = src[x, y]
    return out


def _worst(pts: list[tuple[int, int]], masks: list[list[list[bool]]]) -> int:
    return min(_touches(pts, mask) for mask in masks)


def _best_shift(
    island: list[tuple[int, int]], masks: list[list[list[bool]]]
) -> tuple[int, int]:
    # A bare half leaves the lookbook, which counts the painted picture,
    # just over the line. Sit a little further on.
    target = 0.62 * len(island)
    best = (0, 0)
    best_touch = _worst(island, masks)
    best_cost = 0
    found = best_touch >= target
    if found:
        return best
    for dy in range(-36, 28):
        for dx in range(-28, 29):
            moved = [(x + dx, y + dy) for x, y in island]
            if any(x < 0 or y < 0 or x >= N or y >= N for x, y in moved):
                continue
            touch = _worst(moved, masks)
            cost = abs(dx) + abs(dy)
            if touch < target:
                if not found and (
                    touch > best_touch or (touch == best_touch and cost < best_cost)
                ):
                    best, best_touch, best_cost = (dx, dy), touch, cost
                continue
            if not found or cost < best_cost:
                found = True
                best, best_touch, best_cost = (dx, dy), touch, cost
    return best


def seat_live() -> int:
    """Pull floating shoulders and short gloves onto the body. Rewrites icons."""
    from make_gear_slot_icons import HANDS_MIN_OPAQUE, SHOULDER_MIN_OPAQUE, make_icon
    from paper_doll_manifest import FAMILIES
    from paper_doll_paths import CHAR

    changed = 0
    for family in FAMILIES:
        gear = CHAR / family / "gear"
        idle = Image.open(CHAR / family / "body_idle.png").convert("RGBA")
        clips = [
            Image.open(CHAR / family / f"body_{anim}.png").convert("RGBA")
            for anim in ("idle", "walk", "attack")
            if (CHAR / family / f"body_{anim}.png").exists()
        ]
        paths = [
            *gear.glob("shoulder_*_idle.png"),
            *gear.glob("hands_*short*_idle.png"),
        ]
        authored = gear / "_authored"
        if authored.exists():
            paths += [
                *authored.glob("shoulder_*_idle.png"),
                *authored.glob("hands_*short*_idle.png"),
            ]
        for path in paths:
            with Image.open(path) as raw:
                im = raw.convert("RGBA")
            seated = (
                seat_on_bodies(im, clips)
                if path.name.startswith("shoulder_")
                else seat_rigid(im, idle)
            )
            if seated.tobytes() == im.tobytes():
                continue
            tmp = path.with_name(path.stem + ".writing.png")
            seated.save(tmp)
            tmp.replace(path)
            changed += 1
            if "_authored" in path.parts:
                continue
            floor = HANDS_MIN_OPAQUE if "hands_" in path.name else SHOULDER_MIN_OPAQUE
            icon = make_icon(seated, min_opaque=floor)
            if icon is not None:
                icon_path = path.with_name(path.name.replace("_idle.png", "_icon.png"))
                icon_tmp = icon_path.with_name(icon_path.stem + ".writing.png")
                icon.save(icon_tmp)
                icon_tmp.replace(icon_path)
            print(f"seated {family}/{path.name}")
    return changed


if __name__ == "__main__":
    print(f"seated {seat_live()} pictures")
