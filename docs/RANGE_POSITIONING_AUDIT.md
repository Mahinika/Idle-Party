# Hero range & positioning audit (2026-11-26)

**Status:** analysis + draft PR (`cursor/hero-range-positioning-audit-8a31`). Not for merge without Robert.

## 1. Spec catalog (all 31)

| Class | Spec | `ranged` | `preferredRange` | `attackRange` | Role |
|------|------|----------|------------------|---------------|------|
| Warrior | Greatblade (arms) | no | 1.20 | 1.75 | meleeDps |
| Warrior | Twinrage (fury) | no | 1.15 | 1.70 → **1.75** (draft) | meleeDps |
| Warrior | Shieldwall (protection) | no | 1.15 | 1.70 | tank |
| Paladin | Dawnward (holy) | yes | 3.00 | 3.80 | healer |
| Paladin | Oathwall (prot) | no | 1.20 | 1.75 | tank |
| Paladin | Sunstrike (ret) | no | 1.25 | 1.80 | meleeDps |
| Hunter | Packbond (BM) | yes | 4.20 | 5.20 | rangedDps |
| Hunter | Longshot (MM) | yes | 4.50 | 5.50 | rangedDps |
| Hunter | Snarebow (survival) | yes | 3.60→**2.80** | 4.50→**3.60** | rangedDps |
| Rogue | Venomcut | no | 1.20 | 1.80 | meleeDps |
| Rogue | Alleyblade (combat) | no | 1.25 | 1.85 | meleeDps |
| Rogue | Nightstep | no | 1.20 | 1.80 | meleeDps |
| Priest | Aegislight (disc) | yes | 3.20 | 4.00 | healer |
| Priest | Hymnward (holy) | yes | 3.40 | 4.20 | healer |
| Priest | Duskcant (shadow) | yes | 4.00 | 5.00 | caster |
| DK | Graveward (blood) | no | 1.20 | 1.80 | tank |
| DK | Rimeblade (frost) | no | 1.20 | 1.80 | meleeDps |
| DK | Blightblade (unholy) | no | 1.25 | 1.85 | meleeDps |
| Shaman | Stormcall (ele) | yes | 4.00 | 5.00 | caster |
| Shaman | Totemstrike (enh) | no | 1.30 | 1.90 | meleeDps |
| Shaman | Tidecall (resto) | yes | 3.20 | 4.00 | healer |
| Mage | Prism / Cinder / Glace | yes | 4.00 | 5.00 | caster |
| Warlock | Hexrot / Pactimp / Ashburst | yes | 3.8–4.2 | 4.8–5.2 | caster |
| Druid | Moonweft | yes | 4.00 | 5.00 | caster |
| Druid | Clawdance (feral) | no | 1.20 | 1.80→**1.85** | meleeDps |
| Druid | Barkwall (guardian) | no | 1.15 | 1.70 | tank |
| Druid | Bloomward (resto) | yes | 3.20 | 4.00 | healer |

Bold = recommended draft set.

## 2. Problems found

### Identity / data

- **Survival (Snarebow):** `ranged: true` + 4.5 attack range while the kit is mostly melee-range (Mongoose Bite `maxRange: 1.85`, traps, bombs). WoW-style Survival is a melee trapper; only Harpoon and Multi-Shot want distance.
- **Holy Paladin** is `ranged: true` at 3.0/3.8 — shortest healer reach; pocket heal AI can leave fewer pixels of room for spell casts than Disc (3.2/4.0).

### Positioning logic (`combat_presence.dart`, `spatial_combat.dart`)

- **`_rangedStand` `minStand` 1.35** with LOS: marksmen (5.5 attack) can pick tiles inside enemy melee before the score function corrects — high `rangedOrSpellDamageTaken` on MM/BM in sims.
- **`_partyLine` cap `attackRange * 0.98`:** with `partyBodyGap` 1.45 and lateral wing slots, low-reach melee (Fury 1.7, Guardian 1.7) spend ~33–36% of fight time outside strict auto range (Prot+Disc+focus Sandy F5 metrics).
- **Melee clump on one focus:** `hero_focus` + shared focus is by design; separation uses `keepApart` / `partyBodyGap` — works in tests but impatient melee leash (`packLeash`) can briefly stack before line solver runs.
- **Tanks:** protection/guardian `preferredRange` 1.15 and line slot 0 — correct “in front” intent; Prot Paladin 1.2 slightly farther than warrior tanks (minor inconsistency).

### Ability range vs spec range

