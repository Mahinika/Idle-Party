# AGENTS.md

## Repository Status
- This repository is currently a blueprint/specification for a Flutter/Dart idle RPG engine, not a finished implementation.
- The README is the main source of truth for intended architecture and update order: [README.md](README.md).

## How to Work Here
- Prefer small, localized changes that keep the architecture aligned with the README.
- Do not assume missing files exist; verify before referencing them.
- If you need implementation work, first scaffold the actual Flutter project structure (`pubspec.yaml`, `lib/`, `test/`) before adding features.
- Keep systems isolated and respect the strict update pipeline described in the README.

## Useful Notes
- The repo currently has no documented build or test setup beyond the README mentions of `flutter pub get` and `flutter run`.
- Treat any future architecture docs as supporting material; avoid duplicating details that already live in the README.
