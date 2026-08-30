# AGENTS.md

Idle Party is a **working Flutter idle RPG** with original Dart gameplay code,
**Kenney** (CC0) world art, and **owned** custom identity sprites (`assets/custom/`).

**Ship version:** keep `pubspec.yaml` versionName and `MetaSystems.currentVersion`
in sync (currently **1.12.84**). What’s New lives in `lib/core/meta_systems.dart`.

## Human (vibe-coder)

The owner describes goals in plain language and does not pick tools/skills.
Agents **must** choose methods, skills, and verify steps themselves — see
`.cursor/rules/vibe-coder-autopilot.mdc` and `.cursor/rules/owner-preferences.mdc`.

Preferences (do not re-ask): **content/feel over Play busywork**, owner plays
**AL20 on their own save** (hub chase clarity; in-dungeon wipe advice only when
the sim knows the deficit), early calm for new players / **endgame grindy OK**,
**polish kits** before many new specs, **no new zones or classes for now**,
**hide unused chrome** (BAG Scrap, Sell junk, GEAR Sell, Loadouts) rather than
polish it, **no IAP for now**, optional hub **POWERUPS** rewarded ads
(1 ad = 3 hours, stackable), **Android phone-only** (portrait; no
iOS/web product), **large independent batches**, English in-game copy,
fairness-first balance. After a batch: **short test list**; **APK only when
they ask**; wait for owner notes; **then** GitHub APK **and** Play AAB. Testers do not
get a build before the owner. Commit locally when tests are green; ask before
push / PR / tag / Play.
Near-term execution order:
`docs/CONTENT_CADENCE.md` after 90d M1–M3 shipped. **Default next work:**
**AL20 hub + dungeon feel** unless the owner names something else.
Chat in plain Swedish; after code, say what to test and wait. Full detail:
`.cursor/rules/owner-preferences.mdc`.

**UI target:** ship for **portrait phones** (~360–430 px). Owner reference:
**Samsung Galaxy A56** (1080×2340 → **360×780**). **Live look:** AVD
`Samsung_A56` + `flutter run` (skill `a56-playtest`). USB phone if plugged in.
Web is fallback (Playwright / `WebClickBridge`) with forced 360×780 — never
wide desktop chrome. No hover-only flows for real players — tap / long-press.

**Distribution today:** GitHub Releases APK/AAB is the live install path
(`docs/PLAY_STORE.md`). Package id `com.idleparty.app`. Play Console has listing +
closed Alpha (**1.12.83 / 112** submitted 2026-08-29; testers may still be on
**1.12.78 / 107** until review publishes). Working ship is
**1.12.84**. Production still needs **12 closed testers × 14 days**.
Do not treat Play as the primary install channel.

Closed opt-in: `https://play.google.com/apps/testing/com.idleparty.app`

**Play update notice** (Android, Play-installed only): **mandatory cold-start gate** when Play has a newer versionCode (no play until updated); hub banner + SETTINGS **GET UPDATE** with LATER for optional nudge. Sideload / web stay quiet. Listing opens with `hl=en`.

**Optional Play Games** (Android): seasonal Timed KEY + Gauntlet boards under
**KEY** (bottom tab when jargon unlocks); sign-in + cloud save under
**MORE → SETTINGS**. Opt-in; clipboard export/import still works. IDs in
`lib/core/play_leaderboard_ids.dart`. Soft-fail on web / sideload.

## Legal / IP policy (mandatory)

- **Do not** add, keep, or commit APKs, IPA/AAB, SWF, DEX, or dumps from other commercial games.
- **Do not** copy sprites, audio, code, or text from other games into this repo.
- Shipped art must come from `assets/kenney/` (CC0) or `assets/custom/` (owned Idle Party art).
- Gameplay may follow common idle-RPG *ideas*; implement as original Dart — never paste
  or translate decompiled sources.
- If a third-party binary appears locally, delete it and ensure `.gitignore` covers it.

## Character visuals (dungeon)

Layered Canvas heroes: `lib/visual/` + `docs/CHARACTER_VISUALS.md`.
Dungeon uses class PNG body + anchored gear overlays (`visualSetId`); full
Kenney paper-doll is the no-sprite fallback. Never a Class×Weapon sheet.

## Build & Test

