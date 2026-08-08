# AGENTS.md

Idle Party is a **working Flutter idle RPG** with original Dart gameplay code, **Kenney** (CC0) world art, and **owned** custom identity sprites (`assets/custom/`).

## Legal / IP policy (mandatory)

- **Do not** add, keep, or commit APKs, IPA/AAB, SWF, DEX, or dumps from other commercial games.
- **Do not** copy sprites, audio, code, or text from other games into this repo.
- Shipped art must come from `assets/kenney/` (CC0) or `assets/custom/` (owned Idle Party art) — not third-party commercial dumps.
- Gameplay may follow common idle-RPG *ideas*; implement them as original code — never paste or translate decompiled sources.
- If a third-party binary appears locally, delete it and ensure `.gitignore` covers it.

## Build & Test

```bash
flutter pub get
flutter analyze          # hold to zero issues
flutter test
flutter run -d web-server --web-hostname=localhost --web-port=8080
```

### Agent tooling (balance / honesty / QA)

```bash
# Fast DPS share board while nerfing kits (writes tool/out/class_balance_share.json)
flutter test test/class_balance_share_fast_test.dart --reporter expanded

# CI gate: live light, fail on DPS HIGH
flutter test test/class_balance_gate_test.dart

# What’s New ↔ pubspec ↔ shipped zones
flutter test test/changelog_sync_test.dart
```

Skills: `.cursor/skills/` — domain (`spatial-combat-change`, `add-ability`, `new-dungeon`, `zone-art-identity`, `save-migrate`, `class-audit`, `assets-legal`, `flutter-verify`, `browser-playtest`, `hub-smoke`) and Cursor workflows (`suggesting-skills`, `building-skills-from-patterns`, `grinding-until-pass`, `babysitting-pr`, `parallel-ci-triage`, `verifying-in-browser`, `screenshotting-changelog`, `recording-browser-flow-as-test`, `systematic-debugging`, `reviewing-code`, `accessibility-auditing`).

## Architecture

```
main.dart
 ├─ Hub (inDungeon=false) → HubScreen + optional Is2Shell overlays
 └─ Dungeon (inDungeon=true) → Is2Shell
      ├─ SpatialDungeonView (camera follow, God Hand, farm/push)
      └─ Dungeon chrome (FARM/PUSH, God Hand ring, party HUD + flask,
         target panel, bottom nav: GEAR / BAG / MORE)

GameDirector → SpatialCombat.step @ ~60Hz (live dungeon)
             → GameLogic.simulateSpatialOffline → SpatialCombat.step (AFK; auto-flask + God Hand)
GameLogic + GameState   (rules / persistence)
DungeonCatalog          (named dungeons, bossFloor = 5 + AL)
RoomLayouts (tile_map)  (multi-chamber maps + gates)
```

**SpatialCombat is the combat authority** for live play and in-dungeon offline catch-up (offline uses full enemy stats + independent `afkAssist` + `reducedVfx` for boot speed, auto-flask at low HP, and God Hand off cooldown; same kits/abilities/chambers).

**Infinity Gauntlet** (AL10+): endless Crystal Spire climb from Hub; floor threat/rewards scale; wipe/leave returns to hub; best floor survives Ascend.

Hub AFK (`!inDungeon`) is sanctuary idle gold only — no combat.

## Floor / chamber model

- One **combat wave per floor**; boss on floor `5 + ascensionLevel`.
- Maps are **multi-chamber** with corridor **gates** that open after a chamber is cleared.
- Enemies start **dormant** in later chambers; wake when prior chambers clear.
- After all enemies die and loot is picked up (or times out), party walks to **stairs/exit** → `completeCurrentRoom`.

## Key files

| Area | Path |
|------|------|
| Orchestration | `lib/core/game_director.dart` |
| Rules | `lib/core/game_logic.dart` |
| State | `lib/core/game_state.dart` |
| Spatial sim | `lib/spatial/spatial_combat.dart` |
| Tile maps | `lib/spatial/tile_map.dart` |
| Hub | `lib/ui/hub_screen.dart` |
| Dungeon shell | `lib/ui/is2_shell.dart` |
| Stage view | `lib/ui/spatial_dungeon_view.dart` |
| Assets | `lib/ui/kenney_assets.dart` |

## Conventions

- State is immutable — mutate via `copyWith` in `GameLogic`.
- No Riverpod/Provider — `ChangeNotifier` + `AnimatedBuilder`.
- `GameDirector.preview()` for tests (no SharedPreferences / no spatial timer).
- Asset paths only through `KenneyAssets` / `CustomAssets` (no raw `assets/...` in UI).
- Pixel sprites: `filterQuality: FilterQuality.none`.

## Meta (survives Ascend)

- Essence, relics, sanctuary tracks (infinite levels + optional prestige), pets, soulbound, God Hand level, `highestDungeonCleared`, `lifetimeGoldEarned`, achievements/codex/settings, `metaDepth`
- Ascend resets wallet gold, run gear/stash/loadouts, floor progress, gold party upgrades (ATK/DEF/VIT/move/haste/crit); **keeps hero levels/XP** and meta above
- Dungeon unlock uses **lifetime gold** (and prior dungeon clears), not wallet gold

## God Hand

Tap steers the party briefly and deals AOE; has cooldown. Upgrade with essence.
