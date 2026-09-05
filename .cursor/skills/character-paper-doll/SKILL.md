---
name: character-paper-doll
description: >-
  Idle Party owned hero paper-doll: undertunic body plus 128×128 gear
  overlays (same dest-rect) in GEAR, dungeon, and party HUD. Use when the
  doll looks wrong, equipped gear is invisible, helm/hair is wrong, mage
  hat sits on the base, common chest does nothing, or when editing
  body_*.png, char/gear overlays, paintOwnedHero, or CharacterVisualPose.
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
2. Run `py tool/build_owned_gear_layers.py` — **extract / stamp from `_src` only**
   for body + armor + hat/hood. No `ImageDraw` helms or capes.
3. Inspect `tool/preview_doll_<family>.png` (armor stack). Must read as the same
   character as `_src`, not a grey mushroom head.
4. Run `py tool/check_paper_doll_facit.py` — fail if armor stack drifts from `_src`.
5. Only then full `flutter run` on A56 (PNG bytes need a rebuild, not hot reload).
6. Dart tests prove paths/layers; **facit gate proves looks**.

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

## Must

- Base = family undertunic (cloth + hair + face, never naked). Mage base has **no** wizard hat
- Equipped cape / legs / chest / gloves / helm / off-hand / main-hand all paint, **including common**
- Mage/healer helm = **extracted** hat/hood from `_src`
- Warrior/rogue: `_src` has **no helm** → use `gear/_authored/helm_t0_*.png`
  when present (already shipped). Do **not** invent a metal stamp/ellipse
- Cape = extracted pixels only (rogue/mage cape from `_src` / authored). Empty
  extract → transparent or authored — not a drawn trapezoid. Live thicken for
  readability must **not** overwrite `_authored` masters
- 2H hides off-hand. Legs win over boots (BAG boots icon = foot-band crop).
  Shoulders/waist fold into chest+legs (`pathFor` null)
- Own PNG per idle/walk/attack. Missing clip → idle fallback, never Kenney on owned

## Authored overrides

Optional hand pixels (win over extract):

- `assets/custom/char/<family>/gear/_authored/<setId>_<anim>.png`
- `assets/custom/char/gear/_authored/<setId>_<anim>.png` (shared weapons)

## Tests

```bash
py tool/build_owned_gear_layers.py
py tool/check_paper_doll_facit.py
flutter test test/visual/character_pose_scenarios_test.dart \
  test/visual/equipment_visual_resolver_test.dart \
  test/visual/body_family_test.dart
```

Common chest must add a torso layer (`chest_t0_*.png`). Empty chest = body only.
Jewelry = no body layer. Every `OwnedGearAssets.allAssetPaths` file exists.
Facit gate must pass for all four families × idle.

## A56 (both surfaces) — only after preview + facit OK

- Unequipped chest = undertunic. Equip common chest → silhouette changes
- Helm covers hair; mage hat only when a helm is equipped
- Dungeon heroes match the GEAR doll (same overlays). Party HUD may look clumpy
