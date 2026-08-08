# AGENTS.md

Idle Party is a **working Flutter idle RPG** with original Dart gameplay code,
**Kenney** (CC0) world art, and **owned** custom identity sprites (`assets/custom/`).

**Ship version:** keep `pubspec.yaml` versionName and `MetaSystems.currentVersion`
in sync (currently **1.9.3**). What’s New lives in `lib/core/meta_systems.dart`.

## Human (vibe-coder)

The owner describes goals in plain language and does not pick tools/skills.
Agents **must** choose methods, skills, and verify steps themselves — see
`.cursor/rules/vibe-coder-autopilot.mdc` and `.cursor/rules/owner-preferences.mdc`.

Preferences (do not re-ask): Play Store goal soon, **large batches**, **cozy idle**,
**English in-game copy**, **fairness-first** balance, **propose** commit / push / PR / tag
(with a clear yes/no). Chat in plain Swedish; ask only product/risk questions.

**Distribution today:** GitHub Releases APK/AAB is the live path (`docs/PLAY_STORE.md`).
Play Console is the goal — prepare listing/privacy/IARC, but do not assume Play is
already the primary install channel.

## Legal / IP policy (mandatory)

- **Do not** add, keep, or commit APKs, IPA/AAB, SWF, DEX, or dumps from other commercial games.
- **Do not** copy sprites, audio, code, or text from other games into this repo.
- Shipped art must come from `assets/kenney/` (CC0) or `assets/custom/` (owned Idle Party art).
- Gameplay may follow common idle-RPG *ideas*; implement as original Dart — never paste
  or translate decompiled sources.
- If a third-party binary appears locally, delete it and ensure `.gitignore` covers it.

## Build & Test

```bash
flutter pub get
flutter analyze          # project target: zero issues on lib/test
flutter test
flutter run -d web-server --web-hostname=localhost --web-port=8080
```

CI uses `flutter analyze lib test --no-fatal-infos` then `flutter test` (includes balance gate).

### Agent tooling (balance / honesty / QA)

```bash
# Fast DPS share board (writes tool/out/class_balance_share.json, gitignored)
flutter test test/class_balance_share_fast_test.dart --reporter expanded

# CI gate: live light, fail on DPS HIGH (±20% share band)
flutter test test/class_balance_gate_test.dart

# What’s New ↔ pubspec ↔ shipped zones
flutter test test/changelog_sync_test.dart
```

Skills under `.cursor/skills/`: domain (`spatial-combat-change`, `add-ability`,
`new-dungeon`, `zone-art-identity`, `save-migrate`, `class-audit`, `assets-legal`,
`flutter-verify`, `browser-playtest`, `hub-smoke`) and Cursor workflows
(`suggesting-skills`, `building-skills-from-patterns`, `grinding-until-pass`,
`babysitting-pr`, `parallel-ci-triage`, `verifying-in-browser`,
`screenshotting-changelog`, `recording-browser-flow-as-test`,
`systematic-debugging`, `reviewing-code`, `accessibility-auditing`).

Cadence: `docs/CONTENT_CADENCE.md`. Roadmap: `docs/ROADMAP.md`.

## Architecture

```
main.dart
 ├─ loading → startMenu → optional newGamePicker → play
 ├─ Hub (inDungeon=false) → HubScreen + optional Is2Shell(hubMode) overlays
 └─ Dungeon (inDungeon=true) → Is2Shell
      ├─ SpatialDungeonView (camera follow, God Hand, farm/push)
      └─ Dungeon chrome (FARM/PUSH, God Hand ring, party HUD + flask,
         target panel, bottom nav: GEAR / BAG / MORE)

GameDirector → SpatialCombat.step @ ~60Hz (live dungeon)
             → GameLogic.simulateSpatialOffline → SpatialCombat.step
               (AFK: afkAssist + reducedVfx, auto-flask, God Hand)
GameLogic + GameState   (rules / persistence)
DungeonCatalog          (9 named zones, bossFloor = 5 + AL)
RoomLayouts (tile_map)  (multi-chamber maps + gates)
```

**SpatialCombat is the combat authority** for live play and in-dungeon offline
catch-up (full enemy stats; same kits/abilities/chambers).

