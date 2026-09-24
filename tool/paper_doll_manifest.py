"""Every doll PNG the gear build owns, in one list.

The build, the facit gate, and the Dart asset list must agree with this.
Anything in a family folder that is not listed here is an orphan.
"""
from __future__ import annotations

FAMILIES = ("warrior", "healer", "mage", "rogue")
ANIMS = ("idle", "walk", "attack")
SLOTS = ("helm", "chest", "legs", "cloak", "hands")

# t0 is the plain cut, t2 the grown late cut. short and broad are authored
# styles under gear/_authored/{slot}_{style}_idle.png.
TIERS = ("t0", "t2")
STYLES = ("short", "broad")
CUTS = TIERS + STYLES

NATIVE_MATERIAL = {
    "warrior": "plate",
    "rogue": "leather",
    "mage": "cloth",
    "healer": "cloth",
}

# Non-native materials per family (HeroSpecs armorTypes).
MATERIALS: dict[str, tuple[str, ...]] = {
    "warrior": ("leather",),  # guardian druid
    "rogue": ("mail",),  # hunter 40+, enhancement shaman
    "mage": ("mail", "leather"),  # elemental; druid
    "healer": ("plate", "mail", "leather"),  # holy; resto; druid
}

# Class marks sit on the family's own helm and chest, every cut.
CLASS_MARKS: dict[str, tuple[str, ...]] = {
    "warrior": ("paladin", "deathknight"),
    "mage": ("warlock",),
}
CLASS_SLOTS = ("helm", "chest")


def race_keys() -> tuple[str, ...]:
    from paint_race_bodies import RACES

    return tuple(look.key for look in RACES)


def style_master_names(family: str) -> list[str]:
    return [f"{slot}_{style}_idle.png" for slot in SLOTS for style in STYLES]


def gear_stems(family: str) -> list[str]:
    """Overlay stems painted on the doll (`{stem}_idle.png`)."""
    out: list[str] = []
    for slot in SLOTS:
        for cut in CUTS:
            out.append(f"{slot}_{cut}")
            for mat in MATERIALS[family]:
                out.append(f"{slot}_{mat}_{cut}")
    for mark in CLASS_MARKS.get(family, ()):
        for slot in CLASS_SLOTS:
            for cut in CUTS:
                out.append(f"{slot}_{mark}_{cut}")
    return out


def icon_stems(family: str) -> list[str]:
    """BAG icons: plain and late cut per material, plus boots."""
    out: list[str] = []
    for slot in SLOTS:
        for tier in TIERS:
            out.append(f"{slot}_{tier}")
            for mat in MATERIALS[family]:
                out.append(f"{slot}_{mat}_{tier}")
    for tier in TIERS:
        out.append(f"boots_{tier}")
        for mat in MATERIALS[family]:
            out.append(f"boots_{mat}_{tier}")
    return out


def gear_files(family: str) -> set[str]:
    files = {f"{stem}_idle.png" for stem in gear_stems(family)}
    files |= {f"{stem}_icon.png" for stem in icon_stems(family)}
    return files


def body_files(family: str) -> set[str]:
    files: set[str] = set()
    for anim in ANIMS:
        files.add(f"body_{anim}.png")
        files.add(f"body_tint_{anim}.png")
        for race in race_keys():
            for sex in ("m", "f"):
                files.add(f"{race}_{sex}_body_{anim}.png")
                files.add(f"{race}_{sex}_body_tint_{anim}.png")
    return files
