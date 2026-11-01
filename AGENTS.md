# AGENTS.md

Idle Party is a working Flutter idle RPG. Original Dart. Owned pixel art in
`assets/custom/`.

**Ship version:** `pubspec.yaml` `version:` name must match
`ChangelogCatalog.currentVersion` in `lib/core/changelog.dart`
(`MetaSystems` re-exports it). What’s New is that catalog. Do not
hardcode the number here.

The always-on page is `.cursor/rules/20-how-we-work.mdc`. Do not restate it
here. The full pick is `.cursor/rules/10-what-to-build.mdc`. Growth
principles: `docs/GROWTH_MANDATE.md`. A goal the owner names wins.

**UI:** portrait phones, reference Samsung A56 (360×780). Live look is the
AVD `Samsung_A56` via `a56-playtest`. The agent reads that device with
`py -3 tool/adb_see.py` (UI tree + `[IP]` log; a PNG only when pixels
matter). Web is Playwright / `WebClickBridge` only.

**Distribution:** Google Play is the install path (`com.idleparty.app`,
`docs/PLAY_STORE.md`). Do not link players to GitHub Releases. Never upload
an AAB unless the owner asks that turn. A manual 5% production upload is
`.github/workflows/play-upload.yml` (`workflow_dispatch`, input `tag`). It
does not run on a tag. A release AAB packages native debug
symbols (`debugSymbolLevel FULL`). Do not pass `--obfuscate`. In-app update gate, hub **GET
UPDATE**, and the rating ask are in `docs/PLAY_STORE.md`. Play
Games and Firebase are there and in `docs/PRIVACY.md`. Event names
are in `docs/ANALYTICS.md`.

**Legal:** owned `assets/custom/` only. No foreign dumps, sprites, audio, or
decompiled code. See `.cursor/rules/00-locks.mdc`.

**Doll:** the live hero is the cutout skeleton (`HeroRigPainter`) for
warrior, rogue, mage, and healer. `paintOwnedHero` is the still paper doll:
the fallback before the atlas is ready, and the picture the lookbook
measures. See `docs/CHARACTER_VISUALS.md` and skill `hero-rig`. Gear
pictures follow skill `gear-art` and `tool/gear_style.py`. Gear and race
clips are owned PNGs. Enemies are a separate art pass.

## Build and verify

```bash
flutter pub get
flutter analyze lib test --no-fatal-infos
flutter test --exclude-tags sim
flutter test test/ship_smoke_test.dart
flutter test test/class_balance_gate_test.dart
flutter test test/changelog_sync_test.dart
```

Tag `sim` is nightly (`.github/workflows/sim-nightly.yml`), not missing CI.
Sideload test APKs: `.github/workflows/test-apk-prerelease.yml`
(`workflow_dispatch` or a `test-*` tag). It publishes split arm64 and x86_64
APKs for `com.idleparty.app.test`. Play release builds stay in `build-apk.yml`.
Share-fast: `flutter test test/class_balance_share_fast_test.dart`.

Skills live under `.cursor/skills/`. Slash: `/init` resyncs this file and
the rules; `/repo auditandcleaning` is analysis only. `/playtest` continues
the emulator save for about 10 minutes and writes what it finds.

Hooks (`.cursor/hooks.json`): **sessionStart** injects the owner **Now:**
line plus the Play-upload lock, and deletes `playshots/` images older than
3 days (the folder is git-ignored). **afterFileEdit** marks verify-dirty.
**stop** runs analyze, plus changelog, ship-smoke, or share-fast tests when
those files moved, then nudges once in that same chat if its files are still
uncommitted. Edits from another chat do not land here.
Owner play notes live in `docs/PLAY_NOTES.md`.
`test/agent_rules_test.dart` keeps rule descriptions readable by Cursor.

MCP: `.cursor/mcp.json` → `idle-party` (`tool/mcp_idle_party/`).

Cadence: `docs/CONTENT_CADENCE.md`. Week plans: `docs/weeks/`. Chase: `docs/CHASE_CONTRACT.md`. Gear
math: `docs/GEAR_BUDGET.md`. Floors: `docs/FLOOR_BLUEPRINT.md`.

## Architecture

