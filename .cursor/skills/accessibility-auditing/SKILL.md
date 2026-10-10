---
name: accessibility-auditing
description: >-
  Audits Idle Party a11y: Semantics/WebClickBridge labels, text scale,
  colorblind mode, Minimal VFX as reduce-motion, touch targets. Use after UI
  chrome changes, or when labels, a11y, or reduce motion feel missing
  ("knappen går inte att trycka", "för liten text"). Do not use for general
  hub polish (hub-smoke).
---

# Accessibility auditing (Idle Party)

## Checks

1. **Semantics / automation labels** — interactive controls use `KenneyButton` or `WebClickScope` + matching `Semantics`; decorative full-bleed art under `ExcludeSemantics`.
2. **Hub/dungeon smoke** — the `adb_see.py` dump (or `__idlePartyButtons()` on web) lists ENTER DUNGEON / GEAR / GOLD / SHOP / ESSENCE / MORE / KEY (endgame) / LEAVE (dungeon) / God Hand; no silent unlabeled primary CTAs.
3. **Settings** — ui text scale + colorblind mode still reachable; Minimal VFX copy reads as reduce-motion.
4. **Touch** — primary CTAs meet `GameTheme.minTouch` / `primaryTouch` where applicable.
5. **Color** — combat floaters respect colorblind palette path in SpatialCombat when enabled.
6. **Contrast** — parchment on stone panels remains readable in screenshots.

## How

1. On the A56 (`a56-playtest`): `py -3 tool/adb_see.py` dumps every label,
   center, and bounds. A primary control with no label is a blocker.
2. Same screens on an endgame save: the hub `KEY` button must be in the dump.
3. Settings: text scale, colorblind mode, and the VFX cycle
   (`VfxQuality.settingsLabel`, `Minimal VFX (reduce motion)`) are reachable.
4. Touch size: anything under `GameTheme.minTouch` (44 dp) in the dump is a finding.
5. Web fallback only (`browser-playtest`): `window.__idlePartyButtons()`.
6. Code check for taps without a label:

```bash
rg "GestureDetector" lib/ui --glob "*.dart" -l
```

## Done when

- Blockers (cannot activate, no label, under 44 dp) are fixed or written under Open in `docs/PLAY_NOTES.md`.
- Polish (copy, contrast) is listed separately.
- UI changed: `flutter test test/ship_smoke_test.dart test/first_hour_plain_test.dart` is green.
