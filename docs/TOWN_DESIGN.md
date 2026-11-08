# Idle Party Town

**Branch:** `cursor/town-hub-617a`  
**Updated:** 2026-11-08  
**Phone:** Samsung A56 360×780, English UI, `FilterQuality.none`

When the party is **not in a dungeon**, they rest in a town between
climbs. The town is a place: Guild Hall and Vault on the back row,
FORGE / MARKET / INN on the square, a well, heroes in front, one ENTER.

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
`FilterQuality.none`. Ground repeats 1:1 (`ImageRepeat.repeat`),
backdrop uses `BoxFit.fitWidth`, so the phone does not stretch a
64px strip into giant bricks.

Measured from shipped art, not a new style:

| Rule | Where it already lives |
|------|------------------------|
| Warm ink (32, 22, 18), 1 px outer contour | `tool/gear_style.py` `INK` |
| Upper-left light | `gear_style.py` `LIGHT_DIR` |
| Sand stone (58, 44, 24)…(200, 136, 64) | `dungeon/sandy/tiles/floor_a.png` |
| Dark wall (23, 17, 11)…(74, 58, 36) | `dungeon/sandy/tiles/wall_a.png` |
| Leather / wood / gold ramps | `gear_style.py` `MATERIAL_RAMPS` |
| Iron | `dungeon/fallback/props/anvil.png` |
| Cave mouth, torches, banners | `ui/backdrops/sandy.png`, `ui/hub_scene.png` |
| Hero density | `char/warrior/human_m_body_idle.png` |

Guild is a crenellated gatehouse (the hub gate's cousin). Forge chimney
sits on the right of the smithy. Name chips paint after the sprites, and
hit boxes do not overlap, so GUILD stays readable and tappable.
Heroes stand on the flags with a contact shadow.

Three painted tiers per facade. AL10 pennants and AL20 lanterns stay
Flutter overlays.

Previews: `assets/custom/town/preview_a56.png` (composite) and the
Flutter golden `test/goldens/town/town_preview_a56.png`.

---

## Layout (A56)

Portrait 360×780. The cave sky stays above the plaza. Guild and Vault
stand on the back of the flags; FORGE / MARKET / INN and the party fill
the front. Name chips sit on the buildings. Labels `GameTheme.hint`;
hit targets stay on the building boxes. Text scale 1.45 and 2.0 still
show ENTER. 360×640 uses the compact pack.

---

## Sibling PR overlap (do not import those branches)

Heads read this turn. This PR does not cherry-pick, merge, or rewrite
them. Compatibility can be proved in a disposable worktree.

| PR | Head | Overlap | Resolution |
|----|------|---------|------------|
| **57 camera** | `ed5b9024` | **None on `home_shell.dart`.** Camera / combat / `offline_welcome` / `home_prompts` / `play_shell` + fight and Welcome Back goldens. | Leave camera files, `fight_a56`, Welcome Back, and `home_shell_full_a56` alone. `home_shell_split_a56` on this PR is a justified rail-chip update (WATCH/WISP gone via `HomeCatalog.of`, ~1.28%), not a camera retake. |
| **58 return-week** | `fa0fa46e` | **`home_shell.dart` `_climbRow`** plus `return_week.dart`, chase/guides, `game_logic` check-in line, and hub goldens. | This PR **does not edit `_climbRow`**. Disposable merge of `fa0fa46e` onto **`8fda76d2`** applied their climb-row patch cleanly (import `return_week.dart`; `back = climb == null && ReturnWeek.active(state) ? ReturnWeek.coachLine(state) : null`; tip only when `back == null`; `text = climb ?? back ?? tip`). TownViewport + GOLD intercept stayed. **One conflict:** binary `test/goldens/after/home_shell_split_a56.png` (this PR dropped WATCH/WISP rail chips; PR58 regenerated the same PNG). Combined tree should regenerate that one golden — do not keep either PNG blindly (theirs would restore WATCH/WISP; ours might miss a return-week pixel). `fight_a56` / `home_shell_full_a56` / `welcome_back_a56` / `hub_a56` took PR58 with no conflict. Pending PR58 does not block this town swap. Merge was aborted; this branch does not contain PR58. |
| **59 workflow** | `752d1c9` | Workflows only. | No overlap. This PR does not touch workflows / APK / tags. |

Exact `_climbRow` region this PR leaves untouched so PR58 still applies:

```
final climb = FirstClimbCoach.line(state, inDungeon: state.inDungeon);
if (sheet && climb == null) return const SizedBox.shrink();
final tip = !state.inDungeon && climb == null
    ? FirstSessionTips.active(state, inDungeon: false)
    : null;
final text = climb ??
    (tip == null ? null : FirstSessionTips.displayLine(tip, state));
```

This PR's `home_shell.dart` edits: `CampViewport` → `TownViewport`; GOLD
intercept only while `inDungeon`; drop out-of-dungeon `HomeGoldDock`.

---

## Tests

- `test/town_viewport_test.dart` — catalog, unlocks, locked/unlocked taps, dismiss, repeat, text scale, short 360×640
- `test/town_nav_test.dart` — SCROLLS home, WATCH/WISP drop, POUCH keep
- `test/home_shell_town_test.dart` — live HomeShell routes, hub↔dungeon, Welcome Back, ads chips, vault credit, 1.45 / 2.0 / 360×640
- `test/town_preview_golden_test.dart` — HomeShell town goldens under `goldens/town/` for stone (AL1), timber (AL0), and banners (AL5). ≤0.02% doll AA comparator so parallel doll loads do not flake 4px
