---
name: recording-browser-flow-as-test
description: >-
  Record an Idle Party hub/dungeon flow in Cursor's browser, then emit or update
  a Playwright script using stable labels / WebClickBridge (tool/playtest_*.py).
---

# Record browser flow as test (Idle Party)

## Prerequisites

- Web server on `:8080` (see `browser-playtest`)
- Existing patterns: `tool/playwright_*.py`, `tool/playtest_*.py`

## Recording

1. Define one flow (“New Game → skip tips → ENTER DUNGEON → FARM”).
2. For each step: `browser_snapshot` → click via ref or `__idlePartyClick('LABEL')` → log:
   - action, label/role, optional assertion
3. Prefer **stable KenneyButton / Semantics labels** over XY.
4. Emit or update a Playwright/Python script under `tool/` that replays labels:

```js
// Bridge path (preferred in Cursor)
window.__idlePartyClick('ENTER DUNGEON')
```

```python
# Playwright: click by accessible name when DOM hook exposes it
page.get_by_role("button", name="ENTER DUNGEON").click()
```

5. Run the script once; harden waits (visibility before click). No secrets in repo.

## Idle Party notes

- Title: `NEW GAME` / `CONTINUE`; tips: `SKIP ALL TIPS` / `GOT IT`
- After hub polish: also record MORE → GUIDES / LOADOUTS (see `hub-smoke`)
- God Hand needs map tap / ready control — document coordinates only if label missing

## When not to use

- Pure combat balance (use share-fast sims instead)
- Flows needing real Play Store / device install
