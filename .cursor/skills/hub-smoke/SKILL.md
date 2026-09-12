---
name: hub-smoke
description: >-
  Hub polish smoke playtest for Idle Party (daily vault, TODAY chase, What's New,
  guides, God Hand tip). Use after hub/meta/UX polish, before tagging a release,
  or when the owner says "polish hub" / "kolla hubben". Do not use for
  in-dungeon combat feel (spatial-combat-change).
---

# Hub smoke (Idle Party)

Short visual QA after What’s New / daily vault / MORE / guides / God Hand style work.

**Default setup:** [a56-playtest](../a56-playtest/SKILL.md) (Samsung A56
emulator). Skip boot story → CONTINUE / NEW GAME → dismiss tips. Tap through
the checklist on the emulator.

Web + `WebClickBridge` only if Android cannot run — see
[browser-playtest](../browser-playtest/SKILL.md).

## Fast honesty (before emulator)

```bash
flutter test test/ship_smoke_test.dart test/changelog_sync_test.dart
```

## Checklist (look → click → think)

| # | Check | How |
|---|--------|-----|
| 1 | Hub loads | World Path nodes visible; `ENTER DUNGEON` present |
| 2 | Hub hunt | Hunt line under the map (READY/ALMOST when close); no TODAY stamp |
| 2b | Week affix | Line above the hunt: `Week · …` when `weeklyModifier` is set |
| 2c | Daily CTA | When the hunt is Daily, only the hunt **DAILY** button (no duplicate **DAILY RUN**) |
| 3 | Daily vault claim | Vault filled (1 clear or timed KEY +2): `CLAIM VAULT`; toast says **Daily vault claimed** |
| 4 | MORE badge | Unseen changelog → `★` on **MORE** (`MenuAlerts.more.star`); claimable quests → count badge on **MORE** |
| 5 | What’s New | Open MORE → INFO → WHAT'S NEW; bullets match `MetaSystems.currentVersion` |
| 6 | Guides | MORE → INFO → topics labeled `Guide · …`; WORLD PATH mentions Tidehold/Ashen/Grove |
| 7 | God Hand tip | Enter dungeon once; tip mentions BAL/FOCUS/WIDE or ESSENCE → KEEP |
| 8 | GEAR tabs | GEAR shows GEAR + BAG early; MERGE / ROSTER unlock later — no LOADOUTS tab |
| 9 | Overlay hygiene | Open MORE/CODEX then ENTER: return to hub must not leave sheet stuck open |
| 10 | POWERUPS camera | After first boss: film-camera overlay bottom-right on the map (not in the header). Tap → POWERUPS sheet |

## Bridge helpers (web fallback only)

```js
window.__idlePartyButtons()
window.__idlePartyClick('GEAR')
window.__idlePartyClick('GOLD')
window.__idlePartyClick('MORE')
window.__idlePartyClick('ENTER DUNGEON')
```

## Stop / report

After ~4 failed clicks on the same control, stop. Report: screen, last label tried, screenshot observation, next best step.

## Related

- Changelog honesty: `test/changelog_sync_test.dart`
- Cadence: `docs/CONTENT_CADENCE.md`
