#!/usr/bin/env bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
WT="${ROLE_ICONS_BEFORE_WT:-/tmp/ip-fight-ui-stack-before}"
git -C "$REPO" fetch origin test/fight-ui-stack
if [[ -d "$WT" ]]; then
  git -C "$REPO" worktree remove "$WT" --force 2>/dev/null || rm -rf "$WT"
fi
git -C "$REPO" worktree add "$WT" origin/test/fight-ui-stack
mkdir -p "$WT/test/support"
cp "$REPO/test/support/role_icons_fight_harness.dart" "$WT/test/support/"
cp "$REPO/test/role_icons_before_artifact_test.dart" "$WT/test/"
(
  cd "$WT"
  flutter test test/role_icons_before_artifact_test.dart \
    --dart-define=ROLE_ICONS_AFTER=false
)
git -C "$REPO" worktree remove "$WT" --force