```
main.dart
 ├─ loading → playUpdateRequired? → boot intro → startMenu
 │    → pickSave? → newGamePicker? → play
 └─ PlayShell
     ├─ Hub (!inDungeon) → HubScreen
     └─ Dungeon → Is2Shell → SpatialDungeonView
         + AppBottomBar GEAR / GOLD / SHOP / ESSENCE / MORE
           (early: GEAR + MORE; GOLD/SHOP after first boss or Ascend;
            ESSENCE when camp matters; endgame hub: KEY after MORE;
            dungeon: + LEAVE)
```

GOLD = FORGE + MARKET. SHOP = ad-free, Long Away, and Supporter (hour
packs restore only; forever scrolls and the Cinder pouch show only after
Play lists them). ESSENCE = CAMP + BLESSING + relics + pets. MORE =
QUESTS / CRAFT / SETTINGS / INFO. Redeem code is SHOP and MORE → SETTINGS.
Hub POWERUPS stay on the hub.

**SpatialCombat** is the current fight sim, including in-dungeon offline
via `OfflineSim` → `GameLogic.simulateSpatialOffline` (same authority as
live play; offline uses `afkAssist` except ticket Ashen Crown). The live
fight steps once per screen refresh, so a late frame does not stack
another hitch. A second sim is not forbidden (owner 2026-09-26). Hub AFK is
gold plus slow essence, not combat. A PUSH clear pays +1 essence, a PUSH
boss +2. FARM pays that mint 0. Gauntlet pays its own floor essence,
doubled under GREED, and does not use the PUSH mint.

A PUSH wipe counts down 3 seconds and continues. Two fails on the same new
floor farm the floor below until one clear, then push again. Offline farms
that safe floor instead of stopping. Gauntlet, Rifts, and the daily keep
their own rules.

**Content:** 10 classes / 31 specs · 15 zones through Mothveil Hollow.
Hero cap `maxHeroLevel` 100 (combat XP only). Ascend cap AL20.
A new game starts with 3 heroes. The fourth joins at the first Ascend.
A fifth slot unlocks at AL2 for 80 essence and stays on Ascend. The
active party cap is 4 until that buy. Race locks after New Game START.
Class can still change.
Endgame (KEY, Gauntlet, Rifts, Greater Rifts, Ashen, Craft Trial) unlocks
when the **active party is all Lv100**, not at AL20 alone.

| Hunt | Where |
|------|--------|
| KEYSTONE | Hub KEY. No KEY tab before party Lv100. |
| Gauntlet | Endless Crystal Spire. Pick MIGHT, WARD, or GREED. Boss every 5 floors. Between bosses the floor is one squeeze: tight rooms, a swarm, one echoed tell, or extra gates. After floor 100 the hub names Ranked GR; later floors stay a personal best. Spire Trophies: each squeeze under each pact, kept on Ascend. |
| Rifts | Stormwake Hollow. No fail timer. |
| Greater Rifts | Mothveil Hollow. Timed. Local season PB. |
| Ashen Crown | Weekly ticket. Rotates shipped caves. Not zone 16. |
| Craft Trial | MORE → CRAFT. Not a hub ENDGAME hunt. |

Zone unlock: party mean level (even steps Lv1…100) or prior clear. Sandy
from Lv1. Lifetime gold does not unlock zones.

Hub TODAY reads `ChaseContract`. First hour grows the party in the starter
zone. PATH is a continent atlas (no scroll strip). ENDGAME is Gauntlet,
Ranked GR, Farm Rift, Ashen on the same map. LOADOUTS tab is hidden; save
fields may remain.

## World path

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
| 9 | grove | Hollow Grove |
| 10 | storm | Stormwake Hollow |
| 11 | rime | Rimeglass Rift |
| 12 | fen | Blightfen Mire |
| 13 | brass | Brassvault Deep |
| 14 | veil | Mothveil Hollow |

PATH markers sit on lands. Catalog order is still 0…14.

Floors, chambers, gates, and wipe advice: `docs/FLOOR_BLUEPRINT.md`.
The open hall runs north and south so the next pack, or its closed gate,
stays on one phone screen. A chest floor opens on the chest.
Combat ratings: `docs/GEAR_BUDGET.md` (`CombatRatings`). Player-facing
stamina is STA.

## Key files

