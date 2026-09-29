# F-001 — Full game connectivity audit (119 steps)

**Status:** done 2026-09-27. All 119 steps passed; notes in
`docs/CONNECTIVITY_AUDIT_LOG.md`. Left open: Arms and Fury looked weak on a
small damage sample (step 47), and no fresh A56 look was taken (step 119).  
**Scale:** Epic (multi-day walkthrough + fix-as-we-go)  
**Updated:** 2026-09-27 — the 19 missing screens are folded in (was 100).  
**Goal:** Go through every player-facing surface and prove it is wired,
honest, and reaches the next surface. Not a new feature program — a
connectivity and “does it work?” pass.

**North star:** a stranger can install, fight, come back, Ascend, and
reach the five endgame hunts without dead buttons, lying copy, or soft
locks.

**How we run it (proposed):**

1. One step at a time (or a small batch of related steps).
2. Verify with the matching check (new save / progressed save / endgame
   save / targeted test / A56 look).
3. If broken → fix that step before continuing.
4. Mark the step done in `docs/CONNECTIVITY_AUDIT_LOG.md`.

**Saves used:**

| Tag | Meaning |
|-----|---------|
| NEW | Wipe / new game |
| MID | After first boss, before party Lv100 |
| END | Active party all Lv100 |
| LOGIC | `GameDirector.preview` / `flutter test` only |
| A56 | Samsung A56 live look |

Rows marked **+** are the screens added 2026-09-27.

---

## Batch A — Boot & first hour (1–11)

| # | Check | Pass when | Save |
|---|--------|-----------|------|
| 1 | Boot intro shows Cognifox then one Idle Party beat | One story beat; no long slideshow | NEW · A56 |
| 2 | Start menu → New Game → starter picker | Starter three jobs pickable | NEW · A56 |
| 3 | **+** Continue opens the existing save | Hub matches that save; not a silent new game | MID |
| 4 | Hub after New Game: TODAY + ENTER DUNGEON | Chase is grow-the-party; lead says party fights on its own | NEW |
| 5 | First tip is Tap ENTER DUNGEON only | No menu dictionary tip | NEW · LOGIC |
| 6 | ENTER DUNGEON opens Sandy floor 1 | `inDungeon`, dungeonId sandy, enemies present | NEW |
| 7 | Party walks and lands a hit without a second GOT IT | First damage within ~90s fight time | NEW · LOGIC |
| 8 | Tap-the-fight tip after enter | God Hand tip only after enter; map semantics plain in first hour | NEW |
| 9 | First floor clear → hub names Floor 2 | TODAY not still “Enter the cave” | NEW |
| 10 | Bottom bar first hour is GEAR + MORE only | No GOLD / SHOP / ESSENCE / KEY | NEW · LOGIC |
| 11 | What’s New first-hour shows only the lead bullet | No KEY / Gauntlet / REBORN recap | NEW · LOGIC |

## Batch B — First boss & chrome unlock (12–23)

| # | Check | Pass when | Save |
|---|--------|-----------|------|
| 12 | Clear Sandy boss (or mid save) | Boss victory counted; leave cave clean | NEW/MID |
| 13 | Plain chrome lifts after first boss | SHOP / scrolls can appear; KEY still hidden | MID · LOGIC |
| 14 | GOLD unlocks after first floor clear | Tracks + Market panels both open | MID |
| 15 | SHOP opens with forever SCROLLS | No fake hour packs as buyable; restore-only hours OK | MID |
| 16 | ESSENCE tab stays hidden until essence exists | No empty ESSENCE tease | MID · LOGIC |
| 17 | MORE → INFO early topics | basics / combat / party / bag; no endgame jargon | NEW · LOGIC |
| 18 | MORE → INFO after boss | Daily Vault named; no ISO week jargon | MID · LOGIC |
| 19 | MORE → SETTINGS pages open | Sound, display, bag, account each reachable | MID |
| 20 | **+** Colorblind, minimal VFX, text size, sound | Each toggle sticks after restart and changes the fight or UI | MID |
| 21 | MORE → QUESTS appears after unlock | Daily / weekly jobs claimable; rewards match copy | MID |
| 22 | Redeem code surface exists in SHOP and SETTINGS | Same code path; bad code fails softly | MID |
| 23 | **+** MORE → CREDITS | Screen opens; studio line present | MID |

