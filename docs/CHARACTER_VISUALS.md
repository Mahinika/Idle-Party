# Character visuals (layered dungeon heroes)

Idle Party heroes use a **paper-doll** path when an owned body is available:

1. **Undertunic base** from `assets/custom/char/<family>/body_<anim>.png`
   (skin + hair + simple cloth — never naked). Empty jewelry slots never
   draw on the body (same as WoW rings/neck).
   Spec color uses `body_tint_<anim>.png`, a generated **cloth-only** grayscale
   mask. Never color-filter the whole body: that recolors faces, hair and ink.
2. **Every equipped gear slot** is a 128×128 overlay on the same dest-rect
   (cape, legs, chest, gloves, helm, off-hand, main-hand). Overlays always
   use the **idle** PNG (`*_idle.png`); walk/attack only change the undertunic
   body clip (`body_walk` / `body_attack`). Common/t0 is visible — it is not
   baked into the body. Not Kenney 16×16 tiles.
3. Fallback: class PNG → Kenney paper-doll (Kenney overlays only there).

**GEAR, party HUD, and dungeon** all use `CharacterVisualPainter.paintOwnedHero`
with the same pose (`CharacterVisualPose.resolve(..., owned: true)`).

**Spec identity:** four bodies serve 31 specs, so the pose carries a `bodyTint`
from `HeroIdentity.ownedBodyTintArgb` — a modulate wash through the
**cloth-only mask** plus a thin cloth rim, so skin/hair and gear keep their
palette. Every spec has a color (unlike
`tintArgb`, which skips specs with unique class sprites).

Not one PNG per class×weapon. Items share looks via `visualSetId` (e.g.
legacy `sword_t1` → shipped `sword_t0`; named models keep authored colors).
Armor uses family extract `*_t0` plus palette-preserving derived `*_t2`
silhouettes, and **material variants** when `armorType` differs from the
family’s native look.

**Look axes (no extra loot fields):**

| Axis | Resolves to |
|------|-------------|
| `BodyFamily` | undertunic + native armor folder |
| `armorType` | material suffix when ≠ native (`*_mail_*`, `*_plate_*`, `*_leather_*`) |
| `visualSetId` | tier / named weapon stem (`chest_t0`, `sword_thunderfury`, …) |

Icon and doll share the same resolved stem (`EquipmentVisualResolver`).

| Body family | Native look | Cross-material PNGs (suffix) |
|-------------|-------------|------------------------------|
| warrior | plate (`chest_t0`) | **leather** (guardian druid) |
| rogue | leather | **mail** (hunter 40+, enhancement) |
| mage | cloth | **mail** (elemental), **leather** (druid) |
| healer | cloth | **plate** (holy), **mail** (resto), **leather** (druid) |

**Material shape language:** cloth = soft drape · leather = tight seams · mail =
coif/visor steel · plate = hard mass + trim. A hue-only recolor of the native
silhouette is a bug — facit requires opaque-mask diff vs native and at ~48 px.

Authored-first: `gear/_authored/{slot}_{material}_{tier}_idle.png` wins.
Mail helms remap warrior plate coif onto each family head (face punch). Body
slots remap donor family silhouettes, then material ramp. Fallback recolor only
when no donor exists.

Derived by `tool/derive_armor_material_variants.py`. Rogue native leather helm
(authored, no hat in `_src`) also refreshes via `tool/refresh_native_gear.py`.
Body slots stay `_src` extracts until gold masters are repainted. **Rarity = UI chrome**
(GEAR borders / text tint) — unique looks are authored PNGs, not orange doll
washes. Weapons: `*_t0` plus named models
(`sword_thunderfury`, `sword_emberfang`, `staff_voidspire`, …) — hue variants
from `tool/derive_weapon_hue_variants.py`.

Doll look = body family undertunic + overlay stem from `visualSetId` +
optional material suffix from equipped `armorType`.

## Art modes (mandatory)

