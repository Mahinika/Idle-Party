#!/usr/bin/env py
"""World Path pins — 64×64 pixel landmarks.

Same language as the UI icons (sword, campfire, trophy): a real object,
dark rim, top-left light, two or three tones. Not a flat symbol.

This script owns every zone `hub_icon.png`. Dungeon tile generators must
not rewrite those files.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / "assets" / "custom" / "dungeon"

INK = (22, 12, 8, 255)
N = 64

ZONES = (
    "sandy",
    "goblin",
    "king",
    "underworld",
    "dead",
    "hell",
    "crystal",
    "tide",
    "ember",
    "grove",
    "storm",
    "rime",
    "fen",
    "brass",
    "veil",
)


class Pix:
    def __init__(self) -> None:
        self.im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        self.px = self.im.load()

    def set(self, x: int, y: int, c: tuple[int, int, int, int] | None) -> None:
        if c is None or not (0 <= x < N and 0 <= y < N):
            return
        self.px[x, y] = c

    def rect(self, x0: int, y0: int, x1: int, y1: int, c: tuple[int, int, int, int]) -> None:
        if x1 < x0 or y1 < y0:
            return
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, c)

    def disc(self, cx: int, cy: int, r: int, c: tuple[int, int, int, int]) -> None:
        r2 = r * r
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r2:
                    self.set(x, y, c)

    def erase_disc(self, cx: int, cy: int, r: int) -> None:
        r2 = r * r
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r2:
                    self.set(x, y, (0, 0, 0, 0))

    def diamond(self, cx: int, cy: int, rx: int, ry: int, c: tuple[int, int, int, int]) -> None:
        if rx <= 0 or ry <= 0:
            return
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                if abs(x - cx) * ry + abs(y - cy) * rx <= rx * ry:
                    self.set(x, y, c)

    def finish(self) -> Image.Image:
        return _ground(_outline(self.im))


def _outline(src: Image.Image) -> Image.Image:
    out = src.copy()
    sp = src.load()
    dp = out.load()
    w, h = src.size
    for y in range(h):
        for x in range(w):
            if sp[x, y][3] > 0:
                continue
            hit = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and sp[nx, ny][3] > 0:
                    hit = True
                    break
            if hit:
                dp[x, y] = INK
    return out


def _ground(src: Image.Image) -> Image.Image:
    box = src.getbbox()
    if box is None:
        return src
    x0, y0, x1, y1 = box
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    cx = (x0 + x1) // 2
    half = max(8, (x1 - x0) // 3)
    ImageDraw.Draw(out).ellipse(
        [cx - half, y1 - 3, cx + half, min(N - 1, y1 + 2)],
        fill=(0, 0, 0, 110),
    )
    out.alpha_composite(src)
    return out


def sandy() -> Image.Image:
    """Dune cave mouth with a torch — not a ring."""
    p = Pix()
    sand = (196, 132, 64, 255)
    sand_h = (232, 184, 104, 255)
    sand_l = (122, 78, 36, 255)
    cave = (28, 18, 12, 255)
    wood = (112, 72, 40, 255)
    flame = (255, 168, 48, 255)
    hot = (255, 236, 168, 255)
    # Hill.
    p.rect(8, 36, 55, 56, sand)
    p.rect(14, 30, 50, 38, sand)
    p.rect(20, 26, 44, 32, sand_h)
    p.rect(8, 48, 55, 56, sand_l)
    p.rect(12, 28, 22, 34, sand_h)
    # Mouth.
    p.rect(22, 34, 42, 54, cave)
    p.rect(26, 30, 38, 36, cave)
    p.rect(18, 32, 24, 40, sand_l)
    p.rect(40, 32, 46, 40, sand_l)
    # Lintel.
    p.rect(20, 30, 44, 34, wood)
    p.rect(20, 30, 44, 31, sand_h)
    # Torch on the right jamb.
    p.rect(40, 38, 43, 48, wood)
    p.rect(38, 32, 45, 39, flame)
    p.rect(40, 30, 43, 34, hot)
    # Ground lip.
    p.rect(16, 52, 48, 56, sand_l)
    p.rect(24, 50, 40, 52, sand)
    return p.finish()


def goblin() -> Image.Image:
    """Spiked stash chest with a green cloth."""
    p = Pix()
    wood = (138, 86, 44, 255)
    wood_h = (196, 132, 72, 255)
    wood_l = (88, 52, 28, 255)
    cloth = (46, 128, 52, 255)
    cloth_h = (96, 176, 72, 255)
    gold = (228, 176, 64, 255)
    gold_h = (255, 224, 140, 255)
    spike = (72, 78, 70, 255)
    # Spikes.
    p.rect(16, 12, 21, 22, spike)
    p.rect(18, 8, 19, 14, spike)
    p.rect(42, 12, 47, 22, spike)
    p.rect(44, 8, 45, 14, spike)
    # Lid.
    p.rect(12, 20, 51, 32, wood_h)
    p.rect(12, 28, 51, 32, wood)
    # Body.
    p.rect(12, 32, 51, 54, wood)
    p.rect(12, 46, 51, 54, wood_l)
    p.rect(14, 34, 22, 44, wood_h)
    # Cloth.
    p.rect(20, 24, 44, 40, cloth)
    p.rect(22, 24, 30, 32, cloth_h)
    # Lock.
    p.rect(28, 34, 36, 46, gold)
    p.rect(30, 36, 34, 40, gold_h)
    p.rect(31, 42, 33, 44, wood_l)
    # Bands.
    p.rect(12, 32, 51, 34, wood_l)
    p.rect(12, 50, 51, 52, gold)
    return p.finish()


def king() -> Image.Image:
    """Crownlands keep: two towers, gate, red banner."""
    p = Pix()
    stone = (132, 140, 148, 255)
    stone_h = (196, 204, 210, 255)
    stone_l = (72, 78, 86, 255)
    door = (48, 28, 22, 255)
    banner = (168, 42, 36, 255)
    banner_h = (220, 96, 72, 255)
    gold = (228, 184, 72, 255)
    # Towers.
    p.rect(6, 18, 22, 56, stone)
    p.rect(42, 18, 58, 56, stone)
    p.rect(6, 18, 12, 56, stone_h)
    p.rect(42, 18, 48, 56, stone_h)
    p.rect(16, 40, 22, 56, stone_l)
    p.rect(52, 40, 58, 56, stone_l)
    # Merlons.
    for x in (6, 14, 42, 50):
        p.rect(x, 10, x + 6, 18, stone_h)
    # Curtain wall.
    p.rect(20, 28, 44, 56, stone)
    p.rect(20, 28, 26, 56, stone_h)
    p.rect(38, 40, 44, 56, stone_l)
    # Gate.
    p.rect(28, 40, 36, 56, door)
    p.rect(30, 44, 34, 50, gold)
    # Windows.
    p.rect(10, 28, 16, 36, door)
    p.rect(48, 28, 54, 36, door)
    p.rect(11, 29, 13, 31, stone_h)
    # Banner on the left tower.
    p.rect(16, 22, 24, 40, banner)
    p.rect(16, 22, 19, 32, banner_h)
    p.rect(18, 36, 22, 40, gold)
    return p.finish()


def underworld() -> Image.Image:
    """Stairs dropping into a purple pit."""
    p = Pix()
    stone = (88, 80, 96, 255)
    stone_h = (140, 132, 150, 255)
    stone_l = (48, 40, 58, 255)
    pit = (16, 8, 24, 255)
    glow = (150, 80, 210, 255)
    glow_h = (210, 160, 245, 255)
    # Rim.
    p.rect(8, 14, 55, 28, stone)
    p.rect(8, 14, 55, 18, stone_h)
    p.rect(8, 24, 55, 28, stone_l)
    # Pit.
    p.rect(16, 26, 48, 56, pit)
    p.rect(22, 36, 42, 54, glow)
    p.rect(28, 44, 36, 52, glow_h)
    # Steps down the left.
    p.rect(10, 28, 28, 34, stone)
    p.rect(14, 34, 32, 40, stone_l)
    p.rect(18, 40, 36, 46, stone)
    p.rect(22, 46, 40, 52, stone_l)
    p.rect(10, 28, 16, 34, stone_h)
    # Crystal fang on the rim.
    p.diamond(46, 12, 6, 10, glow)
    p.diamond(46, 10, 3, 6, glow_h)
    return p.finish()


def dead() -> Image.Image:
    """Mossy tombstone."""
    p = Pix()
    stone = (120, 124, 118, 255)
    stone_h = (176, 180, 170, 255)
    stone_l = (64, 68, 64, 255)
    moss = (58, 120, 62, 255)
    moss_h = (110, 168, 80, 255)
    mark = (36, 40, 38, 255)
    # Stone.
    p.rect(16, 16, 48, 54, stone)
    p.rect(20, 10, 44, 20, stone)
    p.rect(24, 6, 40, 14, stone_h)
    p.rect(16, 16, 24, 54, stone_h)
    p.rect(40, 28, 48, 54, stone_l)
    p.rect(16, 46, 48, 54, stone_l)
    # Carved cross.
    p.rect(30, 20, 34, 40, mark)
    p.rect(24, 26, 40, 30, mark)
    # Moss at the foot and a crack of green on the shoulder.
    p.rect(14, 48, 50, 56, moss)
    p.rect(18, 46, 28, 50, moss_h)
    p.rect(36, 14, 44, 20, moss)
    # Base.
    p.rect(12, 52, 52, 58, stone_l)
    return p.finish()


def hell() -> Image.Image:
    """Iron brazier. Same fire language as the campfire icon."""
    p = Pix()
    iron = (56, 48, 48, 255)
    iron_h = (104, 92, 88, 255)
    iron_l = (28, 22, 22, 255)
    lo = (160, 40, 16, 255)
    mid = (240, 112, 32, 255)
    hi = (255, 214, 112, 255)
    # Bowl.
    p.rect(12, 38, 52, 50, iron)
    p.rect(16, 34, 48, 42, iron_h)
    p.rect(18, 46, 46, 52, iron_l)
    # Legs.
    p.rect(16, 50, 22, 58, iron_l)
    p.rect(42, 50, 48, 58, iron_l)
    p.rect(30, 50, 34, 58, iron)
    # Coals.
    p.rect(20, 36, 44, 42, lo)
    # Flame.
    p.rect(24, 26, 40, 38, lo)
    p.rect(26, 16, 38, 30, mid)
    p.rect(29, 8, 35, 20, hi)
    p.rect(20, 22, 26, 32, mid)
    p.rect(38, 20, 44, 32, lo)
    p.rect(30, 12, 33, 16, (255, 244, 210, 255))
    return p.finish()


def crystal() -> Image.Image:
    """Three ice crystals on a rock — not one flat diamond."""
    p = Pix()
    rock = (58, 64, 72, 255)
    rock_h = (96, 104, 112, 255)
    ice = (120, 196, 224, 255)
    ice_h = (220, 246, 255, 255)
    ice_l = (48, 112, 156, 255)
    p.rect(8, 46, 56, 58, rock)
    p.rect(12, 42, 52, 48, rock_h)
    # Left shard.
    p.diamond(18, 36, 8, 18, ice)
    p.diamond(16, 32, 3, 12, ice_h)
    p.rect(20, 28, 22, 46, ice_l)
    # Center shard, tallest.
    p.diamond(34, 30, 10, 26, ice)
    p.diamond(31, 24, 4, 16, ice_h)
    p.rect(38, 16, 40, 48, ice_l)
    # Right shard.
    p.diamond(50, 38, 7, 14, ice_l)
    p.diamond(48, 36, 3, 8, ice)
    return p.finish()


def tide() -> Image.Image:
    """Ship anchor with one coral barnacle."""
    p = Pix()
    iron = (88, 104, 112, 255)
    iron_h = (176, 196, 204, 255)
    iron_l = (40, 52, 60, 255)
    coral = (224, 120, 80, 255)
    coral_h = (255, 180, 140, 255)
    # Ring.
    p.disc(32, 12, 9, iron)
    p.erase_disc(32, 12, 4)
    p.rect(28, 6, 31, 10, iron_h)
    # Stock.
    p.rect(14, 20, 50, 28, iron)
    p.rect(14, 20, 50, 22, iron_h)
    p.rect(14, 26, 50, 28, iron_l)
    # Shank.
    p.rect(28, 16, 36, 46, iron)
    p.rect(28, 16, 31, 46, iron_h)
    p.rect(34, 30, 36, 46, iron_l)
    # Flukes.
    p.rect(10, 42, 30, 50, iron)
    p.rect(34, 42, 54, 50, iron)
    p.rect(10, 36, 18, 50, iron_h)
    p.rect(46, 36, 54, 50, iron_l)
    p.rect(10, 42, 22, 44, iron_h)
    # Coral on the right fluke.
    p.rect(46, 34, 54, 42, coral)
    p.rect(48, 32, 52, 36, coral_h)
    return p.finish()


def ember() -> Image.Image:
    """Ash caldera: rock cone, lava mouth."""
    p = Pix()
    rock = (62, 48, 40, 255)
    rock_h = (112, 84, 64, 255)
    rock_l = (32, 24, 20, 255)
    lava = (255, 96, 32, 255)
    lava_h = (255, 210, 96, 255)
    lava_l = (176, 40, 16, 255)
    # Cone.
    p.rect(6, 40, 58, 58, rock)
    p.rect(12, 32, 52, 44, rock)
    p.rect(18, 24, 46, 36, rock_h)
    p.rect(24, 18, 40, 28, rock_h)
    p.rect(6, 50, 58, 58, rock_l)
    p.rect(40, 36, 56, 52, rock_l)
    # Crater.
    p.rect(22, 20, 42, 32, lava_l)
    p.rect(26, 22, 38, 30, lava)
    p.rect(28, 24, 34, 28, lava_h)
    # Drip down the right slope.
    p.rect(40, 30, 46, 48, lava)
    p.rect(42, 44, 48, 54, lava_l)
    p.rect(41, 32, 43, 36, lava_h)
    return p.finish()


def grove() -> Image.Image:
    """Oak: trunk plus leafy clumps, not a circle on a stick."""
    p = Pix()
    leaf = (36, 120, 48, 255)
    leaf_h = (120, 196, 72, 255)
    leaf_l = (20, 72, 32, 255)
    trunk = (112, 72, 40, 255)
    trunk_h = (160, 108, 64, 255)
    trunk_l = (64, 40, 24, 255)
    # Canopy clumps.
    p.disc(32, 24, 16, leaf)
    p.disc(16, 30, 11, leaf_l)
    p.disc(48, 30, 11, leaf)
    p.disc(32, 14, 8, leaf_h)
    p.disc(22, 18, 6, leaf_h)
    p.rect(20, 28, 28, 36, leaf_l)
    p.rect(36, 16, 42, 22, leaf_h)
    # Trunk.
    p.rect(26, 36, 38, 56, trunk)
    p.rect(26, 36, 30, 56, trunk_h)
    p.rect(34, 44, 38, 56, trunk_l)
    # Root flare.
    p.rect(20, 52, 44, 58, trunk_l)
    p.rect(22, 50, 30, 54, trunk)
    return p.finish()


def storm() -> Image.Image:
    """Wide storm cloud with a bolt, not a bolt alone or a heart."""
    p = Pix()
    cloud = (72, 64, 96, 255)
    cloud_h = (150, 146, 176, 255)
    cloud_l = (40, 32, 58, 255)
    bolt = (255, 220, 72, 255)
    bolt_h = (255, 248, 200, 255)
    # Flat bank, three square puffs — discs were reading as a heart.
    p.rect(6, 18, 58, 34, cloud)
    p.rect(8, 10, 24, 24, cloud_h)
    p.rect(22, 6, 42, 22, cloud_h)
    p.rect(38, 12, 56, 26, cloud)
    p.rect(8, 28, 56, 36, cloud_l)
    p.rect(14, 8, 22, 14, (190, 186, 210, 255))
    # Bolt under the bank.
    p.rect(30, 32, 38, 42, bolt)
    p.rect(22, 40, 34, 48, bolt)
    p.rect(30, 46, 40, 58, bolt)
    p.rect(32, 34, 35, 40, bolt_h)
    p.rect(24, 42, 28, 46, bolt_h)
    return p.finish()


def rime() -> Image.Image:
    """Frozen spire. Tall ice, not a plus sign."""
    p = Pix()
    ice = (168, 220, 236, 255)
    ice_h = (236, 250, 255, 255)
    ice_l = (64, 140, 176, 255)
    snow = (244, 248, 252, 255)
    rock = (70, 78, 88, 255)
    p.rect(10, 50, 54, 58, rock)
    # Spire.
    p.rect(26, 8, 38, 52, ice)
    p.rect(26, 8, 31, 52, ice_h)
    p.rect(34, 20, 38, 52, ice_l)
    p.rect(28, 4, 36, 12, snow)
    # Side icicles.
    p.rect(16, 28, 24, 50, ice_l)
    p.rect(16, 28, 19, 40, ice)
    p.rect(40, 24, 48, 48, ice)
    p.rect(40, 24, 43, 36, ice_h)
    p.rect(44, 32, 48, 48, ice_l)
    # Snow caps on the small ones.
    p.rect(16, 26, 24, 30, snow)
    p.rect(40, 22, 48, 26, snow)
    return p.finish()


def fen() -> Image.Image:
    """Cattails in a mud pool."""
    p = Pix()
    mud = (62, 52, 28, 255)
    mud_h = (104, 86, 44, 255)
    water = (36, 58, 32, 255)
    reed = (150, 132, 48, 255)
    reed_h = (210, 186, 80, 255)
    head = (92, 56, 28, 255)
    head_h = (140, 88, 44, 255)
    p.rect(6, 40, 58, 58, mud)
    p.rect(10, 36, 54, 46, mud_h)
    p.rect(14, 42, 50, 54, water)
    p.rect(18, 44, 28, 48, mud_h)
    # Three reeds.
    p.rect(18, 16, 22, 46, reed)
    p.rect(18, 16, 20, 30, reed_h)
    p.rect(16, 8, 24, 18, head)
    p.rect(17, 9, 20, 13, head_h)
    p.rect(30, 12, 34, 48, reed_h)
    p.rect(28, 4, 36, 16, head)
    p.rect(29, 5, 32, 10, head_h)
    p.rect(44, 20, 48, 46, reed)
    p.rect(42, 12, 50, 22, head_h)
    p.rect(43, 13, 46, 17, (180, 120, 64, 255))
    return p.finish()


def brass() -> Image.Image:
    """Toothed brass gear on a short pipe. Not a crosshair."""
    p = Pix()
    brass = (184, 132, 40, 255)
    brass_h = (240, 200, 96, 255)
    brass_l = (112, 72, 24, 255)
    hole = (36, 24, 12, 255)
    pipe = (72, 64, 56, 255)
    # Teeth.
    for box in (
        (26, 4, 38, 16),
        (26, 48, 38, 60),
        (4, 26, 16, 38),
        (48, 26, 60, 38),
        (10, 10, 22, 22),
        (42, 10, 54, 22),
        (10, 42, 22, 54),
        (42, 42, 54, 54),
    ):
        p.rect(*box, brass_l)
    # Body over the inner half of the teeth.
    p.disc(32, 32, 18, brass)
    p.disc(28, 26, 8, brass_h)
    p.disc(32, 32, 7, hole)
    p.rect(30, 22, 34, 28, brass_h)
    # Pipe under the gear so it reads as a machine.
    p.rect(28, 48, 36, 60, pipe)
    p.rect(24, 54, 40, 60, pipe)
    return p.finish()


def veil() -> Image.Image:
    """Moth. Wings, body, eye-spots — not an X."""
    p = Pix()
    wing = (112, 64, 150, 255)
    wing_h = (196, 150, 220, 255)
    wing_l = (64, 32, 96, 255)
    body = (36, 24, 48, 255)
    spot = (255, 220, 140, 255)
    # Upper wings.
    p.diamond(20, 28, 16, 14, wing)
    p.diamond(44, 28, 16, 14, wing)
    p.diamond(16, 24, 8, 8, wing_h)
    p.diamond(48, 24, 8, 8, wing_h)
    # Lower wings.
    p.diamond(22, 44, 12, 10, wing_l)
    p.diamond(42, 44, 12, 10, wing_l)
    p.diamond(20, 42, 6, 5, wing)
    # Body.
    p.rect(29, 16, 35, 52, body)
    p.rect(30, 18, 32, 28, wing_h)
    # Eye spots.
    p.disc(16, 30, 4, spot)
    p.disc(48, 30, 4, spot)
    p.disc(16, 30, 2, body)
    p.disc(48, 30, 2, body)
    # Antennae.
    p.rect(26, 8, 28, 16, body)
    p.rect(36, 8, 38, 16, body)
    p.rect(22, 6, 26, 9, body)
    p.rect(38, 6, 42, 9, body)
    return p.finish()


PAINTERS = {
    "sandy": sandy,
    "goblin": goblin,
    "king": king,
    "underworld": underworld,
    "dead": dead,
    "hell": hell,
    "crystal": crystal,
    "tide": tide,
    "ember": ember,
    "grove": grove,
    "storm": storm,
    "rime": rime,
    "fen": fen,
    "brass": brass,
    "veil": veil,
}


def main() -> None:
    seen: dict[bytes, str] = {}
    for zone in ZONES:
        img = PAINTERS[zone]()
        if img.size != (N, N):
            raise SystemExit(f"{zone} is {img.size}, expected {N}")
        raw = img.tobytes()
        if raw in seen:
            raise SystemExit(f"{zone} matches {seen[raw]}")
        seen[raw] = zone
        path = ROOT / zone / "hub_icon.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        img.save(path)
        print(f"  {zone}: {path.stat().st_size} bytes")
    print(f"hub map pins: {len(ZONES)}")


if __name__ == "__main__":
    main()