## Batch C — GEAR loop (24–36)

| # | Check | Pass when | Save |
|---|--------|-----------|------|
| 24 | GEAR doll shows undertunic + worn overlays | No missing helm/hair; FilterQuality.none | NEW · A56 |
| 25 | BAG lists drops; EQUIP upgrades worn | BiS uses budget score only | MID |
| 26 | Equip from BAG updates doll immediately | Hot look matches worn slots | MID · A56 |
| 27 | Unequip / swap does not soft-lock bag | Stash count honest | MID |
| 28 | MERGE panel (when unlocked) | Merge rules match footer hint; no BiS lie in first hour | MID |
| 29 | ROSTER (when unlocked) | Specs list; locked specs not pretend-owned | MID |
| 30 | **+** Spec unlocks across Ascend | New specs appear when earned; locked ones stay locked | MID · LOGIC |
| 31 | **+** LOADOUTS tab stays hidden | Save fields may remain; no LOADOUTS destination | MID · LOGIC |
| 32 | Auto-sell / auto-disassemble settings | Distinct copy; both affect bag cleanly | MID |
| 33 | Wipe advice after party wipe | Points at GOLD tracks/listing, not legacy POWER | MID · LOGIC |
| 34 | Soulbound / Apex items (if present) | Survive Ascend when they should; copy says so | END |
| 35 | GEAR in-dungeon same as hub | Same panels | MID |
| 36 | **+** Rename party hero and pet | Name saves; filter blocks a bad name | MID |

## Batch D — Spatial combat (37–47)

| # | Check | Pass when | Save |
|---|--------|-----------|------|
| 37 | Chambers wake in order | No forever-dormant soft lock | MID · LOGIC |
| 38 | Gates / floor clear | Room clear advances; boss floor reachable | MID |
| 39 | FARM vs PUSH modes | Copy and rewards match mode; mid-run switch explained | MID |
| 40 | Party HUD kit chips | Abilities fire; not HUD-only ghosts | MID |
| 41 | God Hand steer + AOE | Steer changes path; AOE under ESSENCE → BLESSING modes | MID |
| 42 | Boss tells readable | Distinct telegraph; not same pulse for every boss | MID · A56 |
| 43 | Offline catch-up uses SpatialCombat | AFK dungeon progress matches live authority | MID · LOGIC |
| 44 | Hub AFK is gold + slow essence, not combat | No fake dungeon while on hub | MID · LOGIC |
| 45 | Party wipe → advice → re-enter | Streak/copy honest; no stuck dungeon | MID |
| 46 | **+** LEAVE mid-dungeon | Returns to hub; run is not stuck inDungeon | MID |
| 47 | DPS fairness gate still green | `class_balance_gate` / share-fast not HIGH | LOGIC |

## Batch E — World path & zones (48–57)

| # | Check | Pass when | Save |
|---|--------|-----------|------|
| 48 | PATH atlas shows lands (no scroll strip) | Markers on continents; order 0…14 | MID · A56 |
| 49 | Sandy unlocked at Lv1 | Enter works | NEW |
| 50 | Zone unlock by party mean level or prior clear | Lifetime gold does **not** unlock | MID · LOGIC |
| 51 | Goblin → King → Underworld early chain | Blurbs + enter lines distinct | MID |
| 52 | Mid zones (Dead → Hell → Crystal → Tide → Ember) | Not crystal/hell reskins of each other | MID · A56 |
| 53 | Late zones (Grove → Storm → Rime → Fen → Brass → Veil) | Distinct packs/tells; Mothveil last | END |
| 54 | Recommended zone matches TODAY / PATH CTA | Primary CTA does not strand on wrong cave | MID |
| 55 | Floor blueprint: chambers, gates, wipe advice | Matches `FLOOR_BLUEPRINT` intent | LOGIC |
| 56 | Travel to cleared floors | FARM lower floors works; PUSH forward works | MID |
| 57 | Zone clear toast / unlock next | Lore line + next zone available when earned | MID |

## Batch F — GOLD / SHOP / ESSENCE (58–69)

