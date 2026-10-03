---
name: armor-placement
description: >-
  Seats Idle Party helms, chests, legs, cloaks, shoulders, and gloves on
  the cutout skeleton. Use when armor floats, a helm hides the face or
  misses the head, pauldrons hang in the air or ride the wrong bone, or
  the owner says "rustningen sitter fel", "hjälmen sitter fel", "axlarna
  svävar", "bröstet hänger", or "manteln". Do not use for weapon grips
  (weapon-grip-placement), drawing a new model (gear-art), baking a pose
  (hero-rig), or a broad doll audit (gear-lookbook).
---

# Armor on the skeleton

All four bodies paint through the cutout skeleton (`HeroRigFlags`). The
still paper doll is the fallback before that atlas is ready. The lookbook
paints the still doll, so a green sheet is the rest pose, not the moving
hero.

Each armor picture is one 128 overlay. The skeleton cuts it with the bone
map from `_src/body_idle.png`. A pixel follows the one bone that owns that
cell. Weapons follow the hand bone (`weapon-grip-placement`). The cape is
one rigid piece on the torso, behind the body.

## Where a piece has to land

- **Helm.** On the head bone. It keeps the hair it covers and leaves a
  face window. If the face is gone, the body is missing those pixels. Do
  not paint the face onto the helm.
- **Chest, legs, cloak.** On the torso. Robe legs stay on the skirt and on
  the leg bones below the hem.
- **Shoulders.** On the upper arm, sharing its pivot. A pad drawn beside
  the head rides the head, or misses the arm when it lifts. Keep pauldron
  angles at 10 degrees or less. Seat against idle, walk, and attack, not
  idle alone (`tool/paper_doll_seat.py`).
- **Gloves.** Short gloves move as one piece onto the hand, so a stripe
  stays a stripe. Other gloves stay put. Moving a glove moves the weapon
  palm. Follow `weapon-grip-placement` after that.

`LIFT`, `COVERED`, `FLOAT`, and `SPILL` judge the still stack only. Healer
and mage `chest_broad` SPILL is a known leftover. Leave it unless the
owner pointed at that chest.

## Diagnose

```bash
py -3 tool/gear_lookbook.py --armor
```

Read `measure.txt`, then `fit_summary.png`. That is the rest pose. Then
read `tool/out/rig/<family>_parts.png` after a bake. Head, shoulders, and
legs must sit on the body there.

- Still doll wrong, skeleton at rest also wrong: the picture's pixels are
  in the wrong place.
- Still doll fine, the arm lifts the wrong pixels: those pixels sit on the
  wrong bone.

## Fix

1. Move the authored pixels so they fall inside the right bone, or change
   the bone map in the baker. Do not edit rig JSON by hand.
2. `py -3 tool/rig/bake_rig.py all` when the bone map changed.
3. Rebuild pictures with `py -3 tool/build_owned_gear_layers.py` when the
   art changed. Publish only when the staged facit is green (`gear-art`).

## Verify

```bash
flutter test test/visual/rig_rest_parity_test.dart test/visual/rig_clip_quality_test.dart
py -3 tool/gear_lookbook.py --armor
py -3 tool/check_paper_doll_facit.py
flutter analyze lib test --no-fatal-infos
```

Rest parity: the standing skeleton stays within 32 pixels of the still
doll once gear cracks are filled. PNG and rig JSON need a full A56 restart
when the owner should look.

## Do not

- Do not treat the lookbook as the fight.
- Do not add a Dart offset.
- Do not copy `_src/body_*.png` onto the live body. Bones are cut from
  `_src`. The live body is the undertunic.
- Do not give one pixel two bones.
- Do not raise a mark limit to hide a float.
