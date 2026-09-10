# Class audit — reference (read on demand)

Read when filling Wowhead slices, rotation buckets, form contracts, or numbers sections.

## Wowhead map

| Wowhead slice | Use in audit |
|---------------|--------------|
| Class index (tank/heal/melee/ranged) | role family |
| Overview | fantasy, strengths/weaknesses |
| Rotation / CDs / abilities | ST / AoE / maintain / CD / def / util / proc buckets |
| Talents / glyphs | identity only — skip point spreads |
| BiS / stats / consumables / PvP | **skip** |

Example:  
`https://www.wowhead.com/wotlk/guide/classes/mage/fire/dps-rotation-cooldowns-abilities-pve`

## Rotation buckets

| Bucket | Examples (names only) |
|--------|------------------------|
| ST filler / builder | Fireball, Sinister Strike, Devastate |
| Maintain / DoT / buff | Living Bomb, Slice and Dice, Power Word: Shield |
| Finisher / dump | Eviscerate, Pyroblast (proc) |
| AoE / cleave | Shockwave, Blade Flurry |
| Offensive CD | Combustion, Killing Spree |
| Defensive / emergency | Shield Wall, Ice Block, Pain Suppression |
| Control | Taunt, Frost Nova, Kidney Shot |
| Party utility | Fortitude, Arcane Intellect, Demo Shout |
| Proc / reaction | Hot Streak → Pyro (auto-friendly) |

Idle has **no opener**. Missing must-keep bucket = **P0/P1**.

## Era honesty

Wrath is the identity baseline, not a taxonomy trap. Record divergence when the
shipped spec name or role belongs to another era. Example: Wrath Feral covered
cat DPS and bear tanking; Idle Party's separate **Feral** and **Guardian**
specs should still inherit the correct cat/bear identity. Do not force a
modern kit into false Wrath parity or rename a shipped spec during an audit.

## Body, form, stance & persistent-state contract

Audit the actor's embodiment before VFX polish:

- **Persistent form:** actor must use that silhouette in live dungeon combat
  and compact party read. A passive multiplier or chip alone fails.
- **Conditional/temporary state:** verify enter/exit timing, save/load default,
  death/revive, floor transitions, offline catch-up, and reduced-VFX fallback.
- **Animations:** idle, move, attack/cast, hit/recoil, and defeat must fit the
  form; never slide an otherwise static replacement sprite.
- **Surfaces:** dungeon actor is authoritative. PARTY HUD and roster/GEAR must
  identify the same spec even if a compact portrait is used.
- **Gear:** explicitly choose visible form-specific equipment or hidden gear.
  Never stretch humanoid paper-doll overlays onto an animal body.
- **Readability:** sibling specs need distinct silhouettes/colors at the
  360×780 A56 target, including colorblind and Minimal VFX modes.
- **Rules + art agree:** `HeroSpecDef`, passive ability, runtime actor state,
  `HeroIdentity`, painter, asset helper, and player copy must describe the same
  form.

For Druids, the expected class contract is explicit:

| Spec | Persistent combat body |
|------|-------------------------|
| Feral | cat |
| Guardian | bear |
| Balance | Moonkin (owlkin / owl-bear humanoid), not a normal caster body |
| Restoration | Tree of Life while its shipped passive says “Always on” |

Missing or wrong persistent silhouette is **P0 identity**. Missing
form-specific animation/portrait polish is usually **P1**.

## Range, AI, threat, triage

- Melee `preferredRange` in face; casters backline; mobility tools fire when fantasy needs them.
- Targets: alive, non-dormant; don’t idle on next chamber forever.
- Tank: holds packs / taunt on lose. Healer: lowest HP + emergencies; no full-HP spam.
- Multi-chamber wake + boss floor: signature/emergency still show up.
- Offline/AFK spatial: kit still works; no soft-lock.

## Gear, unlock, roster, copy

- `armorTypes` / BEST / auto-equip match fantasy.
- Unlock hint + seed level; PARTY roster selectable.
- `shortLabel`, chip names, guides/tips not stale.

## Companions

If spec is companion-family (BM, Demo, …): combat companion present, AI/leash
OK, legal sprite, HUD/meter if intended. Else mark **N/A**. A spec named
Guardian is not automatically a companion check; classify by behavior.

## Modes, save, perf, pitch

- **FARM / PUSH / challenges:** kit still readable; no mode-specific soft-lock.
- **Save/migrate:** loading an older save keeps unlocks/kit; no blank abilities.
- **Perf:** signature/AoE VFX must not tank the ~60 FPS combat target; note `reducedVfx`.
- **Player pitch:** one sentence that matches live feel (for PARTY/UI/store).

## Composition fit

With a normal 1 tank / 1 heal / 2 DPS party: clear job, acceptable overlap, no soft hole if swapped out, any buff/cleave synergy.

## Assets & VFX

Start with silhouette/form/persistent state, then inspect hero sprite, form
animations, chips, `SpellBoltStyle`, bursts, maintain/AoE/emergency telegraphs,
`reducedVfx`, and a11y at ~390×844. Silent signature or wrong art = **P0/P1**.

## Numbers

DPS peers ~0.6×–1.4×; tank ≪ DPS; healer on H/s. Resource edge cases don’t soft-lock. Tunings = Idle fields only.
