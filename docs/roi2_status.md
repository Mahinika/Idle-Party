# ROI audit round 2 — status

Branch: `cursor/roi2-approved-6fa7` → base `cursor/roi2-fixes-747b` (PR #142, head `6fa7fff6`).

| Status | Meaning |
|--------|---------|
| **fixed** | Already on the parent branch, or a non-economy fix landed here |
| **approved-implemented** | Owner-approved change, in this branch |
| **draft-doc** | Written under `docs/`. Not live, not published |
| **declined** | Owner said no |
| **deferred-with-real-reason** | Not in this branch. The note is why |

## Tracker

| ID | Status | Notes |
|----|--------|-------|
| R2-001 | approved-implemented | Welcome floor = min(30, minutes away) × rate, still ×3 |
| R2-002 | approved-implemented | Ad-free uses the same 5-minute gate. VIP auto ×3 only after 5 minutes |
| R2-003 | approved-implemented | Code forces 8 / 480s. RC keys stay in the template |
| R2-004 | declined | Melee unchanged |
| R2-005 | fixed | Parent branch |
| R2-006 | fixed | Parent branch |
| R2-007 | fixed | Parent branch |
| R2-008 | declined | Keep the 2 hour floor per WISP view |
| R2-010 | approved-implemented | Auto Backup includes only `files/idle_party_backup/slot_*.json` |
| R2-011 | approved-implemented | Ascend stays secondary until 2 bosses. Confirm lists the wipe |
| R2-012 | approved-implemented | Analytics on at boot with Consent Mode denied. Privacy text updated |
| R2-013 | deferred-with-real-reason | Camera taus stay 0.05 / 0.09. A zoom change needs an A56 before/after |
| R2-014 | declined | Scroll of Gold still doubles ad floors |
| R2-015 | fixed | Parent branch |
| R2-017 | fixed | Parent branch |
| R2-018 | approved-implemented | Crashlytics stays on for a decline. No advertising ID |
| R2-019 | approved-implemented | Remote Config fetch does not wait on ad consent |
| R2-020 | fixed | Parent branch |
| R2-021 | fixed | Parent branch |
| R2-022 | deferred-with-real-reason | Moving the whole ASCEND control is a screen-size change and needs an A56 pair. The grey-until-2-bosses rule is R2-011 |
| R2-023 | fixed | Parent branch |
| R2-024 | fixed | Parent branch |
| R2-025 | draft-doc | `docs/store_drafts/` en-US, sv-SE, and the other listing locales. Not published |
| R2-026 | deferred-with-real-reason | Needs a Crashlytics pull for 1.14.0. No console credentials on this machine |
| R2-027 | fixed | Parent branch |
| R2-028 | fixed | Parent branch |
| R2-029 | declined | Not in the approved list |
| R2-030 | declined | Not in the approved list |
| R2-031 | fixed | Parent branch |
| R2-032 | approved-implemented | Ad-free skips ads and pays the watch reward. VIP is a separate unlisted row. Old Ad-free saves keep VIP perks |
| R2-033 | fixed | Parent branch |
| R2-034 | fixed | Parent called this verified-not-real. Left as already correct |
| R2-035 | fixed | Parent called this verified-not-real |
| R2-036 | fixed | Parent branch |
| R2-037 | approved-implemented | Ranks 4–7 use +0.005. AL20 weapon / best drop is inside [1.25, 1.45] |
| R2-038 | declined | Not in the approved list |
| R2-039 | declined | Not in the approved list |
| R2-043 | approved-implemented | Gold lantern parks until tapped. Badge: Gold lantern ready |
| R2-044 | deferred-with-real-reason | Session-end Tomorrow card needs the A56 reminder flow. R2-006 already arms the first-boss reminder |
| R2-045 | approved-implemented | Immersive only after consent. UMP after the first fight, still before the ad request |
| R2-046 | fixed | Parent branch |
| R2-047 | draft-doc | Starter pack proposal in `docs/roi2_proposals.md`. Not sold |
| R2-048 | approved-implemented | `coach_step` and `boss_clear` send `elapsed_s`. Guaranteed blue drop is behind `first_boss_guaranteed_drop`, default false. Floor 2 is already the first boss |
| R2-049 | approved-implemented | Hour-pack rows removed. Unknown ids ignored. Forever bundle stays, not chargeable until Play lists it |
| R2-050 | fixed | Parent branch |
| R2-051 | deferred-with-real-reason | Preloading the Sandy floor on the splash changes first-frame art and needs an A56 look |
| R2-052 | deferred-with-real-reason | Lossless PNG recompress of the whole asset tree is a binary diff with no pixel check on this machine (no oxipng). Not started |
| R2-053 | fixed | Parent branch |
| R2-054 | fixed | Parent branch |
| R2-055 | fixed | Parent branch. Retired hour packs are completed and not granted |
| R2-056 | fixed | Parent branch |
| R2-057 | approved-implemented | In-app notes show the last 3 player-facing versions and hide technical bullets. `releases` is unchanged |
| R2-058 | fixed | Parent branch |
| R2-059 | approved-implemented | Welcome card still hidden under 5 minutes |
| R2-060 | fixed | Parent branch |
| R2-061 | fixed | Parent branch |
| R2-062 | fixed | Parent branch |
| R2-063 | approved-implemented | ENDGAME layer from AL1. The page shows the next hunt plus Daily Run |
| R2-064 | draft-doc | Ascend sentence in the store drafts |
| R2-065 | draft-doc | ja-JP and ko-KR drafts expanded |
| R2-066 | fixed | Parent branch |
| R2-067 | fixed | Parent branch |
| R2-068 | fixed | Parent branch |
| R2-069 | fixed | Parent branch |
| R2-070 | fixed | Parent branch |
| R2-071 | fixed | Parent branch |
| R2-072 | fixed | Parent branch |
| R2-073 | fixed | Parent branch |
| R2-075 | fixed | Parent branch |
| R2-076 | fixed | Parent called this verified-not-real |
| R2-077 | fixed | Parent branch |
| R2-078 | fixed | Parent branch |
| R2-079 | approved-implemented | Display name is Ad-free. VIP pass is not shown and not chargeable |
| R2-080 | deferred-with-real-reason | A full 360×1.45 golden sweep of every overlay is a separate visual batch. Shop name and ENDGAME markers are the intended look changes here |
| R2-081 | deferred-with-real-reason | Body text already uses the bundled OFL VT323 face. A second face needs an owner pick |
| R2-082 | deferred-with-real-reason | `roi2.batterySaver` is saved and round-trips. Skipping particles is a fight-look change and needs an A56 check |
| R2-083 | fixed | `test/roi2_approved_test.dart` round-trips every roi2 field and a missing map |
| R2-084 | draft-doc | Types, targets, and rewards in `docs/roi2_proposals.md`. Not built |
| R2-085 | declined | Owner kept the payout. The pin test and `docs/roi2_daily_vault.md` stay |
| R2-086 | deferred-with-real-reason | The watch path already toasts “Loading ad…”. An 8s second line is a widget change across every ad button |
| R2-087 | deferred-with-real-reason | Town torch labels wait on the town art board |
| R2-088 | fixed | Parent branch |
| R2-089 | fixed | Parent branch |
| R2-090 | draft-doc | `docs/PLAY_STORE.md`. Upload key vs test key. SHA-256 is not in the repo |
| R2-091 | fixed | This file |
| R2-092 | deferred-with-real-reason | 4× speed smoke needs the emulator |
| R2-093 | fixed | Remote Config activates last session, then fetches for the next launch |
| R2-094 | declined | No save-format change |
| R2-095 | deferred-with-real-reason | `flutter pub outdated` shows no patch that stays inside the current constraints. Major bumps are not patch-level |
| R2-096 | draft-doc | `docs/roi2_ab_tests.md`. Nothing created in Firebase |
| R2-097 | deferred-with-real-reason | GA4 / BigQuery needs the owner's console |
| R2-098 | approved-implemented | 75 ms boss hit-stop, skipped at 2×/4× and on Minimal VFX. Loot fountain is sparks only. Camera taus unchanged |
| R2-099 | approved-implemented | New installs use SFX 0.70 and music 0.40. A saved volume, or a missing key, stays at 0.45 / 0.22 |
| R2-100 | deferred-with-real-reason | Referral card after the boss card needs the A56 hub sequence |
| R2-101 | draft-doc | Local price table in `docs/roi2_proposals.md`. Not entered in Play |
| R2-102 | approved-implemented | Local midnight, one zone change per day, migration hold so today is not paid twice |
| R2-103 | approved-implemented | Clock back credits nothing. A day jump past uptime skips that refill |
| R2-104 | deferred-with-real-reason | A currency glossary is new HUD copy and needs an A56 pass |
| R2-105 | approved-implemented | `ad_fill` / `ad_no_fill` per placement |
| R2-106 | approved-implemented | `rewarded_complete` already records the placement. Caps unchanged |
| R2-107 | approved-implemented | Save JSON uses `compute` outside tests. Flushes wait 2s. Pause and exit pass immediate. SharedPreferences stays |
| R2-108 | approved-implemented | Previous slot every 30 min and before Ascend. RESTORE PREVIOUS on SAVES and SETTINGS |
| R2-109 | deferred-with-real-reason | TODAY already lists the chase. A second checklist is a hub layout change |
| R2-110 | draft-doc | Non-English listings say the game is English only |
| R2-111 | deferred-with-real-reason | Class silhouettes wait on the town art board (R2-118) |
| R2-112 | approved-implemented | Live event keys default off. Gold is unchanged when the multiplier is 1 |
| R2-113 | approved-implemented | Classic JSON loads as the home shell. Gold, name, and heroes stay. The layout toggle is gone |
| R2-114 | deferred-with-real-reason | NavCopy is a repo-wide string rename with no player change |
| R2-115 | deferred-with-real-reason | `flutter analyze lib test --no-fatal-infos` is clean aside from two existing infos. Turning on stricter lints is a repo-wide edit, and tests stay enabled |
| R2-116 | deferred-with-real-reason | Do not rewrite git history |
| R2-117 | approved-implemented | ENDGAME shows the next hunt and a Daily Run preview |
| R2-118 | deferred-with-real-reason | Town art board is an art direction from the owner |
| R2-119 | deferred-with-real-reason | Gear slot chrome is a golden and an A56 look |
| R2-120 | deferred-with-real-reason | Fight TalkBack labels are a large pass and need the device |
| R2-121 | deferred-with-real-reason | Systrace needs a device |
| R2-122 | deferred-with-real-reason | App Check needs the Firebase console |
| R2-123 | draft-doc | `docs/roi2_range_balance.md`. Numbers already in the tree. No further coeff change |
| R2-124 | draft-doc | Monthly pass next to VIP in `docs/roi2_proposals.md` |
| R2-125 | draft-doc | Paragon point per Reborn, not built |
| R2-126 | deferred-with-real-reason | Colour-blind rarity is a palette change and needs an A56 pair |
| R2-127 | deferred-with-real-reason | Hub weekly rank needs Play boards and sign-in |
| R2-128 | declined | Keep refunded items |
| R2-129 | deferred-with-real-reason | ANR study needs a device trace |
| R2-130 | deferred-with-real-reason | Theme token restyle of hundreds of colors needs an A56 before/after |
| R2-131 | fixed | Parent called this verified-not-real |
| R2-132 | fixed | `GameLogic.debugNow` plus `DayClock` / `ClockGuard` seams. Offline credit uses them |
| R2-133 | fixed | Parent called this verified-not-real |

*Counts: approved-implemented 29 · fixed 46 · draft-doc 12 · declined 10 · deferred-with-real-reason 30.*
