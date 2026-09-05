---
name: verifying-in-browser
description: >-
  After UI/hub/dungeon chrome, verify on the Samsung A56 emulator
  (a56-playtest). Browser/WebClickBridge is fallback only. Use after
  hub/meta/UI edits.
---

# Verify live UI (Idle Party)

**Default:** [a56-playtest](../a56-playtest/SKILL.md) — Samsung A56 emulator,
one `flutter run`, look at the emulator window.

Do **not** start Flutter web for a human look. Do **not** open localhost:808x.

## Steps

1. Follow **a56-playtest** (reuse an attached `flutter run` if it exists).
2. Hot restart (`R`) after menu/copy changes so labels match the build.
3. Exercise the changed flow on the emulator (tap, not hover).
4. Hub polish checklist → **hub-smoke** (same device).

## Fallback (agent clicks only)

If Android cannot run, or you need `WebClickBridge` / Playwright:

1. `flutter run -d web-server --web-hostname=localhost --web-port=8080` — **one**
   port, never a pile of 8082–8088.
2. Cursor browser + CDP **360×780** (see [browser-playtest](../browser-playtest/SKILL.md)).
3. Drive with `__idlePartyClick('…')`.

## Don't

- Raw CDP `Input.*` mouse (blocked in Cursor)
- Treat a wide desktop Chrome window as the product
- Tell the owner “refresh 8088” after code landed on the emulator
