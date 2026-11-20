# Testing Idle Party

Portrait Android is the product. Web is a fallback for agents and goldens, not a Play release.

## What runs where

| Layer | Command | When |
|-------|---------|------|
| Static analysis | `flutter analyze lib test --no-fatal-infos` | Every agent batch and CI |
| Default CI | `flutter test --exclude-tags sim` | GitHub Actions on pushes and PRs |
| Balance sim | `flutter test --tags sim` | Nightly workflow (`sim-nightly.yml`) |
| Targeted tests | Named files under `test/` | Agents during a focused batch |

Agents do **not** run the full non-sim suite locally unless the batch touches broad behavior. Cloud agents fix their own CI until green.

## Goldens

- Phone reference: Samsung A56 logical **360×780** (`a56-playtest` skill).
- Regenerate on **Linux** with the CI Flutter pin (`tool/ci/install_flutter_pinned.sh`).
- Widget harness: `test/widget_golden.dart`.
- Fight / shell / Welcome Back examples live under `test/goldens/after/` and `test/goldens/before/`.

## Map: first climb, Welcome Back, ads, shell

| Area | Tests |
|------|--------|
| First climb coach | `test/first_climb_coach_test.dart`, `test/first_climb_auto_continue_test.dart` |
| First-session tips | `test/first_session_tips_test.dart` |
| One goal line | `test/chase_contract_test.dart` |
| Welcome Back / offline | `test/offline_progress_test.dart`, `test/ad_boost_test.dart`, `test/return_hooks_test.dart` |
| Rewarded offers | `test/rewarded_offer_test.dart` |
| Remote Config flags | `test/remote_tune_test.dart` |
| Home / fight fit | `test/integration_layout_fit_test.dart`, `test/goldens/after/*_a56.png` |
| Return week / D7 copy | `test/return_week_test.dart`, `test/away_fight_tip_test.dart` |

## `sim` tag

Tagged tests are long combat balance runs. They are excluded from the default CI job on purpose. Do not delete or weaken them to save time; shard CI only with owner approval.