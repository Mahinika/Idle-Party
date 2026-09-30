"""BAG icons must be the doll overlay, cropped the same way every time."""
from __future__ import annotations

from PIL import Image

from derive_armor_material_variants import write_boots_icon
from facit.checks_v1 import pixels_differ
from facit.findings import Finding
from make_gear_slot_icons import make_icon
from paper_doll_manifest import FAMILIES
from paper_doll_paths import CHAR, REPO, TOOL


def _icon_for(idle: Image.Image, name: str) -> Image.Image | None:
    token = name.split("_", 1)[0]
    if token == "hands":
        min_op = 24
    elif token == "shoulder":
        min_op = 12
    else:
        min_op = 40
    return make_icon(idle, min_opaque=min_op)


def _boot_icon(legs: Image.Image) -> Image.Image | None:
    dest = TOOL / "out" / "facit" / "_boot_probe.png"
    dest.parent.mkdir(parents=True, exist_ok=True)
    write_boots_icon(legs, dest)
    if not dest.exists():
        return None
    im = Image.open(dest).convert("RGBA")
    dest.unlink(missing_ok=True)
    return im


def check_icon_parity() -> list[Finding]:
    out: list[Finding] = []
    folders = [(CHAR / fam / "gear") for fam in FAMILIES]
    folders.append(CHAR / "gear")
    for folder in folders:
        for idle_path in sorted(folder.glob("*_idle.png")):
            icon_path = idle_path.with_name(idle_path.name.replace("_idle.png", "_icon.png"))
            if not icon_path.exists():
                continue
            expect = _icon_for(Image.open(idle_path).convert("RGBA"), idle_path.name)
            rel = icon_path.relative_to(REPO).as_posix()
            if expect is None:
                out.append(Finding("icon_parity", rel, "empty-crop"))
                continue
            if pixels_differ(expect, Image.open(icon_path).convert("RGBA")):
                out.append(Finding("icon_parity", rel, "drift"))
        for icon_path in sorted(folder.glob("boots_*_icon.png")):
            rel = icon_path.relative_to(REPO).as_posix()
            stem = icon_path.name[: -len("_icon.png")]
            legs_name = stem.replace("boots_", "legs_", 1) + "_idle.png"
            legs_path = folder / legs_name
            if not legs_path.exists():
                out.append(Finding("icon_parity", rel, "missing-legs"))
                continue
            expect = _boot_icon(Image.open(legs_path).convert("RGBA"))
            if expect is None or pixels_differ(expect, Image.open(icon_path).convert("RGBA")):
                out.append(Finding("icon_parity", rel, "boot-drift"))
            legs_icon = folder / legs_name.replace("_idle.png", "_icon.png")
            if legs_icon.exists() and icon_path.read_bytes() == legs_icon.read_bytes():
                out.append(Finding("icon_parity", rel, "same-as-legs"))
        for dye in sorted(folder.glob("*_dye_icon.png")):
            idle = dye.with_name(dye.name.replace("_dye_icon.png", "_idle.png"))
            icon = dye.with_name(dye.name.replace("_dye_icon.png", "_icon.png"))
            if not idle.exists() or not icon.exists():
                continue
            # Dye icon must use the same crop box as the slot icon.
            if Image.open(dye).size != Image.open(icon).size:
                out.append(
                    Finding(
                        "icon_parity",
                        dye.relative_to(REPO).as_posix(),
                        "dye-bbox",
                    )
                )
    return out
