from PIL import Image
from pathlib import Path

root = Path(r"d:\Projects\Personal\idle party\Idle-Party\assets\custom\char")
for p in root.rglob("*.png"):
    im = Image.open(p).convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if r > 228 and g > 228 and b > 228:
                px[x, y] = (0, 0, 0, 0)
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
