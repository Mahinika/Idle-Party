---
name: incremental-implementation
description: "One-task-at-a-time implementation with thin vertical slices, feature flags, and verify-before-next discipline."
user-invocable: true
disable-model-invocation: false
source: pandaos
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
---

# Incremental Implementation

Execute a plan one task at a time. Each task produces a working, verifiable state before the next begins. No speculative batch changes.
## STEP 0: CONFIG

> Project paths and settings are available in your context from `.pandaos/config.yaml`. Use those values. If not present, use the defaults noted in each step.

## STEP 1: SINGLE TASK FOCUS

Pick exactly ONE task - the next incomplete task in dependency order.

Before writing any code:
1. **Re-read the task's acceptance criterion** - what must be true when this task is done?
2. **Identify the files** to create or modify (should already be listed in the plan)
3. **Read those files** to understand current state
4. **Identify the minimal change** that satisfies the AC - nothing more

## STEP 2: IMPLEMENT THE THIN SLICE

Write code for this single task only. Follow these constraints:

### Vertical slice discipline:
- If the task needs a new type, define it now (not "later with all types")
- If the task needs a new API endpoint, implement it now
- If the task needs UI, add it now
- The slice must work end-to-end, even if the feature is incomplete

### Feature flag pattern (for partially complete features):
When the feature is not yet ready for users but needs to exist in the codebase:
```typescript
// Feature flag - remove when [feature name] is complete
const FEATURE_ENABLED = false

if (FEATURE_ENABLED) {
  // new code path
}
```

### Change boundaries:
- Only modify files listed in the task
- If you discover a file not in the plan needs changing, note it but do not change it unless essential
- Never refactor unrelated code while implementing a task
- Keep each task's diff reviewable (under ~200 lines changed)

## STEP 3: VERIFY BEFORE NEXT

After implementing the task, verify it works:

### Verification checklist:
1. **Type check**: Does the code compile without errors?
2. **AC satisfied**: Does the acceptance criterion hold?
3. **No regressions**: Did existing functionality break?
4. **Clean diff**: Are the changes limited to what the task required?

### Verification methods (in preference order):
- Run existing tests: `npm run test` or relevant test command
- Type check: `npx tsc --noEmit`
- Manual verification: describe what to check and expected behavior
- If automated verification is not possible, document what needs manual testing

Do NOT proceed to the next task until verification passes.

## STEP 4: LOG PROGRESS

Write an implementation log entry:

```
Path: {implementation_log_path}/impl-{feature-id}-{date}.md
```

Append to the log (create if first task):

```markdown
## Task N.M: [Name] - DONE

**Changes:**
- `path/to/file.ts`: [what changed]
- `path/to/other.ts`: [what changed]

**Verification:** [how it was verified]
**Issues encountered:** [any surprises, deviations from plan]
**Time:** [timestamp]
```

## STEP 5: HANDLE BLOCKERS

If a task cannot be completed as planned:

### Blocker types and responses:

| Blocker | Response |
|---------|----------|
| Missing dependency from earlier task | Go back and verify that task is truly complete |
| Plan assumption was wrong | Document the deviation, adjust THIS task only, flag for plan update |
| Scope creep ("while I'm here, I should also...") | Stop. Log it as a follow-up. Do not act on it. |
| External dependency (API not ready, package missing) | Implement with a stub/mock, document the stub, move on |
| Task is larger than expected | Split it into sub-tasks NOW, before continuing |

### Anti-rationalization check:

| Shortcut you might try | Why it fails |
|------------------------|-------------|
| "Let me do the next two tasks together, they're related" | Larger diffs, harder to verify, harder to revert |
| "This task is trivial, I'll skip verification" | Trivial tasks have trivial bugs that compound |
| "I'll fix this test later" | Broken tests become normalized, then ignored |
| "The plan is wrong, let me improvise" | Improvisation without updating the plan creates drift |
| "I need to refactor this first" | Refactoring is a separate task. Log it, don't do it now. |

## STEP 6: COMMIT CHECKPOINT

After each verified task:
1. Stage only the files changed for this task
2. Propose a commit with a clear message referencing the task
3. Update the feature plan: mark the task as complete

## STEP 7: ITERATE

Return to STEP 1 with the next incomplete task. Continue until all tasks are done or a blocker requires plan revision.

When all tasks are complete:
1. Review the full implementation log
2. Verify the complete feature works end-to-end
3. Check for any stubs or feature flags that should be cleaned up
4. Propose a final integration commit if needed

## BEHAVIORAL RULES

1. One task at a time. Never batch. Never parallelize implementation of dependent tasks.
2. Never skip verification. A 30-second type check is faster than a 30-minute debug session.
3. Never modify files outside the current task's scope without documenting why.
4. If the plan needs updating, update it explicitly - do not silently deviate.
5. Commit after every verified task. Small commits are always better than large ones.
6. Log everything. The implementation log is the source of truth for what happened.
