#!/usr/bin/env py
"""Owned pixel props for the Floor Blueprint layer (docs/FLOOR_BLUEPRINT.md).

Writes only NEW prop files (shared set + per-zone signature pieces + an open
chest) into assets/custom/dungeon/<zone>/props/. Existing PNGs are never
touched unless --force is given, and --force only rewrites the files named
below — handcrafted zone art stays as it is.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_dungeon_art as base  # noqa: E402

base.ZONE_WASH_AMBIENT.setdefault("fallback", (0xB0A080, 0x0A0908))

ZONES = base.ALL_ZONES + ("fallback",)

SHARED = (
    "altar",
    "statue",
    "bookshelf",
    "banner",
    "crystal_cluster",
    "cauldron",
    "sacks",
    "chains",
    "chest_open",
)


def _rgba(c, a: int = 255):
    return (*c, a)


class Props(base.Generator):
    def canvas(self):
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        return img, ImageDraw.Draw(img)

    @property
    def o(self):
        return self.prop_outline

    # —— shared set ——
    def altar(self):
        p = self.p
        img, d = self.canvas()
        d.rectangle([8, 19, 24, 28], fill=p.wall_m, outline=self.o)
        d.rectangle([5, 15, 27, 19], fill=p.wall_hi, outline=self.o)
        d.line([(9, 22), (23, 22)], fill=p.wall_lo)
        d.ellipse([12, 7, 20, 15], fill=p.accent, outline=self.o)
        d.ellipse([14, 9, 18, 13], fill=p.glow)
        for x in (7, 24):
            d.rectangle([x, 10, x + 1, 15], fill=p.bone)
            self.px(img, x, 9, p.lava_hi)
            self.px(img, x + 1, 8, p.accent_pale)
        return img

    def statue(self):
        p = self.p
        img, d = self.canvas()
        d.rectangle([9, 25, 23, 30], fill=p.wall_lo, outline=self.o)
        d.polygon([(12, 11), (20, 11), (22, 25), (10, 25)], fill=p.wall_m, outline=self.o)
        d.line([(16, 12), (16, 24)], fill=p.wall_lo)
        d.line([(13, 13), (12, 23)], fill=p.wall_hi)
        d.ellipse([12, 3, 20, 11], fill=p.wall_hi, outline=self.o)
        self.px(img, 14, 7, p.accent_hi)
        self.px(img, 18, 7, p.accent_hi)
        d.line([(20, 13), (24, 8)], fill=p.wall_hi, width=2)
        return img

    def bookshelf(self):
        p = self.p
        img, d = self.canvas()
        d.rectangle([6, 5, 26, 29], fill=p.wood, outline=self.o)
        books = (p.accent, p.lava_m, p.wet_m, p.bone, p.accent_m, p.wood_hi)
        for row, y in enumerate((7, 14, 21)):
            x = 8
            i = row
            while x < 24:
                w = 2 + (i % 2)
                h = 5 - (i % 3 == 0)
                d.rectangle([x, y + (5 - h), x + w - 1, y + 5], fill=books[i % len(books)])
                x += w + 1
                i += 1
            d.line([(7, y + 6), (25, y + 6)], fill=p.wood_hi)
        return img

    def banner(self):
        p = self.p
        img, d = self.canvas()
        d.rectangle([7, 3, 25, 5], fill=p.wood_hi, outline=self.o)
        d.polygon([(10, 6), (22, 6), (22, 26), (16, 21), (10, 26)], fill=p.accent, outline=self.o)
        d.line([(11, 7), (11, 24)], fill=p.accent_hi)
        d.polygon([(16, 10), (19, 14), (16, 18), (13, 14)], fill=p.glow, outline=p.accent_m)
        return img

    def crystal_cluster(self):
        p = self.p
        img, d = self.canvas()
        d.ellipse([6, 24, 26, 30], fill=p.wall_lo)
        d.polygon([(15, 4), (19, 14), (17, 27), (12, 27), (11, 14)], fill=p.wet_m, outline=self.o)
        d.polygon([(8, 13), (12, 19), (11, 28), (6, 28), (6, 19)], fill=p.accent, outline=self.o)
        d.polygon([(23, 10), (26, 18), (25, 28), (20, 28), (20, 17)], fill=p.wet, outline=self.o)
        d.line([(15, 6), (14, 25)], fill=p.wet_hi)
        self.px(img, 15, 8, p.accent_pale)
        self.px(img, 24, 13, p.accent_pale)
        return img

    def cauldron(self):
        p = self.p
        img, d = self.canvas()
        for x in (9, 22):
            d.line([(x, 25), (x - 1, 30)], fill=p.wall_lo, width=2)
        d.ellipse([6, 12, 26, 29], fill=p.wall_lo, outline=self.o)
        d.ellipse([5, 10, 27, 16], fill=p.wall_m, outline=self.o)
        d.ellipse([8, 11, 24, 15], fill=p.accent)
        self.px(img, 12, 12, p.glow)
        self.px(img, 19, 13, p.accent_pale)
        self.px(img, 15, 7, p.accent_hi)
        self.px(img, 18, 5, p.accent_pale)
        return img

    def sacks(self):
        p = self.p
        img, d = self.canvas()
        burlap = base._blend(p.wood_hi, p.bone, 0.35)
        burlap_lo = base._dark(burlap, 0.72)
        d.ellipse([4, 14, 18, 29], fill=burlap, outline=self.o)
        d.ellipse([15, 11, 28, 28], fill=burlap_lo, outline=self.o)
        d.polygon([(8, 14), (14, 14), (11, 10)], fill=burlap, outline=self.o)
        d.polygon([(19, 11), (25, 11), (22, 7)], fill=burlap_lo, outline=self.o)
        d.line([(8, 15), (14, 15)], fill=p.wood_m)
        d.line([(19, 12), (25, 12)], fill=p.wood_m)
        self.px(img, 9, 20, base._lite(burlap, 1.2))
        return img

    def chains(self):
        p = self.p
        img, d = self.canvas()
        d.rectangle([7, 2, 25, 4], fill=p.wall_m, outline=self.o)
        for x in (11, 21):
            for i, y in enumerate(range(5, 22, 4)):
                c = p.wall_hi if i % 2 == 0 else p.accent_m
                d.ellipse([x - 2, y, x + 2, y + 4], outline=c)
            d.ellipse([x - 3, 22, x + 3, 28], outline=p.wall_hi, width=2)
        return img

    def chest_open(self):
        p = self.p
        img, d = self.canvas()
        d.rectangle([5, 3, 27, 10], fill=p.wood_hi, outline=self.o)
        d.rectangle([14, 4, 18, 9], fill=p.accent, outline=self.o)
        d.rectangle([5, 15, 27, 27], fill=p.wood, outline=self.o)
        d.rectangle([6, 11, 26, 16], fill=p.outline)
        for x, y in ((9, 13), (13, 12), (18, 13), (22, 12)):
            self.px(img, x, y, p.accent_hi)
        d.rectangle([14, 17, 18, 26], fill=p.accent, outline=self.o)
        return img

    # —— signature primitives ——
    def _pedestal(self, d, top=22):
        p = self.p
        d.rectangle([10, top, 22, 29], fill=p.wall_m, outline=self.o)
        d.rectangle([8, top - 2, 24, top], fill=p.wall_hi, outline=self.o)

    def _brazier(self, flame, core):
        p = self.p
        img, d = self.canvas()
        d.rectangle([14, 16, 18, 28], fill=p.wall_m, outline=self.o)
        d.rectangle([10, 27, 22, 30], fill=p.wall_lo, outline=self.o)
        d.polygon([(6, 12), (26, 12), (22, 18), (10, 18)], fill=p.wall_hi, outline=self.o)
        d.polygon([(9, 12), (13, 3), (16, 8), (19, 1), (23, 12)], fill=flame, outline=self.o)
        d.polygon([(13, 12), (16, 6), (19, 12)], fill=core)
        return img

    def _urn(self, body, trim, glow=None):
        img, d = self.canvas()
        d.polygon([(12, 6), (20, 6), (19, 9), (24, 16), (22, 27), (10, 27), (8, 16), (13, 9)], fill=body, outline=self.o)
        d.line([(9, 17), (23, 17)], fill=trim, width=2)
        d.rectangle([11, 4, 21, 6], fill=trim, outline=self.o)
        d.rectangle([11, 27, 21, 29], fill=base._dark(body, 0.6), outline=self.o)
        if glow:
            self.px(img, 15, 5, glow)
            self.px(img, 17, 4, glow)
        return img

    def _spire(self, body, hi, pale):
        img, d = self.canvas()
        d.ellipse([7, 25, 25, 30], fill=self.p.wall_lo)
        d.polygon([(16, 1), (21, 12), (20, 28), (12, 28), (11, 12)], fill=body, outline=self.o)
        d.line([(16, 3), (15, 26)], fill=hi)
        d.polygon([(9, 16), (12, 21), (11, 28), (7, 28)], fill=hi, outline=self.o)
        d.polygon([(23, 18), (25, 28), (21, 28), (21, 21)], fill=body, outline=self.o)
        self.px(img, 16, 5, pale)
        return img

    def _figure_in_block(self, block, figure):
        img, d = self.canvas()
        d.rectangle([7, 4, 25, 29], fill=_rgba(block, 200), outline=self.o)
        d.ellipse([13, 7, 19, 13], fill=figure)
        d.polygon([(12, 13), (20, 13), (21, 26), (11, 26)], fill=figure)
        d.line([(9, 6), (9, 26)], fill=base._lite(block, 1.35))
        d.line([(22, 8), (18, 14)], fill=base._lite(block, 1.35))
        return img

    def _mushroom(self, cap, spots, stem):
        img, d = self.canvas()
        d.rectangle([13, 15, 19, 29], fill=stem, outline=self.o)
        d.pieslice([3, 3, 29, 27], 180, 360, fill=cap, outline=self.o)
        for x, y in ((9, 10), (16, 7), (22, 11), (13, 13)):
            d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=spots)
        d.ellipse([20, 22, 27, 29], fill=cap, outline=self.o)
        d.rectangle([22, 26, 25, 30], fill=stem)
        return img

    # —— per-zone signature pieces ——
    def signature(self, which: str):
        p = self.p
        z = self.zone_id
        img, d = self.canvas()
        if z == "sandy" and which == "a":
            # Sandstone idol head.
            d.rectangle([7, 18, 25, 29], fill=p.accent_m, outline=self.o)
            d.polygon([(9, 18), (16, 3), (23, 18)], fill=p.accent, outline=self.o)
            d.rectangle([12, 9, 20, 18], fill=p.accent_pale, outline=self.o)
            self.px(img, 14, 12, p.outline)
            self.px(img, 18, 12, p.outline)
            d.line([(14, 15), (18, 15)], fill=p.accent_m)
            return img
        if z == "sandy":
            return self._urn(p.accent, p.accent_m)
        if z == "goblin" and which == "a":
            # Totem pole with a skull and feathers.
            d.rectangle([14, 6, 18, 29], fill=p.wood, outline=self.o)
            d.ellipse([11, 3, 21, 12], fill=p.bone, outline=self.o)
            self.px(img, 14, 7, p.outline)
            self.px(img, 18, 7, p.outline)
            for x, c in ((8, p.accent), (23, p.lava_m)):
                d.polygon([(x, 12), (x + 2, 12), (x + 1, 20)], fill=c, outline=self.o)
            d.line([(10, 14), (22, 14)], fill=p.wood_hi, width=2)
            return img
        if z == "goblin":
            # Stolen loot heap.
            d.ellipse([4, 16, 28, 30], fill=p.wood_m, outline=self.o)
            for x, y in ((9, 18), (14, 16), (19, 18), (12, 22), (18, 23), (23, 21)):
                d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=p.accent_hi, outline=p.accent_m)
            d.rectangle([20, 8, 26, 17], fill=p.wall_hi, outline=self.o)
            return img
        if z == "king" and which == "a":
            # Throne.
            gold = p.accent_hi
            d.rectangle([9, 3, 23, 20], fill=p.wood, outline=self.o)
            d.rectangle([11, 5, 21, 18], fill=p.lava_m)
            d.rectangle([6, 17, 26, 23], fill=p.wood_hi, outline=self.o)
            d.rectangle([7, 23, 10, 29], fill=p.wood_m, outline=self.o)
            d.rectangle([22, 23, 25, 29], fill=p.wood_m, outline=self.o)
            for x in (9, 16, 23):
                self.px(img, x, 2, gold)
            d.line([(9, 3), (23, 3)], fill=gold)
            return img
        if z == "king":
            # Armor stand.
            d.rectangle([15, 20, 17, 29], fill=p.wood_m)
            d.rectangle([10, 28, 22, 30], fill=p.wood, outline=self.o)
            d.polygon([(10, 11), (22, 11), (20, 22), (12, 22)], fill=p.wall_hi, outline=self.o)
            d.ellipse([12, 3, 20, 11], fill=p.wall_hi, outline=self.o)
            d.line([(13, 7), (19, 7)], fill=p.outline)
            d.line([(16, 12), (16, 21)], fill=p.accent)
            return img
        if z == "underworld" and which == "a":
            return self._brazier(p.accent, p.accent_pale)
        if z == "underworld":
            # Eye obelisk.
            d.polygon([(12, 29), (13, 6), (16, 2), (19, 6), (20, 29)], fill=p.wall_m, outline=self.o)
            d.ellipse([12, 11, 20, 17], fill=p.accent_pale, outline=self.o)
            d.ellipse([15, 12, 17, 16], fill=p.accent)
            d.line([(14, 20), (18, 20)], fill=p.accent_m)
            d.line([(14, 24), (18, 24)], fill=p.accent_m)
            return img
        if z == "dead" and which == "a":
            # Bone pile.
            d.polygon([(4, 29), (10, 16), (16, 12), (22, 16), (28, 29)], fill=base._dark(p.bone, 0.7), outline=self.o)
            for x, y in ((11, 20), (18, 17), (15, 24), (22, 24), (8, 26)):
                d.ellipse([x - 3, y - 3, x + 3, y + 2], fill=p.bone, outline=self.o)
                self.px(img, x - 1, y - 1, p.outline)
                self.px(img, x + 1, y - 1, p.outline)
            return img
        if z == "dead":
            # Upright coffin.
            d.polygon([(12, 2), (20, 2), (24, 10), (21, 29), (11, 29), (8, 10)], fill=p.wood, outline=self.o)
            d.line([(16, 8), (16, 20)], fill=p.accent)
            d.line([(12, 12), (20, 12)], fill=p.accent)
            return img
        if z == "hell" and which == "a":
            # Horned skull altar.
            d.rectangle([9, 20, 23, 29], fill=p.wall_m, outline=self.o)
            d.ellipse([10, 8, 22, 21], fill=p.bone, outline=self.o)
            d.polygon([(10, 11), (3, 2), (8, 12)], fill=p.wall_hi, outline=self.o)
            d.polygon([(22, 11), (29, 2), (24, 12)], fill=p.wall_hi, outline=self.o)
            d.ellipse([12, 12, 15, 15], fill=p.lava_hi)
            d.ellipse([17, 12, 20, 15], fill=p.lava_hi)
            return img
        if z == "hell":
            return self._brazier(p.lava, p.lava_hi)
        if z == "crystal" and which == "a":
            return self._spire(p.wet_m, p.wet_hi, p.accent_pale)
        if z == "crystal":
            # Floating prism over a pedestal.
            self._pedestal(d)
            d.polygon([(16, 2), (22, 10), (16, 17), (10, 10)], fill=p.wet_hi, outline=self.o)
            d.line([(16, 3), (16, 16)], fill=p.accent_pale)
            return img
        if z == "tide" and which == "a":
            # Branching coral.
            for pts, c in (
                ([(16, 29), (15, 16), (11, 8)], p.lava_m),
                ([(15, 18), (21, 10), (23, 4)], p.lava_m),
                ([(15, 22), (8, 16), (6, 10)], p.accent),
                ([(18, 14), (19, 5)], p.accent_hi),
            ):
                d.line(pts, fill=c, width=3)
            d.ellipse([8, 26, 24, 30], fill=p.wall_lo)
            return img
        if z == "tide":
            # Sunken anchor.
            d.line([(16, 5), (16, 26)], fill=p.wall_hi, width=3)
            d.ellipse([13, 2, 19, 8], outline=p.wall_hi, width=2)
            d.line([(10, 10), (22, 10)], fill=p.wall_hi, width=2)
            d.arc([6, 14, 26, 30], 20, 160, fill=p.wall_hi, width=3)
            d.line([(8, 22), (15, 28)], fill=p.accent, width=1)
            return img
        if z == "ember" and which == "a":
            return self._urn(p.wall_m, p.lava_m, glow=p.lava_hi)
        if z == "ember":
            # Molten crucible.
            d.line([(8, 30), (11, 18)], fill=p.wall_lo, width=2)
            d.line([(24, 30), (21, 18)], fill=p.wall_lo, width=2)
            d.polygon([(8, 10), (24, 10), (21, 22), (11, 22)], fill=p.wall_m, outline=self.o)
            d.ellipse([9, 8, 23, 13], fill=p.lava_hi, outline=self.o)
            self.px(img, 14, 6, p.lava_m)
            return img
        if z == "grove" and which == "a":
            return self._mushroom(p.accent, p.accent_pale, p.bone)
        if z == "grove":
            # Stump with a sprout.
            d.polygon([(7, 29), (9, 16), (23, 16), (25, 29)], fill=p.wood, outline=self.o)
            d.ellipse([8, 13, 24, 19], fill=p.wood_hi, outline=self.o)
            d.ellipse([12, 14, 20, 18], outline=p.wood_m)
            d.line([(16, 14), (16, 6)], fill=p.accent, width=2)
            d.ellipse([16, 3, 22, 8], fill=p.accent_hi, outline=self.o)
            return img
        if z == "storm" and which == "a":
            # Lightning rod.
            d.rectangle([15, 8, 17, 29], fill=p.wall_hi, outline=self.o)
            d.rectangle([11, 27, 21, 30], fill=p.wall_lo, outline=self.o)
            d.polygon([(18, 1), (13, 9), (17, 9), (13, 16), (21, 6), (17, 6)], fill=p.accent_pale, outline=self.o)
            return img
        if z == "storm":
            # Tesla orb.
            self._pedestal(d, top=20)
            d.ellipse([9, 3, 23, 17], fill=p.accent, outline=self.o)
            d.line([(12, 7), (16, 10), (14, 13), (19, 15)], fill=p.accent_pale)
            self.px(img, 13, 6, p.glow)
            return img
        if z == "rime" and which == "a":
            return self._spire(p.wet, p.wet_hi, p.accent_pale)
        if z == "rime":
            return self._figure_in_block(p.wet_m, p.wall_m)
        if z == "fen" and which == "a":
            return self._mushroom(p.accent_m, p.lava_m, p.wood_hi)
        if z == "fen":
            # Rotting log.
            d.ellipse([3, 17, 13, 29], fill=p.wood_hi, outline=self.o)
            d.rectangle([8, 17, 28, 29], fill=p.wood, outline=self.o)
            d.ellipse([5, 20, 11, 26], outline=p.wood_m)
            for x in (14, 19, 24):
                d.ellipse([x - 1, 14, x + 2, 18], fill=p.accent, outline=self.o)
            return img
        if z == "brass" and which == "a":
            # Big gear.
            d.ellipse([5, 5, 27, 27], fill=p.accent, outline=self.o)
            for x, y in ((16, 2), (16, 30), (2, 16), (30, 16), (6, 6), (26, 26), (6, 26), (26, 6)):
                d.rectangle([x - 2, y - 2, x + 2, y + 2], fill=p.accent_m, outline=self.o)
            d.ellipse([11, 11, 21, 21], fill=p.wall_lo, outline=self.o)
            d.ellipse([14, 14, 18, 18], fill=p.accent_hi)
            return img
        if z == "brass":
            # Steam boiler.
            d.rectangle([8, 9, 24, 28], fill=p.accent_m, outline=self.o)
            d.ellipse([8, 5, 24, 13], fill=p.accent, outline=self.o)
            d.rectangle([22, 2, 25, 9], fill=p.wall_hi, outline=self.o)
            d.ellipse([11, 15, 19, 23], fill=p.bone, outline=self.o)
            d.line([(15, 19), (17, 16)], fill=p.lava_m)
            for y in (12, 25):
                d.line([(8, y), (24, y)], fill=p.accent_hi)
            return img
        if z == "veil" and which == "a":
            # Moth lantern.
            d.line([(16, 1), (16, 6)], fill=p.wall_hi)
            d.rectangle([11, 6, 21, 24], fill=_rgba(p.accent_pale, 220), outline=self.o)
            d.rectangle([13, 9, 19, 21], fill=p.glow)
            d.rectangle([10, 24, 22, 27], fill=p.wall_m, outline=self.o)
            for x, y in ((6, 9), (25, 13), (8, 19), (24, 5)):
                d.polygon([(x - 2, y - 1), (x, y + 1), (x + 2, y - 1)], fill=p.bone)
            return img
        if z == "veil":
            # Hanging silk cocoon.
            d.line([(16, 0), (16, 6)], fill=p.accent_pale)
            d.ellipse([10, 5, 22, 28], fill=p.accent_pale, outline=self.o)
            for y in (10, 15, 20, 24):
                d.arc([10, y - 3, 22, y + 3], 10, 170, fill=p.accent_m)
            return img
        # Fallback zone: plain obelisk / urn.
        if which == "a":
            d.polygon([(12, 29), (13, 6), (16, 2), (19, 6), (20, 29)], fill=p.wall_m, outline=self.o)
            d.line([(16, 6), (16, 26)], fill=p.accent)
            return img
        return self._urn(p.accent_m, p.accent)

    def generate_new(self, force: bool) -> int:
        written = 0
        items = [(name, getattr(self, name)) for name in SHARED]
        items += [("signature_a", lambda: self.signature("a")), ("signature_b", lambda: self.signature("b"))]
        for name, fn in items:
            path = base.ROOT / self.zone_id / "props" / f"{name}.png"
            if path.exists() and not force:
                continue
            self.save(fn(), f"props/{name}.png")
            written += 1
        return written


def main() -> None:
    force = "--force" in sys.argv
    total = 0
    for zone in ZONES:
        n = Props(zone).generate_new(force)
        total += n
        print(f"  {zone}: {n} new prop PNGs")
    print(f"Done. {total} files.")


if __name__ == "__main__":
    main()
