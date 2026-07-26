# AGENTS.md

Idle Party is a **working Flutter idle RPG** with original Dart gameplay code and **Kenney** (CC0) art only.

## Legal / IP policy (mandatory)

- **Do not** add, keep, or commit APKs, IPA/AAB, SWF, DEX, or dumps from other commercial games.
- **Do not** copy sprites, audio, code, or text from other games into this repo.
- Shipped art must come from `assets/kenney/` (or other clearly licensed CC0/owned assets).
- Gameplay may follow common idle-RPG *ideas*; implement them as original code — never paste or translate decompiled sources.
- If a third-party binary appears locally, delete it and ensure `.gitignore` covers it.

## Build & Test

```bash
flutter pub get
flutter analyze          # hold to zero issues
flutter test
flutter run -d web-server --web-hostname=localhost --web-port=8080
```

## Architecture

```
main.dart
 ├─ Hub (inDungeon=false) → HubScreen + optional Is2Shell overlays
 └─ Dungeon (inDungeon=true) → Is2Shell
      ├─ SpatialDungeonView (camera follow, God Hand, farm/push)
      └─ Inventory dock (equip / bag / combinator / GH / pets / flask)

GameDirector → SpatialCombat.step @ ~30Hz (live dungeon)
             → GameLogic.simulateSpatialOffline (offline while inDungeon)
GameLogic + GameState   (rules / persistence)
DungeonCatalog          (named dungeons, bossFloor = 5 + AL)
RoomLayouts (tile_map)  (multi-chamber maps + gates)
```

**SpatialCombat is the combat authority** for live play and in-dungeon offline catch-up.

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
- Asset paths only through `KenneyAssets`.
- Pixel sprites: `filterQuality: FilterQuality.none`.

## Meta (survives Ascend)

- Essence, relics, sanctuary tracks, pets, soulbound, God Hand level, `highestDungeonCleared`, `lifetimeGoldEarned`
- Ascend resets run gear/levels/stash; keeps meta above
- Dungeon unlock uses **lifetime gold** (and prior dungeon clears), not wallet gold

## God Hand

Tap steers the party briefly and deals AOE; has cooldown. Upgrade with essence.
