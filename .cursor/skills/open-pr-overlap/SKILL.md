---
name: open-pr-overlap
description: >-
  Checks a new branch against files other open PRs already change.
  Use before starting work while a PR is open, or when the owner says
  "krockar den". Do not use for fixing that open PR (babysitting-pr).
---

# Open PR overlap

Resolve the open PRs from the remote. Do not keep a list of numbers in
this skill.

## Procedure

1. `gh pr list --state open --json number,headRefOid,baseRefName`.
2. For each PR, `git diff --name-only <base> <headRefOid>` after
   `git fetch` of that base and that oid. Fetch is read-only.
3. Intersect those paths with the files this branch will edit.
4. A shared `.png` or other binary does not merge as text. Say which
   path, and do not edit it on a second branch.
5. Leave the other PR's branch, its town-agent branch, and its commits
   alone unless the owner names that PR in this turn.

## Done when

- The intersection is empty, or the overlapping paths are named and
  this branch does not touch them.