| Area | Path |
|------|------|
| Orchestration | `lib/core/game_director.dart` (+ save / fight / platform parts) |
| Rules | `lib/core/game_logic.dart` (+ ascend / endgame / ladders / meta-season / dungeon / party / forge parts) |
| Offline dungeon | `lib/core/offline_sim.dart`, `lib/core/offline_progress.dart` |
| State / meta | `lib/core/game_state.dart`, `lib/models/meta_depth.dart` |
| Changelog | `lib/core/changelog.dart`, `lib/core/meta_systems.dart` |
| Zones | `lib/models/dungeon_def.dart` |
| Combat | `lib/spatial/spatial_combat.dart` |
| Kits | `lib/models/class_ability.dart`, `lib/models/kits/`, `lib/spatial/ability_effects.dart`, `kit_migrated_casts.dart` |
| Packs / tells | `lib/core/enemy_flavor.dart`, `lib/core/boss_tells.dart`, `lib/spatial/enemy_specials.dart` |
| Floors | `lib/spatial/floor_blueprint.dart`, `placement_plan.dart`, `zone_layout_kit.dart`, `floor_theme.dart`, `floor_decals.dart`, `prop_vignettes.dart`, `room_silhouette.dart` |
| Floor look | `lib/ui/dungeon_floor_layer.dart` (baked terrain, lights, reveal), `dungeon_ambient_particles.dart`; props art `tool/generate_floor_props.py` |
| Menus | `lib/core/menu_router.dart`, `lib/ui/shell/menu_surface.dart`, `app_bottom_bar.dart` |
| Hub / chase | `lib/ui/hub_screen.dart`, `lib/core/hub_chase.dart`, `lib/core/chase_contract.dart` |
| Art helpers | `lib/assets/custom_assets.dart`, `lib/assets/kenney_assets.dart` |
| Gear art | `tool/gear_style.py`, `tool/facit/`, `tool/gear_lookbook.py`, rule `gear-art-standard`, skill `gear-art`, skill `gear-lookbook` |
| UI tokens | `lib/ui/theme.dart`, `docs/UI_THEME.md` |
| Emulator look | `py -3 tool/adb_see.py` (UI tree, tap-by-label, `[IP]` log) |
| Playtest | `py -3 tool/playtest_run.py`, `docs/PLAYTEST_MEMORY.md` |

## Conventions

- Immutable state. Mutate via `copyWith` in `GameLogic`.
- No Riverpod/Provider. `ChangeNotifier` + `AnimatedBuilder`.
- Tests use `GameDirector.preview()` (no SharedPreferences).
- Five local save slots on the title screen. Autosave writes the slot you opened. An older single `idle_party_save_v2` migrates into SAVE 1.
- Sprite paths go through `CustomAssets` or `KenneyAssets`. `assets/data/*.json` from core is fine. Pixel sprites use `FilterQuality.none`.
- LOADOUTS tab is hidden. Armor 2pc/4pc are sets, not loadouts.
- BiS / UPGRADE use budget score only (`docs/GEAR_BUDGET.md`).
- AUTO EQUIP (GEAR, on by default) wears a budget upgrade during the fight and while the app is closed. Ranked GR stays manual. Kept on Ascend.
- Split a giant file when a change needs a home. Do not grow `game_logic` / `spatial_combat`. New HUD goes under `lib/ui/shell/`.
- SpatialCombat is the current fight sim. A second sim is not forbidden.

## Ascend

**Keeps:** hero levels/XP, open zones, essence, Embers, Cinders, relics, pets, sanctuary,
God Hand, Apex, soulbound, settings, unlocked specs, full `metaDepth`
(bests, blessings, constellation, Craft Trial, Spire Trophies, ad tickets and timers,
shop entitlements, coupons, Play opt-in), plus AUTO EQUIP.

**Resets:** wallet gold, forge tracks, worn/stash drops, market, loadouts,
`highestFloorCleared`. Sets `freshPrestige`. Clears boss victories, wipe
streak, and the active dungeon via leave.

Blessing stacks, STAR NODES, and REBORN: `lib/core/blessing_constellation.dart`
and skill `save-migrate`. REBORN is optional and never a TODAY chase.
Dungeon unlock is party mean level, not lifetime gold.

God Hand: long-press the fight or tap the fist + AOE under ESSENCE → BLESSING (BAL / FOCUS / WIDE).
Change direction when the owner names it, or when an A-grade source and a
hole in this game agree (`.cursor/rules/10-what-to-build.mdc`).

**Balance:** fairness first. CI fails on DPS `HIGH` (±20% vs median share).
Iterate with share-fast before kit number work is done.
