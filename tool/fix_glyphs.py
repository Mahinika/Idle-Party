from pathlib import Path
import re

p = Path("lib/ui/is2_shell.dart")
raw = p.read_bytes()
try:
    t = raw.decode("utf-8")
except UnicodeDecodeError:
    t = raw.decode("latin-1")

# Normalize newlines to LF only
t = t.replace("\r\n", "\n").replace("\r", "\n")

reps = [
    ("${leveled.first.name} ? Lv", "${leveled.first.name} · Lv"),
    ("'$dungeonName ? F$floor'", "'$dungeonName · F$floor'"),
    (
        "'Tap item ? choose hero  ?  Hold ? combinator'",
        "'Tap item · choose hero  ·  Hold · combinator'",
    ),
    (
        "'? ${GameLogic.rarityNames[preview.rarity]} i",
        "'→ ${GameLogic.rarityNames[preview.rarity]} i",
    ),
    (
        "' ? +${state.petLootFindPercent}% loot find'",
        "' · +${state.petLootFindPercent}% loot find'",
    ),
    ("label: '? ${state.heroes[i].roleLabel}'", "label: '→ ${state.heroes[i].roleLabel}'"),
    (
        ": 'EQUIP ? ${state.heroes[selectedHeroIndex.clamp(0, state.heroes.length - 1)].roleLabel}'",
        ": 'EQUIP · ${state.heroes[selectedHeroIndex.clamp(0, state.heroes.length - 1)].roleLabel}'",
    ),
    ("'? BEST'", "'◀ BEST'"),
    ("'ASCEND ? AL", "'ASCEND · AL"),
    ("'$name  ?  OWNED'", "'$name  ·  OWNED'"),
    (
        "'Now +${state.sanctuaryGoldBonusPercent}% gold  ?  '",
        "'Now +${state.sanctuaryGoldBonusPercent}% gold  ·  '",
    ),
    ("'Next: $nextBonus  ?  $cost essence'", "'Next: $nextBonus  ·  $cost essence'"),
    (
        "'Gold ${state.gold}  ?  Essence ${state.essence}'",
        "'Gold ${state.gold}  ·  Essence ${state.essence}'",
    ),
    (
        "'No beasts yet. Hatch an egg with essence ? '",
        "'No beasts yet. Hatch an egg with essence — '",
    ),
    ("Text('?')", "Text('−')"),
    ("child: Text('?')", "child: Text('−')"),
]

count = 0
for a, b in reps:
    n = t.count(a)
    if n:
        t = t.replace(a, b)
        count += n
        print(f"{n}x fixed: {a[:50]!r}")

# Report leftovers that look like UI separators
for m in re.finditer(r"'[^'\n]*\?[^'\n]*'", t):
    s = m.group(0)
    if " ? " in s or s.startswith("'?") or "?'" in s[:3]:
        # skip ternaries
        if " == 1 ? " in s or "softcap == 1" in s:
            continue
        print("LEFTOVER", s[:90])

p.write_bytes(t.encode("utf-8"))
print("total", count, "utf8 ok", len(t.encode("utf-8")))
