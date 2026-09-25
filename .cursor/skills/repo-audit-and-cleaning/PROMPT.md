# Idle Party — repository audit

Analysis only. Do not modify, rename, delete, install, or generate replacement code.

The job is evidence on this game's real risks. A short true report beats a tour of the whole tree.

## How to work

- Search. Do not read every file. Do not inventory every symbol.
- Treat `AGENTS.md` as a claim. If code disagrees, that disagreement is a finding.
- Before calling anything DEAD, search `lib/`, `test/`, and `tool/` for the symbol, its library (`part of`), string name, JSON key, enum `switch`, and registration.
- `part` / `part of` files have no imports of their own. Search the parent library.
- One issue, one finding. Omit empty sections. Do not pad to a fixed count.
- Unused imports and unused locals belong to `flutter analyze`. Do not list them.
- Label each finding FACT or INFERENCE. Give `file:line`. If confidence is low, say SUSPICIOUS or drop it.

## Where to look

| In scope | Skip |
|---|---|
| `lib/` | `build/`, `.dart_tool/`, `tool/out/`, coverage |
| `test/` when a `lib/` finding needs a guard, or a test calls a removed API | `windows/flutter/generated_*`, `linux/flutter/generated_*`, `macos/Flutter/ephemeral` |
| `pubspec.yaml` version vs `ChangelogCatalog.currentVersion` | `ios/` (no iOS product) |
| `tool/*.py` only when it publishes into `lib/` or `assets/` and the publish path looks broken | `docs/archive/`, pixel contents of `assets/` |
| Player-facing docs only when they contradict the code you already checked | `.cursor/` |

## Axes

Cover these. Stop when each axis has a result (findings, or "clean" with the search you ran).

### 1. Runtime map

Confirm the live path, then stop:

`main.dart` → `GameDirector` → `GameLogic` / `GameState` → `SpatialCombat.step`

Offline catch-up is the same `step` (`afkAssist: true` via `GameLogic.simulateSpatialOffline`). Hub AFK (`!inDungeon`) is gold and slow essence, not a fight.

Name a second combat sim, a second damage formula, or a kit path that never enters `step` only if you can show the call chain.

### 2. Kit wiring

Pipeline:

`HeroSpecDef` → `ClassAbilityDef` (`lib/models/kits/`, `part of` `class_ability.dart`) → `SpatialCombat.step` → `AbilityEffectRunner` → HUD `ClassKits.hudAbilitiesAtSpec`

Named casts: `ClassAbilityDef.customId` → `KitNamedCasts` in `lib/spatial/kit_migrated_casts.dart`. Passives are fields on the def (`passiveOutMul` and the rest). No direct call site is normal.

Finding: a spec row the HUD can show whose `effect` / `fireMode` / `customId` never runs, or a `customId` with no `KitNamedCasts` case. A kit that is only weak is not a finding (balance gate owns numbers).

### 3. Save compatibility

Paths: `GameState` (`toJson` / `fromJson` / `copyWith`), `GameLogic.stateFromJson`, `MetaDepth`, `GameLogic.ascend`, `GameLogic.rebornAtCap`. Prefs: `idle_party_save_v2`, else v1. Load always goes through `stateFromJson`.

Findings:

- Key written and not read on load, or read with no default when the key is missing.
- Ascend drops a KEEP (hero levels, zones, essence, relics, pets, sanctuary, `metaDepth`, Apex, God Hand, settings) or keeps a run-bag field (gold, forge tracks, worn/stash drops, market, loadouts, `highestFloorCleared`).

A JSON key with no current reader is a legacy save field. Classify SAVE_KEEP. Never DEAD. Never "delete this key". `@Deprecated` helpers kept for old saves stay.

LOADOUTS tab is hidden. Leftover preset fields in JSON stay.

### 4. Dead and orphan non-save code

