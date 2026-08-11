# Class audit — all specs (QUICK)

**Date:** 2026-08-10  
**Depth:** quick (code-only; Wowhead structure for identity, no number scrape)  
**Playtest:** no  
**Branch context:** post-1.11.1 / 1.11.2  
**Follow-up:** P0 kit honesty fixes landed same day (see below).

## P0 fixes (2026-08-10)

| Issue | Fix |
|-------|-----|
| Assa Vendetta/Cold Blood | Damage amp via `combustionTimer` on kit + AA |
| Unholy AMS | Absorb targets self |
| Enhancement SRage | Resource + Shield Wall DR |
| Frost Mage Nova | Pack root like Fire Nova |
| Arcane stacking | Blast charges 0–4; Missiles dump |
| Shadow DoT thin | VT/DP are DoTs; maintain priority |
| (+P1) Fire Hot Streak | 2 Fireball crits → free Pyro |
| (+P1) Affliction overwrite | Stack different DoTs; maintain same-id |
| (+P1) Guardian FR | Self heal |
| (+P1) SpecKit Ice Block | Real `iceBlockTimer` immunity |
| (+P1) Ice Lance shatter | ×1.75 on rooted |
| (+P1) Arcane Slow | Attack slow, not root |

## Rollup verdicts (pre-fix snapshot)

| Spec | Verdict | Notes |
|------|---------|-------|
| protection | ship | Starter tank |
| arms | tune | Sweep nova not buff |
| fury | tune | Reck = DR; BT rage copy soft |
| holyPaladin | tune | Beacon/Favor honesty |
| protPaladin | tune | Holy Shield twin emergency |
| retribution | ship | Clean melee holy DPS |
| beastMastery | tune | Pet live; Feign/Intim soft |
| marksmanship | tune | Strong ST; no AoE |
| survival | tune | Trap at self; Disengage = shield |
| assassination | tune→fixed P0 | Vendetta amp |
| combat | ship | AL1 unlock; combo OK |
| subtlety | tune | Evis dual-path messy |
| discipline | ship | Legacy triage OK |
| holyPriest | ship | CoH ST; Renew pulse |
| shadow | tune→fixed P0 | DoT maintain |
| blood | tune | Tank OK; no diseases |
| frostDk | tune | Hunger = dmg not root |
| unholy | tune→fixed P0 | AMS self |
| elemental | ship | Stormcaster complete |
| enhancement | tune→fixed P0 | SRage DR |
| restorationShaman | tune | Party heals OK; Riptide not HoT |
| arcane | WIP→wired | Charge dump live |
| fire | tune→Hot Streak | Crit → free Pyro |
| frostMage | tune→fixed P0 | Pack Nova |
| affliction | tune→stack/maintain | DoT honesty |
| demonology | tune | Pet live; spider art |
| destruction | ship | Nuke identity clear |
| balance | tune | Moonfire maintain now |
| feral | tune | Bleeds OK; no cat art |
| guardian | tune→FR self | Self heal |
| restorationDruid | ship | Soft: HoTs are pulses |

## Remaining P1 (not this batch)

- Shared class sprites / pet art
- Feign / Disengage / CoH splash / Riptide HoT copy
- DK diseases
- Class blurbs in guides
- Thin kit combat tests beyond honesty suite
