---
name: gear-art
description: >-
  Idle Party gear art: one pixel style for weapons, armor, icons, and the
  paper doll. Use when gear looks inconsistent, two swords look the same,
  the BAG icon does not match the doll, or the owner says "gear ser olika
  ut", "två svärd ser likadana ut", "ikonen matchar inte dockan", "ny
  vapenmodell", or "ny hjälm". Do not use for the body pipeline
  (character-paper-doll), enemy sprites (enemy-art), or a cave that looks
  like its neighbor (zone-art-identity).
---

# Gear art (Idle Party)

Numbers live in `tool/gear_style.py`. The rule is
`.cursor/rules/gear-art-standard.mdc`. The doll pipeline is
`character-paper-doll`. This skill is only the gear picture.

## Workflow

1. Write a one-line `hook` that says what makes this model a different
   shape from the others in its family.
2. Draw the recipe in `tool/author_gear_standard.py` (hands) or a motif
   in `tool/author_snap_ons.py` (helms and shoulders). It writes
   `_authored` only.
3. `py -3 tool/build_owned_gear_layers.py` stages the art and runs the
   facit. Look at `tool/out/facit/` if a contact sheet was written.
4. `py -3 tool/check_paper_doll_facit.py --no-lock --only style,unique,proportion,icon_parity`
   with `IDLE_PARTY_CHAR_ROOT` pointed at the stage.
5. Check that the piece sits on the body with skill `gear-lookbook`
   (`py -3 tool/gear_lookbook.py`). The A56 lookbook (MORE → SETTINGS →
   DEV: GEAR LOOKBOOK) is for when the owner should look. PNG changes
   need a full `flutter run`, not hot reload.
6. `py -3 tool/build_owned_gear_layers.py --publish` only when the staged
   facit is green. Then `py -3 tool/audit_anchors.py` if a hand item moved.

## Do not

- Recolor a model and call it new.
- Write a live PNG from a one-off script.
- Paint the face or the hair on a gear layer.
- Lower a threshold in `tool/gear_style.py` to go green.
- Add rows to `tool/facit_known_debt.json`.
