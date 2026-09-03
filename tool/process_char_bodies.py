from PIL import Image
from pathlib import Path
from collections import deque

root = Path(r"d:\Projects\Personal\idle party\Idle-Party\assets\custom\char")


def clear_corner_bg(im: Image.Image) -> Image.Image:
    """Make near-white and flood-filled near-black corner backgrounds transparent."""
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if r > 228 and g > 228 and b > 228:
                px[x, y] = (0, 0, 0, 0)

    bg = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()
    seeds = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1), (w // 2, 0), (0, h // 2)]
    for x, y in seeds:
        r, g, b, a = px[x, y]
        if a < 10 or (r < 30 and g < 30 and b < 30):
            bg[y][x] = True
            q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not bg[ny][nx]:
                r, g, b, a = px[nx, ny]
                if a < 10 or (r < 28 and g < 28 and b < 28):
                    bg[ny][nx] = True
                    q.append((nx, ny))
    for y in range(h):
        for x in range(w):
            if bg[y][x]:
                px[x, y] = (0, 0, 0, 0)
    return im


for p in root.rglob("*.png"):
    if any(part in ("_src", "gear") for part in p.parts):
        continue
    im = clear_corner_bg(Image.open(p))
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
        pad = 8
        canvas = Image.new("RGBA", (im.width + pad * 2, im.height + pad * 2), (0, 0, 0, 0))
        canvas.paste(im, (pad, pad), im)
        im = canvas
    im = im.resize((128, 128), Image.Resampling.LANCZOS)
    im.save(p, optimize=True)
    print(p.parent.name, p.name, im.size)
