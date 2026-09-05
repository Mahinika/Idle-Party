# Character visuals (layered dungeon heroes)

Idle Party heroes use a **paper-doll** path when an owned body is available:

1. **Undertunic base** from `assets/custom/char/<family>/body_<anim>.png`
   (skin + hair + simple cloth — never naked). Empty jewelry slots never
   draw on the body (same as WoW rings/neck).
2. **Every equipped gear slot** is a 128×128 overlay on the same dest-rect
   (cape, legs, chest, gloves, helm, off-hand, main-hand). Common/t0 is
   visible — it is not baked into the body. Not Kenney 16×16 tiles.
3. Fallback: class PNG → Kenney paper-doll (Kenney overlays only there).

**GEAR, party HUD, and dungeon** all use `CharacterVisualPainter.paintOwnedHero`
with the same pose (`CharacterVisualPose.resolve(..., owned: true)`).

Not one PNG per class×weapon. Items share looks via `visualSetId` (e.g.
`sword_t1` → `sword_t0` art + rarity tint). Armor uses family extract
`*_t0` / `*_t2`, plus **material variants** when `armorType` differs from the
family’s native look:

| Body family | Native look | Extra material PNGs |
|-------------|-------------|---------------------|
| warrior | plate (`chest_t0`) | — |
| rogue | leather | **mail** (`chest_mail_t0`, …) |
| mage | cloth | — |
| healer | cloth | **plate** (`chest_plate_t0`, …) |

Derived by `tool/derive_armor_material_variants.py` (recolor/thicken existing
alpha — no new geometry). Weapons use `*_t0` plus authored models
(`sword_thunderfury`, `sword_warglaive`, `sword_runebound`, `staff_frostfire`,
`staff_nethercore`, `bow_eagle`, `bow_windpierce`, `axe_goreblade`,
`axe_bloodhowl`, `mace_lightbringer`, `mace_dawnbreak`, `dagger_shadowfang`,
`dagger_nightbite`, `shield_aegis`, `shield_ironwall`, `frill_prism`,
`frill_soulcodex`).

Doll look = body family undertunic + overlay stem from `visualSetId` +
optional material suffix from equipped `armorType`.

## Three art modes (mandatory)

| Mode | Source | Used for |
|------|--------|----------|
| Body extract | `_src` → `build_owned_gear_layers.py` | undertunic, helm/chest/legs/cloak/hands |
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
PartyHero.gearAffinity → BodyFamilyCatalog → body_<anim>.png
PartyHero.equipped     → visualSetId → OwnedGearAssets path + rarity tint
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

## Adding a new item

1. Create loot via factory (stamps `visualSetId`) or set id to an existing set.
2. **Do not** add a Class×Weapon spritesheet.
3. Optional: add a new 128 overlay under `assets/custom/char/` and list it in
   `OwnedGearAssets`.

## Adding a body family / denser frame

1. Drop dressed `_src/body_<anim>.png` (gold master) then run
   `py tool/build_owned_gear_layers.py` — **extracts** undertunic + overlays from
   `_src`; never copies dressed `_src` onto body; never invents helm/cape with
   `ImageDraw`. Optional overrides: `gear/_authored/`.
2. Check `tool/preview_doll_<family>.png`, then `py tool/check_paper_doll_facit.py`.
3. Register paths in `BodyFamilyCatalog`.
4. Do **not** paste Kenney tiles on denser bodies.
5. `py tool/process_char_bodies.py` skips `gear/` and `_src/`.

Full workflow: `.cursor/skills/character-paper-doll/SKILL.md`.

## Performance

Pose layers cached per hero id until equip/anim/flip/owned flag changes.
Dungeon precaches body + overlay paths (soft-fail if a PNG is absent).

## Manual A56 checks

- Unequipped doll = undertunic (no plate / no wizard hat).
- Equip common chest → silhouette changes on GEAR **and** dungeon.
- Helm covers hair; mage hat is the helm overlay, not the base.
- GEAR doll: same helm / weapon / shield as dungeon for that hero.
- Flip when the party faces left (dungeon).
- Enemies still use prior art.
