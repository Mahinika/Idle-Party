---
name: hub-smoke
description: >-
  Hub polish smoke playtest for Idle Party (weekly progress, MORE badge,
  What’s New, guides, God Hand tip). Use after hub/meta/UX polish or before
  tagging a release that touches hub chrome.
---

# Hub smoke (Idle Party)

Short visual QA after What’s New / weekly / MORE / guides / God Hand style work.
Uses the same Flutter web + `WebClickBridge` path as [browser-playtest](../browser-playtest/SKILL.md).

## Setup

```bash
flutter run -d web-server --web-hostname=localhost --web-port=8080
```

Open `http://localhost:8080/` → `CONTINUE` or `NEW GAME` → dismiss tips (`SKIP ALL TIPS` / `GOT IT`).

## Checklist (look → click → think)

| # | Check | How |
|---|--------|-----|
| 1 | Hub loads | World Path nodes visible; `ENTER DUNGEON` present |
| 2 | Weekly progress | With `weeklyProgress` 1–2: hub shows `Weekly … · n/3` (not only claim) |
| 2b | TODAY chase | Hub shows a **TODAY** card above ENTER DUNGEON with next goal |
| 3 | Weekly claim | At 3/3 unclaimed: `CLAIM WEEKLY` button; toast includes essence / season |
| 4 | MORE badge | Unseen changelog → `MORE · NEW`; claimable jobs / weekly mid → `MORE · !` |
| 5 | What’s New | Open MORE → Settings / changelog path; bullets match `MetaSystems.currentVersion` |
| 6 | Guides | MORE → GUIDES → WORLD PATH mentions Tidehold/Ashen; LOADOUTS ≠ ARMOR SETS |
| 7 | God Hand tip | Enter dungeon once; tip mentions BAL/FOCUS/WIDE or Forge → META |
| 8 | Loadouts label | MORE → `LOADOUTS` (not “GEAR SETS”) |

## Bridge helpers

```js
window.__idlePartyButtons()
window.__idlePartyClick('MORE')
window.__idlePartyClick('MORE · NEW')
window.__idlePartyClick('GUIDES')
window.__idlePartyClick('ENTER DUNGEON')
```

## Stop / report

After ~4 failed clicks on the same control, stop. Report: screen, last label tried, screenshot observation, next best step.

## Related

- Changelog honesty: `test/changelog_sync_test.dart`
- Cadence: `docs/CONTENT_CADENCE.md`
