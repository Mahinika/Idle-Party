# Range balance pass IP-395..400 (R2-123)

Source: `docs/RANGE_POSITIONING_AUDIT.md`. Those IP ids are not separate tickets in this repo. The audit is the sim record.

This branch does **not** change range numbers again. Option A′ is already in the tree (Fury `attackRange` 1.75, Feral 1.85, Survival preferred 2.8 / attack 3.6, Harpoon `maxRange` 5.0, `_rangedStand` minStand 2.35 / 2.05 / 1.35). A healer `attackRange` +0.2 on top of that tripped **affliction HIGH at 67.6%**. Coeffs stay.

## Before (audit section 3, Sandy F5, 4 trials)

| Spec | Share% | 1st hit (s) | In auto range% |
|------|--------|-------------|----------------|
| fury | 51.4 | 1.93 | 35.9 |
| arms | 45.2 | 2.65 | 33.9 |
| feral | 44.4 | 0.68 | 48.2 |
| survival | 55.9 | 1.15 | 82.9 |
| marksmanship | 54.1 | 1.15 | 89.3 |
| beastMastery | 62.8 | 1.72 | 86.7 |
| enhancement | 55.8 | 0.45 | 50.0 |

## After Option A′ (audit section 5)

| Spec | In-range% | 1st hit (s) |
|------|-----------|-------------|
| survival | 82.9 → 74.2 | 1.15 → 1.32 |
| fury | 35.9 → 38.4 | 1.93 → 1.55 |
| feral | 48.2 → 51.6 | 0.68 → 0.68 |
| marksmanship | 89.3 → 89.3 | unchanged |

## After melee arc v2 (audit section 7)

In-range% before arc → mid → after: arms 33.9 → 49.7 → 59.7; fury 35.9 → 54.5 → 47.5; feral 48.2 → 43.3 → 56.6; retribution 30.7 → 29.9 → 55.4; frost DK 51.1 → 31.8 → 54.2; unholy 50.8 → 40.7 → 57.1; assassination 58.3 → 40.1 → 56.5; combat 68.3 → 61.5 → 68.2; subtlety 49.7 → 71.1 → 75.3; enhancement 50.0 → 46.3 → 61.7.

Live gate after v2: no HIGH. LOW melee band (fury / arms / feral) unchanged. Reach does not fix kit coefficients.
