---
name: weapon-grip-placement
description: >-
  Fixes Idle Party weapon, shield, tome, and off-hand placement on bare hands
  and worn gloves across every body and pose. Use when a weapon floats beside
  the hand, sits on the sleeve, misses the palm, or the owner says "vapnet
  sitter fel", "svävar bredvid handen", "kolla alla vapen", "placeringar på
  vapen", or "greppet". Do not use for helm, chest, legs, cloak, or
  shoulders (armor-placement), drawing a weapon model (gear-art), a broad
  doll audit (gear-lookbook), or ability animation poses (hero-rig).
---

# Weapon grip placement

The player sees the skeleton. The lookbook checks the still doll. A passing
`HAND` mark is not proof. The grip must cross the visible hand or the
painted glove palm in the pictures.

There are two different points. Do not make them the same number:

| Point | Source | Meaning |
|---|---|---|
| Bare fist | `lib/visual/anchor_table.dart` | Skin hand on the live undertunic |
| Worn palm | `tool/gen_owned_glove_tips.py` | Shift from that fist into the glove's painted palm |
| Rig hand | `tool/rig/families.py` | Pixel on the `hand_r` / `hand_l` bone, so a worn weapon follows the hand |

## Diagnose

```bash
py -3 tool/gear_lookbook.py --weapons
```

Read `measure.txt`, then `fit_summary.png`, `fit_weapons.png`, and
`fit_poses.png`. Those sheets wear the gloves. `{family}_weapons_a.png` and
`{family}_weapons_b.png` paint on the undertunic, so a gap there is not a
worn-glove bug.

- Every dressed body is wrong the same way: the shared point is wrong.
- One family is wrong: that family's fist, glove tip, or rig bone.
- One named model is wrong: its hilt pixel in `tool/gen_owned_gear_grips.py`
  or the authored picture (`gear-art`).
- Only bows are wrong: the painter already shifts bows out. Do not move the
  shared fist to fix a bow.
- Staff, polearm, bow, gun, and crossbow hide the off-hand. A missing shield
  there is intended.

## Fix

1. Keep the bare fist on the visible undertunic hand.
2. Change `anchor_table.dart` first. Glove tips are generated from those
   numbers.
3. In `tool/gen_owned_glove_tips.py`, hold inside the painted palm, several
   pixels in from the outer edge. Never use the far rim.
4. Run `py -3 tool/gen_owned_glove_tips.py`. Do not edit
   `lib/visual/owned_glove_tips.dart` by hand.
5. Bake only when the worn grip must follow a moving hand. Put the family
   fist in `tool/rig/families.py` on a pixel owned by `hand_r` / `hand_l`,
   then `py -3 tool/rig/bake_rig.py all`. A palm that lands on `fore_r` or
   `upper_r` is too high. Do not edit rig JSON by hand.

`HAND` / `OFF` counts the smaller of weapon pixels and body-or-glove pixels
inside the same disk (`test/visual/lookbook_measure.dart`). A floating weapon
must not pass just because it was painted at the floating point. Keep the 8 px
disk and the 6 px minimum in `tool/measure_lookbook.py`.

## Verify

After a glove-tip or anchor change:

```bash
py -3 tool/gear_lookbook.py --weapons
flutter test test/visual/rig_clip_quality_test.dart test/visual/rig_core_test.dart test/visual/character_pose_scenarios_test.dart
py -3 tool/audit_anchors.py
flutter analyze lib test --no-fatal-infos
```

After a rig bake or a change to the measure itself, also run:

```bash
py -3 tool/gear_lookbook.py --all
py -3 tool/check_paper_doll_facit.py
flutter test test/visual --exclude-tags sim
```

Done means no `HAND` or `OFF` marks, and the worn grips cross the palms in
idle, walk, windup, strike, and cast on all four bodies. Restart the A56
when the owner should look. PNG and rig JSON need a full restart, not hot
reload.

## Do not

- Do not redraw weapon pixels when the shared point is wrong.
- Do not move the bare fist onto the gauntlet. Use the worn-glove shift.
- Do not lower a mark limit or widen a test tolerance to hide a float.
- Do not treat the undertunic weapon sheets as the dressed result.
