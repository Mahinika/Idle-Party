"""Patch kit passives with explicit mul fields; update ClassAbilityDef + _applyPassive."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# AbilityId -> kwargs (only non-default). Defaults: out/in/heal/haste=1.0, root=0, innerFire=false
PASSIVES: dict[str, dict] = {
    "righteousFury": {"passiveOutMul": 0.97, "passiveInMul": 0.82},
    "bloodPresence": {
        "passiveOutMul": 0.98,
        "passiveInMul": 0.85,
        "passiveHealMul": 1.18,
    },
    "bearForm": {"passiveOutMul": 0.95, "passiveInMul": 0.88},
    "holyLightAura": {"passiveHealMul": 1.32},
    "spiritOfRedemption": {"passiveHealMul": 1.32},
    "ancestralAwakening": {"passiveHealMul": 1.32},
    "treeOfLife": {"passiveHealMul": 1.34},
    "armsStance": {"passiveOutMul": 2.02, "passiveInMul": 1.04},
    "berserkerStance": {
        "passiveOutMul": 1.70,
        "passiveHasteMul": 1.12,
        "passiveInMul": 1.06,
    },
    "sealOfCommand": {"passiveOutMul": 2.05},
    "improvedPoisons": {"passiveOutMul": 1.28},
    "masterOfSubtlety": {"passiveOutMul": 1.46, "passiveHasteMul": 1.08},
    "frostPresence": {"passiveOutMul": 2.10, "passiveInMul": 0.97},
    "unholyPresence": {"passiveOutMul": 1.16, "passiveHasteMul": 1.10},
    "enhancementWeapons": {"passiveOutMul": 1.26},
    "catForm": {"passiveOutMul": 1.28, "passiveHasteMul": 1.10},
    "aspectOfHawk": {"passiveOutMul": 1.18},
    "trueshotAura": {"passiveOutMul": 1.22, "passiveHasteMul": 1.06},
    "trapMastery": {"passiveOutMul": 1.26, "passiveRootBonus": 1.0},
    "shadowform": {"passiveOutMul": 1.16, "passiveInMul": 1.04},
    "elementalFocus": {"passiveOutMul": 1.14, "passiveHasteMul": 1.10},
    "arcanePowerPassive": {"passiveOutMul": 1.12},
    "frostArmor": {
        "passiveInMul": 0.92,
        "passiveOutMul": 1.12,
        "passiveRootBonus": 0.5,
    },
    "soulSiphon": {"passiveOutMul": 1.14, "passiveHealMul": 1.08},
    "demonicKnowledge": {"passiveOutMul": 0.96, "passiveHasteMul": 1.06},
    "cataclysm": {"passiveOutMul": 1.06},
    "moonkinForm": {"passiveOutMul": 1.16, "passiveInMul": 0.92},
    "defensiveStance": {"passiveOutMul": 0.9, "passiveInMul": 0.92},
    "revenge": {},  # no always-on mul
    "innerFire": {
        "innerFire": True,
        "passiveHealMul": 1.36,
        "passiveInMul": 0.94,
    },
    "sinisterStrike": {"passiveOutMul": 1.62},
    "arcaneIntellect": {"passiveOutMul": 1.24},
}


def fmt_kw(kwargs: dict) -> str:
    parts = []
    for k, v in kwargs.items():
        if isinstance(v, bool):
            parts.append(f"{k}: {str(v).lower()}")
        elif isinstance(v, float):
            # keep simple decimals
            s = f"{v:g}" if v == int(v) and k != "passiveRootBonus" else repr(v)
            if k == "passiveRootBonus":
                s = repr(v)
            parts.append(f"{k}: {s}")
        else:
            parts.append(f"{k}: {v}")
    return parts


def patch_class_ability_def() -> None:
    path = ROOT / "lib" / "models" / "class_ability.dart"
    text = path.read_text(encoding="utf-8")

    old_ctor = """    this.selfBuffKind,
    this.selfBuffDuration = 0,
    this.aoeShape,
    this.usesSpellPower,
    this.castDelaySeconds = 0,
  });"""

    new_ctor = """    this.selfBuffKind,
    this.selfBuffDuration = 0,
    this.aoeShape,
    this.usesSpellPower,
    this.castDelaySeconds = 0,
    this.passiveOutMul = 1.0,
    this.passiveInMul = 1.0,
    this.passiveHealMul = 1.0,
    this.passiveHasteMul = 1.0,
    this.passiveRootBonus = 0.0,
    this.innerFire = false,
  });"""

    if old_ctor not in text:
        raise SystemExit("constructor fields not found")
    text = text.replace(old_ctor, new_ctor, 1)

    old_fields = """  /// Signature cast delay before damage resolves (haste reduces in combat).
  final double castDelaySeconds;

  /// Infer spell vs physical scaling when [usesSpellPower] is null.
