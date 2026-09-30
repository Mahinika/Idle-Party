"""One-shot: split ClassKits.all into lib/models/kits/<class>.dart."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "lib" / "models" / "class_ability.dart"
OUT = ROOT / "lib" / "models" / "kits"

# Spec section start line (1-based) -> class file stem.
# Grouped by WotLK class family.
CLASS_SECTIONS: list[tuple[int, str, str]] = [
    (658, "warrior", "Warrior kits (Protection / Arms / Fury)"),
    (903, "priest", "Priest kits (Discipline / Holy / Shadow)"),
    (1061, "mage", "Mage kits (Fire / Arcane / Frost)"),
    (1258, "rogue", "Rogue kits (Combat / Assassination / Subtlety)"),
    (1430, "warrior", "Warrior kits (Protection / Arms / Fury)"),  # arms continues warrior
    (1573, "warrior", "Warrior kits (Protection / Arms / Fury)"),
    (1727, "paladin", "Paladin kits (Holy / Protection / Retribution)"),
    (1875, "paladin", "Paladin kits (Holy / Protection / Retribution)"),
    (2030, "paladin", "Paladin kits (Holy / Protection / Retribution)"),
    (2167, "hunter", "Hunter kits (Beast Mastery / Marksmanship / Survival)"),
    (2297, "hunter", "Hunter kits (Beast Mastery / Marksmanship / Survival)"),
    (2462, "hunter", "Hunter kits (Beast Mastery / Marksmanship / Survival)"),
    (2634, "rogue", "Rogue kits (Combat / Assassination / Subtlety)"),  # assassination
    (2794, "rogue", "Rogue kits (Combat / Assassination / Subtlety)"),
    (2978, "priest", "Priest kits (Discipline / Holy / Shadow)"),  # holy
    (3128, "priest", "Priest kits (Discipline / Holy / Shadow)"),
    (3285, "death_knight", "Death Knight kits (Blood / Frost / Unholy)"),
    (3476, "death_knight", "Death Knight kits (Blood / Frost / Unholy)"),
    (3618, "death_knight", "Death Knight kits (Blood / Frost / Unholy)"),
    (3791, "shaman", "Shaman kits (Elemental / Enhancement / Restoration)"),
    (3965, "shaman", "Shaman kits (Elemental / Enhancement / Restoration)"),
    (4127, "shaman", "Shaman kits (Elemental / Enhancement / Restoration)"),
    (4264, "mage", "Mage kits (Fire / Arcane / Frost)"),  # arcane
    (4409, "mage", "Mage kits (Fire / Arcane / Frost)"),
    (4577, "warlock", "Warlock kits (Affliction / Demonology / Destruction)"),
    (4744, "warlock", "Warlock kits (Affliction / Demonology / Destruction)"),
    (4900, "warlock", "Warlock kits (Affliction / Demonology / Destruction)"),
    (5053, "druid", "Druid kits (Balance / Feral / Guardian / Restoration)"),
    (5223, "druid", "Druid kits (Balance / Feral / Guardian / Restoration)"),
    (5394, "druid", "Druid kits (Balance / Feral / Guardian / Restoration)"),
    (5573, "druid", "Druid kits (Balance / Feral / Guardian / Restoration)"),
]

# Preferred file order for ClassKits.all spread.
CLASS_ORDER = [
    "warrior",
    "priest",
    "mage",
    "rogue",
    "paladin",
    "hunter",
    "death_knight",
    "shaman",
    "warlock",
    "druid",
]


def main() -> None:
    lines = SRC.read_text(encoding="utf-8").splitlines(keepends=True)
    # 0-based indices for list body (first ability comment .. last before ];)
    list_start = None
    list_end = None
    for i, line in enumerate(lines):
        if "static const List<ClassAbilityDef> all" in line:
            list_start = i + 1  # line after `[`
            # find `[` on same or next line
            if "[" not in line:
                list_start = i + 1
            else:
                list_start = i + 1
        if list_start is not None and list_end is None:
            if line.strip() == "];" and i > list_start + 10:
                list_end = i  # exclusive of content, this is `];`
                break
    assert list_start is not None and list_end is not None

    # Build section ranges from CLASS_SECTIONS markers (1-based -> 0-based)
    markers = sorted({s[0] for s in CLASS_SECTIONS})
    # Map each marker line to class stem
    marker_to_class = {s[0]: s[1] for s in CLASS_SECTIONS}
    titles = {s[1]: s[2] for s in CLASS_SECTIONS}

    # Collect body lines per class, preserving catalog order within each chunk
    chunks: dict[str, list[str]] = {c: [] for c in CLASS_ORDER}
    # Walk the list body in order; assign by nearest preceding marker
    body = lines[list_start:list_end]
    # Absolute line numbers for markers
    current_class = None
    abs_line = list_start + 1  # 1-based for first body line
    # Actually list_start points to first line AFTER `all = [`
    # Marker lines are absolute 1-based in file.
    for i, line in enumerate(lines[list_start:list_end]):
        abs_1 = list_start + i + 1
        if abs_1 in marker_to_class:
            current_class = marker_to_class[abs_1]
        if current_class is None:
            raise SystemExit(f"No class for line {abs_1}: {line[:60]!r}")
        chunks[current_class].append(line)

    OUT.mkdir(parents=True, exist_ok=True)

    for stem in CLASS_ORDER:
        body_lines = chunks[stem]
        # Trim trailing blank lines inside chunk
        while body_lines and body_lines[-1].strip() == "":
            body_lines.pop()
        # Ensure trailing comma on last ClassAbilityDef if missing — keep as-is
        title = titles[stem]
        content = (
            f"// {title}\n"
            f"part of '../class_ability.dart';\n"
            f"\n"
            f"const List<ClassAbilityDef> _{stem}Kit = <ClassAbilityDef>[\n"
            + "".join(body_lines)
            + "];\n"
        )
        (OUT / f"{stem}.dart").write_text(content, encoding="utf-8")
        print(f"wrote {stem}.dart ({len(body_lines)} lines)")

    # Rebuild class_ability.dart: keep through ClassKits opening, replace all list
    header = lines[: list_start - 1]  # includes `static const List... = [`
    # Find the line with `all = [` — header should end with that line
    # list_start was index of first line after `[` line... need the `[` line itself.
    # Find exact all-declaration line
    all_decl = None
    for i, line in enumerate(lines):
        if "static const List<ClassAbilityDef> all" in line:
            all_decl = i
            break
    assert all_decl is not None

    footer = lines[list_end + 1 :]  # after `];`

    part_directives = "\n".join(
        f"part 'kits/{stem}.dart';" for stem in CLASS_ORDER
    )

    # Insert part directives just before `class ClassKits`
    classkits_idx = None
    for i, line in enumerate(lines):
        if line.startswith("class ClassKits"):
            classkits_idx = i
            break
    assert classkits_idx is not None

    # Rebuild: [0..classkits) + parts + ClassKits with spread all
    pre = lines[:classkits_idx]
    # Drop any old part directives if re-run
    pre = [l for l in pre if not (l.startswith("part 'kits/") or l.startswith('part "kits/'))]

    spread = ",\n".join(f"    ..._{stem}Kit" for stem in CLASS_ORDER)

    classkits_block = (
        "/// Class kits adapted for Idle Party auto-combat (Wrath of the Lich King).\n"
        "class ClassKits {\n"
        "  ClassKits._();\n"
        "\n"
        "  static const List<ClassAbilityDef> all = <ClassAbilityDef>[\n"
        f"{spread},\n"
        "  ];\n"
        "\n"
    )

    # footer currently starts after `];` of all — which is helper methods
    # The old footer begins with blank line then `static ClassAbilityDef? defFor`
    new_text = (
        "".join(pre)
        + part_directives
        + "\n\n"
        + classkits_block
        + "".join(footer)
    )
    SRC.write_text(new_text, encoding="utf-8")
    print(f"rewrote {SRC.relative_to(ROOT)} ({len(new_text.splitlines())} lines)")


if __name__ == "__main__":
    main()
