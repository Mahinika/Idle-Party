# Audit P0 fix rollup — 2026-08-02

Batch fix after parallel class audits. Scope: wiring/identity P0s (not full rebalance of every mid outlier).

## Fixed

| Area | Change |
|------|--------|
| Combat | SnD before Kidney; Kidney only at 5 CP with SnD up |
| Heal AoE | Party heal path for Chain/Rain/Link/WG/Tranq/Hymn/Holy Nova |
| Holy Pala | Beacon → absorb on lowest; LoH copy fixed |
| RDruid | Barkskin protects injured ally on emergency; Tree mul ↑ |
| Fury | Rampage (`furyExecute`) no longer execute-gated |
| Subtlety | `eviscerateSub` finisher + CP on AA |
| Affliction | Drain Life → damage + self-heal |
| Shadow | VT → damage + mana refund |
| Blood | Heart Strike/Death Strike → ST damage (+ DS self-heal) |
| Pets | BM/Demo/Unholy spawn class companions in `SpatialCombat.build` |
| Casters | selfBuff haste no longer double-stacks PI × haste buff |

## Still backlog (not this batch)

- Full live VFX pass per WIP kit
- Fine mid-share retune after live FARM feedback