"""

    new_fields = """  /// Signature cast delay before damage resolves (haste reduces in combat).
  final double castDelaySeconds;

  /// Always-on kit multipliers for [AbilityEffectKind.passive] rows.
  final double passiveOutMul;
  final double passiveInMul;
  final double passiveHealMul;
  final double passiveHasteMul;
  final double passiveRootBonus;

  /// Disc Inner Fire — enables shield/heal amp in named casts.
  final bool innerFire;

  /// Infer spell vs physical scaling when [usesSpellPower] is null.
"""

    if old_fields not in text:
        raise SystemExit("castDelaySeconds field block not found")
    text = text.replace(old_fields, new_fields, 1)
    path.write_text(text, encoding="utf-8")
    print("patched ClassAbilityDef")


def patch_kit_files() -> None:
    kit_dir = ROOT / "lib" / "models" / "kits"
    for path in sorted(kit_dir.glob("*.dart")):
        text = path.read_text(encoding="utf-8")
        changed = 0

        def replacer(m: re.Match[str]) -> str:
            nonlocal changed
            aid = m.group(1)
            block = m.group(0)
            if aid not in PASSIVES:
                return block
            kwargs = PASSIVES[aid]
            if not kwargs:
                changed += 1
                return block  # revenge: leave empty
            # Already patched?
            if "passiveOutMul:" in block or "innerFire:" in block or "passiveHealMul:" in block:
                return block
            lines = fmt_kw(kwargs)
            insert = "".join(f"      {line},\n" for line in lines)
            # Insert before closing `),` of this ClassAbilityDef
            # block ends with `    ),` or `    )`
            new_block = re.sub(
                r"\n(\s*)\),\s*$",
                f"\n{insert}\\1),",
                block,
                count=1,
            )
            if new_block == block:
                raise SystemExit(f"failed to insert fields for {aid} in {path.name}")
            changed += 1
            return new_block

        # Match each ClassAbilityDef(...) balanced enough via non-greedy through effect passive
        pattern = re.compile(
            r"ClassAbilityDef\(\s*id:\s*AbilityId\.(\w+),.*?\n    \),",
            re.S,
        )
        new_text, n = pattern.subn(replacer, text)
        # Only rewrite if we actually changed something for passives in this file
        if changed:
            path.write_text(new_text, encoding="utf-8")
            print(f"{path.name}: patched {changed} passives")


def patch_apply_passive() -> None:
    path = ROOT / "lib" / "spatial" / "ability_effects.dart"
    text = path.read_text(encoding="utf-8")

    # Replace entire _applyPassive method
    start = text.find("  /// Applies always-on kit passive bonuses from [ability.id].")
    if start < 0:
        raise SystemExit("_applyPassive doc not found")
    end = text.find("\n  static bool _resolveEffect(", start)
    if end < 0:
        raise SystemExit("_resolveEffect not found after _applyPassive")

    new_method = """  /// Applies always-on kit passive bonuses from [ability] data fields.
  /// Magnitudes are mild so stacking with GameState auras stays sane.
  static void _applyPassive(
    SpatialActor hero,
    ClassAbilityDef ability,
    HeroSpecDef spec,
  ) {
    hero.kitOutMul *= ability.passiveOutMul;
    hero.kitInMul *= ability.passiveInMul;
    hero.kitHealMul *= ability.passiveHealMul;
    hero.kitHasteMul *= ability.passiveHasteMul;
    hero.kitRootBonus += ability.passiveRootBonus;
    if (ability.innerFire) {
      hero.innerFireActive = true;
    }
  }

"""
    text = text[:start] + new_method + text[end + 1 :]
    path.write_text(text, encoding="utf-8")
    print("rewrote _applyPassive")


def main() -> None:
    patch_class_ability_def()
    patch_kit_files()
    patch_apply_passive()


if __name__ == "__main__":
    main()