DEAD: no consumer in `lib/`, `test/`, `tool/`, generated code, callbacks, or data tables, and it is not a save key. HIGH confidence only.

ORPHAN: implemented, chain breaks before runtime (menu nothing opens, service nothing registers, asset helper nothing calls).

Still check: factories, `MenuRouter` / `MenuTabs`, zone and enemy tables (`enemy_flavor`, `boss_tells`, `enemy_specials`), coupons, Play leaderboard ids.

Hidden-until-unlock is intentional (first hour: GEAR + MORE; KEY tab only when the active party is all Lv100). Do not call that dead.

### 5. Asset paths

Sprites and UI images go through `CustomAssets` or `KenneyAssets`. A raw `assets/` image path in `lib/ui/` is a finding.

`assets/data/*.json` loaded from core is allowed. `KenneyAssets` is a legacy name for owned art.

APK, AAB, IPA, SWF, DEX, or a dump from another game anywhere in the repo is P0.

### 6. Copy and version

`pubspec.yaml` `version:` name must match `ChangelogCatalog.currentVersion` in `lib/core/changelog.dart` (`MetaSystems.currentVersion` reads it).

Finding: What's New, `GameGuides`, or hub chase text states a rule the code does not implement, or the version pair disagrees. Do not audit tone.

### 7. Hot path cost

Look only at `SpatialCombat.step` and dungeon paint. Party is about 5 heroes. Packs and chambers are capped.

A finding needs current cost, input size on a phone, and why that size hurts. O(n) on a few dozen units is not a finding.

Do not recommend caching, mutability, or replacing `copyWith`. Immutable state is the architecture.

### 8. Tests

Name a gap only for a P0/P1 path you found that no test covers. Existing guards: `test/class_balance_gate_test.dart`, `test/changelog_sync_test.dart`, `test/ship_smoke_test.dart`, `test/save_load_test.dart`. Tag `sim` is nightly on purpose, not missing CI.

## Severity

| Level | Use for |
|---|---|
| P0 | Second fight sim, save load/Ascend corrupts KEEP or bag, HUD ability that cannot fire, foreign dump, image path that ships foreign art |
| P1 | HIGH-confidence dead non-save code, player-facing copy that lies, version desync |
| P2 | Orphan with a broken chain, hot-path cost that matters at pack size |
| P3 | Leave it out unless it hides a P0–P2 |

## Not findings

Say these once under **Lämna** if you noticed them. Do not turn them into work.

- `game_logic.dart`, `spatial_combat.dart`, and `game_director.dart` are large. Parts already exist. Length is not a split ticket.
- `copyWith` on the hot path.
- Offline fight inside `SpatialCombat`.
- Shop hour-packs kept for restore, not listed.
- Soft-fail Play Games / Firebase off Play installs.
- This audit is not the next feature batch. Do not propose zones, classes, hub programs, or god-file splits.

## Report

Swedish. Paths and symbols stay as in the repo. The owner reads this. No English essay, no empty tables, no top-20 list.

```
# REPO-AUDIT

## Kort
(≤12 lines: what is solid, what is actually wrong, what to leave alone.
Say explicitly that this is not the next batch.)

## Karta
(the runtime path you confirmed, a few lines)

## Fynd
### P0 / P1 / P2
- Category: DEAD | ORPHAN | SAVE | SAVE_KEEP | KIT | SECOND_SIM | ASSET | COPY | PERF | TEST | BUG
- Confidence: HIGH | MEDIUM | LOW
- FACT or INFERENCE
- Where: file:line
- Evidence: the search or the broken chain
- Safe next step: one sentence, or "rör inte"

## Lämna
(intentional things that looked wrong)

## Axlar utan fynd
(one line each: what you searched)
```

If there are zero findings, say so under **Kort** and still list **Axlar utan fynd**.

## Before you finish

1. Re-check every DEAD against save keys, `part of`, and `customId`.
2. Drop anything you would not bet on.
3. Do not modify the repository.
