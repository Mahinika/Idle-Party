---
name: accessibility-auditing
description: >-
  Audit Idle Party a11y: Semantics/WebClickBridge labels, text scale, colorblind
  mode, Minimal VFX as reduce-motion, touch targets. Use after UI chrome changes.
---

# Accessibility auditing (Idle Party)

## Checks

1. **Semantics / automation labels** — interactive controls use `KenneyButton` or `WebClickScope` + matching `Semantics`; decorative full-bleed art under `ExcludeSemantics`.
2. **Hub/dungeon smoke** — `__idlePartyButtons()` lists ENTER / MORE / GEAR / God Hand; no silent unlabeled primary CTAs.
3. **Settings** — ui text scale + colorblind mode still reachable; Minimal VFX copy reads as reduce-motion.
4. **Touch** — primary CTAs meet `GameTheme.minTouch` / `primaryTouch` where applicable.
5. **Color** — combat floaters respect colorblind palette path in SpatialCombat when enabled.
6. **Contrast** — parchment on stone panels remains readable in screenshots.

## How

- Browser: snapshot aria tree + screenshots (see `browser-playtest`)
- Code: grep new buttons for raw `GestureDetector` without Semantics

## Report

List blockers (can't activate / no label) vs polish (copy, contrast).
