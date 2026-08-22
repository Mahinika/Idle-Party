#!/usr/bin/env py
"""Generate owned dungeon pixel art for all zones (docs/DUNGEON_ART.md)."""

from __future__ import annotations

import random
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / "assets" / "custom" / "dungeon"

ALL_ZONES = (
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

PROP_FILES = (
    "barrel",
    "crate",
    "table",
    "stool",
    "torch",
    "torch_alt",
    "gravestone",
    "fountain",
    "trap",
    "pot",
    "bones",
    "skull",
    "hatch",
    "water",
    "lava",
    "anvil",
    "shelf",
    "fence",
    "pillar",
    "rubble",
    "chest",
)

# Flutter Color(0xAARRGGBB) wash + ambient per zone (lib/models/zone_art.dart).
ZONE_WASH_AMBIENT: dict[str, tuple[int, int]] = {
    "sandy": (0xC88840, 0x0C0A08),
    "goblin": (0x28A050, 0x0A0C09),
    "king": (0x3060A0, 0x080A10),
    "underworld": (0x7040B0, 0x0A0810),
    "dead": (0x305040, 0x070908),
    "hell": (0xA02018, 0x120606),
    "crystal": (0x50A0F0, 0x081018),
    "tide": (0x20B8A0, 0x02141A),
    "ember": (0xE08820, 0x160A02),
    "grove": (0x48A838, 0x041208),
    "storm": (0x8040D0, 0x0A0614),
    "rime": (0x60D8E0, 0x041018),
    "fen": (0xB0C028, 0x0C1404),
    "brass": (0xC89820, 0x120A04),
    "veil": (0xE8C8F8, 0x140812),
}

# Extra identity knobs beyond wash/ambient (hell≠ember, sandy sand, etc.).
ZONE_FLOOR_STYLE: dict[str, str] = {
    "sandy": "sand",
    "goblin": "moss_dirt",
    "king": "flagstone",
    "underworld": "void_crack",
    "dead": "ashen",
    "hell": "bloodstone",
    "crystal": "crystal",
    "tide": "silt",
    "ember": "forge",
    "grove": "root",
    "storm": "storm",
    "rime": "frost",
    "fen": "swamp",
    "brass": "brass",
    "veil": "silk",
}


def _rgb(c: int) -> tuple[int, int, int]:
    return ((c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF)


def _blend(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _dark(c: tuple[int, int, int], f: float = 0.55) -> tuple[int, int, int]:
    return tuple(max(0, int(x * f)) for x in c)


def _lite(c: tuple[int, int, int], f: float = 1.35) -> tuple[int, int, int]:
    return tuple(min(255, int(x * f)) for x in c)


@dataclass
class Palette:
    floor: tuple[int, int, int]
    floor_m: tuple[int, int, int]
    floor_hi: tuple[int, int, int]
    floor_lo: tuple[int, int, int]
    wall: tuple[int, int, int]
    wall_m: tuple[int, int, int]
    wall_hi: tuple[int, int, int]
    wall_lo: tuple[int, int, int]
    accent: tuple[int, int, int]
    accent_m: tuple[int, int, int]
    accent_hi: tuple[int, int, int]
    accent_pale: tuple[int, int, int]
    wood: tuple[int, int, int]
    wood_m: tuple[int, int, int]
    wood_hi: tuple[int, int, int]
    wet: tuple[int, int, int]
    wet_m: tuple[int, int, int]
    wet_hi: tuple[int, int, int]
    lava: tuple[int, int, int]
    lava_m: tuple[int, int, int]
    lava_hi: tuple[int, int, int]
    glow: tuple[int, int, int]
    bone: tuple[int, int, int]
    outline: tuple[int, int, int]


def palette_for(zone_id: str) -> Palette:
    wash, ambient = ZONE_WASH_AMBIENT[zone_id]
    w, a = _rgb(wash), _rgb(ambient)

    # Strong identity anchors — generator wash alone made hell≈ember and dead≈underworld.
    if zone_id == "hell":
        floor = (0x28, 0x0C, 0x0A)
        accent = (0xD0, 0x38, 0x28)
        lava = (0xE8, 0x50, 0x18)
        wet = (0x60, 0x10, 0x08)
    elif zone_id == "ember":
        floor = (0x34, 0x20, 0x0C)
        accent = (0xF0, 0x98, 0x28)
        lava = (0xFF, 0xA8, 0x30)
        wet = (0x50, 0x28, 0x08)
    elif zone_id == "sandy":
        floor = (0x5A, 0x44, 0x28)
        accent = (0xD8, 0xA8, 0x58)
        lava = _blend(w, (0xFF, 0x60, 0x20), 0.55)
        wet = _blend(w, (0x90, 0xC0, 0xE0), 0.25)
    elif zone_id == "goblin":
        floor = (0x28, 0x34, 0x1A)
        accent = (0x48, 0xB0, 0x48)
        lava = _blend(w, (0xFF, 0x60, 0x20), 0.55)
        wet = _blend(w, (0x28, 0x70, 0x38), 0.45)
    elif zone_id == "dead":
        floor = (0x1A, 0x22, 0x24)
        accent = (0x68, 0x88, 0x80)
        lava = _blend(w, (0xFF, 0x60, 0x20), 0.55)
        wet = _blend(w, (0x40, 0x60, 0x58), 0.35)
    elif zone_id == "underworld":
        floor = (0x18, 0x10, 0x28)
        accent = (0x90, 0x48, 0xD0)
        lava = _blend(w, (0xFF, 0x40, 0x80), 0.45)
        wet = _blend(w, (0x50, 0x28, 0x90), 0.45)
    elif zone_id == "tide":
        floor = (0x1A, 0x3A, 0x42)
        accent = (0x38, 0xD0, 0xB8)
        lava = _blend(w, (0xFF, 0x60, 0x20), 0.55)
        wet = (0x28, 0xA0, 0xB8)
    elif zone_id == "rime":
        floor = (0x18, 0x38, 0x48)
        accent = (0x88, 0xE8, 0xF8)
        lava = _blend(w, (0xFF, 0x60, 0x20), 0.55)
        wet = (0x48, 0xC8, 0xE8)
    elif zone_id == "storm":
        floor = (0x20, 0x14, 0x30)
        accent = (0xA8, 0x58, 0xE8)
        lava = _blend(w, (0xFF, 0xE0, 0x40), 0.35)
        wet = _blend(w, (0x60, 0x40, 0xC0), 0.45)
    else:
        floor = _blend(a, w, 0.35)
        accent = w
        wet = _blend(w, (0x28, 0xA0, 0xB8), 0.45)
        lava = _blend(w, (0xFF, 0x60, 0x20), 0.55)

    outline = _blend(_dark(a, 0.35), (0x48, 0x48, 0x50), 0.35)
    return Palette(
        floor=floor,
        floor_m=_blend(floor, accent, 0.35),
        floor_hi=_lite(_blend(floor, accent, 0.5), 1.08),
        floor_lo=_dark(floor, 0.72),
        wall=_dark(_blend(a, accent, 0.3), 0.82),
        wall_m=_dark(_blend(a, accent, 0.4), 0.92),
        wall_hi=_blend(_dark(a, 0.88), accent, 0.4),
        wall_lo=_dark(a, 0.42),
        accent=accent,
        accent_m=_dark(accent, 0.82),
        accent_hi=_lite(accent, 1.22),
        accent_pale=_lite(_blend(accent, (255, 255, 255), 0.48), 1.05),
        wood=_blend(a, (0x5A, 0x40, 0x30), 0.5),
        wood_m=_blend(a, (0x6E, 0x50, 0x38), 0.55),
        wood_hi=_blend(a, (0x80, 0x60, 0x40), 0.45),
        wet=wet,
        wet_m=_lite(wet, 1.15),
        wet_hi=_lite(wet, 1.45),
        lava=lava,
        lava_m=_lite(lava, 1.18),
        lava_hi=_lite(lava, 1.5),
        glow=_lite(accent, 1.55),
        bone=_blend((0xE8, 0xE0, 0xD0), accent, 0.12),
        outline=outline,
    )


class Generator:
    def __init__(self, zone_id: str) -> None:
        self.zone_id = zone_id
        self.p = palette_for(zone_id)
        self.floor_style = ZONE_FLOOR_STYLE.get(zone_id, "stone")
        self.rng = random.Random(hash(zone_id) & 0xFFFF)
        # Props read better on phone — slightly lifted rim vs void-black tile outline.
        self.prop_outline = _lite(self.p.outline, 1.45)

    def save(self, img: Image.Image, rel: str) -> None:
        path = ROOT / self.zone_id / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        img.save(path, optimize=True)

    def px(self, img: Image.Image, x: int, y: int, c) -> None:
        if 0 <= x < img.width and 0 <= y < img.height:
            img.putpixel((x, y), c)

    def tile_floor(self, variant: int) -> Image.Image:
        p = self.p
        img = Image.new("RGB", (16, 16), p.floor)
        for y in range(16):
            for x in range(16):
                n = (x * 5 + y * 3 + variant * 7) % 11
                if n in (0, 1):
                    self.px(img, x, y, p.floor_hi if n == 0 else p.floor_m)
                elif n == 2:
                    self.px(img, x, y, p.floor_lo)
                elif n == 3:
                    self.px(img, x, y, p.accent_m)
        d = ImageDraw.Draw(img)
        style = self.floor_style
        if style == "sand":
            for y in range(0, 16, 3):
                d.line([(0, y), (15, y)], fill=p.floor_lo)
            for x, y in ((2, 5), (9, 11), (13, 3)):
                self.px(img, x, y, p.accent_pale)
        elif style == "moss_dirt":
            for x, y in ((3, 4), (11, 9), (6, 13), (14, 6)):
                self.px(img, x, y, p.accent)
                self.px(img, x + 1, y, p.accent_m)
        elif style == "bloodstone":
            for x in range(16):
                if (x + variant) % 5 == 0:
                    self.px(img, x, 7, p.lava_m)
                    self.px(img, x, 8, p.lava)
        elif style == "forge":
            for y in range(4, 14, 3):
                d.line([(2, y), (13, y)], fill=p.lava_m)
            self.px(img, 8, 10, p.lava_hi)
        elif style == "silt":
            if variant:
                for x in range(16):
                    y = 5 + ((x + variant) % 4)
                    self.px(img, x, y, p.floor_m)
            else:
                for y in range(0, 16, 4):
                    d.line([(0, y), (15, y)], fill=p.floor_lo)
        elif style == "frost":
            for x, y in ((4, 4), (11, 7), (7, 12), (13, 2)):
                self.px(img, x, y, p.accent_pale)
                self.px(img, x, y + 1, p.wet_hi)
        elif style == "storm":
            if variant == 0:
                d.line([(0, 6), (15, 9)], fill=p.accent_m)
        elif style == "void_crack":
            d.line([(4, 0), (6, 15)], fill=p.accent_m)
            d.line([(12, 0), (10, 15)], fill=p.accent_m)
        elif style == "ashen":
            for x in range(0, 16, 4):
                self.px(img, x, 8, p.bone)
        elif style == "swamp":
            d.ellipse([2, 10, 8, 14], fill=p.wet_m)
            d.ellipse([9, 11, 14, 15], fill=p.wet_m)
        elif style == "crystal":
            for x, y in ((2, 2), (13, 4), (8, 13)):
                d.polygon([(x, y), (x + 2, y + 1), (x + 1, y + 3)], fill=p.wet_hi)
        elif style == "flagstone":
            for y in range(0, 16, 4):
                d.line([(0, y), (15, y)], fill=p.floor_lo)
            for x in range(0, 16, 8):
                d.line([(x, 0), (x, 15)], fill=p.floor_lo)
        elif style == "root":
            for x, y in ((2, 8), (8, 12), (14, 6)):
                d.line([(x, y), (x + 4, y + 2)], fill=p.wood_m)
        elif style == "brass":
            for x in range(2, 14, 4):
                self.px(img, x, 8, p.accent_hi)
                self.px(img, x + 1, 9, p.accent)
        elif style == "silk":
            for y in range(2, 14, 3):
                d.line([(1, y), (14, y + 1)], fill=p.accent_pale)
        elif variant:
            for x in range(16):
                y = 5 + ((x + variant) % 4)
                self.px(img, x, y, p.floor_m)
        else:
            for y in range(0, 16, 4):
                d.line([(0, y), (15, y)], fill=p.floor_lo)
        for x, y in ((0, 0), (15, 0), (0, 15), (15, 15)):
            self.px(img, x, y, p.floor_lo)
        return img

    def tile_wall(self, variant: int) -> Image.Image:
        p = self.p
        img = Image.new("RGB", (16, 16), p.wall)
        for x in range(16):
            self.px(img, x, 0, p.wall_hi)
            self.px(img, x, 1, p.wall_m)
            self.px(img, x, 14, p.wall_lo)
            self.px(img, x, 15, p.outline)
        d = ImageDraw.Draw(img)
        for y in range(2, 14, 4):
            d.line([(0, y), (15, y)], fill=p.wall_lo)
        for x in range(0, 16, 8):
            d.line([(x, 2), (x, 13)], fill=p.wall_lo)
        spots = [(3, 6), (11, 9)] if variant == 0 else [(2, 8), (12, 5), (7, 11)]
        for x, y in spots:
            self.px(img, x, y, p.accent if (x + y) % 2 == 0 else p.accent_m)
        return img

    def tile_stairs(self, boss: bool) -> Image.Image:
        p = self.p
        img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        pool = p.lava if self.zone_id in ("hell", "ember") else p.wet
        pool_hi = p.lava_hi if self.zone_id in ("hell", "ember") else p.wet_hi
        d.rectangle([1, 11, 14, 15], fill=(*pool, 255))
        for i, y in enumerate(range(10, 2, -2)):
            left, right = 2 + i, 13 - i
            shade = p.floor_hi if i % 2 == 0 else p.floor_m
            d.rectangle([left, y, right, y + 1], fill=(*shade, 255))
        top = p.accent_hi if boss else pool_hi
        d.rectangle([5, 2, 10, 4], fill=(*top, 255), outline=p.outline)
        if boss:
            d.rectangle([0, 0, 15, 1], fill=(*p.accent, 255))
            self.px(img, 7, 1, p.glow)
        return img

    def tile_door(self, open_gate: bool) -> Image.Image:
        p = self.p
        img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rectangle([2, 1, 13, 14], fill=(*p.wall_lo, 255), outline=p.outline)
        d.rectangle([3, 2, 12, 13], fill=(*p.wall, 255))
        if open_gate:
            d.rectangle([5, 4, 10, 12], fill=(*p.wet, 255))
            self.px(img, 7, 6, p.wet_hi)
        else:
            for y in range(4, 12):
                for x in range(4, 12):
                    if (x + y) % 2 == 0:
                        self.px(img, x, y, p.accent if y < 8 else p.accent_m)
            d.rectangle([4, 3, 11, 12], outline=p.accent_hi)
        return img

    def prop_water(self) -> Image.Image:
        p = self.p
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.ellipse([3, 12, 29, 27], fill=(*p.wet, 255), outline=self.prop_outline)
        d.ellipse([8, 15, 24, 24], fill=(*p.wet_m, 255))
        self.px(img, 14, 18, p.glow)
        return img

    def prop_lava(self) -> Image.Image:
        p = self.p
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.ellipse([4, 13, 28, 28], fill=(*p.lava, 255), outline=self.prop_outline)
        d.ellipse([9, 16, 23, 25], fill=(*p.lava_m, 255))
        self.px(img, 15, 19, p.lava_hi)
        return img

    def prop_fountain(self) -> Image.Image:
        p = self.p
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.ellipse([6, 22, 26, 31], fill=(*p.wet, 200), outline=self.prop_outline)
        d.polygon([(10, 22), (22, 22), (24, 28), (8, 28)], fill=p.accent, outline=self.prop_outline)
        d.rectangle([13, 10, 19, 22], fill=p.accent_m, outline=self.prop_outline)
        d.ellipse([11, 6, 21, 14], fill=p.wet_hi, outline=self.prop_outline)
        self.px(img, 16, 4, p.glow)
        self.px(img, 12, 24, p.wet_hi)
        self.px(img, 20, 25, p.wet_hi)
        return img

    def prop_barrel(self) -> Image.Image:
        p = self.p
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.ellipse([7, 11, 25, 29], fill=p.wood, outline=self.prop_outline)
        d.line([(7, 18), (25, 18)], fill=p.wood_m)
        d.line([(7, 23), (25, 23)], fill=p.wood_m)
        self.px(img, 10, 14, p.accent_m)
        return img

    def prop_crate(self) -> Image.Image:
        p = self.p
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rectangle([7, 12, 25, 28], fill=p.wood, outline=self.prop_outline)
        d.line([(7, 20), (25, 20)], fill=p.wood_m)
        d.line([(16, 12), (16, 28)], fill=p.wood_m)
        return img

    def prop_table(self) -> Image.Image:
        p = self.p
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rectangle([6, 14, 26, 18], fill=p.wood_hi, outline=self.prop_outline)
        for x in (9, 23):
            d.rectangle([x, 18, x + 2, 27], fill=p.wood_m)
        return img

    def prop_stool(self) -> Image.Image:
        p = self.p
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.ellipse([10, 16, 22, 22], fill=p.wood_hi, outline=self.prop_outline)
        d.rectangle([15, 22, 17, 28], fill=p.wood_m)
        return img

    def prop_torch(self, alt: bool) -> Image.Image:
        p = self.p
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rectangle([15, 14, 17, 28], fill=p.wood_m, outline=self.prop_outline)
        flame = p.lava_hi if alt else p.accent_hi
        core = p.glow if alt else p.accent_pale
        d.polygon([(16, 6), (20, 14), (12, 14)], fill=flame, outline=self.prop_outline)
        self.px(img, 16, 10, core)
        return img

    def prop_gravestone(self) -> Image.Image:
        p = self.p
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rectangle([11, 10, 21, 28], fill=p.wall_m, outline=self.prop_outline)
        d.polygon([(11, 10), (16, 4), (21, 10)], fill=p.wall_hi, outline=self.prop_outline)
        d.line([(16, 12), (16, 18)], fill=p.accent_m)
        d.line([(13, 15), (19, 15)], fill=p.accent_m)
        return img

    def prop_trap(self) -> Image.Image:
        p = self.p
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rectangle([6, 18, 26, 26], fill=p.wall_lo, outline=self.prop_outline)
        for x in range(8, 25, 4):
            d.polygon([(x, 26), (x + 2, 14), (x + 4, 26)], fill=p.accent_hi, outline=self.prop_outline)
        return img

    def prop_pot(self) -> Image.Image:
        p = self.p
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.polygon([(9, 13), (23, 13), (25, 27), (7, 27)], fill=p.accent, outline=self.prop_outline)
        d.rectangle([11, 8, 21, 13], fill=p.accent_hi, outline=self.prop_outline)
        return img

    def prop_bones(self) -> Image.Image:
        p = self.p
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.line([(8, 22), (24, 14)], fill=p.bone, width=2)
        d.ellipse([6, 20, 12, 26], fill=p.bone, outline=self.prop_outline)
        d.ellipse([20, 12, 26, 18], fill=p.bone, outline=self.prop_outline)
        return img

    def prop_skull(self) -> Image.Image:
        p = self.p
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.ellipse([10, 10, 22, 24], fill=p.bone, outline=self.prop_outline)
        d.ellipse([12, 14, 15, 17], fill=p.outline)
        d.ellipse([17, 14, 20, 17], fill=p.outline)
        return img

    def prop_hatch(self) -> Image.Image:
        p = self.p
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rectangle([5, 13, 27, 28], fill=p.wall_lo, outline=self.prop_outline)
        for x in range(8, 25, 4):
            d.line([(x, 15), (x, 26)], fill=p.wood_hi)
        d.rectangle([9, 22, 23, 26], fill=(*p.wet, 220))
        return img

    def prop_anvil(self) -> Image.Image:
        p = self.p
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rectangle([8, 20, 24, 28], fill=p.wall_m, outline=self.prop_outline)
        d.polygon([(10, 20), (22, 20), (20, 14), (12, 14)], fill=p.wall_hi, outline=self.prop_outline)
        d.rectangle([13, 10, 19, 14], fill=p.accent_m, outline=self.prop_outline)
        return img

    def prop_shelf(self) -> Image.Image:
        p = self.p
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rectangle([8, 12, 24, 14], fill=p.wood_hi, outline=self.prop_outline)
        d.rectangle([8, 18, 24, 20], fill=p.wood_hi, outline=self.prop_outline)
        d.rectangle([9, 14, 14, 18], fill=p.wood_m, outline=self.prop_outline)
        d.rectangle([18, 14, 23, 18], fill=p.wood_m, outline=self.prop_outline)
        return img

    def prop_fence(self) -> Image.Image:
        p = self.p
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rectangle([6, 12, 26, 14], fill=p.accent_m, outline=self.prop_outline)
        for x in range(8, 25, 5):
            d.rectangle([x, 8, x + 2, 24], fill=p.accent, outline=self.prop_outline)
        return img

    def prop_pillar(self) -> Image.Image:
        p = self.p
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rectangle([11, 5, 21, 28], fill=p.accent, outline=self.prop_outline)
        d.rectangle([9, 3, 23, 7], fill=p.accent_hi, outline=self.prop_outline)
        d.rectangle([10, 27, 22, 30], fill=p.wall_lo, outline=self.prop_outline)
        for y in range(6, 26, 3):
            self.px(img, 12, y, p.accent_pale)
        return img

    def prop_rubble(self) -> Image.Image:
        p = self.p
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        for x, y, c in ((8, 20, p.wall_m), (14, 22, p.wall_lo), (20, 19, p.wall_hi), (12, 16, p.floor_m)):
            d.rectangle([x, y, x + 5, y + 4], fill=c, outline=self.prop_outline)
        return img

    def prop_chest(self) -> Image.Image:
        p = self.p
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rectangle([5, 15, 27, 27], fill=p.wood, outline=self.prop_outline)
        d.rectangle([5, 10, 27, 17], fill=p.wood_hi, outline=self.prop_outline)
        d.rectangle([14, 11, 18, 26], fill=p.accent, outline=self.prop_outline)
        self.px(img, 16, 12, p.accent_pale)
        self.px(img, 16, 18, p.glow)
        self.px(img, 8, 14, p.wood_hi)
        return img

    def hub_icon(self) -> Image.Image:
        p = self.p
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        icons = {
            "sandy": lambda: d.ellipse([8, 10, 24, 26], fill=p.accent, outline=self.prop_outline),
            "goblin": lambda: d.rectangle([8, 8, 24, 26], fill=p.wood, outline=self.prop_outline),
            "king": lambda: d.polygon([(16, 4), (24, 12), (20, 26), (12, 26), (8, 12)], fill=p.accent_hi, outline=self.prop_outline),
            "underworld": lambda: d.polygon([(16, 4), (22, 28), (10, 28)], fill=p.accent, outline=self.prop_outline),
            "dead": lambda: None,
            "hell": lambda: d.polygon([(16, 4), (22, 18), (16, 28), (10, 18)], fill=p.lava_hi, outline=self.prop_outline),
            "crystal": lambda: d.polygon([(16, 4), (26, 16), (16, 28), (6, 16)], fill=p.wet_hi, outline=self.prop_outline),
            "tide": lambda: d.polygon([(16, 3), (21, 10), (19, 18), (16, 20), (13, 18), (11, 10)], fill=p.accent, outline=self.prop_outline),
            "ember": lambda: d.rectangle([12, 10, 20, 22], fill=p.wall_m, outline=self.prop_outline),
            "grove": lambda: d.polygon([(16, 4), (26, 20), (16, 28), (6, 20)], fill=p.accent, outline=self.prop_outline),
            "storm": lambda: d.polygon([(18, 4), (22, 14), (28, 14), (20, 20), (24, 30), (14, 18), (10, 18), (16, 12), (12, 4)], fill=p.accent_hi, outline=self.prop_outline),
            "rime": lambda: d.line([(16, 4), (16, 28)], fill=p.wet_hi, width=2),
            "fen": lambda: d.ellipse([10, 14, 22, 26], fill=p.accent_m, outline=self.prop_outline),
            "brass": lambda: d.ellipse([8, 8, 24, 24], fill=p.accent_hi, outline=self.prop_outline),
            "veil": lambda: d.polygon([(6, 16), (16, 6), (26, 16), (16, 26)], fill=p.accent_pale, outline=self.prop_outline),
        }
        fn = icons.get(self.zone_id, icons["sandy"])
        if self.zone_id == "dead":
            d.rectangle([11, 10, 21, 28], fill=p.wall_m, outline=self.prop_outline)
            d.polygon([(11, 10), (16, 4), (21, 10)], fill=p.wall_hi, outline=self.prop_outline)
            d.line([(16, 12), (16, 18)], fill=p.accent_m)
            d.line([(13, 15), (19, 15)], fill=p.accent_m)
        elif self.zone_id == "rime":
            d.line([(16, 4), (16, 28)], fill=p.wet_hi, width=2)
            d.line([(8, 16), (24, 16)], fill=p.wet_hi, width=2)
            d.line([(10, 8), (22, 24)], fill=p.wet_m, width=1)
            d.line([(22, 8), (10, 24)], fill=p.wet_m, width=1)
        elif self.zone_id == "ember":
            d.rectangle([12, 10, 20, 22], fill=p.wall_m, outline=self.prop_outline)
            self.px(img, 16, 8, p.lava_hi)
        else:
            fn()
        self.px(img, 16, 16, p.glow)
        return img

    def prop_by_name(self, name: str) -> Image.Image:
        return {
            "barrel": self.prop_barrel,
            "crate": self.prop_crate,
            "table": self.prop_table,
            "stool": self.prop_stool,
            "torch": lambda: self.prop_torch(False),
            "torch_alt": lambda: self.prop_torch(True),
            "gravestone": self.prop_gravestone,
            "fountain": self.prop_fountain,
            "trap": self.prop_trap,
            "pot": self.prop_pot,
            "bones": self.prop_bones,
            "skull": self.prop_skull,
            "hatch": self.prop_hatch,
            "water": self.prop_water,
            "lava": self.prop_lava,
            "anvil": self.prop_anvil,
            "shelf": self.prop_shelf,
            "fence": self.prop_fence,
            "pillar": self.prop_pillar,
            "rubble": self.prop_rubble,
            "chest": self.prop_chest,
        }[name]()

    def generate_all(self) -> None:
        self.save(self.tile_floor(0), "tiles/floor_a.png")
        self.save(self.tile_floor(1), "tiles/floor_b.png")
        self.save(self.tile_wall(0), "tiles/wall_a.png")
        self.save(self.tile_wall(1), "tiles/wall_b.png")
        self.save(self.tile_stairs(False), "tiles/stairs.png")
        self.save(self.tile_stairs(True), "tiles/stairs_boss.png")
        self.save(self.tile_door(False), "tiles/door_closed.png")
        self.save(self.tile_door(True), "tiles/door_open.png")
        for name in PROP_FILES:
            self.save(self.prop_by_name(name), f"props/{name}.png")
        self.save(self.hub_icon(), "hub_icon.png")
        print(f"  {self.zone_id}: {8 + len(PROP_FILES) + 1} PNGs")


def main() -> None:
    print("Generating custom dungeon art for all zones…")
    for zone_id in ALL_ZONES:
        Generator(zone_id).generate_all()
    print("Done.")


if __name__ == "__main__":
    main()
