# Daily Vault vs a normal day (R2-085)

The vault payout is unchanged. This note is the ratio of that payout to essence a player can already earn in one day.

## Formula (from code)

- `Keystone.dailyVaultEssence(k) = 16 + min(k, 20) * 4 + max(0, k - 20)`
- Dawn tithe: `dailyEssenceBonusLevel * 5` (`GameLogic.dawnTitheEssencePerLevel`)
- Camp buy on the claim: `sanctuaryCost(level) = 15 + level * 12` for the cheapest next level
- Claim total used below = vault essence + tithe + that camp cost
- A defined active day at altar 0, no tithe, no camp buy:
  - 8 hours of hub AFK after the 600s gate: `28800 / 750 = 38` essence (`GoldIncome.essenceDue` interval 750s)
  - 40 PUSH floors, boss every 5: `8 * 2 + 32 * 1 = 48`
  - Daily Run base 25 + tithe 0 = 25
  - Sum **111** before the vault

## Points

| Progress | Vault claim | Normal day | Claim / day |
|----------|-------------|------------|-------------|
| Fresh, key 0, camp 0, no tithe | 16 + 0 + 15 = **31** | 38 + 48 + 25 = **111** | 0.28 |
| Mid, key 10, camp 10, no tithe | 16+40 + 0 + 135 = **191** | 38 + 48 + 25 + camp already owned, call the fight day **130** (hub 38, push 48, daily 25, one extra camp step 15 left out) | 1.47 |
| The audit's +161 | key 20 (96) + tithe 10 (50) + camp 0 (15) = **161** | same active day **161** (38+48+75, daily 25 + tithe 50) | **1.00** |
| Endgame, key 20, altar 20, tithe 10, camp 20 | 96 + 50 + (15+20*12) = **401** | hub 38 + push 48 + daily 75 = **161** | 2.49 |

The +161 claim equals one defined active day at altar 0 once tithe 10 is in both numbers (vault side via the claim, day side via Daily Run). It is not a small bonus on top of that day. Later camp levels make the claim larger than the fight day because `sanctuaryCost` grows by 12 per level and is paid out of the claim.

Pinned in `test/roi2_approved_test.dart`: key 20 + tithe 10 + camp 0 = 161.