| # | Check | Pass when | Save |
|---|--------|-----------|------|
| 58 | GOLD → TRACKS ATK/DEF/STA | Upgrades spend gold; power felt next fight | MID |
| 59 | GOLD → MARKET listings | Buy/sell; UPGRADE chase matches affordability | MID |
| 60 | Ascend wipes gold + forge tracks | Essence/relics kept (see batch G) | MID |
| 61 | SHOP supporter / ad-free | Entitlement sticks across restart | MID |
| 62 | SHOP SCROLLS forever | Effects match description | MID |
| 63 | **+** Hub SCROLLS button | Ads / tickets open from the hub glyph; not the same as the SHOP tab | MID |
| 64 | **+** Income sheet | Gold breakdown matches what the run actually earns | MID |
| 65 | ESSENCE → CAMP (Sanctuary) tracks | Lasting buys; prices honest | MID |
| 66 | ESSENCE → BLESSING / God Hand modes | BAL / FOCUS / WIDE present; steer rules OK | MID |
| 67 | ESSENCE → RELICS (Embers) | Discover/level; survive Ascend | MID/END |
| 68 | Cinders economy | Vault / Ad Tickets / pouch sources match What’s New | MID · LOGIC |
| 69 | ESSENCE → PETS | Equip/bonus; no Beast Pen jargon | MID |

## Batch G — Ascend, Blessing, meta clocks (70–82)

| # | Check | Pass when | Save |
|---|--------|-----------|------|
| 70 | Ascend READY copy | Party stays; bag/gold/forge/floors reset named honestly | MID |
| 71 | Ascend keep list | Levels, zones, essence, relics, pets, sanctuary, God Hand, Apex, settings, specs, metaDepth | MID · LOGIC |
| 72 | Ascend reset list | Wallet gold, forge, worn/stash, market, loadouts, highestFloorCleared, freshPrestige | MID · LOGIC |
| 73 | Blessing stacks | Spend path clear; no second prestige loop | MID |
| 74 | **+** STAR NODES / constellation buys | Nodes spend and stick across Ascend | MID · LOGIC |
| 75 | **+** Prestige shop | Overlay opens; buys match prices; nothing pretends to be the main SHOP | MID |
| 76 | REBORN optional at AL20 | Never a TODAY chase | END · LOGIC |
| 77 | Daily Vault UTC claim | Payday / payday month bonus named when included | MID |
| 78 | Daily Run after first Ascend | +25e floor; not shown as first-hour job | MID · LOGIC |
| 79 | Quests Daily ≠ Vault ≠ Daily Run | Three systems stay distinct in UI | MID |
| 80 | Week goal / KEY affix week | ISO week copy only where unlocked | END |
| 81 | Welcome Back / Up next | Uses ChaseContract same title as hub TODAY | MID · LOGIC |
| 82 | **+** Offline gold banner vs Welcome Back | Hub AFK gold is not the same screen as the return “Up next” | MID · LOGIC |

## Batch H — Endgame five hunts (83–96)

| # | Check | Pass when | Save |
|---|--------|-----------|------|
| 83 | Endgame unlock at party all Lv100 | Not AL20 alone; KEY tab appears | END · LOGIC |
| 84 | Hub PATH \| ENDGAME split | ENDGAME is four hunts map, not zone 16 | END · A56 |
| 85 | KEY dial + habit | Affixes + par on TODAY; +21 stays on KEY tab | END |
| 86 | **+** KEY challenge toggles | Boss rush and no flask change the run; copy matches | END |
| 87 | Gauntlet (Crystal Spire endless) | Boss every 5; PB after F100 path | END |
| 88 | **+** Gauntlet anomaly | The extra Spire rule shows and applies | END · LOGIC |
| 89 | Ranked GR (Mothveil, timed) | Local season PB; hub chase before Farm Rift | END |
| 90 | **+** Greater Rift timer fail | Time running out fails the GR; it does not count as a clear | END · LOGIC |
| 91 | Farm Rift (Stormwake, no fail timer) | Dial on KEY; chase order after GR | END |
| 92 | Ashen Crown weekly ticket | Rotates shipped caves; not a sixth hunt | END |
| 93 | Craft Trial on MORE → CRAFT | Apex only; not hub ENDGAME | END · LOGIC |
| 94 | **+** Apex craft goals | A finished goal produces the item it names | END · LOGIC |
| 95 | TODAY ladder order after KEY +20 | Gauntlet → Ranked GR → Farm Rift → Ashen | END · LOGIC |
| 96 | Done-for-today soft rest | Vault + Daily + KEY settled → soft rest, not dump | END |

