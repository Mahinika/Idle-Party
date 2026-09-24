---
name: systematic-debug
description: "Systematic debugging workflow: reproduce, isolate, hypothesize, verify, fix. Prevents guesswork and shotgun debugging."
user-invocable: true
disable-model-invocation: false
model: sonnet
source: anthropic
---

# Systematic Debugging

A structured approach to finding and fixing bugs that eliminates guesswork. Every step must be completed before moving to the next.

## STEP 1: REPRODUCE

Establish a minimal, reliable reproduction case for the bug described in $ARGUMENTS or the conversation.

- Identify the exact inputs, state, and sequence of actions that trigger the bug
- Confirm the bug is reproducible on demand — intermittent bugs need frequency characterization
- Document: "Given X, when Y happens, I expect Z but instead get W"
- If the bug cannot be reproduced, halt here and request more information

## STEP 2: READ THE ERROR

Read the full error message, stack trace, and any relevant logs. Do not skip any line.

- Identify the exact file, line, and function where the error originates
- Distinguish between the error origin (where it throws) and the error cause (why it throws)
- Check if the error is a symptom of an upstream failure, not the root cause

## STEP 3: ISOLATE

Narrow the problem space:
- Identify the smallest code path involved in the failure
- Remove variables: simplify inputs, disable unrelated code paths, rule out environmental factors
- Check recent changes: `git log --oneline -20` and `git diff HEAD~5` to identify what changed recently near the bug

## STEP 4: FORM HYPOTHESES

List 2-3 specific, falsifiable hypotheses about the root cause. Rank by likelihood. For each:
- State the hypothesis clearly: "The bug is caused by X because Y"
- Identify how to verify or disprove it without making code changes yet

## STEP 5: VERIFY

Test each hypothesis systematically, starting with the most likely. Use:
- Console logs or debugger statements at precise points (not scattered throughout)
- Unit tests that isolate the suspected function
- Binary search: comment out half the code path to locate the failing segment

Do NOT make any fixes during this phase. Only gather evidence.

## STEP 6: FIX

Apply the minimal targeted fix that addresses the verified root cause:
- Change only what is necessary — do not refactor surrounding code
- Add a regression test that would have caught this bug before the fix
- Verify the original reproduction case now works
- Run the full test suite to confirm no regressions

## STEP 7: DOCUMENT

Add a comment at the fix location explaining WHY the bug occurred and WHY this fix is correct. Not what the code does — why it was wrong and why this is right.

## FIVE-STEP TRIAGE SUMMARY

Quick reference for the systematic process:

| Step | Action | Gate (must pass before next step) |
|------|--------|-----------------------------------|
| **Reproduce** | Reliable reproduction case documented | Bug triggers on demand |
| **Localize** | Narrow to specific file, function, line | Know WHERE it breaks |
| **Reduce** | Minimal reproduction, remove all noise | Smallest possible failing case |
| **Fix** | Minimal targeted change to root cause | Tests pass, regression test added |
| **Guard** | Prevent recurrence | Regression test, monitoring, or type guard in place |

## STOP-THE-LINE RULE

If the bug is in production and affects users:
1. **Assess severity** - Data loss? Security? Degraded UX?
2. **Deploy a safe fallback** - Feature flag off, graceful degradation, or revert
3. **Then** investigate root cause systematically (do not skip steps under pressure)

Safe fallbacks:
- Feature flag to disable the broken feature
- Return cached/stale data instead of erroring
- Show a degraded but functional UI
- Revert the deploy if the bug was introduced in the last release

## POST-MORTEM TEMPLATE

After fixing any production bug, document:

```
## What happened
<One sentence: what broke, who was affected, for how long>

## Root cause
<Why it broke - the actual technical cause, not the symptom>

## Detection
<How was it detected? Monitoring, user report, CI?>

## Fix
<What was changed and why>

## Prevention
<What will prevent this class of bug from recurring?>
- [ ] Regression test added
- [ ] Monitoring/alerting improved
- [ ] Type safety tightened
- [ ] Documentation updated
```

## ANTI-PATTERNS

- Shotgun debugging: changing multiple things at once without verifying each
- Fixing the symptom instead of the root cause
- Skipping reproduction confirmation
- Not adding a regression test after fixing
- Assuming the most obvious explanation is correct without verification

## ANTI-RATIONALIZATION TABLE

| Shortcut | Why It Fails | Do This Instead |
|----------|-------------|-----------------|
| "Let me just try this quick fix" | You'll spend 3 hours on quick fixes that don't work | Spend 15 minutes reproducing and isolating first |
| "It works on my machine" | Environment differences are a category of bugs, not an excuse | Document the exact environment where it reproduces |
| "It's probably a race condition" | "Probably" is not a diagnosis | Prove it with logging, then fix the ordering |
| "Let me add a null check here" | Null checks mask the real bug upstream | Find WHY it's null and fix the source |
| "Restarting the server fixes it" | The bug will return; you've just delayed it | Investigate why state gets corrupted |
