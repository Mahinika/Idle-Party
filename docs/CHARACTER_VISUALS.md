# Character visuals (layered dungeon heroes)

Idle Party heroes use a **paper-doll** path when an owned body is available:

1. **Undertunic base** from `assets/custom/char/<family>/body_<anim>.png`
   (skin + hair + simple cloth — never naked). Race/sex clips sit beside
   that file as `<race>_<m|f>_body_<anim>.png` for every family × 12 races ×
   both sexes. Family `body_*.png` matches male Human; do not treat a
   missing race file as a Kenney fallback.
   Empty jewelry slots never draw on the body (same as WoW rings/neck).
   Spec color uses `body_tint_<anim>.png` (or `<race>_<m|f>_body_tint_<anim>.png`),
   a generated **cloth-only** grayscale mask. Never color-filter the whole body:
   that recolors faces, hair and ink.
2. **Every equipped gear slot** is a 128×128 overlay on the same dest-rect
   (cape, legs, chest, gloves, helm, off-hand, main-hand). Overlays always
   use the **idle** PNG (`*_idle.png`); walk/attack only change the undertunic
   body clip (`body_walk` / `body_attack`). Common/t0 is visible — it is not
   baked into the body. Not Kenney 16×16 tiles.
3. Fallback: class PNG → Kenney paper-doll (Kenney overlays only there).

**Exception — unique form sprites:** when
`CustomAssets.hasUniqueHeroSprite(specId)` is true (Shadow; Druid Balance
moonkin, Feral cat, Guardian bear, Restoration tree), dungeon / GEAR / party
HUD draw the owned 96×96 form PNG from `assets/custom/heroes/` instead of the
paper-doll stack. **No gear overlays** on form bodies — the silhouette is the
kit identity. Generated via `tool/gen_druid_form_sprites.py` for moonkin/tree;
feral/guardian/shadow are authored.

**GEAR, party HUD, and dungeon** all use `CharacterVisualPainter.paintOwnedHero`
with the same pose (`CharacterVisualPose.resolve(..., owned: true)`) when on
the paper-doll path (not form sprites).

**Spec identity:** four bodies serve 31 specs. The owned body is drawn as
authored, so skin, hair, and cloth keep that picture's palette.

Not one PNG per class×weapon. Items share looks via `visualSetId` (e.g.
legacy `sword_t1` → shipped `sword_t0`; named models keep authored colors).

**Four cuts per armor slot** (helm, chest, legs, cloak, hands):

| Cut | Source |
|-----|--------|
| `t0` plain | extract from `_src` (or `_authored/{slot}_t0`) |
| `t2` late | t0 grown, palette kept |
| `short` | authored `_authored/{slot}_short_idle.png` — brow band, vest, breeches, capelet, cuff |
| `broad` | authored `_authored/{slot}_broad_idle.png` — wide rim, pauldrons, skirt, hooded cloak, gauntlet |

Loot stamps one of the four (`chest_short`). Material (`*_plate_*` …) and
class marks resolve at paint. Old saves: `{slot}_v00…v04` → t0, `v05…v09` →
t2, `v10…v14` → short, `v15…v19` → broad, `wide` → broad, `slim` → short
(`OwnedGearAssets.legacyArmorCut`). Short and broad keep their own palette
(no rarity wash) and borrow the plain cut's BAG icon.

**The face lives on the body.** The undertunic carries the master's face,
eyes, and haircut (`head_from_master`). No armor overlay paints those pixels;
helms keep the hair they cover and leave a transparent face window.

**Look axes (no extra loot fields):**

| Axis | Resolves to |
|------|-------------|
| `BodyFamily` | gear pose + overlay atlas (warrior / healer / mage / rogue) |
| `HeroRace` + `HeroSex` | undertunic clip (`<race>_<m|f>_body_<anim>.png`) for every shipped race. Old saves default Human; sex follows family (healer female). |
| `armorType` | material suffix when ≠ native (`*_mail_*`, `*_plate_*`, `*_leather_*`) |
| `visualSetId` | armor cut / named weapon stem (`chest_t0`, `chest_broad`, `sword_thunderfury`, …) |
| class | paladin / death knight mark on warrior helm+chest, warlock on mage helm+chest (`*_paladin_*`) |

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

Authored-first: `gear/_authored/{slot}_{material}_{cut}_idle.png` wins. A
hand-drawn plain cut grows its own late cut. Otherwise every cut takes the
donor family that owns the material's shape (warrior for plate and mail,
rogue for leather), moved onto the body by landmarks — chin to chin and feet
to feet, helms by the face — then the material ramp. A donor is never
stretched to the whole body box.

