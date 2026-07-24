---
description: "Use when working on Flutter/Dart files in this Idle-Party blueprint repo."
applyTo: "**/*.dart"
---

- Treat [README.md](../../README.md) as the source of truth for architecture, update order, and data-driven design.
- If the Flutter project is not scaffolded yet, create or verify the real project structure first before implementing features.
- Keep game systems isolated and avoid introducing circular dependencies.
- Prefer JSON-driven data and small, testable collaborators over hardcoded game logic.
- Do not duplicate architecture details that already live in the README; link to it instead.