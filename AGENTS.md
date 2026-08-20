# AGENTS.md

Idle Party is a **working Flutter idle RPG** with original Dart gameplay code,
**Kenney** (CC0) world art, and **owned** custom identity sprites (`assets/custom/`).

**Ship version:** keep `pubspec.yaml` versionName and `MetaSystems.currentVersion`
in sync (currently **1.12.21**). What’s New lives in `lib/core/meta_systems.dart`.

## Human (vibe-coder)

The owner describes goals in plain language and does not pick tools/skills.
Agents **must** choose methods, skills, and verify steps themselves — see
`.cursor/rules/vibe-coder-autopilot.mdc` and `.cursor/rules/owner-preferences.mdc`.

Preferences (do not re-ask): **content/feel over Play busywork**, first-hour
**progression/power**, early calm / **endgame grindy OK**, **polish kits** before
many new specs, **no new zones or classes for now**, hub TODAY / Ascend Blessing / unlock teasers for
“what am I chasing”, **no IAP for now**, **Android phone-only** (portrait; no
iOS/web product), **large batches**, English in-game copy, fairness-first balance,
**commit locally when a batch is verified**, ask before push / PR / tag.
Near-term execution order:
`docs/CONTENT_CADENCE.md` after 90d M1–M3 shipped. **Default next work:**
**core-loop feel** (power beats in the fight you already have) unless the owner names something else.
Chat in plain Swedish; ask only product/risk questions. Full detail:
`.cursor/rules/owner-preferences.mdc`.

**UI target:** ship for **portrait phones** (~360–430 px). Owner reference:
**Samsung Galaxy A56** → playtest at **360×780** CSS (DPR 3). Web is playtest
only — agents must force phone emulation in Cursor browser. No hover-only flows
for real players — tap / long-press.

**Distribution today:** GitHub Releases APK/AAB is the live install path
(`docs/PLAY_STORE.md`). Package id `com.idleparty.app`. Play Console has listing +
closed Alpha (last submit **1.12.21 / 51**, 2026-08-20; testers keep 1.12.12 until review). Working ship is
**1.12.21**. Production still needs **12 closed testers × 14 days**.
Do not treat Play as the primary install channel.

Closed opt-in: `https://play.google.com/apps/testing/com.idleparty.app`

