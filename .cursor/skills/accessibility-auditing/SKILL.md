---
name: accessibility-auditing
description: >-
  Audits Idle Party a11y: Semantics/WebClickBridge labels, text scale, colorblind
  mode, Minimal VFX as reduce-motion, touch targets. Use after UI chrome changes
  or when labels, a11y, or reduce motion feel missing. Do not use for general hub polish
  (hub-smoke).
---

# Accessibility auditing (Idle Party)

## Checks

1. **Semantics / automation labels** — interactive controls use `KenneyButton` or `WebClickScope` + matching `Semantics`; decorative full-bleed art under `ExcludeSemantics`.
2. **Hub/dungeon smoke** — `__idlePartyButtons()` lists ENTER / GEAR / GOLD / SHOP / ESSENCE / MORE / LEAVE (dungeon) / God Hand; no silent unlabeled primary CTAs.
3. **Settings** — ui text scale + colorblind mode still reachable; Minimal VFX copy reads as reduce-motion.
4. **Touch** — primary CTAs meet `GameTheme.minTouch` / `primaryTouch` where applicable.
5. **Color** — combat floaters respect colorblind palette path in SpatialCombat when enabled.
6. **Contrast** — parchment on stone panels remains readable in screenshots.

## How

- Live look: A56 emulator (`a56-playtest`). Agent aria dump: `browser-playtest` fallback.
- Bridge dump (web fallback):

```js
window.__idlePartyButtons()
```

- Code grep for raw `GestureDetector` without Semantics:

```bash
rg "GestureDetector" lib/ui --glob "*.dart" -l
```

## Report

List blockers (can't activate / no label) vs polish (copy, contrast).
