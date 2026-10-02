---
name: hero-rig
description: >-
  Idle Party in-game cutout skeleton for heroes. Use when a hero's limbs,
  weapons, or ability pose look wrong, when baking a family rig, or when the
  owner says skelettet i spelet, dockan rör sig fel, or the rig. Do not use
  for the outside-the-game demo (skeleton-demo), drawing gear pixels
  (gear-art), or one missing cast (add-ability).
---

# Hero rig (in the game)

The live families in `HeroRigFlags` paint through `lib/visual/rig/`.
`paintOwnedHero` is the fallback until the part atlas is ready, and for any
family not in the flag set. Form sprites are unchanged.

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

Look at the parts preview before adding a family to `HeroRigFlags`. Head, arms,
and legs must sit on the body. Robes need a `skirt` bone and legs only below
the hem.

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
- Each pixel has one bone. A second owner darkens soft cloth at rest.
- Ability poses live in `lib/visual/rig/rig_ability_clips.dart`. The actor's
  `animAbility` is visual only and is not saved. Other classes fall back to
  attack or cast.