```bash
flutter pub get
flutter analyze          # project target: zero issues on lib/test
flutter test             # local: full suite; CI excludes tag `sim`
flutter emulators --launch Samsung_A56   # wait until booted
flutter run -d emulator-5554             # live look (skill a56-playtest)
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
`flutter-verify`, `a56-playtest`, `browser-playtest`, `hub-smoke`, `play-store-prep`, `init`,
`repo-audit-and-cleaning`) and
Cursor workflows (`suggesting-skills`, `building-skills-from-patterns`,
`grinding-until-pass`, `babysitting-pr`, `parallel-ci-triage`,
`verifying-in-browser`, `screenshotting-changelog`, `recording-browser-flow-as-test`,
`systematic-debugging`, `reviewing-code`, `accessibility-auditing`).
Slash: `/init` resyncs AGENTS/rules; `/repo auditandcleaning` runs a read-only
full-repo audit (see `.cursor/commands/repo-auditandcleaning.md`).

Cadence: `docs/CONTENT_CADENCE.md` (decision table + tag rhythm; 90d M1–M3
shipped). Background (optional): `docs/TOP_GAMES_RESEARCH.md`. Chase contract
(hub TODAY ↔ offline Up next): `docs/CHASE_CONTRACT.md`. Gear budget:
`docs/GEAR_BUDGET.md`. Floor blueprint (shipped): `docs/FLOOR_BLUEPRINT.md`.
Play ops: `docs/PLAY_STORE.md` + skill `play-store-prep`.

### Cursor automation

- Project hooks: `.cursor/hooks.json` — **sessionStart** injects cadence context;
  **afterFileEdit** marks `.cursor/hooks/.verify-dirty` when `lib/` / `test/` /
  docs / rules change; **stop** verifies only if that flag exists
  (`flutter analyze lib test --no-fatal-infos`), plus `changelog_sync_test` when
  version / What’s New / `dungeon_def.dart` touched, plus `ship_smoke_test` when
  hub / chase / guides files touched.
- UI chrome: `.cursor/rules/ui-theme.mdc` (globs `lib/ui/**`).
- Git: daily work on `main`; `release/*` only when cutting a tag.
- Ship bar: `.cursor/rules/definition-of-done.mdc`.
- Fast honesty: `flutter test test/ship_smoke_test.dart`.
- MCP: `.cursor/mcp.json` → **`idle-party`** (`tool/mcp_idle_party/`; Cursor UI
  may show `user-idle-party`) — `verify`, ship_smoke, balance_share/gate,
  changelog_check, kit/aoe_audit, save_peek, zone_identity, hub smoke helpers.

## Architecture

```
main.dart
 ├─ loading → boot intro (optional first-launch cinematic, else 3 beats) → startMenu → optional newGamePicker → play
 ├─ PlayShell (one MenuSurface + toast; hub vs dungeon scenes)
 │   ├─ Hub (!inDungeon) → HubScreen + FirstSessionTips
 │   └─ Dungeon (inDungeon) → Is2Shell
 │        ├─ SpatialDungeonView (camera follow, God Hand, farm/push)
 │        └─ chrome (FARM/PUSH, God Hand, party HUD + flask, target panel)
 │           + AppBottomBar GEAR / POWER / QUESTS + LEAVE
 │             (hub also KEY when jargon unlocks + MORE; dungeon: KEY/MORE via HUD gear)

Shared menus: MenuRouter + GearSession + NavIntent + MenuAlerts + MenuSurface
 (flat tabs; dungeon LEAVE = hub; MORE/KEY via HUD gear in dungeon)
 POWER inner tabs: Gold · Shop · Relics · Craft · Essence
 (prestige buys in Shop; Beast in Essence; Blessing / God Hand / REBORN under Gold → KEEP)
```

**SpatialCombat is the combat authority** for live play and in-dungeon offline
catch-up (full enemy stats; same kits/abilities/chambers). Offline / AFK
catch-up uses `afkAssist: true` inside the same `build`/`step` API — enemy
hits are softer and hero hits harder so long catch-up stays snappy. Hub AFK
(`!inDungeon`) is sanctuary idle gold only — no combat. Healers open each floor
with mana; **Spirit** refills mana over time (not a damage stat). Warrior /
Paladin / Shaman can equip **shields** in the off-hand.

**Content inventory:** 10 classes / **31 specs** (`HeroSpecId`) · **15 zones**
through Mothveil Hollow.

**Infinity Gauntlet** (`GameLogic.endgameUnlocked` = active party all at
`maxHeroLevel` **100**): endless Crystal
Spire climb from Hub; **boss every 5 floors**; wipe/leave → hub;
`metaDepth.gauntletBestFloor` survives Ascend.

**KEYSTONE** (same party-max-level gate): Mythic+-style keys on
normal zone runs — dial under hub **KEY**. Before party max level there is no KEY habit or KEY tab.

**Rifts** (same gate): farm timed kill-quota from hub /
**KEY** — gold and gear mid-run; not Play-ranked.
`metaDepth.riftBestTier` survives Ascend.

**Greater Rifts** (same gate): harder timed ladder,
no mid-run gear, larger clear payout; season PB on Play Games BOARDS.
`metaDepth.grBestTier` / `seasonBestGrTier` survive Ascend.

**Ashen Crown** (same gate): weekly ticket solo boss (ember art); wipe/leave
returns the ticket; PRACTICE free after the paid clear. Tickets /
`worldBoss*` fields in `metaDepth`; see `lib/core/ashen_crown.dart`.

**Ascension cap:** `GameLogic.maxAscensionLevel` = **AL20** — Ascend stops here
(Blessing / kit roadmap). **Endgame content** (KEY +20, Gauntlet, Rifts, Greater
Rifts) unlocks when the **active party is all Lv100**, not at AL20 alone.
**Hero level cap:** `GameLogic.maxHeroLevel` = **100**; combat XP only (no gold
Train +1 level). Endgame (KEY / Gauntlet / Rifts) when every active hero is
Lv100. Gold tracks (ATK/DEF/STA/MOVE/HASTE/CRIT) still buyable (wipe on
Ascend).

**Zone unlock:** party **mean level** (even steps 1…100 across 15 zones) **or**
prior zone clear. Zone 0 (Sandy) from Lv1. Lifetime gold no longer unlocks zones.

**QUESTS** (bottom tab; was JOBS/contracts): 3-slot board — **Daily** (UTC kill
quest), **Bounty** ladder (100/500/1000 at endgame), **Side** rotating
non-kill. Claim via TODAY **CLAIM QUESTS**.

**Hub TODAY** — selection in `HubChase.forState`; every surface reads the same
words via **`ChaseContract`** (`lib/core/chase_contract.dart` + hub / offline Up
next). One chase card — claimables first (vault / quests / **Meet new kit** /
**equip BAG** / **Shop upgrade**), then Ascend / progress. Urgency **READY** /
**ALMOST** (zone/Will/Gauntlet/Ascend-near beat Daily grind; also KEY +1 vault,
etc.). Local-season **week goal** can surface as a chase. **First hour** (no
boss, no Ascend): grow the party in the starter zone — skip Daily /
vault-start / kit teasers until after the first boss
(`GameLogic.showDailyChase`). **KEY habit** (`ENTER KEY +N`), KEY tab,
week-affix jargon, and KEYSTONE tips wait until the **active party is all
Lv100** (`GameLogic.showKeystoneJargon` → `endgameUnlocked`). At endgame,
TODAY prefers KEY then Gauntlet → Greater Rift → Rift → Ashen Crown before
Daily grind; Meet-kit backlog stays on PARTY badge. New unlocks queue
`metaDepth.pendingHeroReveals` until PARTY opens. Ascend confirm/toast + chase
detail use **`AscendRoadmap`** (`lib/core/ascend_roadmap.dart`) for next AL
unlocks — kit ladder AL1–6 (e.g. Combat Rogue / Arms / Holy Paladin,
BM/Holy/Arcane + 5th slot, DKs, Aff/Demo) plus AL20 party-level gate copy.
Spec look: `HeroIdentity` (tint + Shadow→warlock sprite).

New Game picker: choose **3 unique specs** from the starter pool. Role copy is
**Shield / Healer / Damage** (easy start = one of each), not three fixed buttons.
Advanced menu tabs (ROSTER, Essence, KEY, BEAST, CODEX, …) gate via
`MenuTabs` so day-one chrome stays small. **LOADOUTS** tab is hidden/removed
(save fields may remain). PARTY badges mean bag upgrades (`MenuAlerts`).

Offline return uses `OfflineProgressResult` (wow headline + ≤3 highlights +
“Up next” = ChaseContract).

Live look: `a56-playtest` (Samsung A56 emulator). Web fallback:
`WebClickBridge` + Semantics (`browser-playtest`).

**Hub POWERUPS** (optional rewarded ads, Android): `AdBoost` + `AdRewarded` +
`ad_config.dart` (live AdMob ids on release Android; sample ids in debug). 1 ad =
3 hours of ×2 gold and +25% ATK; duration stacks (max 24h) in
`metaDepth.adBoostUntilMs` (survives Ascend). Web playtest grants the same
**3 hours**. Ads never interrupt combat. SETTINGS **AD PRIVACY** withdraws AdMob
GDPR consent.

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

Unlock: prior clear **or** party **mean level** gate (even steps Lv1…Lv100).

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
- **Wipe advice** (in-dungeon panel only): POWER track tips after **2** wipes on
  the same floor (`WipeAdvice.streakNeeded`); bag / floor-too-far / early DEF /
  Shop can fire on wipe 1. Stay quiet if the sim cannot prove a deficit.

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
| Combat presence (idle/inertia/barks) | `lib/spatial/combat_presence.dart` |
| Ability runtime | `lib/spatial/ability_effects.dart` + `kit_migrated_casts.dart` (`ClassAbilityDef.fireMode` / `gate` / `customId`) |
| Tile maps | `lib/spatial/tile_map.dart` |
| Floor blueprint / placement | `lib/spatial/floor_blueprint.dart`, `placement_plan.dart`, `zone_layout_kit.dart` + `docs/FLOOR_BLUEPRINT.md` |
| Shared menus | `lib/core/menu_router.dart`, `menu_alerts.dart` · `lib/ui/shell/menu_surface.dart`, `app_bottom_bar.dart` |
| Hub | `lib/ui/hub_screen.dart` |
| Hub TODAY chase | `lib/core/hub_chase.dart` |
| Hub POWERUPS ads | `lib/core/ad_boost.dart`, `ad_rewarded.dart`, `ad_config.dart` · `lib/ui/hub/hub_powerups.dart` |
| Hub gold/min (keep AFK) | `lib/core/gold_income.dart` |
| POWER Essence rates | `lib/ui/shell/income_overlay.dart` (`CampRatesSection`) |
| Apex hub (craft / vault / target meter) | `lib/ui/apex_forge_panel.dart` (`ApexHubPanel`) — POWER → Craft |
| Chase contract (hub ↔ AFK) | `lib/core/chase_contract.dart` + `docs/CHASE_CONTRACT.md` |
| Guides copy | `lib/core/game_guides.dart` |
| Keystone | `lib/core/keystone.dart` |
| Ashen Crown | `lib/core/ashen_crown.dart` |
| Local season weeks | `lib/core/local_season.dart` |
| Play Games | `lib/core/play_games_bridge.dart`, `play_leaderboard_ids.dart` |
| Ascend unlock teasers | `lib/core/ascend_roadmap.dart` |
| Ascend / lore copy | `lib/core/story_lore.dart` |
| Dungeon shell | `lib/ui/is2_shell.dart` (~thin; HUD in `lib/ui/shell/*`) |
| Play shell | `lib/ui/shell/play_shell.dart` (one MenuSurface, pause, toast) |
| Meta panels | `lib/ui/meta/` (roster, KEY, prestige, Play Games, Welcome Back, …) |
| Stage view | `lib/ui/spatial_dungeon_view.dart` |
| Wipe advice | `lib/core/wipe_advice.dart` |
| Kenney helpers | `lib/ui/kenney_assets.dart` |
| Custom art helpers | `lib/ui/custom_assets.dart` |
| Gear budget contract | `docs/GEAR_BUDGET.md` |
| UI theme guide | `docs/UI_THEME.md` — tokens, families, action hierarchy, layout escape hatches (`MenuChrome` / `GameTheme`) |

## Conventions

- State is immutable — mutate via `copyWith` in `GameLogic`.
- No Riverpod/Provider — `ChangeNotifier` + `AnimatedBuilder`.
- `GameDirector.preview()` for tests (no SharedPreferences / no spatial timer).
- Asset paths only through `KenneyAssets` / `CustomAssets` (no raw `assets/...` in UI).
- Pixel sprites: `filterQuality: FilterQuality.none`.
- **LOADOUTS** tab is hidden; leftover save presets may still exist in JSON.
  Dungeon armor 2pc/4pc = **armor sets** (not the same).
- Gear BiS / UPGRADE: budget-honest score only — see `docs/GEAR_BUDGET.md`
  (`itemBudgetScore`; no affinity/armor/rarity/set crumbs).
- Split giant files (`game_logic`, `spatial_combat`, …) when a change needs a
  home — do not merge more into them. `is2_shell` is already thin; put new HUD
  under `lib/ui/shell/`. SpatialCombat stays the only fight sim.

## Meta (survives Ascend)

**Keeps:** essence (and rewards), relics, sanctuary tracks + prestige, pets,
God Hand **level** on `GameState.godHandLevel` (style/CD in `metaDepth`),
**Apex** vault + equipped apex, soulbound item + fragments (rescale on AL; old
saves may still have a legacy heirloom), `highestDungeonCleared`,
`lifetimeGoldEarned`, achievements/codex, settings
(mute/VFX/colorblind/text scale/dungeon zoom/haptics/keep-awake/auto-sell/**auto-disassemble**),
full `metaDepth` (Gauntlet best, Will / Gauntlet claims, daily vault / weekly
affix season, **prestige shop** purchases — Apothecary Writ / Junk Magnifier /
Away Ledger / …; Loadout Folio is delisted but old slot-count purchases stay),
unlocked specs, **`pendingHeroReveals`** (Meet … TODAY until PARTY), party slot
5, ascend streak/titles/trophies, **`ascendBlessings`**, **`adBoostUntilMs`**,
Play Games opt-in + season PBs, **`sessionTelemetryOptIn`** / log, …),
**hero levels/XP**, craft mats/pity, keystone **dial** (`hardmodeLevel`,
clamped) + challenge toggles, FARM/PUSH (`dungeonMode`), daily vault UI
(`lastDailyDate` / `dailyClaimed`). **Does not keep** wallet gold, forge gold
tracks, normal gear/stash/market/loadouts, or `highestFloorCleared`.

**Ascend Blessing** (stacks in `metaDepth.ascendBlessings`, default `0` on old saves):
each Ascend adds **+5 ATK · +20 DEF · +60 STA · +8% gold** on top of AL flats
(`+1 ATK` / `+4 DEF` / `+12 STA` / `+10% gold` per AL). Shown in
**POWER → Gold → KEEP** and Sanctuary. Constants: `GameLogic.ascendBlessing*`.
Player-facing label is **STA / Stamina** (same as gear); internal fields may
still say vitality.

**Ascend prestige:** raises AL, stacks Blessing, unlocks kits, pays essence,
and **resets the run bag** (gold, forge tracks, worn/stash drops, market,
loadouts, floors → starter gear). **Keeps** hero levels/XP, open zones
(`highestDungeonCleared`), essence, relics, pets, sanctuary, God Hand, Apex,
soulbound, settings. Sets `metaDepth.freshPrestige` so TODAY farms gear instead
of KEY until real drops land. **Clears** `bossVictories`, wipe streak/advice,
active dungeon / KEY / rift via leave-dungeon; mission board rebuilt.
**AL20 REBORN** (**POWER → Gold → KEEP**, optional): same bag wipe, AL and
Blessing unchanged, essence + 1 constellation point. Never a TODAY chase.

Dungeon unlock uses **party mean level** (and prior clears), not lifetime gold.

### Keystone (Mythic+-style)

Hub **KEY** (bottom tab after party max level / jargon unlock) sets preferred
key (`hardmodeLevel` 0–20, AL-gated). On enter, affixes lock + idle-friendly par
timer starts (AFK counts). Boss clear under par → TIMED (upgrade key, vault
score); overtime → depleted. Loot iLvl bonus is `key * 2`
(`Keystone.lootItemLevelBonus`) so higher keys are a visible gear jump. Combat
**gold** scales with the same curve as threat (`Keystone.goldMul` — e.g. KEY +10
≈ gold ×5.5) so harder keys are not a gold/hour tax. At party max level, hub
TODAY chases the next KEY until the AL key cap; then Gauntlet / GR / Rift /
Ashen Crown / Daily / Will (ALMOST cliffs stay above). **Daily vault** (UTC):
1 clear **or** timed KEY+2; claim once per day (scales with best timed key).
Affixes still rotate weekly. See `lib/core/keystone.dart`.

## God Hand

Tap steers the party briefly and deals AOE; has cooldown. Damage upgrades with essence.
Styles under **POWER → Gold → KEEP**: **BAL** / **FOCUS** (+dmg −radius) /
**WIDE** (+radius −dmg). Optional CD upgrades: `metaDepth.godHandCdLevel`. Soft
knobs — do not redesign direction without asking.

## Balance policy

Owner: **fairness first**. Live-light CI gate fails on DPS `HIGH` (±20% vs median share).
Iterate with share-fast / `--focus=` before declaring kit work done.
