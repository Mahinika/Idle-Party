# AGENTS.md

Idle Party is a working Flutter idle RPG. Original Dart. Owned pixel art in
`assets/custom/`.

**Ship version:** `pubspec.yaml` `version:` name must match
`ChangelogCatalog.currentVersion` in `lib/core/changelog.dart`
(`MetaSystems.currentVersion` reads it). What’s New lives in
`lib/core/meta_systems.dart`. Do not hardcode the number here.

Work style, locks, and Swedish handoff live in `.cursor/rules/`. Do not
restate them here. Growth principles: `docs/GROWTH_MANDATE.md`.

**UI:** portrait phones, reference Samsung A56 (360×780). Live look is the
AVD `Samsung_A56` via `a56-playtest`. Web is Playwright / `WebClickBridge`
only.

**Distribution:** Google Play is the install path (`com.idleparty.app`,
`docs/PLAY_STORE.md`). Do not link players to GitHub Releases. Never upload
an AAB unless the owner asks that turn. Update notice, rating ask, Play
Games, and Firebase live in `docs/PLAY_STORE.md` and `docs/PRIVACY.md`.

**Legal:** owned `assets/custom/` only. No foreign dumps, sprites, audio, or
decompiled code. See `.cursor/rules/product-locks.mdc`.

**Doll:** `paintOwnedHero` plus `docs/CHARACTER_VISUALS.md` and skill
`character-paper-doll`. Gear and race clips are owned PNGs. Enemies are a
separate art pass.

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
Share-fast: `flutter test test/class_balance_share_fast_test.dart`.

Skills live under `.cursor/skills/`. Slash: `/init` resyncs this file and
the rules; `/repo auditandcleaning` is analysis only.

Hooks (`.cursor/hooks.json`): **sessionStart** injects the owner **Now:**
line plus the Play-upload lock. **afterFileEdit** marks verify-dirty.
**stop** runs analyze, plus changelog or ship-smoke tests when those files
moved.

MCP: `.cursor/mcp.json` → `idle-party` (`tool/mcp_idle_party/`).

Cadence: `docs/CONTENT_CADENCE.md`. Chase: `docs/CHASE_CONTRACT.md`. Gear
math: `docs/GEAR_BUDGET.md`. Floors: `docs/FLOOR_BLUEPRINT.md`.

## Architecture

```
main.dart
 ├─ loading → boot intro → startMenu → optional newGamePicker → play
 └─ PlayShell
     ├─ Hub (!inDungeon) → HubScreen
     └─ Dungeon → Is2Shell → SpatialDungeonView
         + AppBottomBar GEAR / GOLD / SHOP / ESSENCE / MORE
           (first hour: GEAR + MORE; endgame hub: + KEY; dungeon: + LEAVE)
```

GOLD = FORGE + MARKET. SHOP = forever SCROLLS + ad-free / supporter (hour
packs are restore-only). ESSENCE = CAMP + BLESSING + relics + pets. MORE =
QUESTS / CRAFT / SETTINGS / INFO. Redeem code is SHOP and MORE → SETTINGS.
Hub POWERUPS stay on the hub.

**SpatialCombat** is the only fight sim, including in-dungeon offline
(`afkAssist: true`, `GameLogic.simulateSpatialOffline`). Hub AFK is gold
plus slow essence, not combat. PUSH clear +1 essence, boss +2; FARM and
Gauntlet pay 0.

**Content:** 10 classes / 31 specs · 15 zones through Mothveil Hollow.
Hero cap `maxHeroLevel` 100 (combat XP only). Ascend cap AL20.
Endgame (KEY, Gauntlet, Rifts, Greater Rifts, Ashen, Craft Trial) unlocks
when the **active party is all Lv100**, not at AL20 alone.

| Hunt | Where |
|------|--------|
| KEYSTONE | Hub KEY. No KEY tab before party Lv100. |
| Gauntlet | Endless Crystal Spire. Boss every 5 floors. |
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
Combat ratings: `docs/GEAR_BUDGET.md` (`CombatRatings`). Player-facing
stamina is STA.

## Key files

| Area | Path |
|------|------|
| Orchestration | `lib/core/game_director.dart` |
| Rules | `lib/core/game_logic.dart` (+ ascend / endgame / ladders / meta-season parts) |
| State / meta | `lib/core/game_state.dart`, `lib/models/meta_depth.dart` |
| Changelog | `lib/core/changelog.dart`, `lib/core/meta_systems.dart` |
| Zones | `lib/models/dungeon_def.dart` |
| Combat | `lib/spatial/spatial_combat.dart` |
| Kits | `lib/models/class_ability.dart`, `lib/models/kits/`, `lib/spatial/ability_effects.dart`, `kit_migrated_casts.dart` |
| Packs / tells | `lib/core/enemy_flavor.dart`, `lib/core/boss_tells.dart`, `lib/spatial/enemy_specials.dart` |
| Floors | `lib/spatial/floor_blueprint.dart`, `placement_plan.dart`, `zone_layout_kit.dart` |
| Menus | `lib/core/menu_router.dart`, `lib/ui/shell/menu_surface.dart`, `app_bottom_bar.dart` |
| Hub / chase | `lib/ui/hub_screen.dart`, `lib/core/hub_chase.dart`, `lib/core/chase_contract.dart` |
| Art helpers | `lib/assets/custom_assets.dart`, `lib/assets/kenney_assets.dart` |
| UI tokens | `lib/ui/theme.dart`, `docs/UI_THEME.md` |

## Conventions

- Immutable state. Mutate via `copyWith` in `GameLogic`.
- No Riverpod/Provider. `ChangeNotifier` + `AnimatedBuilder`.
- Tests use `GameDirector.preview()` (no SharedPreferences).
- Sprite paths go through `CustomAssets` or `KenneyAssets`. `assets/data/*.json` from core is fine. Pixel sprites use `FilterQuality.none`.
- LOADOUTS tab is hidden. Armor 2pc/4pc are sets, not loadouts.
- BiS / UPGRADE use budget score only (`docs/GEAR_BUDGET.md`).
- Split a giant file when a change needs a home. Do not grow `game_logic` / `spatial_combat`. New HUD goes under `lib/ui/shell/`.
- One fight sim. Do not add a second.

## Ascend

**Keeps:** hero levels/XP, open zones, essence, relics, pets, sanctuary,
God Hand, Apex, soulbound, settings, unlocked specs, full `metaDepth`
(bests, blessings, constellation, Craft Trial, ad tickets and timers,
shop entitlements, coupons, Play opt-in).

**Resets:** wallet gold, forge tracks, worn/stash drops, market, loadouts,
`highestFloorCleared`. Sets `freshPrestige`. Clears boss victories, wipe
streak, and the active dungeon via leave.

Blessing stacks, STAR NODES, and REBORN: `lib/core/blessing_constellation.dart`
and skill `save-migrate`. REBORN is optional and never a TODAY chase.
Dungeon unlock is party mean level, not lifetime gold.

God Hand: tap steer + AOE under ESSENCE → BLESSING (BAL / FOCUS / WIDE).
Change direction only when the owner names it.

**Balance:** fairness first. CI fails on DPS `HIGH` (±20% vs median share).
Iterate with share-fast before kit number work is done.
