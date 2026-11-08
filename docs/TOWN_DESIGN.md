# Idle Party Town

**Branch:** `cursor/town-hub-617a`  
**Updated:** 2026-11-08  
**Phone:** Samsung A56 360×780, English UI, `FilterQuality.none`

When the party is **not in a dungeon**, they rest in a town between
climbs. The town is a place: three distinct buildings, heroes on the
square, one ENTER. It is not a second grid of the same rail icons.

---

## Implemented now (this slice)

| Piece | Where | What it does |
|-------|--------|----------------|
| Town scene | `TownViewport` | Backdrop + cobble + FORGE / MARKET / INN + party dolls + ENTER |
| FORGE tap | existing GOLD sheet | `showHomeGoldSheet` → FORGE tracks |
| MARKET tap | existing GOLD sheet | `showHomeGoldSheet` → MARKET |
| INN tap | existing HEROES | `MenuRoute.gear` + ROSTER when that tab exists, else GEAR |
| ENTER | existing chase | Same `runChasePlan` as camp |
| Art | `assets/custom/town/` | Owned pixel facades, backdrop, ground, A56 composite |
| Shortcut policy | `TownNavPolicy` | One home for SCROLLS; WATCH/WISP are not extra buttons |
| Preview harness | `TownPreview` | 360×780 pump **without** `HomeShell` |

No new currency, no new save field, no ad gate, no energy, no chore
timer. Offline gold, auto combat, SHOP, and WISP-in-the-cave are
untouched.

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

## WISP / POUCH / SCROLLS / WATCH audit

Robert’s screenshot: four rail chips, all opening the same sheet,
several red dots.

| Shortcut | True job | Live `HomeCatalog` | Town policy |
|----------|----------|--------------------|-------------|
| **SCROLLS** | Tickets, daily Well, spend buffs, WISP status line, optional WATCH | Rail + MENU | **Keep. This is the home.** |
| **WATCH** | Watch an ad for a ticket | Duplicate of SCROLLS | Drop as a hub chip. Action stays inside SCROLLS. |
| **WISP** | In-cave lantern for gold; optional ad for a bigger pile | Duplicate of SCROLLS | Drop as a hub chip. Lantern stays in the dungeon. Status stays in SCROLLS. |
| **POUCH** | One-time reinstall gold | Shown only when due | **Keep while due.** Still claims through the same sheet. |

`TownNavPolicy.duplicatePowerupIds` is `{watch, wisp, menu_watch, menu_wisp}`.
Applying that filter to `HomeCatalog.entries` is **pending integration**
so this PR does not rewrite hub goldens or PR58’s `home_shell`.

Nothing is removed as a system: ads, tickets, WISP lantern, pouch grant
all still exist.

---

## Buildings — purposes (v1)

| Building | Player decision | Reuses | Idle rule |
|----------|-----------------|--------|-----------|
| **FORGE** | Which run-power track to buy with **wallet gold** | GOLD → tracks | Optional. AUTO EQUIP and AFK combat do not require a visit. |
| **MARKET** | Flask vs listed upgrade vs skip | GOLD → market | Optional. Listings already refresh without standing in town. |
| **INN** | Who is in the active four | HEROES → ROSTER | Optional. A new spec already badges GEAR; Inn is the place that *looks* like a roster. |

These three are enough for a first town because they match jobs the
player already has, with different verbs (spend run gold / buy a listing /
pick who walks).

---

## Ranked expansion (proposals — not built)

Do not add currencies or prices until Robert picks a row.

