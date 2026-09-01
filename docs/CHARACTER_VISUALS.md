# Character visuals (layered dungeon heroes)

Idle Party heroes use a **Phase 3 denser body** path when available:

1. **Owned body** from `assets/custom/char/<family>/` (gear affinity → family).
2. **Anchored gear overlays** (helm / weapon / shield) from `visualSetId`.
3. Fallback: class PNG → full Kenney paper-doll.

Used in **dungeon** (`spatial_dungeon_view`, denser owned bodies) and **GEAR /
party HUD** (`HeroDollSprite` → same owned idle body; gear shown in slots).

Not one PNG per class×weapon.

## Pipeline

```text
PartyHero.gearAffinity → BodyFamilyCatalog → body_<anim>.png
PartyHero.equipped     → EquipmentVisualResolver → gear overlays
SpatialActor signals   → HeroAnimController → anim + frame + anchors
Canvas: body sprite + CharacterVisualPainter.paintGearOverlays
```

## Key types

| File | Role |
|------|------|
| `lib/visual/body_family.dart` | Owned denser body families + asset paths |
| `lib/visual/hero_anim_state.dart` | `HeroAnimKind`, signals, pose |
| `lib/visual/hero_anim_controller.dart` | SM + `snapshot()` for paint |
| `lib/visual/character_layer.dart` | Layer ids + draw order |
| `lib/visual/equipment_visual_resolver.dart` | `visualSetId` → atlas cell |
| `lib/visual/anchor_table.dart` | Per-frame hand anchors |
| `lib/visual/character_visual_pose.dart` | Resolved layers for a frame |
| `lib/visual/character_visual_painter.dart` | Gear overlays / Kenney fallback |
| `lib/ui/hero_paper_doll.dart` | Kenney body/hair/armor cell picks |

Facing is **L/R flipX only**. Enemies unchanged in Phase 3.

## Animation priority

`death > hit > attack|cast > walk > idle` (victory optional).

## Adding a new item

1. Create loot via factory (stamps `visualSetId`) or set id to an existing set.
2. **Do not** add a Class×Weapon spritesheet.

## Adding a body family / denser frame

1. Drop `assets/custom/char/<family>/body_<anim>.png` (128×128, empty hands).
2. Register paths in `BodyFamilyCatalog`.
3. Run `py tool/process_char_bodies.py` if sources need chroma-key/resize.
4. Same gear overlay + anchor API.

## Performance

Pose layers cached per hero id until equip/anim/flip changes.

## Manual A56 checks

- Denser bodies show in dungeon for warrior/healer/mage/rogue affinities.
- **GEAR** doll: owned denser idle body (class silhouette); slots show gear.
- Flip when the party faces left (dungeon).
- Enemies still use prior art.
