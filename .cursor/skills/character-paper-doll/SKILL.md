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
2. Run `py tool/build_owned_gear_layers.py` — **extract armor from `_src/body_idle`
   only**; walk/attack rebuild undertunic bodies plus cloth-only
   `body_tint_<anim>` masks. No `ImageDraw` helms or capes. Use
   `--tint-masks-only` when approved body/gear art must stay byte-identical.
   Live t2 armor is palette-preserving derivation from approved t0; use
   `--t2-only` to refresh it without rebuilding bases.
3. Inspect `tool/preview_doll_<family>.png` (armor stack). Must read as the same
   character as `_src`, not a grey mushroom head.
4. Rogue native leather (body + helm): `py tool/upgrade_native_body_src.py` then
   `py tool/refresh_native_gear.py`. Cross-material: `derive_armor_material_variants.py`.
   Mage/healer native body still uses `_src` hat extract until a hat-aware bake exists.
5. Run `py tool/check_paper_doll_facit.py` — composites **live** body+overlays
   vs `_src` (no gitignored preview required). Fail if idle armor stack drifts.
   After a **deliberate** art change: `--relock`, then commit the lock file.
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