**Infinity Gauntlet** (`GameLogic.gauntletMinAscension` = AL10+): endless Crystal
Spire climb from Hub; wipe/leave → hub; `metaDepth.gauntletBestFloor` survives Ascend.

Hub AFK (`!inDungeon`) is sanctuary idle gold only — no combat.

Web playtest: `WebClickBridge` + Semantics (`browser-playtest` skill).

## World path (9 zones)

| # | id | Name |
|---|-----|------|
| 0 | sandy | Sandy Caverns |
| 1 | goblin | Goblin's Hideout |
| 2 | king | King's Fort |
| 3 | underworld | Underworld |
| 4 | dead | City of Dead |
| 5 | hell | Hell's Gate |
| 6 | crystal | Crystal Spire |
| 7 | tide | Sunken Tidehold |
| 8 | ember | Ashen Vault |

Unlock: prior clear **or** enough **lifetime gold** (not wallet gold).

## Floor / chamber model

- One **combat wave per floor**; boss on floor `5 + ascensionLevel`.
- Maps are **multi-chamber** with corridor **gates** after a chamber clears.
- Enemies in later chambers start **dormant**; wake when prior chambers clear
  (and can wake on **proximity** so soft-locks are rare).
- After all enemies die and loot is picked up (or times out), party walks to
  **stairs/exit** → `completeCurrentRoom`.

## Key files

| Area | Path |
|------|------|
| Orchestration | `lib/core/game_director.dart` |
| Rules | `lib/core/game_logic.dart` |
| State | `lib/core/game_state.dart` |
| Changelog / meta helpers | `lib/core/meta_systems.dart` |
| Meta blob | `lib/models/meta_depth.dart` |
| Dungeon catalog | `lib/models/dungeon_def.dart` |
| Spatial sim | `lib/spatial/spatial_combat.dart` |
| Ability runtime | `lib/spatial/ability_effects.dart` |
| Tile maps | `lib/spatial/tile_map.dart` |
| Hub | `lib/ui/hub_screen.dart` |
| Dungeon / hub shell | `lib/ui/is2_shell.dart` |
| Stage view | `lib/ui/spatial_dungeon_view.dart` |
| Kenney helpers | `lib/ui/kenney_assets.dart` |
| Custom art helpers | `lib/ui/custom_assets.dart` |

## Conventions

- State is immutable — mutate via `copyWith` in `GameLogic`.
- No Riverpod/Provider — `ChangeNotifier` + `AnimatedBuilder`.
- `GameDirector.preview()` for tests (no SharedPreferences / no spatial timer).
- Asset paths only through `KenneyAssets` / `CustomAssets` (no raw `assets/...` in UI).
- Pixel sprites: `filterQuality: FilterQuality.none`.
- Loadouts UI label = **LOADOUTS**; dungeon armor 2pc/4pc = **armor sets** (not the same).

## Meta (survives Ascend)

**Keeps:** essence (and rewards), relics, sanctuary tracks + prestige, pets,
soulbound (item may rescale for new AL), God Hand level + style/CD in `metaDepth`,
`highestDungeonCleared`, `lifetimeGoldEarned`, achievements/codex, settings
(mute/VFX/colorblind/text scale/auto-sell), full `metaDepth` (Gauntlet best, Will /
Gauntlet claims, weekly/season, prestige shop, unlocked specs, party slot 5, …),
**hero levels/XP**, **Apex** vault + equipped apex, craft mats/pity, hardmode
(clamped) + challenge toggles.

**Resets:** wallet gold, floor progress, gold party upgrades (ATK/DEF/VIT/move/haste/crit),
non-Apex gear/stash, **loadouts**, leave dungeon; mission board rebuilt for new AL.

Dungeon unlock uses **lifetime gold** (and prior clears), not wallet gold.

## God Hand

Tap steers the party briefly and deals AOE; has cooldown. Damage upgrades with essence.
Styles under Forge → META: **BAL** / **FOCUS** (+dmg −radius) / **WIDE** (+radius −dmg).
Optional CD upgrades: `metaDepth.godHandCdLevel`.

## Balance policy

Owner: **fairness first**. Live-light CI gate fails on DPS `HIGH` (±20% vs median share).
Iterate with share-fast / `--focus=` before declaring kit work done.
