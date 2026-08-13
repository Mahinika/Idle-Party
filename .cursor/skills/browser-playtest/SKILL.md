---
name: browser-playtest
description: >-
  Playtests Idle Party in Cursor's browser (look → click → think) via Flutter
  web + WebClickBridge. Use when the user asks to play, playtest, click through
  the UI, manually verify hub/dungeon/Gauntlet flows, or automate browser QA.
---

# Browser playtest (Idle Party)

Flutter CanvasKit has no real DOM widgets. Cursor often cannot send trusted CDP
`Input.*` mouse events. Idle Party exposes semantics + `WebClickBridge` so the
agent can see screenshots and drive buttons.

## Phone viewport (mandatory)

Idle Party ships **phone-only**. Owner reference device: **Samsung Galaxy A56**
(1080×2340 @ DPR 3 → **360×780** CSS px). Never playtest at desktop/tablet width.

After every navigate / restart / new tab, before judging UI:

```
Emulation.setDeviceMetricsOverride
  width: 360, height: 780, deviceScaleFactor: 3, mobile: true
  screenWidth: 360, screenHeight: 780
Emulation.setTouchEmulationEnabled { enabled: true, maxTouchPoints: 5 }
```

Optional UA: `Mozilla/5.0 (Linux; Android 15; SM-A566B) … Mobile Safari/537.36`

Confirm: `window.innerWidth === 360` (and height ≈ 780). If wider → re-apply metrics.

## Loop

1. Serve web (repo root):

```bash
flutter run -d web-server --web-hostname=localhost --web-port=8080
```

2. Open Cursor browser → `http://localhost:8080/`
3. **Apply A56 phone metrics** (section above) — do this every session
4. Wait ~3–4s for load + start-menu input unlock (900ms)
5. `browser_lock` → screenshot / `browser_snapshot` → click → repeat
6. `browser_unlock` when done

## Click order (prefer this)

1. **`browser_click`** on a button ref from `browser_snapshot`  
   Works when semantics + `WebClickBridge` are live (`ensureSemantics` + install in `main.dart`).
2. **Bridge API** if click no-ops (CDP `Runtime.evaluate`):

```js
window.__idlePartyButtons()           // registered labels
window.__idlePartyClick('ENTER DUNGEON')  // true if handled
window.__idlePartyTap(x, y)           // map / coordinate tap (logical px)
```

3. **Playwright** only as last resort (`tool/playtest_al3.py`, `tool/playwright_newgame_test.py`) — real OS mouse path.

Do **not** rely on raw canvas coordinate clicks alone; full-bleed art used to steal hits.

## Typical path

| Step | Action |
|------|--------|
| Title | `CONTINUE` or `NEW GAME` → `START` (confirm `OVERWRITE` if prompted) |
| Tips | `SKIP ALL TIPS` or `GOT IT` |
| Hub | `ENTER DUNGEON` |
| Dungeon | `FARM dungeon mode` / `PUSH dungeon mode`, `God Hand ready`, `Use healing flask`, `PARTY` / `POWER` / `META` / `HUB` |

After each click: wait briefly, new snapshot/screenshot, then decide. Stop after ~4 failed attempts on the same control; report what you saw.

## Wiring new clickable UI

For any control you want automation to press:

1. Prefer `KenneyButton` (already registers + `Semantics(onTap:)`).
2. Else wrap with `WebClickScope(label: …, onPressed: …)` and set matching `Semantics(label:, onTap:, button: true)`.
3. Keep decorative full-bleed art behind `ExcludeSemantics` (`CaveAtmosphere.fullBleedScene` already does).
4. Label must be stable and match what appears in the a11y tree / `__idlePartyButtons()`.

Key files: `lib/ui/web_click_bridge.dart`, `web_click_bridge_web.dart`, `kenney_button.dart`, `main.dart` (`ensureSemantics` + `WebClickBridge.install()`).

## Sanity checks

```js
typeof window.__idlePartyClick     // "function"
window.__idlePartyButtons()        // non-empty after UI mounts
!!window.__idlePartyDomHooked      // true after install (DOM capture hook)
window.__idlePartySetSpeed(10)     // debug combat speed (1–20); returns applied
window.__idlePartyGetSpeed()       // current multiplier
```

Settings (debug builds): **DEV: SPEED 1x (tap → 10x)** toggles the same knob.

If bridge missing: hard-reload after `flutter run` (hot restart may be enough; full relaunch if not).

## Faster playtests

After boot, set `window.__idlePartySetSpeed(10)` so combat runs ~10 sim steps per frame. Keep UI clicks at normal cadence; only dungeon combat is accelerated.

## Hub polish smoke

After hub / What’s New / weekly / guides changes, follow **hub-smoke** (`.cursor/skills/hub-smoke/SKILL.md`) — short checklist for MORE badge, weekly n/3, LOADOUTS, and God Hand tip.

## Pitfalls

- **Title CONTINUE disabled** in a fresh browser profile with no save — use `NEW GAME`.
- **Start menu** ignores input for ~900ms (`_inputUnlocked`).
- **Screenshot coords ≠ layout coords** if the tab is scaled; prefer refs / bridge labels over XY.
- **God Hand on map** needs a point → `God Hand ready` (focus cast) or `__idlePartyTap(x,y)`.
- CDP `Input.*` is blocked in Cursor — do not waste time on raw CDP mouse dispatch.

## Progress

```
Browser playtest:
- [ ] web-server on :8080
- [ ] browser open + **A56 phone metrics (360×780)**
- [ ] bridge live
- [ ] lock → snapshot
- [ ] drive target flow (click or __idlePartyClick)
- [ ] screenshot evidence of result
- [ ] unlock
```
