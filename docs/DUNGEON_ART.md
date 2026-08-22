# Dungeon art — custom tiles & props

Owned pixel art for **in-dungeon** floors, walls, exits, gates, and floor props.
Heroes, enemies, hub backdrops, and gear icons already live under `assets/custom/`;
this doc covers the **room interior** migration off Kenney `tiny_dungeon`.

**Showcase zone:** Sunken Tidehold (`tide`) — first fully custom dungeon interior.  
**All 15 zones** now ship owned dungeon tiles + props under `assets/custom/dungeon/<id>/`.

Related: [FLOOR_BLUEPRINT.md](FLOOR_BLUEPRINT.md) (placement grammar),
[assets/custom/dungeon/README.md](../assets/custom/dungeon/README.md) (folder layout).

---

## Style bible (all custom dungeon art)

Match existing Idle Party identity art (`assets/custom/heroes/`, `enemies/`):

| Rule | Value |
|------|--------|
| **Native tile size** | **16×16 px** (stage scales ×4 → 64 logical px) |
| **Native prop size** | **32×32 px** (scale ×2 → 64; tall props may be 32×48) |
| **Filter** | Nearest-neighbor only (`FilterQuality.none` / KenneySprite) |
| **Outline** | 1 px dark rim on props; tiles tile seamlessly (no outer rim) |
| **Shading** | Top-left light; 2–3 tones per material; no blur |
| **Palette** | Zone wash from `ZoneArt` + material anchors below |
| **Transparency** | Props on alpha; floor/wall tiles opaque |
| **Naming** | `assets/custom/dungeon/<zoneId>/tiles/` and `.../props/` |
| **Code** | Paths only via `CustomAssets` → `KenneyAssets.propAsset(..., dungeonId:)` |

### Material anchors (Tidehold)

| Material | Hex anchors | Use |
|----------|-------------|-----|
| Silt floor | `#1a3a42`, `#245860`, `#2d7888` | walkable tiles |
| Wet stone wall | `#0c2228`, `#143038`, `#1e4850` | rim walls |
| Shallow water | `#1a5870`, `#28a0b8`, `#48d0e8` | puddles, pools |
| Coral / barnacle | `#c87858`, `#e8a878`, `#ffe8c8` | accents, chest, pillar |
| Salvage wood | `#5a4030`, `#806040` | barrel, hatch |
| Teal glow | `#38d0b8` | hub icon, bubble spring |

Other zones reuse the **same pixel rules** with their own wash row from `ZoneArt`.

---

## Tide asset manifest (v1)

Drop or replace PNGs at these paths. Regenerate owned art for **all zones**:

```bash
py tool/generate_dungeon_art.py
```

Tide-only (legacy alias): `py tool/generate_tide_dungeon_art.py`

### Tiles (`assets/custom/dungeon/tide/tiles/`)

| File | Role |
|------|------|
| `floor_a.png` | Primary silt — subtle teal speckle |
| `floor_b.png` | Worn variant — lighter ripple |
| `wall_a.png` | Barnacle stone — top highlight |
| `wall_b.png` | Darker seep / algae streak |
| `stairs.png` | Exit — stone steps rising through water |
| `stairs_boss.png` | Boss exit — wider, coral-framed |
| `door_closed.png` | Chamber gate — coral grate closed |
| `door_open.png` | Gate open — water trickle |

### Props (`assets/custom/dungeon/tide/props/`)

| File | `MapPropKind` | Placement role |
|------|---------------|----------------|
| `water.png` | `water` | Edge puddles — **wall-adjacent only** |
| `fountain.png` | `fountain` | Bubble spring — treasure / landmark |
| `barrel.png` | `barrel` | Salvage drift barrel |
| `hatch.png` | `hatch` | Flooded floor grate |
| `pot.png` | `pot` | Amphora / relic jar |
| `pillar.png` | `pillar` | Coral column — approach landmark |
| `chest.png` | `chest` | Barnacle chest — room reward |

### Hub

| File | Role |
|------|------|
| `assets/custom/dungeon/tide/hub_icon.png` | World Path node (anchor / coral shell) |

---

## Code wiring (per zone rollout)

1. Add PNGs under `assets/custom/dungeon/<id>/`
2. Register zone in `CustomAssets.customDungeonZones`
3. Add getters + `dungeonPropPath` / `dungeonExitPath` / `dungeonGatePath` cases
4. Point `ZoneArt` floor / wall / hubIcon at custom paths; set `customDungeonArt: true`
5. `PlacementPlan` uses lower clutter density + intentional edge placement for custom zones
6. Tests: `custom_assets_test` + existing layout tests

Repeat for next zone (Rime, Ember, …). When all zones ship: remove `assets/kenney/tiny_dungeon` props/tiles.

---

## Generation prompts (final art)

Use the manifest filenames. Example prompt block for Tide floor tile:

> 16×16 pixel art game tile, seamless top-down dungeon floor, sunken cavern silt,
> dark teal-green (#1a3a42), subtle wet speckles, no characters, no border,
> flat retro RPG style matching Idle Party, transparent background none (opaque tile)

Prop example (`fountain.png`):

> 32×32 pixel art, top-down dungeon prop, coral bubble spring with teal glow,
> 1px dark outline, Idle Party retro RPG style, transparent background

Keep **one zone per batch** so palette and outline stay consistent.
