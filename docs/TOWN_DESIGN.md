# Idle Party Town

**Branch:** `cursor/town-hub-617a`  
**Updated:** 2026-11-08  
**Phone:** Samsung A56 360×780, English UI, `FilterQuality.none`

When the party is **not in a dungeon**, they rest in a town between
climbs. The town is a place: Guild Hall and Vault on the back row,
FORGE / MARKET / INN on the square, a well, heroes in front, one ENTER.

This slice lives in `TownPreview`. It is **not** the live home shell.

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
(those stay labeled FORGE under the fight after live wiring). MARKET is
`MarketOverlay` listings. INN is party composition, not the GEAR tab.

No new currency, save field, energy, chore timer, or ad gate. Offline
gold, auto combat, SHOP, and WISP-in-the-cave are untouched.

### Not wired into the live home shell

PR58 edits `home_shell.dart`. This branch **does not**. Camp stays
the live out-of-dungeon view until merge:

```
HomeShell  →  CampViewport     (live, unchanged)
TownPreview → TownViewport     (this slice, tests + review)
```

**Pending integration (one-line swap):** in `home_shell.dart`, replace
`CampViewport(...)` with `TownViewport(...)`. Do not copy camp logic.

---

## WISP / POUCH / SCROLLS / WATCH

| Shortcut | True job | Live `HomeCatalog` | Town policy |
|----------|----------|--------------------|-------------|
| **SCROLLS** | Tickets, daily Well, spend buffs, WISP status, optional WATCH | Rail + MENU | **Keep. This is the home.** |
| **WATCH** | Watch an ad for a ticket | Duplicate of SCROLLS | Drop as a hub chip. Action stays inside SCROLLS. |
| **WISP** | In-cave lantern for gold | Duplicate of SCROLLS | Drop as a hub chip. Lantern stays in the dungeon. |
| **POUCH** | One-time reinstall gold | Shown only when due | **Keep while due.** |

`TownNavPolicy` is **not** applied to live `HomeCatalog` on this branch.

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
`assets/custom/`. No paid packs. `FilterQuality.none`.

Three painted tiers per facade (forge / market / inn / guild), vault
shut/open, well, backdrop 360×520, cobble.

Previews: `assets/custom/town/preview_a56.png` (composite) and the
Flutter golden `test/goldens/town/town_preview_a56.png`.

---

## Layout (A56)

Portrait 360×780. Guild + Vault on the back row, FORGE / MARKET / INN
large on the cobble, well in the square, party in front, ENTER in the
dock. Short height (`<720`, 360×640) shrinks facades. Labels
`GameTheme.hint`; hit targets ≥44px. Text scale 1.45 and 2.0 still
show ENTER.

---

## Integration seam

| File | This PR | Merge later |
|------|---------|-------------|
| `lib/ui/shell/home/town_viewport.dart` | new | keep |
| `lib/core/town_nav.dart` / `town_access.dart` | new | apply nav filter to catalog |
| `lib/models/town_building.dart` | new | keep |
| `lib/assets/custom_assets.dart` | register `town*` | keep |
| `pubspec.yaml` | `assets/custom/town/` | keep |
| `lib/ui/shell/home/home_shell.dart` | **untouched** | swap Camp → Town |
| `lib/ui/shell/home/home_catalog.dart` | **untouched** | filter with `TownNavPolicy` |
| `lib/core/game_logic.dart` | **untouched** | none |
| Shared goldens | **untouched** | retake after the swap |
| PR57 combat / camera / welcome-back | **untouched** | none |
| Save JSON | **untouched** | none |

---

## Tests

- `test/town_viewport_test.dart` — catalog, unlocks, locked/unlocked taps, dismiss, repeat, text scale, short 360×640
- `test/town_nav_test.dart` — SCROLLS home, WATCH/WISP drop, POUCH keep
- `test/town_preview_golden_test.dart` — town-only A56 golden
