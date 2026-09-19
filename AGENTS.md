# AGENTS.md

Idle Party is a **working Flutter idle RPG** with original Dart gameplay code
and **owned** pixel art (`assets/custom/`).

**Ship version:** keep `pubspec.yaml` versionName and `MetaSystems.currentVersion`
in sync (currently **1.12.173**). What’s New lives in `lib/core/meta_systems.dart`.

## Human (vibe-coder)

Owner describes goals in plain language; agents pick skills/tools/verify alone.
**Rules (don’t duplicate here):**
- `.cursor/rules/growth-mandate.mdc` + `docs/GROWTH_MANDATE.md` — standing Play-growth principles; no numbered programs. Owner names work. Do not restore AL20 as the batch.
- `.cursor/rules/studio-seats.mdc` — six chairs (EP, Game, UX, Tech, Art, Marketing)
- `.cursor/rules/product-locks.mdc` — hard locks only
- `.cursor/rules/owner-preferences.mdc` — work loop; push when green; **never Play upload without ask**
- `.cursor/rules/vibe-coder-autopilot.mdc` — skill map + plain Swedish handoff
- `.cursor/rules/definition-of-done.mdc` — analyze / tests / commit locally

Cadence: `docs/CONTENT_CADENCE.md` (tag rhythm). **Default work** when
vague: ask once what to do. Chat Swedish; if they should look at the phone,
emu already running **this batch**, then short test list (new save first) →
wait. Commit locally when green; push / PR / tag when needed. **Ask before
Google Play AAB.**

**UI target:** portrait phones (~360–430 px). Reference **Samsung A56**
(1080×2340 → **360×780**). Live look: AVD `Samsung_A56` + `flutter run`
(`a56-playtest`). Web = Playwright / `WebClickBridge` fallback only (forced
360×780). Tap / long-press — no hover-only player flows.

**Distribution today:** **Google Play is the primary install path**
(`docs/PLAY_STORE.md`). Package id `com.idleparty.app`. Store listing:
`https://play.google.com/store/apps/details?id=com.idleparty.app` (production
live as of owner **2026-09-13**; store **1.12.171 / 201**; Production **1.12.172 / 202** submitted **2026-09-17**). Closed opt-in remains for early builds.
Do **not** link players to GitHub Releases (repo may be private). Working ship
in-repo may be ahead of Play — **never upload a new AAB without owner ask**.

Closed opt-in: `https://play.google.com/apps/testing/com.idleparty.app`

**Play update notice** (Android, Play-installed only): **mandatory cold-start gate** when Play has a newer versionCode (no play until updated); hub banner + SETTINGS **GET UPDATE** with LATER for optional nudge. Sideload / web stay quiet. Listing opens with `hl=en`.

**Play rating ask** (after first boss or Ascend, hub only, once): honest card + MORE → SETTINGS **RATE ON PLAY**. Google in-app review when Play allows it, else listing. **No loot / tickets.** Never covers a READY hunt or other hub cards the same visit. `metaDepth.reviewPrompted` survives Ascend.

**Optional Play Games** (Android): seasonal Timed KEY + Gauntlet boards under
**KEY** (bottom tab when jargon unlocks); sign-in + cloud save under
**MORE → SETTINGS**. Opt-in; clipboard export/import still works. IDs in
`lib/core/play_leaderboard_ids.dart`. Soft-fail on web / sideload.

**Optional Firebase Analytics** (Android): soft events via `AppAnalytics`
(`lib/core/app_analytics.dart`) when `android/app/google-services.json` is
present. UMP consent gates collection (same AD PRIVACY path as AdMob). Play
funnel: `first_open` (Firebase auto + local stamp) → `app_ready` →
`first_enter` (+ `time_to_combat` seconds) → `first_reward` → `first_boss` →
`d1_return`. Optional later: `notify_opt_in` / `notify_opt_out` (card or SETTINGS).
See `docs/PRIVACY.md` + setup in `docs/PLAY_STORE.md`.

## Legal / IP policy (mandatory)

- **Do not** add, keep, or commit APKs, IPA/AAB, SWF, DEX, or dumps from other commercial games.
- **Do not** copy sprites, audio, code, or text from other games into this repo.
- Shipped art must come from `assets/custom/` (owned Idle Party art).
- Gameplay may follow common idle-RPG *ideas*; implement as original Dart — never paste
  or translate decompiled sources.
