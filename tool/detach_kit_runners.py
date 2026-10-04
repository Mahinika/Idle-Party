"""Publicize SpatialCombat cast surface and detach ability_effects / kit_migrated."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPATIAL = ROOT / "lib" / "spatial"

# SpatialCombat private members that kit runners need.
COMBAT_MEMBERS = [
    "_abilityCdLeft",
    "_addProjectile",
    "_announceCast",
    "_applyTankSoftThreat",
    "_combatHitSfxFor",
    "_countNearbyEnemies",
    "_dist",
    "_distPoint",
    "_floaterDamage",
    "_floaterHeal",
    "_gainRage",
    "_hasClearCorridor",
    "_healLowestAlly",
    "_hurtEnemy",
    "_nearestActiveEnemy",
    "_noteFeelHit",
    "_onEnemyKilled",
    "_pickSmartFocus",
    "_recordHeroDamage",
    "_recordHeroHeal",
    "_setAttackAnim",
    "_snapToWalkable",
    "_spawnBurst",
    "_spawnCone",
    "_spawnFloater",
    "_spawnGroundFx",
    "_spawnRing",
    "_spawnSlash",
    "_spawnSpark",
    "_spellBolt",
    "_spendRage",
    "_startAbilityCd",
    "_tauntLooseEnemies",
]

# Top-level helpers in spatial_combat.dart
TOP_LEVEL = [
    "_actorIsTank",
    "_actorIsHealer",
    "_actorIsMeleeDps",
]

# AbilityEffectRunner members used by KitNamedCasts
RUNNER_MEMBERS = [
    "_spendAndCd",
    "_castDamage",
    "_castAoe",
    "_announce",
    "_abilityOutScale",
    "_stateOut",
    "_goldOut",
]


def rename_member(text: str, old: str, new: str) -> str:
    # Word-boundary style: SpatialCombat._foo or ._foo( or static void _foo
    # Avoid replacing unrelated identifiers.
    return re.sub(rf"(?<![A-Za-z0-9]){re.escape(old)}(?![A-Za-z0-9])", new, text)


def publicize_spatial() -> None:
    mapping = {m: m[1:] for m in COMBAT_MEMBERS}  # _gainRage -> gainRage
    mapping.update({m: m[1:] for m in TOP_LEVEL})

    for path in SPATIAL.rglob("*.dart"):
        text = path.read_text(encoding="utf-8")
        orig = text
        for old, new in mapping.items():
            text = rename_member(text, old, new)
        if text != orig:
            path.write_text(text, encoding="utf-8")
            print(f"renamed in {path.relative_to(ROOT)}")


def publicize_runner_in_ability_effects() -> None:
    path = SPATIAL / "ability_effects.dart"
    text = path.read_text(encoding="utf-8")
    for old in RUNNER_MEMBERS:
        new = old[1:]
        text = rename_member(text, old, new)
    path.write_text(text, encoding="utf-8")
    print("publicized AbilityEffectRunner members")

    path = SPATIAL / "kit_migrated_casts.dart"
    text = path.read_text(encoding="utf-8")
    for old in RUNNER_MEMBERS:
        new = old[1:]
        text = rename_member(text, f"AbilityEffectRunner.{old}", f"AbilityEffectRunner.{new}")
        # also bare if any
        text = rename_member(text, old, new) if old in ("_stateOut", "_goldOut") else text
    # Fix kit file AbilityEffectRunner references only
    text = path.read_text(encoding="utf-8")
    for old in RUNNER_MEMBERS:
        new = old[1:]
        text = text.replace(f"AbilityEffectRunner.{old}", f"AbilityEffectRunner.{new}")
    path.write_text(text, encoding="utf-8")
    print("updated kit_migrated AbilityEffectRunner calls")


def detach_libraries() -> None:
    # ability_effects.dart
    ae = SPATIAL / "ability_effects.dart"
    ae_text = ae.read_text(encoding="utf-8")
    if ae_text.startswith("part of"):
        ae_text = ae_text.split("\n", 1)[1]
    header = """import 'dart:math' as math;

import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../models/class_ability.dart';
import '../models/hero_spec.dart';
import 'kit_migrated_casts.dart';
import 'spatial_combat.dart';

"""
    if not ae_text.lstrip().startswith("import "):
        ae_text = header + ae_text
    ae.write_text(ae_text, encoding="utf-8")

    # kit_migrated_casts.dart
    km = SPATIAL / "kit_migrated_casts.dart"
    km_text = km.read_text(encoding="utf-8")
    if km_text.startswith("part of"):
        km_text = km_text.split("\n", 1)[1]
    km_header = """import 'dart:math' as math;

import '../models/class_ability.dart';
import '../models/hero_spec.dart';
import 'ability_effects.dart';
import 'spatial_combat.dart';

"""
    if not km_text.lstrip().startswith("import "):
        km_text = km_header + km_text
    # Replace _actorIsTank / Healer with public names
    km_text = rename_member(km_text, "_actorIsTank", "actorIsTank")
    km_text = rename_member(km_text, "_actorIsHealer", "actorIsHealer")
    km.write_text(km_text, encoding="utf-8")

    # spatial_combat.dart — drop parts, add imports + export
    sc = SPATIAL / "spatial_combat.dart"
    sc_text = sc.read_text(encoding="utf-8")
    sc_text = sc_text.replace("part 'ability_effects.dart';\n", "")
    sc_text = sc_text.replace("part 'kit_migrated_casts.dart';\n", "")
    if "import 'ability_effects.dart';" not in sc_text:
        # After existing imports
        insert_at = sc_text.find("export '../models/spell_bolt_style.dart';")
        if insert_at < 0:
            raise SystemExit("export marker not found")
        sc_text = (
            sc_text[:insert_at]
            + "import 'ability_effects.dart';\n"
            + "export 'ability_effects.dart' show AbilityEffectRunner;\n"
            + "export 'kit_migrated_casts.dart' show KitNamedCasts;\n"
            + sc_text[insert_at:]
        )
    sc.write_text(sc_text, encoding="utf-8")
    print("detached part libraries")


def main() -> None:
    publicize_spatial()
    publicize_runner_in_ability_effects()
    detach_libraries()


if __name__ == "__main__":
    main()
