---
name: hub-smoke
description: >-
  Hub polish smoke playtest for Idle Party (daily vault, TODAY chase,
  What’s New, guides, God Hand tip). Use after hub/meta/UX polish or before
  tagging a release that touches hub chrome.
---

# Hub smoke (Idle Party)

Short visual QA after What’s New / daily vault / MORE / guides / God Hand style work.
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
| 2 | TODAY chase | Hub shows a **TODAY** card (also on short/phone heights) with READY/ALMOST when close |
| 2b | Week affix | Line above TODAY: `Week · …` when `weeklyModifier` is set |
| 2c | Daily CTA | When TODAY is Daily, only TODAY’s **DAILY** button (no duplicate **DAILY RUN**) |
| 3 | Daily vault claim | Vault filled (1 clear or timed KEY +2): `CLAIM VAULT`; toast says **Daily vault claimed** |
| 4 | MORE badge | Unseen changelog → `MORE · NEW`; claimable jobs / vault mid → `MORE · !` |
| 5 | What’s New | Open MORE → sheet title **MORE** → Settings / changelog path; bullets match `MetaSystems.currentVersion` |
| 6 | Guides | MORE → GUIDES → topics labeled `Guide · …` in a11y; WORLD PATH mentions Tidehold/Ashen/Grove; DAILY VAULT guide; LOADOUTS ≠ ARMOR SETS |
| 7 | God Hand tip | Enter dungeon once; tip mentions BAL/FOCUS/WIDE or Forge → META |
| 8 | Loadouts label | MORE → `LOADOUTS` (not “GEAR SETS”) |
| 9 | Overlay hygiene | Open Codex/Guides then ENTER: return to hub must not leave Codex stuck open |

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
