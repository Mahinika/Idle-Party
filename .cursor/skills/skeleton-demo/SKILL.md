---
name: skeleton-demo
description: >-
  Runs and adjusts the outside-the-game warrior skeleton demo (rigid
  cutouts, sword, shield, ability clips). Use when the owner says skelett,
  skeleton demo, förmågor on the rig, svärdplacering, skölden sitter fel,
  or "titta igen" at tool/out/skel_demo. Do not use for the live paper doll
  (character-paper-doll), one kit cast (add-ability), or the fight sim
  (spatial-combat-change).
---

# Skeleton demo (outside the game)

The demo is not the doll. Do not edit `lib/`, live PNGs, or `owned_gear_grips.dart`.

| What | Where |
|------|--------|
| Player | `py -3 tool/skel_demo/play.py` |
| Grip sheet | `py -3 tool/skel_demo/play.py --marks` |
| Run / jump / swing film | `py -3 tool/skel_demo/play.py --gif` |
| Ability reel | `py -3 tool/skel_demo/play.py --abilities` |
| Ability film | `py -3 tool/skel_demo/play.py --abilities --gif` |

Output is gitignored under `tool/out/skel_demo/`. Commit only `tool/skel_demo/` sources. Check `--abilities` before `--gif` in `play.py`.

Plate source is `assets/custom/char/warrior/_src/body_idle.png`. The live `body_idle.png` is only the undertunic. Parts are rigid pictures, spun nearest-neighbor. Angles are screen-clockwise degrees.

## Placement

Image captions invent gaps and where a cross sits. Measure, then move.

1. Run `--marks`. Green box is the fist rectangle. Blue box is the brown handle. Yellow cross is the grip pixel.
2. Trust the printed counts and a color sample. The sword grip pixel is `(92, 62, 22)`. If the frame pixel at the cross is not that color, the cross is not on the handle.
3. "Inside the fist" means pixels on the hand sprite. The green rectangle is larger than the hand.
4. Shift the sword in `cut_warrior.py` `_fist(...)` by the source-pixel delta between the two box centers. Rebuild `--marks` and confirm the centers match before `--gif`.
5. A red mark on a screenshot: measure its distance from the green box center, divide by how many screenshot pixels one source pixel became (green box height in the shot divided by the fist height in pixels). Apply that many pixels. Do not guess from the caption.

The shield cross is the inner-rim attach, not the boss. A gap of 0 and a high overlap can already be right while the cross sits beside the hand. The doll's shield grip is the top rim, so do not copy it. The doll's sword rest is about 65 degrees and leans the blade out of this fist. The demo rest is 48 degrees. Game fist dots land on the forearms of this plate. Use the cut gauntlets.

Draw order is the body, then shield, then sword, so both weapons sit in front of the hands.

## Bones

Pauldron pivot is the top center of that upper arm. Keep pauldron angles small.

| Bone | Positive | Negative |
|------|----------|----------|
| `thigh_l` | kick out left | in |
| `thigh_r` | in | kick out right |
| `upper_l` | out left | in across the chest |
| `upper_r` | in across the chest | out right |
| `fore_r` | in | out |
| `shin_l` | out | fold in |

A tuck is `thigh_l` positive, `thigh_r` negative, `shin_l` negative, `shin_r` positive. Sword keys add to `restRot`.

## Abilities

Clips live in `tool/skel_demo/abilities.py`. Names and order match `lib/models/kits/warrior.dart`. Each clip is a readable pose, not the combat numbers. Add a name there, then render `--abilities --gif`.
