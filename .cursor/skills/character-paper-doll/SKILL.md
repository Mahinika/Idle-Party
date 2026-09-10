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
   It also gates t2 / mail / plate / leather variants (silhouette vs native +
   squint), mail/plate helm face cutouts, checks every grip lands on opaque
   pixels, and compares every shipped PNG against `tool/paper_doll_lock.json`.
   After a **deliberate** art change: `--relock`, then commit the lock file.
6. Hand art moved? `py tool/gen_owned_gear_grips.py`, then
   `py tool/audit_anchors.py` (findings must be empty; "reaches past the hero
   box" notes are fine — the painter does not clip).
7. Only then full `flutter run` on A56 (PNG bytes need a rebuild, not hot reload).
8. Dart tests prove paths/layers; **facit gate proves looks**.

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
- Own **body** PNG per idle/walk/attack. **Armor/weapon overlays** ship
  **idle-only** live PNGs (`OwnedGearAssets.pathFor` → `*_idle.png`). Do not
  regenerate live `*_walk` / `*_attack` overlays. Missing body clip → idle
  fallback, never Kenney on owned
- `hit` uses the **idle** body + painter recoil — not the walk stride
- Motion for the single clips lives in `ownedStepOffset` /
  `mainHandExtraRotation`, not in new PNGs
- Every spec gets a body wash (`HeroIdentity.ownedBodyTintArgb`) on the
  generated **cloth-only mask**; never filter the whole body (skin/hair/face
  ink stay original). Gear overlays keep their authored palette.
- Armor t2 may thicken/clarify t0 alpha but must keep its palette. Never apply
  a global gold/orange transform; `_authored/*_t2` is archive, not a live win.
- Grips must sit on **opaque** pixels (handle centroid; bows mid-shape).
  Never hand-edit `owned_gear_grips.dart` — regenerate it
- Dungeon precache uses `dollOverlayPaths`, not `allAssetPaths` (icons are
  GEAR/BAG only)
- Leftover walk/attack under `gear/_authored/` may exist as art archive — not
  shipped live overlays

## Authored overrides

Optional hand pixels (win over extract):

- `assets/custom/char/<family>/gear/_authored/<setId>_<anim>.png`
- `assets/custom/char/<family>/gear/_authored/<slot>_<material>_<tier>_<anim>.png`
  (cross-material masters — mail helm first)
- `assets/custom/char/gear/_authored/<setId>_<anim>.png` (shared weapons)

**Material matrix** (native → no suffix): warrior plate · rogue leather · mage/healer
cloth. Non-native needs PNG + `OwnedGearAssets.materialSuffix` in the same
commit. Silent native fallback for an allowed cross-material type is a bug.

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

## A56 (both surfaces) — only after preview + facit OK

- Unequipped chest = undertunic. Equip common chest → silhouette changes
- Helm covers hair; mage hat only when a helm is equipped
- Dungeon walk/attack heroes match GEAR gear (idle overlays on poser body)
