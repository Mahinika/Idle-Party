"""Delete generated named gear variants that are no longer in the catalog.

Keeps: *_t0_*, *_t2_*, EquipmentModelCatalog.authoredSharedIds, and
*_icon.png for those. Removes ImageDraw mass-variant PNGs.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(r"d:\Projects\Personal\idle party\Idle-Party\assets\custom\char")
# Keep in sync with lib/visual/equipment_model_catalog.dart authoredSharedIds.
KEEP_NAMED = {
    "sword_thunderfury",
    "sword_warglaive",
    "sword_runebound",
    "staff_frostfire",
    "staff_nethercore",
    "bow_eagle",
    "bow_windpierce",
    "axe_goreblade",
    "axe_bloodhowl",
    "mace_lightbringer",
    "mace_dawnbreak",
    "dagger_shadowfang",
    "dagger_nightbite",
    "shield_aegis",
    "shield_ironwall",
    "frill_prism",
    "frill_soulcodex",
}
TIER_RE = re.compile(r"^(.+)_t[02]_(idle|walk|attack|icon)\.png$")
NAMED_RE = re.compile(r"^(.+)_(idle|walk|attack|icon)\.png$")


def set_id_from_name(name: str) -> str | None:
    m = NAMED_RE.match(name)
    if not m:
        return None
    stem = m.group(1)
    # strip trailing nothing — stem is visualSetId
    return stem


def should_keep(name: str) -> bool:
    if TIER_RE.match(name):
        return True
    sid = set_id_from_name(name)
    if sid is None:
        return True
    if sid in KEEP_NAMED:
        return True
    # body / non-gear leftovers
    if not any(
        sid.startswith(p)
        for p in (
            "sword_",
            "staff_",
            "dagger_",
            "mace_",
            "axe_",
            "bow_",
            "shield_",
            "frill_",
            "helm_",
            "chest_",
            "legs_",
            "cloak_",
            "hands_",
        )
    ):
        return True
    # named generated variant → delete
    return False


def clean_folder(folder: Path) -> int:
    if not folder.is_dir():
        return 0
    n = 0
    for p in list(folder.glob("*.png")):
        if should_keep(p.name):
            continue
        p.unlink()
        n += 1
    return n


def main() -> None:
    n = clean_folder(ROOT / "gear")
    n += clean_folder(ROOT / "gear" / "_authored")
    for family in ("warrior", "healer", "mage", "rogue"):
        n += clean_folder(ROOT / family / "gear")
        n += clean_folder(ROOT / family / "gear" / "_authored")
    print(f"deleted {n} generated variant PNGs")


if __name__ == "__main__":
    main()