## Batch I — Chase honesty & return (97–108)

| # | Check | Pass when | Save |
|---|--------|-----------|------|
| 97 | Hub primary CTA follows chase | Endgame hunt owns primary when that is TODAY | END · LOGIC |
| 98 | ENTER stays secondary when claim/Ascend owns primary | Never trapped on one button | MID · LOGIC |
| 99 | Meet kit / EQUIP wait until after first boss | First hour stays on cave | NEW · LOGIC |
| 100 | Fresh prestige → Rebuild your bag | Skips KEY/Gauntlet until gear lands | MID |
| 101 | Level the party to 100 chase | Before endgame unlock; under Daily unless ALMOST | MID |
| 102 | **+** Codex (Will) | A discovered enemy or item shows up; TODAY CODEX CTA opens it | MID |
| 103 | **+** Achievements | Overlay lists real feats; a met feat can be seen as done | MID · LOGIC |
| 104 | Local reminders opt-in | Off in first hour; honest later | NEW/MID |
| 105 | Play rating ask | Never on brand-new save; copy says no reward | NEW · LOGIC |
| 106 | Funnel analytics stamps | first_open → app_ready → first_enter → time_to_combat → … | NEW · LOGIC |
| 107 | In-app update gate / GET UPDATE | Matches Play Store docs; no GitHub Releases push | MID |
| 108 | English UI throughout checked surfaces | No Swedish leak in player copy | ALL |

## Batch J — Ship bar, legal, distribution (109–119)

| # | Check | Pass when | Save |
|---|--------|-----------|------|
| 109 | `flutter analyze lib test --no-fatal-infos` | Clean (infos policy OK) | LOGIC |
| 110 | `flutter test` excluding sim | Green | LOGIC |
| 111 | `ship_smoke` + `first_hour_plain` | Green | LOGIC |
| 112 | `changelog_sync` / version match | pubspec = ChangelogCatalog | LOGIC |
| 113 | Art only `assets/custom/` via helpers | No foreign dumps | LOGIC |
| 114 | Portrait Android only | No iOS / Apple paths introduced | LOGIC |
| 115 | Play package `com.idleparty.app` | Listing docs match live app | LOGIC |
| 116 | Save export/import round-trip | Progress survives | MID · LOGIC |
| 117 | **+** Play Games sign-in + cloud backup/restore | Backup and restore round-trip; a failed sign-in does not wipe the local save | MID |
| 118 | Ascend then cold restart | Kept fields intact; wiped fields gone | MID |
| 119 | Final owner smoke on A56 | New save to first hit + one MID claim + END KEY peek | NEW/MID/END · A56 |

---

## Still out (own pass if you name it)

- One step per kit for all 10 classes / 31 specs
- Discord thanks toast
- “Does the music sound good”
- New zone / class / hunt / gacha / second fight sim
- Google Play AAB upload
- iOS / Apple
- Rewriting What’s New for acquisition (Oct 18 Reddit is separate)
- Restoring a standing “Program N” beyond this audit

## Risks

| Risk | Mitigation |
|------|------------|
| 119 steps stall forever | Batches of ~10; fix-as-we-go; skip cosmetic Light if you say so |
| Endgame needs a real END save | Use preview helpers / seeded endgame save; don’t wipe your A56 save for shots |
| Play Games restore can overwrite a save | Step 117 uses a preview save, not the owner’s phone save |
| Scope creep into new features | Each step is verify/fix connectivity only |
| Balance grind hijacks the audit | Gate tests only when a kit step fails HIGH |

## Complexity

**Very High** as a full pass — but each step is small. Expected calendar: several sessions, not one evening.

## Approval gate

Owner says go (and optionally: fix-as-we-go yes/no, phone vs agent-first).  
Then Builder runs Batch A from step 1.
