from PIL import Image
from pathlib import Path
import shutil

src = Path(r"C:\Users\Ropbe\.cursor\projects\d-Projects-Personal-idle-party-Idle-Party\assets")
root = Path(r"D:\Projects\Personal\idle party\Idle-Party\assets\custom")
(root / "ui" / "backdrops").mkdir(parents=True, exist_ok=True)
(root / "heroes").mkdir(parents=True, exist_ok=True)

backdrops = {
    "backdrop_sandy.png": "ui/backdrops/sandy.png",
    "backdrop_goblin.png": "ui/backdrops/goblin.png",
    "backdrop_king.png": "ui/backdrops/king.png",
    "backdrop_underworld.png": "ui/backdrops/underworld.png",
    "backdrop_dead.png": "ui/backdrops/dead.png",
    "backdrop_hell.png": "ui/backdrops/hell.png",
    "backdrop_crystal.png": "ui/backdrops/crystal.png",
}
heroes = {
    "hero_knight.png": "heroes/knight.png",
    "hero_healer.png": "heroes/healer.png",
    "hero_wizard.png": "heroes/wizard.png",
    "hero_rogue.png": "heroes/rogue.png",
}
enemies = {
    "enemy_slime.png": "enemies/slime.png",
    "enemy_bat.png": "enemies/bat.png",
    "enemy_cultist.png": "enemies/cultist.png",
    "enemy_golem.png": "enemies/golem.png",
    "enemy_boss_king.png": "enemies/boss_king.png",
    "enemy_boss_hell.png": "enemies/boss_hell.png",
}


def compress_backdrop(p: Path, max_edge=960):
    im = Image.open(p).convert("RGBA")
    w, h = im.size
    scale = min(1.0, max_edge / max(w, h))
    if scale < 1:
        im = im.resize((int(w * scale), int(h * scale)), Image.Resampling.NEAREST)
    q = im.convert("RGB").quantize(colors=96, method=Image.Quantize.MEDIANCUT)
    q.save(p, optimize=True)
    print("bg", p.name, Image.open(p).size, p.stat().st_size)


def punch_dark_bg(p: Path, thresh=32, max_edge=96):
    im = Image.open(p).convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if r < thresh and g < thresh and b < thresh:
                px[x, y] = (0, 0, 0, 0)
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    side = max(im.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    ox = (side - im.size[0]) // 2
    oy = (side - im.size[1]) // 2
    canvas.paste(im, (ox, oy), im)
    if side > max_edge:
        canvas = canvas.resize((max_edge, max_edge), Image.Resampling.NEAREST)
    canvas.save(p, optimize=True)
    print("spr", p.name, canvas.size, p.stat().st_size)


for name, dest in {**backdrops, **heroes, **enemies}.items():
    shutil.copy2(src / name, root / dest)

for p in (root / "ui" / "backdrops").glob("*.png"):
    compress_backdrop(p)
for p in (root / "heroes").glob("*.png"):
    punch_dark_bg(p)
for name in enemies.values():
    punch_dark_bg(root / name, max_edge=96)
