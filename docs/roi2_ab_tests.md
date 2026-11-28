# Firebase A/B setup (R2-096)

Nothing is started in the Firebase console. These keys already exist in `RemoteTune.defaults`. Create the experiments later. Do not publish a treatment until Robert says so.

| Experiment | Remote Config key | Shipped default | What the code does today |
|------------|-------------------|-----------------|--------------------------|
| WISP cadence | `wisp_daily_cap`, `wisp_interval_sec` | 8 and 480 | **Ignored.** `RemoteTune.apply` forces 8 and 480. Keys stay in the template so a later build can honor them. Do not expect an A/B of these two to change the live lantern until that code change. |
| First climb Play now | `first_climb_play_now` | true | Honored. Bool. |
| Welcome floor | `welcome_back_first_return_short` | true | Honored for the first-return short card. The gold floor itself is code: `min(30, minutes away) × hub gold per minute`, still ×3. There is no RC number for that floor yet. Add `welcome_floor_minutes` only when a build reads it. |

Suggested later setup (not created):

1. One experiment per key. Audience: new installs, 7 days.
2. Control = the shipped default. One treatment only.
3. Goal: `boss_clear` with `elapsed_s` for the first boss, and `welcome_back_ad` for the welcome card.
4. Leave `first_boss_guaranteed_drop` and `vip_pass_listed` and the live-event keys out of these experiments. They default off.