**Optional Play Games** (Android, META → SETTINGS): seasonal Timed KEY + Gauntlet
boards + cloud save. Opt-in; clipboard export/import still works. IDs in
`lib/core/play_leaderboard_ids.dart`. Soft-fail on web / sideload.

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
flutter test             # local: full suite; CI excludes tag `sim`
flutter run -d web-server --web-hostname=localhost --web-port=8080
```

CI (`ci.yml`): `flutter analyze lib test --no-fatal-infos` then
`flutter test --exclude-tags sim` (live-light balance gate still runs).
Long Monte-Carlo sims are tag `sim` → `.github/workflows/sim-nightly.yml`.
Runs on push to `main` / `master` / `cursor/**` / `release/**`, and on pull requests.

### Agent tooling (balance / honesty / QA)

```bash
# Fast DPS share board (writes tool/out/class_balance_share.json, gitignored)
flutter test test/class_balance_share_fast_test.dart --reporter expanded

# CI gate: live light, fail on DPS HIGH (±20% share band)
flutter test test/class_balance_gate_test.dart

# What’s New ↔ pubspec ↔ shipped zones
flutter test test/changelog_sync_test.dart

# Fast world-path / unlock / guides honesty
flutter test test/ship_smoke_test.dart
```

Skills under `.cursor/skills/`: domain (`spatial-combat-change`, `add-ability`,
`new-dungeon`, `zone-art-identity`, `save-migrate`, `class-audit`, `assets-legal`,
`flutter-verify`, `browser-playtest`, `hub-smoke`, `play-store-prep`, `init`) and
Cursor workflows (`suggesting-skills`, `building-skills-from-patterns`,
`grinding-until-pass`, `babysitting-pr`, `parallel-ci-triage`,
`verifying-in-browser`, `screenshotting-changelog`, `recording-browser-flow-as-test`,
`systematic-debugging`, `reviewing-code`, `accessibility-auditing`).

Cadence: `docs/CONTENT_CADENCE.md`. Near-term (90d, M1–M3 **shipped**):
`docs/STRATEGY_90D.md` (decision table only — operate from cadence). Year roadmap:
`docs/ROADMAP.md` (historical Q1–Q4; ship line in that file can lag). Background:
`docs/TOP_GAMES_RESEARCH.md`. Systems rebuild (P1–P5 chase/offline/kits/KEY/GH
shipped): `docs/SYSTEMS_REBUILD.md`. Chase contract (hub TODAY ↔ offline Up next):
`docs/CHASE_CONTRACT.md`. Gear budget contract: `docs/GEAR_BUDGET.md`. Floor
blueprint (shipped): `docs/FLOOR_BLUEPRINT.md`. Play ops: `docs/PLAY_STORE.md`
+ skill `play-store-prep`.

### Cursor automation

- Project hooks: `.cursor/hooks.json` — **sessionStart** injects current STRATEGY
  month; after game/docs edits, **stop** runs `flutter analyze lib test`, plus
  changelog sync when version/What’s New files touched, plus `ship_smoke_test`
  when hub/chase/guides files touched.
- Git: daily work on `main`; `release/*` only when cutting a tag.
- Ship bar: `.cursor/rules/definition-of-done.mdc`.
- Fast honesty: `flutter test test/ship_smoke_test.dart`.
- MCP: `.cursor/mcp.json` → **`idle-party`** (`tool/mcp_idle_party/`; Cursor UI
  may show `user-idle-party`) — balance_share, changelog_check, flutter_analyze/test,
  zone_identity, hub smoke helpers.

## Architecture

```
main.dart
 ├─ loading → boot intro → startMenu → optional newGamePicker → play
 ├─ Hub (!inDungeon) → HubScreen + FirstSessionTips + MenuSurface
 └─ Dungeon (inDungeon) → Is2Shell
      ├─ SpatialDungeonView (camera follow, God Hand, farm/push)
      └─ chrome (FARM/PUSH, God Hand, party HUD + flask, target panel)
         + AppBottomBar PARTY / POWER / META / HUB + MenuSurface

Shared menus: MenuRouter + MenuAlerts + MenuSurface
  (same PARTY/POWER/META words in hub and dungeon; dungeon adds HUB = leave)
```

**SpatialCombat is the combat authority** for live play and in-dungeon offline
catch-up (full enemy stats; same kits/abilities/chambers). Offline / AFK
catch-up uses `afkAssist: true` inside the same `build`/`step` API — enemy
hits are softer and hero hits harder so long catch-up stays snappy. Hub AFK
(`!inDungeon`) is sanctuary idle gold only — no combat.

**Content inventory:** 10 classes / **31 specs** (`HeroSpecId`) · **15 zones**
through Mothveil Hollow.

**Infinity Gauntlet** (`GameLogic.gauntletMinAscension` = AL10+): endless Crystal
Spire climb from Hub; wipe/leave → hub; `metaDepth.gauntletBestFloor` survives Ascend.

**Hub TODAY** — selection in `HubChase.forState`; every surface reads the same
words via **`ChaseContract`** (`lib/core/chase_contract.dart` + hub / offline Up
next). One chase card — claimables first (vault / jobs / **Meet new kit**), then
Ascend / progress. Urgency **READY** / **ALMOST** (zone/Will/Gauntlet/Ascend-near
beat Daily grind; also KEY +1 vault, etc.). **First hour** (no boss, no Ascend):
grow the party in the starter zone — skip Daily / KEY / vault-start / kit teasers
until after the first boss (`GameLogic.showDailyChase`). KEY / weekly-affix jargon
waits until AL≥2 or King's Fort cleared (`GameLogic.showKeystoneJargon`). New unlocks
queue `metaDepth.pendingHeroReveals` until PARTY opens. Ascend confirm/toast + chase
detail use **`AscendRoadmap`** (`lib/core/ascend_roadmap.dart`) for next AL
unlocks — kit ladder AL1–6 (e.g. Combat Rogue / Arms / Holy Paladin, BM/Holy/Arcane + 5th slot, DKs,
Aff/Demo) plus AL10 Gauntlet. Spec look: `HeroIdentity` (tint + Shadow→warlock
sprite).

New Game picker: three starters in plain English (**Shield / Healer / Damage**).
Advanced menu tabs (LOADOUTS, ROSTER, CAMP, SHOP, KEY, BEAST, CODEX, …) gate via
`MenuTabs` so day-one chrome stays small. PARTY badges mean bag upgrades
(`MenuAlerts`).

Hub AFK (`!inDungeon`) is sanctuary idle gold only — no combat (see SpatialCombat
note above for dungeon offline assist). Offline return
uses `OfflineProgressResult` (wow headline + ≤3 highlights + “Up next” =
ChaseContract).

Web playtest: `WebClickBridge` + Semantics (`browser-playtest` skill).

## World path (15 zones)

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

Unlock: prior clear **or** enough **lifetime gold** (not wallet gold).

## Floor / chamber model

- One **combat wave per floor**; boss on floor `5 + ascensionLevel`.
- Generation: **FloorBlueprint** (room beats) → **PlacementPlan** (props +
  chest sockets) → `RoomLayouts` / `SpatialCombat.build`, with per-zone
  **`ZoneLayoutKit`** (e.g. Brassvault treasure alcoves vs Mothveil silk chokes).
- Maps are **multi-chamber** with corridor **gates** after a chamber clears.
- Enemies in later chambers start **dormant**; wake when prior chambers clear
  (and can wake on **proximity** so soft-locks are rare).
- **Room chests** on elite/treasure beats drop gold/gear pickups — vacuumed
  with kill loot when the floor clears (same bank path).
- After all enemies die, ground loot is vacuumed immediately and the party
  walks to **stairs/exit** → `completeCurrentRoom`.

## Combat ratings (1.12.12)

Sheet power is `CombatRatings` (`lib/models/combat_ratings.dart`) — keep aligned
with `docs/GEAR_BUDGET.md` / `EquipStatWeights`:

- **Plate melee:** 2 AP per Strength. **Rogue-family** (leather/mail: rogues,
  hunters, cats, Enhancement): 1 AP/Str + **2 AP/Agility**.
- **Casters:** level Intellect is full ATK; **gear Int and Spell Power both ~/3**
  into ATK. Int still adds spell crit.
- **Armor:** percent mitigation `taken = raw * K / (def + K)` (K ≈ 1.2× attacker
  ATK), floor **25% of the hit** — more DEF always helps; nothing is immune.
- Player-facing STA = Stamina. BiS / UPGRADE still use budget score only.

## Key files

| Area | Path |
|------|------|
| Orchestration | `lib/core/game_director.dart` |
| Rules | `lib/core/game_logic.dart` |
| State | `lib/core/game_state.dart` |
| Changelog / meta helpers | `lib/core/meta_systems.dart` |
| Meta blob | `lib/models/meta_depth.dart` |
| Dungeon catalog | `lib/models/dungeon_def.dart` |
| Combat sheet | `lib/models/combat_ratings.dart` + `docs/GEAR_BUDGET.md` |
| Spatial sim | `lib/spatial/spatial_combat.dart` |
| Ability runtime | `lib/spatial/ability_effects.dart` + `kit_migrated_casts.dart` (`ClassAbilityDef.fireMode` / `gate` / `customId`) |
| Tile maps | `lib/spatial/tile_map.dart` |
| Floor blueprint / placement | `lib/spatial/floor_blueprint.dart`, `placement_plan.dart`, `zone_layout_kit.dart` + `docs/FLOOR_BLUEPRINT.md` |
| Shared menus | `lib/core/menu_router.dart`, `menu_alerts.dart` · `lib/ui/shell/menu_surface.dart`, `app_bottom_bar.dart` |
| Hub | `lib/ui/hub_screen.dart` |
| Hub TODAY chase | `lib/core/hub_chase.dart` |
| Hub gold/min (keep AFK) | `lib/core/gold_income.dart` |
| POWER INCOME tab | `lib/ui/shell/income_overlay.dart` |
| Apex hub (craft / vault / target meter) | `lib/ui/apex_forge_panel.dart` (`ApexHubPanel`) |
| Chase contract (hub ↔ AFK) | `lib/core/chase_contract.dart` + `docs/CHASE_CONTRACT.md` |
| Guides copy | `lib/core/game_guides.dart` |
| Keystone | `lib/core/keystone.dart` |
| Local season weeks | `lib/core/local_season.dart` |
| Play Games | `lib/core/play_games_bridge.dart`, `play_leaderboard_ids.dart` |
| Ascend unlock teasers | `lib/core/ascend_roadmap.dart` |
| Ascend / lore copy | `lib/core/story_lore.dart` |
| Dungeon shell | `lib/ui/is2_shell.dart` (~thin; HUD in `lib/ui/shell/*`) |
| Stage view | `lib/ui/spatial_dungeon_view.dart` |
| Kenney helpers | `lib/ui/kenney_assets.dart` |
| Custom art helpers | `lib/ui/custom_assets.dart` |
| Gear budget contract | `docs/GEAR_BUDGET.md` |
| UI theme guide | `docs/UI_THEME.md` (+ `MenuChrome` / `GameTheme`) |

## Conventions

- State is immutable — mutate via `copyWith` in `GameLogic`.
- No Riverpod/Provider — `ChangeNotifier` + `AnimatedBuilder`.
- `GameDirector.preview()` for tests (no SharedPreferences / no spatial timer).
- Asset paths only through `KenneyAssets` / `CustomAssets` (no raw `assets/...` in UI).
- Pixel sprites: `filterQuality: FilterQuality.none`.
- Loadouts UI label = **LOADOUTS**; dungeon armor 2pc/4pc = **armor sets** (not the same).
- Gear BiS / UPGRADE: budget-honest score only — see `docs/GEAR_BUDGET.md`
  (`itemBudgetScore`; no affinity/armor/rarity/set crumbs).
- Split giant files (`game_logic`, `spatial_combat`, …) when a change needs a
  home — do not merge more into them. `is2_shell` is already thin; put new HUD
  under `lib/ui/shell/`. SpatialCombat stays the only fight sim.

## Meta (survives Ascend)

**Keeps:** essence (and rewards), relics, sanctuary tracks + prestige, pets,
God Hand level + style/CD in `metaDepth`, **Apex** vault + equipped apex,
legacy heirloom item if an old save still has one (no new binds; may rescale),
`highestDungeonCleared`, `lifetimeGoldEarned`, achievements/codex, settings
(mute/VFX/colorblind/text scale/auto-sell/**auto-disassemble**), full `metaDepth`
(Gauntlet best, Will / Gauntlet claims, daily vault / weekly affix season,
prestige shop, unlocked specs, **`pendingHeroReveals`** (Meet … TODAY until PARTY),
party slot 5, ascend streak/titles/trophies, **`ascendBlessings`**, Play Games
opt-in + season PBs, …), **hero levels/XP**,
craft mats/pity, keystone prefs (clamped) + challenge toggles, FARM/PUSH preference.

**Ascend Blessing** (stacks in `metaDepth.ascendBlessings`, default `0` on old saves):
each Ascend adds **+2 ATK · +8 DEF · +24 STA · +3% gold** on top of AL flats
(`+1 ATK` / `+4 DEF` / `+12 STA` / `+10% gold` per AL). Shown in Forge → KEEP
and Sanctuary. Constants: `GameLogic.ascendBlessing*`. Player-facing label is
**STA / Stamina** (same as gear); internal fields may still say vitality.

**Resets:** wallet gold, floor progress (`highestFloorCleared`), gold party upgrades
(ATK/DEF/STA/move/haste/crit), non-Apex gear/stash, **loadouts**, leave dungeon
(`inDungeon=false`); mission board rebuilt for new AL.

Dungeon unlock uses **lifetime gold** (and prior clears), not wallet gold.

### Keystone (Mythic+-style)

Hub **KEY** (META tab, after jargon unlock) sets preferred key (`hardmodeLevel`
0–20, AL-gated). On enter, affixes lock + idle-friendly par timer starts (AFK
counts). Boss clear under par → TIMED (upgrade key, vault score); overtime →
depleted. Loot iLvl bonus is `key * 2` (`Keystone.lootItemLevelBonus`) so higher
keys are a visible gear jump. After the first hour, hub TODAY chases the next KEY
until the AL cap; Daily / Will / Gauntlet surface when the preferred key is at cap
(ALMOST cliffs stay above). **Daily vault** (UTC): 1 clear **or** timed KEY+2;
claim once per day (scales with best timed key). Affixes still rotate weekly.
See `lib/core/keystone.dart`.

## God Hand

Tap steers the party briefly and deals AOE; has cooldown. Damage upgrades with essence.
Styles under Forge → KEEP: **BAL** / **FOCUS** (+dmg −radius) / **WIDE** (+radius −dmg).
Optional CD upgrades: `metaDepth.godHandCdLevel`. Soft knobs — do not redesign
direction without asking.

## Balance policy

Owner: **fairness first**. Live-light CI gate fails on DPS `HIGH` (±20% vs median share).
Iterate with share-fast / `--focus=` before declaring kit work done.
