# Character visuals (layered dungeon heroes)

Idle Party dungeon heroes use a **Canvas layered** system (`lib/visual/`), not
one PNG per class×weapon. Custom class portraits remain available for hub /
non-dungeon UI; the spatial dungeon always prefers layered gear.

## Pipeline

```text
PartyHero.equipped  →  EquipmentVisualResolver  →  layer stack
SpatialActor signals →  HeroAnimController / snapshot →  anim + frame
AnchorTables         →  mainHand / offHand offsets + attack swing
CharacterVisualPainter → SpatialDungeonView Canvas
```

## Key types

| File | Role |
|------|------|
| `lib/visual/hero_anim_state.dart` | `HeroAnimKind`, signals, pose |
| `lib/visual/hero_anim_controller.dart` | SM + `snapshot()` for paint |
| `lib/visual/character_layer.dart` | Layer ids + draw order |
| `lib/visual/equipment_visual_resolver.dart` | `visualSetId` → atlas cell |
| `lib/visual/anchor_table.dart` | Per-frame hand anchors |
| `lib/visual/character_visual_pose.dart` | Resolved layers for a frame |
| `lib/visual/character_visual_painter.dart` | `drawImageRect` stack |
| `lib/ui/hero_paper_doll.dart` | Kenney body/hair/armor cell picks |

Art v1: Kenney Roguelike Characters (`RoguelikeCharAtlas`). Facing is **L/R
flipX only**.

## Animation priority

`death > hit > attack|cast > walk > idle` (victory optional).

Combat must not know sprites — only flash timers (`attackFlash`, `castFlash`,
`hitFlash`) and motion.

## Adding a new item

1. Create loot via `EquipmentFactory` / `GameLogic.createEquipment` (stamps a
   default `visualSetId`).
2. Or set `visualSetId` explicitly to an existing catalog id
   (e.g. all iron swords → `sword_t1`).
3. **Do not** add a Class×Weapon spritesheet.

Catalog (Dart authoritative): `EquipmentVisualResolver.catalog`.
Mirror list: `assets/data/equipment_visuals.json`.

## Adding a class / body family

1. Add a skin row / body family in `HeroPaperDoll.skinRowFor`.
2. Reuse the same layer + anim + anchor API.

## Adding an animation

1. Map frames in `HeroAnimController._frameFor` (Kenney col 0/1 today).
2. Add anchors for those frames in `AnchorTables`.
3. Optional draw-order override in `character_layer.dart`.

## Performance

Pose layers are cached per hero id until `equipHash` / anim frame / flip
changes (`CharacterVisualPoseCache`).

## Phase 3 (later)

Swap denser owned atlases by changing catalog atlas paths — same resolver /
anchors API. Enemies stay on their own pass.

## Manual A56 checks

- Equip/unequip in GEAR while party is in Sandy — dungeon updates live.
- Attack lunge + weapon swing orientation looks reasonable.
- Flip when the party faces left.