- If a third-party binary appears locally, delete it and ensure `.gitignore` covers it.

## Character visuals (dungeon)

Layered Canvas heroes: `lib/visual/` + `docs/CHARACTER_VISUALS.md`.
Dungeon, GEAR, and party HUD share `paintOwnedHero` (undertunic body +
equipped 128×128 overlays, including common gear). Missing bodies use class
PNGs — Kenney 16×16 tiles are not bundled. Items share looks via
`visualSetId`. Four bodies serve 31 specs, so each spec washes its own color
through generated **cloth-only** `body_tint_<anim>` masks
(`HeroIdentity.ownedBodyTintArgb`); skin/hair and authored gear keep their
palette. One body clip per anim — walk bob, weapon swing and hit recoil come from
`CharacterVisualPainter.ownedStepOffset`, not new PNGs. Hand items grip
opaque pixels (`OwnedGearGrips`, generated). Looks gate:
`py tool/check_paper_doll_facit.py` (idle facit + t2/material + grips +
`tool/paper_doll_lock.json` art hashes; `--relock` after deliberate art
changes). Enemies are a separate art pass.

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
`character-paper-doll`, `flutter-verify`, `a56-playtest`, `browser-playtest`, `hub-smoke`, `play-store-prep`, `init`,
`repo-audit-and-cleaning`) and
Cursor workflows (`suggesting-skills`, `building-skills-from-patterns`,
`grinding-until-pass`, `babysitting-pr`, `parallel-ci-triage`,
`verifying-in-browser`, `screenshotting-changelog`, `recording-browser-flow-as-test`,
`systematic-debugging`, `reviewing-code`, `accessibility-auditing`).
Slash: `/init` resyncs AGENTS/rules; `/repo auditandcleaning` runs a read-only
full-repo audit (see `.cursor/commands/repo-auditandcleaning.md`).

Cadence: **`docs/CONTENT_CADENCE.md`** (tag rhythm). No standing program —
owner names work. Not AL20-as-batch. Why:
[`docs/LEARNINGS.md`](docs/LEARNINGS.md). Archived polish/audits:
[`docs/archive/`](docs/archive/). Background (optional):
`docs/archive/TOP_GAMES_RESEARCH.md`. Chase contract (hub TODAY ↔ offline Up next):
`docs/CHASE_CONTRACT.md`. Gear budget: `docs/GEAR_BUDGET.md`. Floor blueprint
(shipped): `docs/FLOOR_BLUEPRINT.md`. Play listing: `docs/PLAY_STORE.md` +
skill `play-store-prep` (in mandate, not background). Growth / ASO / reviews /
tiny ads: `docs/PLAY_GROWTH.md` + listing copy in `docs/STORE_LISTING.md`.

### Cursor automation

- Project hooks: `.cursor/hooks.json` — **sessionStart** injects growth-mandate context;
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
 ├─ loading (Cognifox) → boot intro (studio card; first-launch cave beat) → startMenu → optional newGamePicker → play
 ├─ PlayShell (one MenuSurface + toast; hub vs dungeon scenes)
 │   ├─ Hub (!inDungeon) → HubScreen + FirstSessionTips
 │   └─ Dungeon (inDungeon) → Is2Shell
 │        ├─ SpatialDungeonView (camera follow, God Hand, farm/push)
 │        └─ chrome (FARM/PUSH, God Hand, party HUD + flask, target panel)
 │           + AppBottomBar GEAR / GOLD / SHOP / ESSENCE / MORE
 │             (first hour: GEAR + MORE until unlock; hub endgame: + KEY after MORE;
 │              dungeon: + LEAVE)

