---
name: reviewing-code
description: >-
  Review Idle Party diffs for correctness against AGENTS.md — SpatialCombat
  authority, immutable state, assets-legal, Ascend/save defaults, balance honesty.
---

# Code review (Idle Party)

## Understand

Scope: feature / fix / polish. Read `git diff` (or PR) fully.

## Must-fix checklist

- **Combat**: live and AFK go through SpatialCombat; no duplicate authority
- **State**: mutations via GameLogic `copyWith`; no silent field drops on Ascend
- **Save**: new fields have fromJson defaults + test (`save-migrate`)
- **Assets**: only Kenney/custom via `KenneyAssets` / `CustomAssets`; `FilterQuality.none`
- **Balance**: kit buffs that move share → share-fast / gate considered
- **What’s New**: player-visible systems mentioned if version bump (`changelog_sync_test`)

## Should-fix

- Toast spam / discoverability for new meta payoffs
- Guides/tips lagging features
- Zone identity reskins (`zone-art-identity`)
- Tests missing for new GameLogic branches

## Nit

- Style the analyzer already covers — don't bikeshed

## Output format

**Must fix** / **Should fix** / **Nit** — each with path, why, suggested fix. Acknowledge what is solid.

## Don't

- Demand Riverpod/Provider
- Suggest commercial art dumps
- Approve weakening CI balance HIGH assertions without an explicit product decision
