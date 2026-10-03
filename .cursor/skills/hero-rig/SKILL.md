---
name: hero-rig
description: >-
  Idle Party in-game cutout skeleton for heroes. Use when a hero's limbs,
  weapons, or ability pose look wrong, when baking a family rig, or when the
  owner says skelettet i spelet, dockan rör sig fel, "delarna ser konstiga ut",
  or the rig. Do not use for seating a helm, chest, or pauldron
  (armor-placement), weapon grips (weapon-grip-placement), the
  outside-the-game demo (skeleton-demo), drawing gear pixels (gear-art),
  or one missing cast (add-ability).
---

# Hero rig (in the game)

This is the primary draw. Warrior, rogue, mage, and healer paint through
`lib/visual/rig/`. `paintOwnedHero` is the still paper doll: the fallback
until the part atlas is ready, and the picture the lookbook measures.
Form sprites are unchanged.

## Bake

```bash
py -3 tool/rig/bake_rig.py warrior
py -3 tool/rig/bake_rig.py all
```

Reads `assets/custom/char/<family>/_src/body_idle.png`. Writes
`assets/custom/rig/<family>.json` and previews `tool/out/rig/<family>_parts.png`
and `<family>_races.png`. Do not put rig files under `assets/custom/char/<family>/`
(the facit treats them as orphans). Do not edit live PNGs, `paper_doll_lock.json`,
or `owned_gear_grips.dart` by hand.

The parts picture is the dressed doll with a light bone tint. Head, arms,
and legs must sit on that body. A flat color block is the wrong view.

- A hat or hood above the shoulders is the whole head. The chin is not the skirt.
- The skirt is only the cloth below the sleeves. The chest stays the torso.
- A cloak stays on the torso. `arm_width` keeps only the outer limb as the arm.
  A cloak tip beside the pants stays on the body. The shoes stay feet.
- The bake must print `hand_r` and `hand_l`. A fist on `torso` means the arm
  is too thin. An empty pauldron is fine when the hood took those pixels.

## Tests

```bash
flutter test test/visual/rig_core_test.dart
flutter test test/visual/rig_rest_parity_test.dart
flutter test test/visual/rig_clip_quality_test.dart
```

Rest parity: empty, starter, and one broad/short loadout versus the paper doll,
at most 32 pixels apart once gear cracks are filled. Clip quality: no new small islands versus idle, and the
warrior sword grip stays on the bone under the fist.

## Sign table

Angles are screen-clockwise degrees. Mirror with flipX on the final image only.

| Bone | Negative | Positive |
|------|----------|----------|
| `upper_r` | out right | in across the chest |
| `upper_l` | in across the chest | out left |
| `thigh_l` | in | kick out left |
| `thigh_r` | kick out right | in |

Keep pauldron angles at 10 degrees or less. They share the upper-arm pivot.
Robe legs stay within 12 degrees.

## Gotchas

- Cut bones from `_src/body_idle.png`. Split the live undertunic and overlays
  with that map. The live body is the undertunic, not the dressed master.
- The weapon follows the bone that owns the idle fist pixel (`handBones`),
  not a gauntlet you assume is `hand_r`.
- Draw weapons last, in front of the body. The cape is one rigid piece on
  the torso, behind the body.
- Poses step at 16 fps into a 256 image, then scale with nearest-neighbor.
- A hands picture follows the arm even where the body map says chest, shoulder, or leg. A helm follows the head, including the brim. A chest collar that overlaps the chin stays on the head, or the face covers it.
- Ability poses live in `lib/visual/rig/rig_ability_clips.dart`. The actor's
  `animAbility` is visual only and is not saved. Other classes fall back to
  attack or cast.