Class marks: the family's cut in the class palette plus a small authored
emblem `gear/_authored/{slot}_{mark}_mark_idle.png`, clipped to the piece.

Rogue, mage, and healer native armor can rebake the gold master through
`tool/upgrade_native_body_src.py` (pass the family name); rogue helm stays
authored (`refresh_native_gear.py`). Both only write inputs; run the build
after. **Rarity on the doll:** plain `*_t0` / `*_t1` / `*_t3` overlays get a
cool-steel or warm-gold modulate so uncommon vs epic reads at phone size.
**t2, short, broad, and named weapon models keep authored palettes** — no
global orange wash. Slot borders stay UI chrome. Weapons: `*_t0` plus named
models (`sword_thunderfury`, `sword_emberfang`, `staff_voidspire`, …) live
under `char/gear/_authored/`. The old hue scripts refuse to write; the gear
build is the only doll writer.

Doll look = body family undertunic + overlay stem from `visualSetId` +
optional material suffix from equipped `armorType`.

## Art modes (mandatory)

| Mode | Source | Used for |
|------|--------|----------|
| Body extract | `_src` → `build_owned_gear_layers.py` | undertunic per anim (face + haircut); armor extract **idle only** |
| Armor tier | approved live `t0` → palette-preserving `t2` | rare silhouette; never global gold/orange wash |
| Armor style | `gear/_authored/{slot}_{short,broad}_idle.png` | two drawn silhouettes per slot; never t0 rescaled |
| Authored weapon | `char/gear/_authored/` | shared weapons / shields / frills |
| Kenney / custom icons | `KenneyAssets` / `CustomAssets` | jewelry, flask, empty shoulder/waist slots |

Boots fold into legs on the doll; BAG uses a foot-band `boots_t*_icon.png` crop.

Do **not** invent armor or mass weapon variants with `ImageDraw`.
`generate_item_model_variants.py` refuses to copy masters into live gear.

Slot / BAG icons: `*_icon.png` (bbox crop of the same idle overlay), built
by `tool/make_gear_slot_icons.py` at the end of `build_owned_gear_layers.py`.

## Pipeline

```text
PartyHero.gearAffinity → BodyFamilyCatalog → family pose + overlays
PartyHero.race / sex → `<race>_<m|f>_body_<anim>.png` + matching cloth tint mask
PartyHero.equipped     → normalized visualSetId → OwnedGearAssets idle overlay
SpatialActor signals   → HeroAnimController → anim + frame
Canvas: paintOwnedHero (body + armor same dest rect; hand items
grip-aligned to owned anchors via `OwnedGearGrips`)
```

## Key types

| File | Role |
|------|------|
| `lib/visual/body_family.dart` | Owned denser body families + race/sex undertunic paths |
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
- Owned cape paints **behind** the body, same order as the gold master.
  The sides still show. Painting the cape in front covers the chest.
- Off-hand / main-hand — same 128 PNGs grip-aligned to owned hand
  anchors (`OwnedGearGrips`). When hand art moves, regenerate the grip
  table with `py tool/gen_owned_gear_grips.py`. Do not shift the PNGs.
  Audit: `py tool/audit_anchors.py`.
  Grips are **opaque-pixel** points: handle centroid for melee/staves, shape
  mid-height for bows, shape centroid for shields/frills. A bbox center is
  empty air on diagonal art — that hung ten weapons beside the fist.
  A large shift onto the hand anchor is normal; the painter does not clip to
  the 128 box, so long weapons reach past the hero square.
- BAG/GEAR icons use `EquipmentVisualResolver.ownedIconPathFor` (same
  `resolveId` as the doll) so missing `visualSetId` still matches overlays.
- Empty slot = undertunic showing through. No ghost t0.
- Spec color modulates `body_tint_*.png` onto the body only. Skin, hair, and
  empty corners stay the body PNG. Gear overlays are not washed.
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
| walk | `body_walk` | step bob + side sway + weapon swing (`mainHandExtraRotation`) |
| attack | `body_attack` | swing rotation + forward lean |
| cast | `body_attack` | weapon raised, body lifts — not the melee lunge |
| hit | **`body_idle`** | recoil and lean back; shield kicks out |
| death | `body_idle` | drop and feet-pivot fall, plus fade |

`hit` must not fall back to `body_walk` — the stride read as a phantom step
every time a hero took damage.

## Adding a new item

