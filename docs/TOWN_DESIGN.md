# Idle Party Town

**Branch:** `cursor/town-life-617a` (town life pass, off merged main)  
**Updated:** 2026-11-08  
**Phone:** Samsung A56 360×780, English UI, `FilterQuality.none`

When the party is **not in a dungeon**, they rest in a town between
climbs. The town is a place: Guild Hall and Vault on the back row,
FORGE / MARKET / INN on the square, a yard between them, heroes in
front, one ENTER.

Live home layout: `HomeShell` → `TownViewport`. `TownPreview` is the
isolated harness. In the cave, FORGE / CAMP / MARKET stay under the fight.

---

## Implemented now (this slice)

| Building | Opens | Unlock | Locked tap |
|----------|--------|--------|------------|
| **FORGE** | MORE → **CRAFT** (`ApexHubPanel`) | First boss (`MenuTabs.showCraft`) | "CRAFT opens after the first boss." |
| **MARKET** | GOLD → **MARKET** listings | First boss (`MenuTabs.showGold`) | "MARKET opens after the first boss." |
| **INN** | GEAR → **ROSTER** (`TeamCompositionOverlay`) | First Ascend or a pending spec | Honest gap: starter three cannot swap until then |
| **GUILD** | MORE → **QUESTS** (`JobsOverlay`) | First floor / claim waiting | "QUESTS open after the first floor." |
| **VAULT** | `director.claimDailyVault()` when ready | Season after first boss | Progress copy, or "claimed today" |

FORGE is the Apex craft/upgrade station, **not** GOLD run-power tracks
(those stay labeled FORGE under the fight). MARKET is `MarketOverlay`
listings. INN is party composition, not the GEAR tab.

No new currency, save field, energy, chore timer, or ad gate. Offline
gold, auto combat, SHOP, and WISP-in-the-cave are untouched.

```
HomeShell  →  TownViewport     (live, out of the cave)
TownPreview → TownViewport     (harness)
Fight      → FightViewport + HomeGoldDock (FORGE tracks / CAMP / MARKET)
```

Out-of-dungeon `HomeGoldDock` is gone. Town buildings own FORGE and MARKET.
CAMP stays on ESSENCE. GOLD opened from town is a real `GoldDock` overlay
(listings). In the cave, GOLD still intercepts to the fight dock.

---

## WISP / POUCH / SCROLLS / WATCH

| Shortcut | True job | Live `HomeCatalog` | Town policy |
|----------|----------|--------------------|-------------|
| **SCROLLS** | Tickets, daily Well, spend buffs, WISP status, optional WATCH | Rail + MENU | **Keep. This is the home.** |
| **WATCH** | Watch an ad for a ticket | Duplicate of SCROLLS | Drop as a hub chip. Action stays inside SCROLLS. |
| **WISP** | In-cave lantern for gold | Duplicate of SCROLLS | Drop as a hub chip. Lantern stays in the dungeon. |
| **POUCH** | One-time reinstall gold | Shown only when due | **Keep while due.** |

`HomeCatalog.entries` still defines WATCH / WISP. `HomeCatalog.of`
applies `TownNavPolicy`, so rails and MENU drop those chips. SCROLLS
opens `openPowerupsSheet` (WATCH AD lives there). POUCH stays while due.

---

## Domain gap (INN)

Party composition is `TeamCompositionOverlay` on the ROSTER tab. That
tab exists at **first Ascend** (or when a new spec is waiting). A new
game has three fixed starters and **no swap command**. Town does not
open GEAR and call that composition. Locked INN tells the player the
real gate.

---

## Cosmetic growth (no save field)

Painted facades: `TownTier.fromAscension` → 0 timber, 1 stone (AL1),
2 banners (AL5). AL1 is the first prestige, the town "settles." AL5 is
when blessing/camp already feel lived-in; a third paint pass still
reads on a 118px facade. AL10 pennants and AL20 lantern arcade are
overlays on the same sprites — extra full buildings would be the same
silhouettes with more flags.

Progress line under the square names the next milestone.

---

## Ranked leftovers (not built)

Do not add currencies or prices until Robert picks a row.

| Rank | Building | Why not this slice |
|------|----------|--------------------|
| 3 | **SHRINE** | God Hand already lives under ESSENCE → BLESSING. A building would alias that tab. |
| 4 | **TAVERN** | Would duplicate SCROLLS / optional ads. |
| 5 | **PET YARD** | Pets already have ESSENCE → PETS. |

**Not proposed:** town energy, build timers, a town-only gold sink,
paid façade SKUs, NPC chatter trees, a sixth currency.

---

## Art

Source: `tool/generate_town_art.py`. License: owned, same as
`assets/custom/`. No paid packs. Deterministic (no RNG).
`FilterQuality.none`.

The first daylight pass was too flat (checker grass, stick villagers,
hatched awnings). The stone-and-tile buildings stay. This pass replaces
the lawn and the people: a quiet meadow, one ragged stepping-stone
course, four different plantings, and villagers painted at hero source
size. Warm ink `(32, 22, 18)` and upper-left light still match the
heroes. Dungeon art is unchanged.

Guild is a pale stone hall. Forge, Market, and Inn keep their jobs
(chimney and anvil, stall, jetty). Name chips paint last, on the
facades. Hit boxes do not overlap.

Three painted tiers per facade (timber / plaster / banners). AL10
pennants and AL20 lanterns stay Flutter overlays, drawn as pixel blocks.

Townsfolk live on `folk.png` (3 people × idle + 4 walk frames, 96×112
cells). `TownFolkLayer` nearest-neighbors them to 48×56, beside the
42px party, and shrinks further when the yard is short. It walks two of
them through the yard and idles the third. The clock runs only while
motion is on, the route's `TickerMode` is enabled, and the app is
resumed. Minimal VFX and the system reduce-motion flag hold the idle
pose. Goldens stay deterministic: Minimal VFX does not tick, and a
full-VFX capture is a fixed pump duration.

---

## Layout (A56)

Portrait 360×780. Sky and hills stay above the roofs. Guild and Vault
sit on the back row, the yard (path + walkers) is between the rows, and
FORGE / MARKET / INN and the party fill the front. Name chips sit on
the buildings, not in the sky. Labels `GameTheme.hint`; hit targets
stay on the building boxes and at least 44 dp on the phone sizes the
layout test covers. Text scale 1.45 and 2.0 still show ENTER. 360×640
uses the compact pack; the yard keeps a walker when it is at least one
sprite tall.

---

PRs 57, 58, 59, and 61 are already in this release candidate.

---

## Tests

- `test/town_viewport_test.dart` — catalog, unlocks, locked/unlocked taps, dismiss, repeat, text scale, short 360×640
- `test/town_nav_test.dart` — SCROLLS home, WATCH/WISP drop, POUCH keep
- `test/home_shell_town_test.dart` — live HomeShell routes, hub↔dungeon, Welcome Back, ads chips, vault credit, 1.45 / 2.0 / 360×640
- `test/town_preview_golden_test.dart` — HomeShell town goldens under `goldens/town/` for stone (AL1), timber (AL0), and banners (AL5). ≤0.02% doll AA comparator so parallel doll loads do not flake 4px. Home-shell goldens use Minimal VFX so the walkers hold the idle pose
- `test/town_scene_layout_test.dart` — labels on facades, hit boxes 44 dp and disjoint, yard clear of taps
- `test/town_life_test.dart` — walkers advance; Minimal VFX, system reduce-motion, pause, offstage ticker, and dispose do not keep ticking
