---
name: reviewing-code
description: >-
  Reviews Idle Party diffs against AGENTS.md and the ship bar (SpatialCombat
  authority, save defaults, matching tests, product locks). Use when reviewing a PR/diff, before merge, or when the
  owner says "granska", "kolla PR", "innan merge", or asks for a code review.
  Do not use for automated CI babysitting (babysitting-pr) or running the
  verify loop (flutter-verify).
---

# Code review (Idle Party)

Review only. Do **not** implement, push, or merge in this turn — that is
`babysitting-pr` (CI / review comments) or a new coding turn if the owner
asks to fix.

## 1. Scope the diff

Name the tree, then read **that** diff fully (no sampling):

| Context | Command |
|---------|---------|
| Dirty tree / "kolla det här" | `git diff` + untracked |
| Branch vs main / "innan merge" | `git diff main...HEAD` |
| GitHub PR | `gh pr diff` |

Do not run full `flutter test` unless they asked to verify (`flutter-verify`).

If the diff belongs to a domain skill, follow it for that slice:

| Diff touches | Follow |
|--------------|--------|
| `spatial/` / kits / AFK combat | `spatial-combat-change` |
| `GameState` / `metaDepth` / Ascend | `save-migrate` |
| `assets/` | `assets-legal` (+ `character-paper-doll` if body/gear) |
| hub / chase / guides / first hour | `ship_smoke_test` + `first_hour_plain_test` |
| kit DPS numbers | share-fast / gate — do not weaken HIGH |
| version / What's New | `changelog_sync_test` |
| zone sprites | `zone-art-identity` (only if art moved) |

## 2. Must fix (block merge)

- **Combat**: live + in-dungeon AFK through SpatialCombat; no second sim
- **State**: GameLogic `copyWith`; no silent Ascend field drops
- **Save**: new fields have fromJson defaults + test (`save-migrate`)
- **Assets**: Kenney/custom via helpers; `FilterQuality.none`; no dumps
- **Balance**: share-moving kit changes considered share-fast/gate; no HIGH-assert edits without an explicit product decision
- **What's New**: version bump names the player-visible systems
- **Honesty**: English in-game copy matches reality
- **Chrome**: prefer shared `MenuRouter` + `MenuSurface` + `AppBottomBar` when it fits; flat nav / hide-until-unlock are not hard review blocks
- **Tests**: new GameLogic / hub / chase / guides branches have matching tests using `GameDirector.preview()`
- **Locks**: hard product locks only (no iOS/web-as-product, gacha / BiS-for-cash, GitHub Releases as install path)

## 3. Should fix

- Guides/tips lag the feature
- New meta payoff with no chase/toast/MORE path (discoverability — not "toast spam")
- New HUD dumped into `game_logic` / `spatial_combat` / `is2_shell` instead of `lib/ui/shell/`
- Architecture / Ascend / world path / distribution changed but `AGENTS.md` not updated
- Tests missing for a new branch that is not already a must-fix

## 4. Nit

Style the analyzer already covers — don't bikeshed. Omit Nit if empty.

## Output

Owner chat: **Swedish**. GitHub review comments: **English**.

```
Scope: <uncommitted | main...HEAD | PR #N>

Solid: <1-3 things that are correct>

Must fix
- `path`: why. Suggested fix.

Should fix
- `path`: why. Suggested fix.
```

Example:

```
Scope: PR #412 (main...HEAD)

Solid: fromJson default on the new meta field; offline catch-up still uses SpatialCombat.step.

Must fix
- `lib/ui/hub_screen.dart`: first-hour copy names ESSENCE before first reward. Gate it with the same unlock as the tab.
```

## Don't

- Demand Riverpod/Provider
- Suggest commercial art dumps
- Restore AL20 as the default work slice
- Approve weakening the live-light HIGH gate without an explicit product decision
- Implement the fixes unless the owner asked this turn
