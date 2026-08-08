---
name: babysitting-pr
description: >-
  Keep an Idle Party PR merge-ready: watch CI, fix flutter analyze/test/balance
  gate failures, address clear review comments, resolve conflicts (no force-push).
---

# Babysitting a PR (Idle Party)

## Steps

1. **Status**

```bash
gh pr view --json number,title,state,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup,url
gh pr checks
```

2. **Failing checks** — pull logs:

```bash
gh run list --branch "$(git branch --show-current)" --limit 3
gh run view <RUN_ID> --log-failed
```

3. **Fix locally (Flutter)**

| Failure | Local command |
|---------|----------------|
| Analyze | `flutter analyze` |
| Unit tests | `flutter test` (or the failing file) |
| Balance HIGH | `flutter test test/class_balance_gate_test.dart` + share-fast iterate |
| Changelog sync | `flutter test test/changelog_sync_test.dart` |

Minimal fix → commit → `git push` (never `--force` on shared PR branches).

4. **Review comments** — apply clear fixes; skip design debates and report them.

5. **Conflicts**

```bash
git fetch origin main
git merge origin/main
# resolve, commit, push
```

6. **Re-check** — `gh pr checks` (watch pending). Max **3** fix-push cycles, then report blockers.

7. **Report** — what failed, what changed, ready-to-merge or remaining issues.

## Idle Party gotchas

- Don't commit `windows/flutter/generated_plugin_*` noise unless intentional
- Don't weaken balance gate assertions; tune kits instead
- What's New / `pubspec` / `MetaSystems.currentVersion` must stay in sync

## Stop when

- Checks green, no blocking comments, mergeable — or
- 3 cycles without full green — or
- Needs a product decision
