# ROI audit round 2 — status

Branch: `cursor/roi2-fixes-747b` → base `cursor/integrate-fixlist-751c` (PR #141).

Play Console boards still missing dedicated ids for **2026-11+ KEY/Gauntlet** (reuse `CgkIhuXGvNocEAIQAA` / `CgkIhuXGvNocEAIQAQ` / `CgkIhuXGvNocEAIQAw` until new boards are published).

| Status | Meaning |
|--------|---------|
| **fixed** | Landed in this branch with tests or evidence |
| **verified-not-real** | Checked; behavior already correct or audit stale |
| **deferred** | Out of scope this batch (tooling, owner action, or follow-up) |
| **needs-approval** | Economy, balance, save-format, or large product change |

## Tracker

| ID | Status | Notes |
|----|--------|-------|
| R2-005 | fixed | `lib/core/play_leaderboard_ids.dart` fallback via `_rowFor`; `test/roi2_live_ops_test.dart` |
| R2-006 | fixed | `lib/core/local_reminders.dart` first-boss milestone + promise copy; tests |
| R2-007 | fixed | `lib/ui/meta/play_games_protect_overlay.dart` after first Ascend |
| R2-013 | deferred | Default zoom / equip close-up — needs A56 before/after (camera taus locked) |
| R2-015 | fixed | `lib/core/ad_rewarded_io.dart` `onPaidEvent` → `AppAnalytics.adImpression` |
| R2-017 | fixed | `lib/core/shop_catalog.dart` bullets + `shop_dock.dart` INFO dialog |
| R2-020 | fixed | `lib/ui/start_menu_screen.dart` PLAY + “Have a save?” |
| R2-021 | fixed | `lib/ui/shell/home/home_nav_bar.dart` hide locked tabs |
| R2-022 | deferred | Hub CTA stack — partial via prior #141; full ASCEND move needs layout review |
| R2-023 | fixed | BiS manual guard `gear_cleanup.dart`; `recommendAutoSellCeiling` + seed test |
| R2-024 | fixed | Apex/double-tap + shop bullets; vault equip path in director_meta_actions |
| R2-026 | deferred | Needs Firebase Crashlytics pull for 1.14.0 (no agent credentials) |
| R2-027 | fixed | `.github/workflows/ci.yml` push only `main`/`release/**` |
| R2-028 | fixed | `release-appbundle-pr` job on pull_request |
| R2-031 | fixed | `AppAnalytics.logVirtualCurrency` sampled; `EconomyService.logGoldDelta` |
| R2-033 | fixed | `wisp_gift.dart` claim on complete/dismiss; `director_platform.dart` skip keeps pending |
| R2-034 | verified-not-real | Product analytics doc only until Play install funnel refreshed |
| R2-035 | verified-not-real | `menu_surface.dart` / `game_director.dart` use post-frame on #141 |
| R2-036 | fixed | `lib/core/home_prompt_budget.dart` one modal / session ×3 |
| R2-044 | deferred | Session-end “Tomorrow” hook — pairs with R2-006 follow-up |
| R2-046 | fixed | Locked rails hidden + R2-078 hint; full party/rail merge deferred |
| R2-050 | fixed | `local_season.dart` `weekRotationPool`; test 2027-W01..W52 |
| R2-051 | deferred | Loading floor backdrop — perf/preload batch |
| R2-052 | deferred | Asset diet (62 MB) — separate compression pass |
| R2-053 | fixed | `integration_test/ftue_smoke_test.dart` + `pubspec.yaml` |
| R2-054 | fixed | `game_guides.dart` dedupe + ≤5 bullets; `game_guides_test.dart` |
| R2-055 | fixed | `shop_store_io.dart` unknown SKU no `completePurchase` |
| R2-056 | fixed | Player-facing buy error string |
| R2-058 | fixed | `reusedBoardNotice` plain English |
| R2-060 | fixed | `home_catalog.dart` MENU dot gated |
| R2-061 | fixed | `return_week.dart` CAMP verb+result |
| R2-062 | fixed | `game_state.dart` default `home`; `test/roi2_live_ops_test.dart` |
| R2-063 | deferred | ENDGAME tab hide until AL1 — needs MAP golden |
| R2-066 | fixed | `autoSellJunk` single pass |
| R2-067 | fixed | `lib/core/firebase_boot.dart` shared init |
| R2-068 | fixed | `save_transfer.dart` share file IO/stub |
| R2-069 | fixed | `docs/fixlist-ui-751c-status.md` IP-145/146/186 notes corrected |
| R2-070 | fixed | `docs/fixlist_code_status.md` IP-230/231/394 → this list |
| R2-071 | fixed | `first_climb_coach_test.dart` shorter pump |
| R2-072 | fixed | `sim-nightly.yml` gate job |
| R2-073 | fixed | `test/roi2_live_ops_test.dart` |
| R2-075 | fixed | `tool/ci/install_flutter_pinned.sh` on box (`Flutter 3.47.9`) |
| R2-076 | verified-not-real | `a56-playtest/reference.md` already `hw.gpu.mode=host` |
| R2-077 | fixed | `town_viewport.dart` dim lock signs |
| R2-078 | fixed | `fight_seam.dart` hint budget |
| R2-080 | deferred | Full 360×1.45 overlay golden sweep — batch too large |
| R2-081 | deferred | Readable font OFL bundle — new asset + settings |
| R2-082 | deferred | Battery saver — gameplay perf policy |
| R2-083 | deferred | Exhaustive save round-trip — needs generated fixture |
| R2-084 | needs-approval | New mission types — content/balance |
| R2-086 | deferred | 8s ad load UX — partial toast exists |
| R2-087 | deferred | Town torch labels — art pass |
| R2-088 | fixed | `floater_banner_stack.dart` max 2 + gap |
| R2-089 | fixed | `main.dart` parallel Firebase boot |
| R2-091 | fixed | This file is the batch ledger |
| R2-092 | deferred | 4× speed manual smoke — next emulator run |
| R2-093 | deferred | RC activate-on-next-launch — behavior change |
| R2-095 | deferred | Pub upgrades — separate 1.15 branch |
| R2-097 | deferred | GA4/BigQuery dashboard — owner console |
| R2-098 | needs-approval | Hit-stop / loot fountain — VFX scope |
| R2-099 | needs-approval | Default volume lift — player settings |
| R2-100 | deferred | Referral card timing — after boss card exists |
| R2-104 | deferred | Currency hide/glossary — HUD scope |
| R2-109 | deferred | Unified TODAY checklist — hub card expansion |
| R2-111 | deferred | Distinct class silhouettes — art |
| R2-113 | needs-approval | Retire classic shell — migration |
| R2-114 | deferred | NavCopy removal — wide string sweep |
| R2-115 | deferred | Strict lints — repo-wide |
| R2-116 | deferred | Git history diet — infra |
| R2-119 | deferred | Gear slot chrome — golden |
| R2-120 | deferred | Fight TalkBack — large a11y pass |
| R2-121 | deferred | Systrace after 8h — device-only |
| R2-122 | deferred | App Check — Firebase console |
| R2-126 | deferred | Colour-blind rarity — overlaps settings |
| R2-127 | deferred | Hub weekly rank — after boards + sign-in |
| R2-129 | deferred | ANR frame budget — combat perf study |
| R2-130 | deferred | Theme token pass — 659 colors |
| R2-131 | verified-not-real | Policy: split on touch only (`AGENTS.md`) |
| R2-132 | deferred | Clock injection — cross-cutting |
| R2-133 | verified-not-real | Single-player; doc acknowledged |

*Counts (this table): fixed 38 · verified-not-real 5 · deferred 41 · needs-approval 4*