| Mode | Source | Used for |
|------|--------|----------|
| Body extract | `_src` → `build_owned_gear_layers.py` | undertunic per anim; armor extract **idle only** |
| Armor tier | approved live `t0` → palette-preserving `t2` | rare silhouette; never global gold/orange wash |
| Authored weapon | `char/gear/_authored/` | shared weapons / shields / frills |
| Kenney / custom icons | `KenneyAssets` / `CustomAssets` | jewelry, flask, empty shoulder/waist slots |

Boots fold into legs on the doll; BAG uses a foot-band `boots_t*_icon.png` crop.

Do **not** invent armor or mass weapon variants with `ImageDraw` /
`generate_item_model_variants` mutate. That script only syncs authored
frames and rebuilds `*_icon.png` crops.

Slot / BAG icons: `*_icon.png` (bbox crop of the same idle overlay), built
by `tool/make_gear_slot_icons.py` at the end of `build_owned_gear_layers.py`.

## Pipeline

```text
PartyHero.gearAffinity → BodyFamilyCatalog → body_<anim>.png + cloth tint mask
PartyHero.equipped     → normalized visualSetId → OwnedGearAssets idle overlay
SpatialActor signals   → HeroAnimController → anim + frame
Canvas: paintOwnedHero (body + armor same dest rect; hand items
grip-aligned to owned anchors via `OwnedGearGrips`)
```

## Key types

| File | Role |
|------|------|
| `lib/visual/body_family.dart` | Owned denser body families + asset paths |
| `lib/visual/owned_gear_assets.dart` | 128 overlay path helpers |
| `lib/visual/hero_anim_state.dart` | `HeroAnimKind`, signals, pose |
| `lib/visual/hero_anim_controller.dart` | SM + `snapshot()` for paint |
| `lib/visual/character_layer.dart` | Layer ids + draw order |
| `lib/visual/equipment_visual_resolver.dart` | `visualSetId` → Kenney cell + owned path |
| `lib/visual/anchor_table.dart` | Per-frame hand anchors (Kenney + owned) |
| `lib/visual/owned_gear_grips.dart` | Grip UVs for owned weapons/shields |
| `lib/visual/character_visual_pose.dart` | Resolved layers for a frame |
| `lib/visual/character_visual_painter.dart` | `paintOwnedHero` / Kenney fallback |
| `lib/ui/hero_paper_doll.dart` | Kenney body/hair/armor cell picks |
| `lib/ui/hero_doll_sprite.dart` | GEAR / HUD doll |

Facing is **L/R flipX only**. Enemies unchanged in Phase 3.

## What paints on the body

- Cape, legs, torso, gloves, helm — full 128 same-origin blit (incl. common).
- Owned cape paints **after** body/armor (front wrap). Kenney keeps cape behind.
- Off-hand / main-hand — same 128 PNGs grip-aligned to owned hand
  anchors (`OwnedGearGrips`). Bake art to the socket with
  `py tool/bake_owned_hand_grips.py`, then `py tool/gen_owned_gear_grips.py`.
  Audit: `py tool/audit_anchors.py`.
  Grips are **opaque-pixel** points: handle centroid for melee/staves, shape
  mid-height for bows, shape centroid for shields/frills. A bbox center is
  empty air on diagonal art — that hung ten weapons beside the fist.
  A large shift onto the hand anchor is normal; the painter does not clip to
  the 128 box, so long weapons reach past the hero square.
- BAG/GEAR icons use `EquipmentVisualResolver.ownedIconPathFor` (same
  `resolveId` as the doll) so missing `visualSetId` still matches overlays.
- Empty slot = undertunic showing through. No ghost t0.
- Helm covers hair (hair lives in the body; no extra hair layer on owned).
- Neck, rings, trinkets, flask: slots only.
- Shoulders / belt fold into chest+legs art — `OwnedGearAssets.pathFor` is
  null for those stems (no extra PNG).

## Animation priority

`death > hit > attack|cast > walk > idle` (victory optional).

