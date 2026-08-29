---
name: hub-smoke
description: >-
  Hub polish smoke playtest for Idle Party (daily vault, TODAY chase,
  What’s New, guides, God Hand tip). Use after hub/meta/UX polish or before
  tagging a release that touches hub chrome.
---

# Hub smoke (Idle Party)

Short visual QA after What’s New / daily vault / MORE / guides / God Hand style work.

**Default setup:** [a56-playtest](../a56-playtest/SKILL.md) (Samsung A56
emulator). Skip boot story → CONTINUE / NEW GAME → dismiss tips. Tap through
the checklist on the emulator.

Web + `WebClickBridge` only if Android cannot run — see
[browser-playtest](../browser-playtest/SKILL.md).

## Checklist (look → click → think)

| # | Check | How |
|---|--------|-----|
| 1 | Hub loads | World Path nodes visible; `ENTER DUNGEON` present |
| 2 | TODAY chase | Hub shows a **TODAY** card (also on short/phone heights) with READY/ALMOST when close |
| 2b | Week affix | Line above TODAY: `Week · …` when `weeklyModifier` is set |
| 2c | Daily CTA | When TODAY is Daily, only TODAY’s **DAILY** button (no duplicate **DAILY RUN**) |
| 3 | Daily vault claim | Vault filled (1 clear or timed KEY +2): `CLAIM VAULT`; toast says **Daily vault claimed** |
| 4 | MORE badge | Unseen changelog → `META · NEW` (phone: `META ★`); claimable jobs → `META · !` (phone: `META !`) |
| 5 | What’s New | Open META → GUIDE → WHAT'S NEW; bullets match `MetaSystems.currentVersion` |
| 6 | Guides | META → GUIDE → topics labeled `Guide · …`; WORLD PATH mentions Tidehold/Ashen/Grove |
| 7 | God Hand tip | Enter dungeon once; tip mentions BAL/FOCUS/WIDE or POWER → Forge |
| 8 | Loadouts label | PARTY → `LOADOUTS` (phone tab may say `LOAD`; not “GEAR SETS”) |
| 9 | Overlay hygiene | Open META/CODEX then ENTER: return to hub must not leave sheet stuck open |

## Bridge helpers (web fallback only)

```js
window.__idlePartyButtons()
window.__idlePartyClick('PARTY')
window.__idlePartyClick('POWER')
window.__idlePartyClick('META')
window.__idlePartyClick('META · NEW')
window.__idlePartyClick('ENTER DUNGEON')
```

## Stop / report

After ~4 failed clicks on the same control, stop. Report: screen, last label tried, screenshot observation, next best step.

## Related

- Changelog honesty: `test/changelog_sync_test.dart`
- Cadence: `docs/CONTENT_CADENCE.md`
