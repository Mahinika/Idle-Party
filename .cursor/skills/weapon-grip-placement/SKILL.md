---
name: weapon-grip-placement
description: >-
  Fixes Idle Party weapon, shield, tome, and off-hand placement on bare hands
  and worn gloves across every body and pose. Use when a weapon floats beside
  the hand, sits on the sleeve, misses the palm, or the owner says "vapnet
  sitter fel", "kolla alla vapen", "placeringar på vapen", or "greppet".
  Do not use for drawing a weapon model (gear-art), a broad doll audit
  (gear-lookbook), or ability animation poses (hero-rig).
---

# Weapon grip placement

The grip must cross the visible hand or painted glove palm. Passing a check
because the weapon is near its own requested anchor is not enough.

## Workflow

1. Read `docs/PLAY_NOTES.md` Open.
2. Render the baseline:

```bash
py -3 tool/gear_lookbook.py --weapons
```

3. Read:
   - `tool/out/lookbook/measure.txt`
   - `fit_summary.png`
   - `fit_weapons.png`
   - `fit_poses.png`
   - `{family}_weapons_a.png` / `{family}_weapons_b.png` only where needed
4. Isolate the bad layer:
   - Bare hand wrong → `lib/visual/anchor_table.dart`
   - Worn glove wrong → `tool/gen_owned_glove_tips.py`
   - Moving rig loses the grip → `tool/rig/families.py` and rig tests
   - One model's hilt has no usable grip pixel → `tool/gen_owned_gear_grips.py`
     or its authored gear recipe
5. Keep the bare fist on the visible undertunic hand. For a worn glove,
   generate a shift into the painted palm, several pixels inside the outer
   edge. Never seat the grip on the far rim.
6. Regenerate; do not hand-edit generated output:

```bash
py -3 tool/gen_owned_glove_tips.py
py -3 tool/rig/bake_rig.py all
```

7. Re-render and inspect all four bodies and all five poses. Named models
   share placement rules but still inspect both weapon detail sheets.

## Measurement contract

`HAND` / `OFF` must require both:

- weapon pixels inside the grip disk; and
- body or glove pixels inside the same disk.

This prevents a self-referential test where a floating weapon passes merely
because it was painted at the floating anchor. Keep the thresholds in
`tool/measure_lookbook.py`; fix placement instead of lowering them.

## Verify

```bash
py -3 tool/gear_lookbook.py --all
py -3 tool/check_paper_doll_facit.py
py -3 tool/audit_anchors.py
flutter test test/visual --exclude-tags sim
flutter analyze lib test --no-fatal-infos
```

Done means:

- no `HAND` or `OFF` marks across all measured weapon dolls;
- grips visually cross palms in idle, walk, windup, strike, and cast;
- rig grip tests, facit, anchor audit, visual tests, and analyze are green.

If the owner should inspect it, restart the A56 after the batch.

## Do not

- Do not move weapon PNG pixels when the shared anchor is the problem.
- Do not move the bare fist to an armored hand; use the worn-glove shift.
- Do not hand-edit `owned_glove_tips.dart` or rig JSON.
- Do not lower mark limits or widen tolerances to hide a floating weapon.
