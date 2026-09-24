---
name: character-paper-doll
description: >-
  Idle Party owned hero paper-doll: undertunic body plus 128×128 gear overlays
  in GEAR, dungeon, and party HUD. Use when the doll looks wrong, gear is
  invisible, helm/hair is wrong, or when editing body_*.png / paintOwnedHero.
  Swedish: "dockan" / "gear syns inte" / "undertunic". Do not use for zone
  enemy art (zone-art-identity).
---

# Character paper-doll (Idle Party)

Legal: [assets-legal](../assets-legal/SKILL.md). Live look: [a56-playtest](../a56-playtest/SKILL.md).
Full contract: `docs/CHARACTER_VISUALS.md`.

GEAR, dungeon, and party HUD share `CharacterVisualPainter.paintOwnedHero`
(`CharacterVisualPose.resolve(..., owned: true)`). Do **not** add a second
painter, Kenney 16×16 stickers on owned bodies, or Offset sockets on armor.

## Root cause (why dolls looked weird)

Dart stacking was fine. Failures were in the **Python build**:

1. **Inventing art** (`ImageDraw` helms/capes/swords) while chest/legs came from
   `_src` → two styles in one doll.
2. **Destroying the gold-master face:** `strip_ink_black` wiped eye/outline
   pixels; `is_gold_pixel` matched peach skin; chest `head_max` cut off the
   gorget → hollow face + grey gap under the chin.

**Fix the cause:** copy head/armor from `_src` (or `_authored`); never invent
geometry; never classify warm skin as gold; keep dark pixels that touch art.

## Gold master

`assets/custom/char/<family>/_src/body_<anim>.png` is the **facit** for that
family’s dressed armor pose (no jewelry). A stack of undertunic + extracted
armor (+ mage/healer hat from `_src`) must **look like** that facit.

Weapons / shields are often **not** in `_src`. They need authored overlays under
`assets/custom/char/gear/` (or family gear). Do not call placeholder swords “done”.

## Workflow (mandatory order)

1. Drop / update dressed `_src/body_*.png` (owned art, same 128 origin).
2. Run `py tool/build_owned_gear_layers.py` — the **only** doll writer. It
   builds everything in `tool/out/doll_stage/char` (bodies with the face and
   haircut, cloth-only tint masks, t0/t2, short/broad styles, materials,
   class marks, icons, race clips), runs facit there, and leaves live art
   alone. `--publish` swaps a green build in, deletes orphans, and relocks.
   The file list is `tool/paper_doll_manifest.py`. Do not run
   `derive_armor_material_variants.py` or `make_gear_slot_icons.py` alone —
   they are build steps. There is no `derive_armor_variants.py` any more.
3. Inspect `tool/preview_doll_<family>.png` (armor stack). Must read as the same
   character as `_src`, not a grey mushroom head.
4. Rogue native leather (body + helm): `py tool/upgrade_native_body_src.py rogue`
   then `py tool/refresh_native_gear.py`. Mage/healer:
   `py tool/upgrade_native_body_src.py mage` (hat pixels are kept). Both only
   write inputs (`_src`, `_authored`); build and publish after.
5. `py tool/check_paper_doll_facit.py` checks live art: idle stack vs `_src`,
   face ownership, styles, manifest, and the lock. The build already ran it
   on the staged copy; publish relocks. Never relock over a red facit.

**Face ownership:** the body owns face, eyes, and haircut. Chest, legs,
cloak, and hands never paint them; helms keep the hair they cover and leave
a face window. If a composite drifts after removing face pixels from armor,
the body is missing them — fix `head_from_master`, do not put the face back
on the armor.

**Styles:** `short` and `broad` are drawn 128 masters in
`gear/_authored/{slot}_{style}_idle.png` (same origin, no face). Facit fails a
style that is t0 or t0 stretched. Replace a master by hand any time;
`tool/author_style_masters.py` never overwrites one without `--force`.
6. Hand art moved? `py tool/gen_owned_gear_grips.py`, then
   `py tool/audit_anchors.py` (findings must be empty).
7. Only then full `flutter run` on A56 (PNG bytes need a rebuild, not hot reload).
8. Dart tests prove paths/layers; **facit gate proves looks**.

For Must rules, authored overrides, and A56 checks, read
**[reference.md](reference.md)** when baking layers or a facit fails.

## Never

- Copy dressed `_src/body_*.png` onto live `body_*.png`
- Skip t0 chest/legs/cloak/hands (`_ownedLayerBakedInBody` is gone — keep it gone)
- Bbox-crop overlays (Unity jitter). Full 128, same origin as body
- Auto-strip armor luminance onto body (brown plate blocks)
- **Invent** helm / cape / chest / legs with `ImageDraw` shapes
- Ghost t0 on empty slots. Jewelry/flask on the body
- `py tool/process_char_bodies.py` on `gear/` or `_src/` (it crops)
- Declare done from “layer paths exist” alone — facit / preview must pass
- Tune placeholder ellipses to chase A56 symptoms

## Tests

```bash
py tool/build_owned_gear_layers.py
py tool/gen_owned_gear_grips.py   # only when hand art moved
py tool/check_paper_doll_facit.py # add --relock after deliberate art changes
py tool/audit_anchors.py
flutter test test/visual
```

Common chest must add a torso layer (`chest_t0_*.png`). Empty chest = body only.
Jewelry = no body layer. Every `OwnedGearAssets.allAssetPaths` file exists.
Facit gate must pass for all four families (idle stack vs `_src/body_idle`).
Dungeon walk/attack = poser body + same idle overlays as GEAR.
