---
name: verifying-in-browser
description: >-
  After UI/hub/dungeon chrome changes, run Flutter web and verify in Cursor's
  browser via WebClickBridge — don't trust code-only. Use after hub/meta/UI edits.
---

# Verify in browser (Idle Party)

Flutter CanvasKit has no real DOM widgets. Prefer **browser-playtest** mechanics (`WebClickBridge` + semantics).

## Steps

1. **Serve** (if not already):

```bash
flutter run -d web-server --web-hostname=localhost --web-port=8080
```

2. Open `http://localhost:8080/` in Cursor browser.
3. **Phone mode (mandatory):** CDP `Emulation.setDeviceMetricsOverride` →
   **360×780**, `deviceScaleFactor: 3`, `mobile: true` (Samsung A56). Confirm
   `innerWidth === 360`. See **browser-playtest**.
4. Wait ~3–4s for load + start-menu unlock.
5. `browser_lock` → snapshot / screenshot.
6. Drive with `__idlePartyClick('…')` / button refs (see `browser-playtest`).
7. Health:
   - Page renders (not blank forever)
   - Viewport is phone (360 wide), not desktop
   - Bridge live: `typeof window.__idlePartyClick === 'function'`
   - Changed UI reachable (hub / dungeon chrome)
8. For hub polish checklist → follow **hub-smoke**.
9. Unlock when done; report verdict + evidence.

## When

- Hub / MORE / What’s New / weekly / guides
- Dungeon chrome, tips, overlays
- Before claiming “UX polish done”

## Don't

- Raw CDP `Input.*` mouse (blocked in Cursor)
- Coordinate-only clicks when labels exist
- Skip unlock after long automation