Walk/attack overlays fall back to `_idle.png` if a clip is missing.

`HeroAnimController` is **stateless** (`snapshot` only) — the dungeon repaints
from combat flash timers, so there is no per-hero clip clock.

**One body clip per anim**, so motion comes from the painter
(`CharacterVisualPainter.ownedStepOffset`, applied to the whole stack inside the
flip so "backward" follows facing):

| Clip | Body PNG | Painter motion |
|------|----------|----------------|
| walk | `body_walk` | step bob + weapon swing (`mainHandExtraRotation`) |
| attack | `body_attack` | swing rotation + view lean |
| cast | `body_attack` | slow float |
| hit | **`body_idle`** | short recoil away from facing |
| death | `body_idle` | none (0.35 opacity) |

`hit` must not fall back to `body_walk` — the stride read as a phantom step
every time a hero took damage.

## Adding a new item

1. Create loot via factory (stamps `visualSetId`) or set id to an existing set.
2. **Do not** add a Class×Weapon spritesheet.
3. Optional: add a new 128 overlay under `assets/custom/char/` and list it in
   `OwnedGearAssets`.

## Adding a body family / denser frame

1. Drop dressed `_src/body_<anim>.png` (gold master) then run
   `py tool/build_owned_gear_layers.py` — **extracts** undertunic + overlays from
   `_src`, and regenerates the cloth-only identity masks; never copies dressed
   `_src` onto body; never invents helm/cape with `ImageDraw`. Optional
   overrides: `gear/_authored/`. When only the mask contract changes, use
   `--tint-masks-only` so approved body/gear PNGs are not rewritten.
   When only armor tier derivation changes, use `--t2-only`; t2 is rebuilt from
   live t0 and old `_authored/*_t2` files remain archive inputs, not live wins.
2. Check `tool/preview_doll_<family>.png` (written by the facit script from **live**
   body+overlays), then `py tool/check_paper_doll_facit.py`. Facit does not
   depend on a previously generated preview file.
3. Register paths in `BodyFamilyCatalog`.
4. Do **not** paste Kenney tiles on denser bodies.
5. `py tool/process_char_bodies.py` skips `gear/` and `_src/`.

Full workflow: `.cursor/skills/character-paper-doll/SKILL.md`.

## Facit gate (`py tool/check_paper_doll_facit.py`)

1. Idle stack vs dressed `_src` per family (hard-diff ≤ 0.38) + helm width.
2. t2 and material variants exist, hold pixels, and keep the t0 silhouette.
3. Cross-material overlays differ from native in opaque mask (and at ~48 px
   squint). Mail/plate helms keep a face cutout.
4. Every body tint mask stays inside the body and outside face/hair.
4. Every `OwnedGearGrips` entry lands on opaque pixels.
5. `tool/paper_doll_lock.json` pins a hash per shipped PNG — any generator run
   that reshapes art fails here. After a **deliberate** art change, re-run with
   `--relock` and commit the lock.

## Performance

Pose layers cached per hero id until equip/**material**/**rarity**/spec/anim/
flip/owned changes; clip progress is refreshed on cache hits (`withAnim`) so
the step bob stays live. Dungeon precaches bodies + cloth tint masks +
`OwnedGearAssets.dollOverlayPaths` in parallel (soft-fail if a PNG is absent) —
**not** `allAssetPaths`, whose `*_icon` crops only GEAR/BAG draw.

## Manual A56 checks

- Two specs of the same class read as different colors (Frost DK vs Blood).
- Walking heroes bob and swing the weapon; a hit is a recoil, not a step.
- Weapons and shields sit **in the hand**, not beside it.
- Unequipped doll = undertunic (no plate / no wizard hat).
- Equip common chest → silhouette changes on GEAR **and** dungeon.
- Helm covers hair; mage hat is the helm overlay, not the base.
- GEAR doll: same helm / weapon / shield as dungeon for that hero.
- Flip when the party faces left (dungeon).
- Enemies still use prior art.