| Rank | Building | Session loop | Concrete decision | Depends on | Visible upgrade | Anti-chore |
|------|----------|--------------|-------------------|------------|-----------------|------------|
| 1 | **GUILD HALL** | Claim jobs that are already done | Open QUESTS vs skip; TODAY still owns the ready claim | First floor / QUESTS unlock | Board fills with posted slips; AL paints a banner | No extra daily. Hall only shows **claimable** rows. Never a “visit 3 buildings” quest. |
| 2 | **VAULT** | First-week return | Claim the daily vault **here** instead of a rail chip | `showDailyVault` | Chest lid open vs shut, fill pips on the stone | Claim is optional; missing a day does not punish tomorrow. No second vault. |
| 3 | **SHRINE** | Between Ascends | BAL / FOCUS / WIDE God Hand | Blessing unlock | Lantern count = blessing stacks | Changing mode is free and rare. No daily pray. |
| 4 | **TAVERN** | Social / ads without a fourth duplicate chip | TIP A FRIEND, or open SCROLLS if you actually want a ticket | SHOP unlock | Hearth lit while a scroll buff runs | Ads stay optional. Tavern never pops a forced WATCH. |
| 5 | **PET YARD** | Hatch / errand | Send a pet or leave it home | Pets unlock | Occupied vs empty pen | Errand already runs AFK. Yard is a window, not a walk. |

**Not proposed:** town energy, building build timers, a town-only gold
sink, paid façade SKUs, NPC chatter trees, a sixth currency.

---

## Town upgrades (proposal — not v1 art)

Tier is `TownTier.fromAscension(AL)`. **No save field.** v1 paints
tier 0 for every save.

| Tier | When | What the square should show |
|------|------|-----------------------------|
| 0 | New game | Timber / thatch, empty square |
| 1 | AL1 | Stone sills, one lit lantern |
| 2 | AL5 | Painted signs, flower boxes |
| 3 | AL10 | Banners, two extra NPC silhouettes |
| 4 | AL20 | Torch arcade, grand inn sign |

Upgrades are **cosmetic milestones**, not a second prestige. Combat
power still comes from forge, gear, blessing, pets.

---

## Art

| File | Size | Notes |
|------|------|--------|
| `assets/custom/town/backdrop.png` | 360×400 | Day sky, hills, dirt square |
| `building_forge.png` | 96×128 | Chimney, anvil, fire |
| `building_market.png` | 96×128 | Red awning, crates |
| `building_inn.png` | 96×128 | Thatch, mug sign |
| `ground.png` | 360×64 | Cobble |
| `preview_a56.png` | 360×780 | Layout composite (not a Flutter screenshot) |
| `buildings_sheet.png` | 320×160 | Review strip |

Source: `tool/generate_town_art.py`. License: owned, same as
`assets/custom/`. No paid packs. Paint with `FilterQuality.none`.

This is **v1 shipped town art**, not a grey box labeled “placeholder”.
Higher tiers are not drawn yet.

Previews also copied to `/opt/cursor/artifacts/town_*.png` on generate
(`python3 tool/generate_town_art.py --preview /opt/cursor/artifacts`).

---

## Layout (A56)

Portrait 360×780. Buildings in one row (min 44 px hit). Party well
under the square. One brown ENTER. Labels use `GameTheme.hint` so
text scale 1.45 still fits. Short height (`<720`) tucks the row up.

Rails (SCROLLS / QUESTS / …) stay on `HomeShell` after the swap.
TownViewport does not duplicate them.

---

## Integration seam

| File | This PR | Merge later |
|------|---------|-------------|
| `lib/ui/shell/home/town_viewport.dart` | new | keep |
| `lib/ui/shell/home/town_nav` via `lib/core/town_nav.dart` | new | apply to catalog |
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

- `test/town_viewport_test.dart` — catalog, assets on disk, taps, text scale
- `test/town_nav_test.dart` — live duplicates vs intended filter

---

## Risks

| Risk | Mitigation |
|------|------------|
| Merge vs PR58 `home_shell` | No edit this branch; one-line swap after 58 lands |
| Goldens vs catalog cleanup | Policy lives in `TownNavPolicy` until goldens can move |
| Art reads cheap at phone size | Distinct silhouettes (chimney / awning / thatch); nearest-neighbor |
| Forced town visits | ENTER is still the primary; buildings are optional |