Shared menus: MenuRouter + GearSession + NavIntent + MenuAlerts + MenuSurface
  (flat tabs; one shared bar always visible under sheets; dungeon LEAVE = hub)
  GOLD = FORGE (this-run gold) + MARKET · SHOP = forever SCROLLS + ad-free / supporter
  (Play Billing on Play installs; timed hour packs exist as SKUs for restore only, not listed)
  · SHOP **REDEEM CODE** + MORE → SETTINGS **REDEEM CODE** (`CouponCodes`)
  · ESSENCE = CAMP + BLESSING (God Hand / STAR NODES / lasting buys) + relics + pets
  MORE rows = QUESTS (after first floor) / Craft (after first boss; monthly Craft Trial at Lv100)
  MORE → SETTINGS ACCOUNT = Play Games / AD PRIVACY / away reminders (after first loot) / redeem
  MORE → INFO uses `GameGuides.topicsFor` (first hour / mid-game / endgame)
  (Blessing / God Hand / REBORN / STAR NODES under ESSENCE → BLESSING)
  Hub POWERUPS rewarded ads stay on the hub (not under SHOP)
```

**SpatialCombat is the combat authority** for live play and in-dungeon offline
catch-up (full enemy stats; same kits/abilities/chambers). Offline / AFK
catch-up uses `afkAssist: true` inside the same `build`/`step` API — enemy
hits are softer and hero hits harder so long catch-up stays snappy. Hub AFK
(`!inDungeon`) is sanctuary idle **gold** plus **slow essence** (`GoldIncome.essenceDue`) — no combat.
**PUSH** floor clear **+1 essence**, boss **+2** (`GameLogic.pushClearEssence`); FARM and Gauntlet pay **0**. Healers open each floor
with mana; **Spirit** refills mana over time (not a damage stat). Warrior /
Paladin / Shaman can equip **shields** in the off-hand.

**Content inventory:** 10 classes / **31 specs** (`HeroSpecId`) · **15 zones**
through Mothveil Hollow.

**Infinity Gauntlet** (`GameLogic.endgameUnlocked` = active party all at
`maxHeroLevel` **100**): endless Crystal
Spire climb from Hub; **boss every 5 floors** (tells cycle shipped-cave jobs —
not the same SHARD forever); **non-boss F3/F8/F13…** (not treasure) can squeeze, swarm,
echo a tell, or add extra gates (same SpatialCombat); wipe/leave → hub;
`metaDepth.gauntletBestFloor` survives Ascend.

**KEYSTONE** (same party-max-level gate): Mythic+-style keys on
normal zone runs — dial under hub **KEY**. Before party max level there is no KEY habit or KEY tab.

**Rifts** (same gate): Diablo 3 Nephalem-style farm in **Stormwake Hollow**
from hub / **KEY** — kills fill a progress bar → **Rift Guardian**; no clear-timer
fail; gold and gear mid-run; not Play-ranked; not Spire climb. Endless after R20
(progress target holds; threat keeps climbing). `metaDepth.riftBestTier` survives Ascend.

**Greater Rifts** (same gate): Diablo 3 Greater-style timed ladder in
**Mothveil Hollow** — same progress bar → Guardian under [parTimeMs]; no mid-run
gear (gold OK; chests skip equipment), larger clear payout;
season PB is **local** on hub and submits to Play Games when the month’s
`PlayLeaderboardIds.greaterRift` ID is wired (2026-09 `CgkIhuXGvNocEAIQAw`).
After GR20 the progress target holds; the clock stays at the 90s cap
and threat climbs slower so the ladder stays winnable.
`metaDepth.grBestTier` / `seasonBestGrTier` survive Ascend.

**Ashen Crown** (same gate): weekly ticket solo boss; each ISO week visits a
**different shipped cave** (ember staging / art; not dungeon #16); wipe/leave
returns the ticket; PRACTICE free after the paid clear. Tickets /
`worldBoss*` fields in `metaDepth`; see `lib/core/ashen_crown.dart`.

**Craft Trial** (same party-Lv100 gate; **not** a hub ENDGAME hunt / TODAY
chase): **MORE → CRAFT** `START CRAFT TRIAL` once per ISO month on the
recommended PATH cave. Combat sheet uses **Apex-crafted gear only** (bag
untouched). Boss clear → hub, **+20 essence** + **1 constellation point**;
`metaDepth.apexTrialCleared` / `apexTrialMonthKey` survive Ascend. See
`GameLogic.startApexTrial`.

**Ascension cap:** `GameLogic.maxAscensionLevel` = **AL20** — Ascend stops here
(Blessing / kit roadmap). **Endgame content** (endless KEY / Ranked GR, Gauntlet, Rifts, Ashen, Craft Trial) unlocks when the **active party is all Lv100**, not at AL20 alone.
**Hero level cap:** `GameLogic.maxHeroLevel` = **100**; combat XP only (no gold
Train +1 level). Gold tracks (ATK/DEF/STA/MOVE/HASTE/CRIT/MASTERY) still buyable (wipe on
Ascend).

**Zone unlock:** party **mean level** (even steps 1…100 across 15 zones) **or**
prior zone clear. Zone 0 (Sandy) from Lv1. Lifetime gold no longer unlocks zones.

**QUESTS** (MORE row; was bottom-tab JOBS/contracts): **5-slot** board —
**Daily** (UTC kill), **Bounty** (ladder; endgame 100…25k), **Side** (non-kill),
**Week** (ISO-week goal), **Contract** (big goal; endgame KEY / Gauntlet /
Rift / Ranked GR / Ashen). Claim via the hub hunt **CLAIM QUESTS** or MORE · QUESTS.

**Hub hunt** (code: TODAY / `HubChase.forState`) — every surface reads the same
words via **`ChaseContract`** (`lib/core/chase_contract.dart` + hub / offline Up
next). Player-facing stamp is **READY / ALMOST** + the job, not the word TODAY. One chase card — claimables first (vault / quests / **Meet new kit** /
**equip BAG** / **Shop upgrade**), then Ascend / progress. Urgency **READY** /
**ALMOST** (zone/Will/Gauntlet/Ascend-near beat Daily grind; also KEY +1 vault,
etc.). Local-season **week goal** can surface as a chase. **First hour** (no
boss, no Ascend): grow the party in the starter zone — skip Daily /
vault-start / kit teasers until after the first boss
(`GameLogic.showDailyChase`). **Day 2–7 job:** one cave today (Daily Vault
fill → CLAIM). Daily Run waits until first Ascend (`showDailyRunOnHub`). First-session overlay is **≤2 beats** before the
first reward (`first_run` + tap-the-fight); GOLD / MARKET / ESSENCE / pets tips
wait. **KEY habit** (`ENTER KEY +N`), KEY tab,
week-affix jargon, and KEYSTONE tips wait until the **active party is all
Lv100** (`GameLogic.showKeystoneJargon` → `endgameUnlocked`). At endgame,
the hub grows a **PATH | ENDGAME** switch: PATH is a **fitted continent atlas**
(`CustomAssets.worldPathMap`, `ZonePathMap.markerNorm` by land — dunes / crown /
frost / tide / blight / ash / grove / storm / brass / veil — **no scroll strip**);
**ENDGAME** is its own board (`HubEndgameHunt`: Gauntlet, Ranked GR, Farm Rift, Ashen Crown)
on the same PNG darkened — not a footer under Mothveil, not dungeon #16. Craft Trial stays under MORE → CRAFT.
Tap a hunt then ENTER — Farm Rift and Ranked GR pick any R/GR with arrows. KEY
holds the KEY dial. Hub KEY / Vault / Week crumbs stay off while that
hunt is KEY, Gauntlet, Ranked GR, Farm Rift, or Ashen.
TODAY prefers KEY then Gauntlet → Greater Rift → Rift → Ashen Crown before
Daily grind; Meet-kit backlog stays on PARTY badge. New unlocks queue
`metaDepth.pendingHeroReveals` until PARTY opens. Ascend confirm/toast + chase
detail use **`AscendRoadmap`** (`lib/core/ascend_roadmap.dart`) for next AL
unlocks — kit ladder AL1–6 (e.g. Combat Rogue / Arms / Holy Paladin,
BM/Holy/Arcane + 5th slot, DKs, Aff/Demo) plus AL20 party-level gate copy.
Spec look: `HeroIdentity` (tint + Shadow→warlock sprite).

New Game picker: choose **3 unique specs** from the starter pool. Role copy is
**Shield / Healer / Damage** (easy start = one of each), not three fixed buttons.
Advanced menu tabs (ROSTER, KEY, BEAST, CODEX, …) gate via
`MenuTabs` so day-one chrome stays small. ESSENCE is a bottom tab; tracks
unlock after Ascend / first essence. **LOADOUTS** tab is hidden/removed
(save fields may remain). PARTY badges mean bag upgrades (`MenuAlerts`).

Offline return uses `OfflineProgressResult` (wow headline + ≤3 highlights +
“Up next” = ChaseContract title only — no chase-detail dump).

Live look: `a56-playtest` (Samsung A56 emulator). Web fallback:
`WebClickBridge` + Semantics (`browser-playtest`).

**Hub SCROLLS** (optional rewarded ads, Android): `AdBoost` + `AdRewarded` +
`ad_config.dart` (live AdMob ids on release Android; sample ids in debug). 1 ad =
**1 Ad Ticket**; spend tickets on Scroll of Damage (+40% ATK 2h), Scroll of Gold (×2 gold
2h), Scroll of XP (+50% party XP 2h), Scroll of Speed (+30% walk 2h), Scroll of Loot (+40% item find 2h),
Scroll of Haste (+25% dungeon speed 2h),
Scroll of Battle (ATK+gold 4h / 2 tickets), or Scroll of Rest (next offline gold ×3). Timers stack
per buff (max 24h) on `metaDepth.adAtkUntilMs` / `adGoldUntilMs` / `adXpUntilMs` /
`adMoveUntilMs` / `adLootUntilMs` / `adSpeedUntilMs`; tickets on
`adTickets` (survives Ascend). Camera overlay on the hub map opens the sheet.
Web playtest grants a ticket. Ads never interrupt combat. SETTINGS **AD PRIVACY**
withdraws AdMob GDPR consent. See `docs/AD_POWERUPS_DESIGN.md`.
SHOP **forever SCROLLS** (`shopPermScrolls`) skip the ticket spend; timed hour
packs are **not listed** (`ShopCatalog.timePacks` restore-only). Coupon
`CouponCodes.foreverScrolls` (`FOREVERSCROLLS`) grants `AdBoost.permAll` once
(`redeemedCoupons`). Redeem **after** the dialog pops (`useRootNavigator`).

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
Hub PATH markers sit on lands, not a top→bottom road (catalog order is still 0…14).

## Floor / chamber model

- One **combat wave per floor**; boss on floor `5 + ascensionLevel`.
- Pack size + map pressure: `DungeonGenerator.layoutPressure` from **AL** and
  **KEY** (Rift/GR tier as KEY; Gauntlet AL only). Caps so endless keys stay sane.
- Generation: **FloorBlueprint** (room beats) → **PlacementPlan** (props +
  chest sockets) → `RoomLayouts` / `SpatialCombat.build`, with per-zone
  **`ZoneLayoutKit`** (e.g. Brassvault treasure alcoves vs Mothveil silk chokes).
- Chamber **footprints** are ovals / L / plus / blobs, not only rectangles
  (`_carveRoomFootprint` in `tile_map.dart`). Chamber AABB still used for wake.
- Maps are **multi-chamber** with corridor **gates** after a chamber clears.
  Main path zigzags; treasure vaults branch off the stairs. High trash budgets
  carve **up to five** fight rooms after staging (was three at 6+ trash).
- Enemies in later chambers start **dormant**; wake when prior chambers clear
  (and can wake on **proximity** so soft-locks are rare).
- **Room chests** on elite/treasure beats drop gold/gear pickups — vacuumed
  with kill loot when the floor clears (same bank path).
- After all enemies die, ground loot is vacuumed immediately and the party
  walks to **stairs/exit** → `completeCurrentRoom`.
- **Wipe advice** (in-dungeon panel only): GOLD ATK/STA after **2** wipes on
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
| Rules | `lib/core/game_logic.dart` (+ parts `game_logic_ascend` / `_endgame` / `_ladders` / `_meta_season`) |
| State | `lib/core/game_state.dart` |
| Changelog / meta helpers | `lib/core/meta_systems.dart` |
| Meta blob | `lib/models/meta_depth.dart` |
| Dungeon catalog | `lib/models/dungeon_def.dart` |
| Combat sheet | `lib/models/combat_ratings.dart` + `docs/GEAR_BUDGET.md` |
| Spatial sim | `lib/spatial/spatial_combat.dart` |
| Zone packs / boss tells | `lib/core/enemy_flavor.dart` + `lib/spatial/enemy_specials.dart` |
| Combat presence (idle/inertia/barks) | `lib/spatial/combat_presence.dart` |
| Ability runtime | `lib/spatial/ability_effects.dart` + `kit_migrated_casts.dart` (`ClassAbilityDef.fireMode` / `gate` / `customId`) |
| Tile maps | `lib/spatial/tile_map.dart` |
| Floor blueprint / placement | `lib/spatial/floor_blueprint.dart`, `placement_plan.dart`, `zone_layout_kit.dart` + `docs/FLOOR_BLUEPRINT.md` |
| Shared menus | `lib/core/menu_router.dart`, `menu_alerts.dart` · `lib/ui/shell/menu_surface.dart`, `app_bottom_bar.dart` |
| Hub | `lib/ui/hub_screen.dart` |
| Hub TODAY chase | `lib/core/hub_chase.dart` |
| Hub POWERUPS ads | `lib/core/ad_boost.dart`, `ad_rewarded.dart`, `ad_config.dart` · `lib/ui/hub/hub_powerups.dart` |
| Away reminders | `lib/core/local_reminders.dart` + `local_notify.dart` · SETTINGS ACCOUNT + hub card |
| Real-money SHOP catalog | `lib/core/shop_catalog.dart` · `lib/ui/shell/shop_dock.dart` · `docs/SHOP_MONETIZATION.md` |
| Coupons | `lib/core/coupon_codes.dart` · `lib/ui/redeem_coupon_dialog.dart` (SHOP + SETTINGS) |
| Hub PATH / ENDGAME maps | `lib/ui/hub/hub_world_map.dart`, `hub_endgame_map.dart` |
| Hub gold/min (keep AFK) | `lib/core/gold_income.dart` |
| POWER Essence rates | `lib/ui/shell/income_overlay.dart` (`CampRatesSection`) |
| Apex hub (craft / vault / farm meter / Craft Trial) | `lib/ui/apex_forge_panel.dart` (`ApexHubPanel`) — MORE → CRAFT |
| Blessing STAR NODES | `lib/core/blessing_constellation.dart` · **ESSENCE → BLESSING** |
| God Hand mastery claims | `lib/core/god_hand_mastery.dart` · **ESSENCE → BLESSING** |
| Hub ENDGAME map | `lib/core/hub_endgame_act.dart` |
| Chase contract (hub ↔ AFK) | `lib/core/chase_contract.dart` + `docs/CHASE_CONTRACT.md` |
| Guides copy | `lib/core/game_guides.dart` |
| Keystone | `lib/core/keystone.dart` |
| Farm / Ranked GR pacing | `lib/core/rift.dart`, `greater_rift.dart`, `rift_pacing.dart` |
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
| Kenney helpers | `lib/assets/kenney_assets.dart` |
| Custom art helpers | `lib/assets/custom_assets.dart` |
| Gear budget contract | `docs/GEAR_BUDGET.md` |
| UI theme | `lib/ui/theme.dart` + `docs/UI_THEME.md` — `GameTheme` tokens, `MenuChrome`, `GameButton`, `GameIcon` |
| Game UX / placement | `.cursor/rules/game-ux-director.mdc` — placement map (pairs with `ui-theme.mdc`; flat nav / hide-until / ≤90 s are guidance, not hard locks) |

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
full `metaDepth` (Gauntlet / Rift / GR bests, Will / Gauntlet claims, daily vault / weekly
affix season, **constellation** nodes/points, **Craft Trial** month/cleared,
**God Hand mastery** claims / smash count, **prestige shop** purchases — Apothecary Writ / Junk Magnifier /
Away Ledger / …; Loadout Folio is delisted but old slot-count purchases stay;
Play funnel `funnelInstallMs` / `funnelLogged`,
**local reminders** `notifyOptIn` / `notifyPrompted` / `notifyPingMs`,
**Play rating** `reviewPrompted`),
unlocked specs, **`pendingHeroReveals`** (Meet … TODAY until PARTY), party slot
5, ascend streak/titles/trophies, **`ascendBlessings`**, **`adTickets`** /
**`adAtkUntilMs`** / **`adGoldUntilMs`**, SHOP **`shopPermScrolls`** / **`adFree`** /
**`shopBagBonusSlots`** / **`redeemedCoupons`**,
Play Games opt-in + season PBs, **`sessionTelemetryOptIn`** / log,
**away reminders** (SETTINGS ACCOUNT; card after first loot), …),
**hero levels/XP**, craft mats/pity, keystone **dial** (`hardmodeLevel`,
clamped) + challenge toggles, FARM/PUSH (`dungeonMode`), daily vault UI
(`lastDailyDate` / `dailyClaimed`). **Does not keep** wallet gold, forge gold
tracks, normal gear/stash/market/loadouts, or `highestFloorCleared`.

**Ascend Blessing** (stacks in `metaDepth.ascendBlessings`, default `0` on old saves):
each Ascend adds **+5 ATK · +20 DEF · +60 STA · +8% gold** on top of AL flats
(`+1 ATK` / `+4 DEF` / `+12 STA` / `+10% gold` per AL). Shown in
**ESSENCE → BLESSING** and Sanctuary. Constants: `GameLogic.ascendBlessing*`.
Player-facing label is **STA / Stamina** (same as gear); internal fields may
still say vitality.

**Ascend prestige:** raises AL, stacks Blessing, unlocks kits, pays essence,
and **resets the run bag** (gold, forge tracks, worn/stash drops, market,
loadouts, floors → starter gear). **Keeps** hero levels/XP, open zones
(`highestDungeonCleared`), essence, relics, pets, sanctuary, God Hand, Apex,
soulbound, settings. Sets `metaDepth.freshPrestige` so TODAY farms gear instead
of KEY until real drops land. **Clears** `bossVictories`, wipe streak/advice,
active dungeon / KEY / rift via leave-dungeon; mission board rebuilt.
**AL20 STAR NODES** (`BlessingConstellation`, KEEP): not Ascend Blessing stacks.
AL20 grants **3** starter points; Ashen Crown, Craft Trial, and REBORN each add
**+1**. Spend on ≤6 nodes (Offense / Defense / Fortune). Never a TODAY chase.
**AL20 REBORN** (**ESSENCE → BLESSING**, optional): same bag wipe, AL and
Blessing unchanged, essence + 1 constellation point. Never a TODAY chase.

Dungeon unlock uses **party mean level** (and prior clears), not lifetime gold.

### Keystone (Mythic+-style)

Hub **KEY** (bottom tab after party max level / jargon unlock) sets preferred
key (`hardmodeLevel` 0…endless, party-max gated). On enter, affixes lock + idle-friendly par
timer starts (AFK counts). Boss clear under par → TIMED (upgrade key, vault
score); overtime → depleted. Loot iLvl bonus is `key * 2`
(`Keystone.lootItemLevelBonus`) so higher keys are a visible gear jump. Combat
**gold** scales with the same curve as threat (`Keystone.goldMul` — e.g. KEY +10
≈ gold ×5.5) so harder keys are not a gold/hour tax. At party max level, hub
TODAY chases the next KEY until +20; then Gauntlet / GR / Rift /
Ashen Crown / Daily / Will (ALMOST cliffs stay above). KEY +21 stays on the KEY tab. Ranked GR past 20 shows the next rank on hub ENDGAME (no KEY dial) so weekly Ashen is not buried on TODAY. **Daily vault** (UTC):
1 clear **or** timed KEY+2; claim once per day (scales with best timed key).
Affixes still rotate weekly. This week’s KEY also borrows another shipped
cave’s pack jobs and boss tell (PATH art stays). See `lib/core/keystone.dart`.

## God Hand

Tap steers the party briefly and deals AOE; has cooldown. Damage upgrades with essence.
Styles under **ESSENCE → BLESSING**: **BAL** / **FOCUS** (+dmg −radius) /
**WIDE** (+radius −dmg). Optional CD upgrades: `metaDepth.godHandCdLevel`.
KEEP also lists **God Hand mastery** claims (`GodHandMastery` — titles + essence).
Direction changes only when the owner’s goal names them.

## Balance policy

Owner: **fairness first**. Live-light CI gate fails on DPS `HIGH` (±20% vs median share).
Iterate with share-fast / `--focus=` before declaring kit work done.