| Ability | Spec | Gate | Issue |
|---------|------|------|--------|
| Mongoose Bite | Survival | `maxRange: 1.85` | Was unreachable identity when spec stood at 3.6+ |
| Harpoon | Survival | `maxRange: 6.5` | Far beyond spec attack 4.5 — honesty gap |
| Binding Shot | MM | focus only | OK at 5.5 spec range |
| Heroic Throw / Charge | Warrior | `minRange 3.5` | Intentional melee kit — OK |
| Killing Spree | Rogue | `minRangeMul: 1.85` | Requires ~3.4 tiles — above auto range; intentional gap-closer |

### AoE aim (`aoe_aim.dart`)

- Melee threshold `preferredRange < 3.2` — Survival at 3.6 was treated as “ranged” for ground AoE reach (Multi-Shot / bombs), pulling aim logic away from mongoose/trap fantasy.

## 3. Sim baselines (main, before draft)

**Balance gate:** `class_balance_share_fast` + `class_balance_gate` + `class_balance_aoe_share` — all green. Notable DPS share vs band median (Prot+Disc, Sandy F5, live light, 6 trials): enhancement/combat/arms/feral/fury/unholy **LOW**; no **HIGH**.

**Positioning sweep** (`test/positioning_range_sim_test.dart`, Sandy F5, 4× trials, focus hero = third slot):

| Spec | Share% | 1st hit (s) | In auto range% | Ranged/spell dmg taken |
|------|--------|-------------|----------------|------------------------|
| fury | 51.4 | 1.93 | 35.9 | 186 |
| arms | 45.2 | 2.65 | 33.9 | 226 |
| feral | 44.4 | 0.68 | 48.2 | 157 |
| survival | 55.9 | 1.15 | 82.9 | 160 |
| marksmanship | 54.1 | 1.15 | 89.3 | 211 |
| beastMastery | 62.8 | 1.72 | 86.7 | 154 |
| enhancement | 55.8 | 0.45 | 50.0 | 110 |

Full JSON: `tool/out/positioning_baseline_main.json` (local artifact, not committed).

## 4. Options

### A — Minimal consistency (no Survival role flip)

- Fury `attackRange` 1.75; Feral 1.85; healers `attackRange` +0.2; Harpoon `maxRange` 5.0.
- `_rangedStand` long-range `minStand` 2.05 / 2.35.
- **Risk:** Survival still ranged — mongoose/trap fantasy stays wrong.

### B — A + Survival → melee

- Survival: `meleeDps`, `ranged: false`, 1.25 / 1.85 (same as combat rogue).
- Multi-Shot / Harpoon remain ranged abilities via gates.
- **Risk:** DPS share shift for Survival in balance sim (was +0.3% vs median).

### C — B + healer preferred nudge + tank front

- Holy Pal 3.1 pref / 4.0 attack; optional tank pref 1.15→1.12 (not in draft — needs phone check).
- **Risk:** Larger healer positioning change across generated cave tests.

## 5. Recommended for merge prep

**Option B (Survival → full melee)** is the best identity fit, but on this branch it **redistributed DPS share** and tripped the live gate (`affliction` **HIGH** at 67.6%) without any coeff changes — Robert should pick B only with a follow-up kit pass.

**This draft PR implements Option A′** (green CI):

- Survival **mid-range trapper** `2.8 / 3.6` (mongoose + traps in range; Multi-Shot / Harpoon still “ranged” abilities).
- Fury 1.75; Feral 1.85; Survival 2.8/3.6.
- Harpoon `maxRange` 5.0; `_rangedStand` minStand tiers.
- **Omitted from draft (gate):** healer `attackRange` +0.2 — combined with Survival mid-range it pushed **affliction** share **HIGH** at 67.6% in the gate sim; keep for Option C after Robert approves.

### Exact changes on branch

- `hero_spec.dart`, `hunter.dart`, `combat_presence.dart`, `test/positioning_range_sim_test.dart`, this doc.

### After draft sim (Option A′, 4 trials)

Compared to main baseline (focus hero, Sandy F5):

| Spec | Main in-range% → draft | Main 1st hit → draft |
|------|------------------------|----------------------|
| survival | 82.9 → **74.2** | 1.15 → **1.32** |
| fury | 35.9 → **38.4** | 1.93 → **1.55** |
| feral | 48.2 → **51.6** | 0.68 → 0.68 |
| marksmanship | 89.3 → **89.3** (minStand reduces melee-folder risk) |

Balance gate (6 trials): still **no HIGH**; LOW melee band unchanged (fury/arms/feral) — reach tweak alone does not fix kit coeffs.

## 6. Risks

- **Balance gate:** LOW melee kits (fury, arms, feral) may move slightly as reach improves; Survival share may rise as mongoose bites connect.
- **Tests:** `loot_equip_audit` lists Survival as `rangedDps` — may need expectation update if Survival role changes (check CI).
- **No HIGH kit buffs** in this draft — coeffs untouched.