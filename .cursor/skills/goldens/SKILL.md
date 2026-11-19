---
name: goldens
description: >-
  How to add or regenerate Idle Party UI goldens. Use when a widget or
  menu needs a screenshot test, a golden fails, or goldens must be
  updated. Do not use for the verify loop (flutter-verify) or paper-doll
  facit (gear-art).
---

# Goldens

Do not rewrite or weaken existing golden tests.

## New goldens

- Prefer **small per-widget or per-menu** goldens, not a full hub or
  fight shot, unless the change is the whole shell.
- Use the helper in `test/widget_golden.dart` (`pumpWidgetGolden`) for
  those small shots. They live under `goldens/widgets/`.
- Existing full-shell / fight shots stay on `test/shell_golden_harness.dart`
  and `goldens/after/`. Leave that path alone unless those files already
  cover the change.

## Generate and regenerate

- Create and update goldens on **Linux** with the **pinned Flutter**
  from `.github/workflows/ci.yml` (`flutter-version`, currently 3.47.9).
  A different OS or SDK makes pixels drift.
- **Regenerate by running the whole golden file.** Never a single named
  test. A named test renders differently than the file run as a whole.
- Example: `flutter test test/shell_chrome_golden_test.dart --update-goldens`

## Done when

- New goldens are small, generated on Linux with the pin, and the whole
  file was used to write or update them.
- Existing goldens were not weakened or rewritten unasked.