1. Create loot via factory (stamps `visualSetId`) or set id to an existing set.
2. **Do not** add a Class×Weapon spritesheet.
3. Optional: add a new 128 overlay under `assets/custom/char/` and list it in
   `OwnedGearAssets`.

## Adding a body family / denser frame

1. Drop dressed `_src/body_<anim>.png` (gold master) then run
   `py tool/build_owned_gear_layers.py`. It is the **only** writer of doll
   PNGs: it copies the art to `tool/out/doll_stage/char`, runs every step
   there (bodies, tint masks, t0/t2, styles, materials, class marks, face
   ownership, icons, race clips), and runs facit `--no-lock` on the copy.
   Live art is untouched until you pass `--publish`, which swaps changed
   PNGs in, deletes orphans, and relocks. `--publish-staged` re-checks and
   publishes the last staged build. Never copies dressed `_src` onto body;
   never invents helm/cape with `ImageDraw`. Optional overrides:
   `gear/_authored/`. The PNG list lives in `tool/paper_doll_manifest.py`.
2. Check `tool/preview_doll_<family>.png` (written by facit from body+overlays).
3. Register paths in `BodyFamilyCatalog`.
4. Do **not** paste Kenney tiles on denser bodies.
5. `process_char_bodies.py` refuses to run. It used to crop body PNGs.

## Adding a race undertunic

Shipped LOOK set = Cataclysm’s **12** playable races (Human…Goblin; no Pandaren),
each with **male and female** undertunic bases. Keep `BodyFamily` as the gear
pose. Files live at `assets/custom/char/<family>/<race>_<m|f>_body_<anim>.png`
(the gear build runs `paint_race_bodies.py` on the staged copy).

**Bake pipeline** (pose-matched to gear, not a stick redraw):

1. Load gold `_src/body_<anim>.png` (same silhouette as armor extract).
2. **Classify** every pixel into one exclusive tag (eye > skin > hair > ink >
   helm > armor > cloth) — YCbCr chroma + 8-connected flood, never recolor
   while guessing (`tool/paper_doll_classify.py`).
3. Family/facit body: copy identity pixels, drop helm and robe/plate wings,
   paint shirt and pants in the family cloth, and bare arms in face skin.
   Mage/healer hat colors above the chin stay off the body (the hat is the
   helm overlay). LOOK variants use that same shirt, then recolor skin/hair
   and bare arms **by race**.
4. Cloth-only `*_body_tint_*.png` from GARMENT tags — never overlaps
   gold-master skin / eyes / hair.

`BodyFamilyCatalog.authoredRaceLooks` lists all family × race × sex. Family
`body_*.png` mirrors **male Human** undertunic. Do **not** regenerate family gear
here. Chest/robe overlays must not include a baked face. LOOK / RACE lives on
New Game only (locked after START; hidden for Shadow / Druid form kits). New
Party preview uses `StarterGear.forSpec` so the doll matches the first dungeon
stack.

Full workflow: `.cursor/skills/character-paper-doll/SKILL.md`.

## Facit gate (`py tool/check_paper_doll_facit.py`)

1. Idle stack vs dressed `_src` per family (hard-diff ≤ 0.38) + helm width.
2. t2 and material variants exist, hold pixels, and keep the t0 silhouette.
3. Cross-material overlays differ from native in opaque mask (and at ~48 px
   squint). Mail/plate helms keep a face cutout.
4. Every body tint mask stays inside the body and outside face/hair.
5. Walk and attack undertunic + tint match a fresh bake of that clip.
   Race LOOK clips match a fresh race bake, so a body rebuild cannot leave
   them behind.
6. Owned draw order keeps the cape behind the body (same stack as this gate).
7. Every `OwnedGearGrips` entry lands on opaque pixels.
8. Only the body paints the face: no chest, legs, cloak, or hands overlay
   touches the idle face mask; helms leave the face window open.
9. Short and broad differ from t0 and from t0 stretched to their box, and sit
   where the slot sits.
10. Family folders hold exactly `tool/paper_doll_manifest.py` — no orphans.
11. `tool/paper_doll_lock.json` pins a hash per shipped PNG — any generator run
   that reshapes art fails here. `build_owned_gear_layers.py --publish`
   relocks after a green publish; commit the lock.

## Drawing a new style

Replace `gear/_authored/{slot}_{short|broad}_idle.png` with a hand-drawn 128
PNG on the family's canvas (same origin as the body, transparent, no face),
then build and publish. `tool/author_style_masters.py` composed the first set
from owned pixels (crop for short; a wider donor piece under the family's own
for broad); it never overwrites an existing master unless `--force`.

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
