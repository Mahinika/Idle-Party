---
name: planning-and-task-breakdown
description: "Feature planning with vertical slicing, dependency graphs, checkpoint gates, and anti-rationalization safeguards."
user-invocable: true
disable-model-invocation: false
source: pandaos
allowed-tools: Read, Write, Glob, Grep, Bash, Agent
---

# Planning & Task Breakdown

Structured feature planning that produces thin vertical slices with dependency ordering, checkpoint gates, and built-in resistance to common agent shortcuts.
## STEP 0: CONFIG

> Project paths and settings are available in your context from `.pandaos/config.yaml`. Use those values. If not present, use the defaults noted in each step.

## STEP 1: SCALE DETECTION

Assess scope from $ARGUMENTS before planning. Classify into one of three scales:

| Scale | Signal | Output |
|-------|--------|--------|
| **Quick** (<30 min) | Single file, clear fix, no unknowns | Inline task list, no feature doc |
| **Standard** (1-4 hours) | 2-8 files, one feature boundary | Feature doc `F-NNN`, dependency graph |
| **Epic** (multi-day) | Cross-cutting, multiple subsystems | Feature doc + sub-feature breakdown + milestone gates |

For Quick tasks, skip directly to STEP 4 with an inline checklist. For Standard and Epic, continue through all steps.

## STEP 2: CODEBASE RECONNAISSANCE

Before any planning, understand what exists:

1. **Find related code**: Search for similar patterns, existing implementations, and integration points
2. **Map the dependency surface**: Which modules, types, stores, and APIs will this feature touch?
3. **Identify constraints**: Performance budgets, shared code risks, platform differences (Electron/web)
4. **Check for prior art**: Has something similar been attempted before? Check git log for related commits

Do NOT proceed until you can answer: "What existing code will this feature interact with, and how?"

## STEP 3: VERTICAL SLICING

Decompose the feature into thin vertical slices - each slice delivers a minimal but working piece of functionality from data layer to UI.

### Slice rules:
- Each slice must be independently deployable and testable
- A slice touches all layers needed (type, data, logic, UI) - never "build all types first, then all UI"
- Order slices by dependency: Slice 2 can depend on Slice 1, never the reverse
- Each slice has exactly ONE acceptance criterion that can be verified

### Dependency graph:
```
Slice 1: [name] — no dependencies
Slice 2: [name] — depends on Slice 1
Slice 3: [name] — depends on Slice 1
Slice 4: [name] — depends on Slice 2 + 3
```

Mark slices that can run in parallel (no mutual dependency).

## STEP 4: TASK DECOMPOSITION

For each slice, break into ordered tasks:

```
Slice N: [Name]
  AC: [Single verifiable acceptance criterion]

  [ ] Task N.1: [Name]
      Files: [exact paths to create or modify]
      Change: [what specifically changes]
  [ ] Task N.2: ...
```

### Task sizing rules:
- A task should complete in one focused session (15-60 min)
- If a task description uses "and" connecting unrelated changes, split it
- If a task touches more than 5 files, split it
- If you cannot describe the task's acceptance criterion in one sentence, split it

## STEP 5: ANTI-RATIONALIZATION CHECK

Before finalizing the plan, explicitly check for these common agent shortcuts:

| Shortcut agents try | Why it fails | What to do instead |
|---------------------|-------------|-------------------|
| "I'll handle edge cases later" | Edge cases become bugs users hit first | Include edge case handling in the slice where the code lives |
| "Let me build the foundation first" | Horizontal slicing delays testability | Slice vertically: each slice includes its own foundation piece |
| "This is simple enough to do in one task" | Underestimation leads to large uncommitted diffs | If it touches >3 files or >100 lines, split it |
| "I'll add types for everything upfront" | Type-first planning creates unused abstractions | Define types as each slice needs them |
| "Testing can happen at the end" | Late testing finds architectural issues too late | Each slice's AC must be verifiable before starting the next |
| "I'll refactor this to be cleaner once it works" | The refactor never happens | Build it clean the first time or accept the current quality |

Flag any task in the plan that triggers one of these patterns.

## STEP 6: CHECKPOINT GATES

Define gates between phases. A gate is a condition that must be true before proceeding:

- **Gate 0**: Reconnaissance complete - all integration points identified
- **Gate 1**: First slice works end-to-end (proves the approach)
- **Gate N**: Each subsequent slice passes its AC
- **Gate Final**: All slices integrated, no regressions

For Epic scale: add milestone gates every 3-5 slices.

## STEP 7: RISK REGISTER

List concrete risks, not generic ones:

```
RISK: [Specific thing that could go wrong]
IMPACT: [What breaks if this happens]
LIKELIHOOD: low / medium / high
MITIGATION: [Specific action to prevent or recover]
```

Focus on:
- Integration risks (shared code, cross-platform)
- Data risks (migrations, backward compatibility)
- Performance risks (large datasets, render loops)
- Sequencing risks (tasks that seem independent but aren't)

## STEP 8: WRITE FEATURE DOC

For Standard and Epic scale, write the feature doc:

```
Path: {features_path}/{F-NNN}-{kebab-case-name}.md

# F-NNN: [Feature Name]

## Objective
[One paragraph: what problem this solves and for whom]

## Slices
[Dependency graph from STEP 3]

## Tasks
[Full task list from STEP 4]

## Risks
[Risk register from STEP 7]

## Checkpoint Gates
[Gates from STEP 6]

## Decisions
[Any decisions made during planning with rationale]
```

## STEP 9: PRESENT AND CONFIRM

Output the complete plan. For Quick tasks, present inline. For Standard/Epic, reference the written feature doc path.

Never begin implementation before the plan is reviewed.

## BEHAVIORAL RULES

1. Never plan without reading existing code first
2. Never create horizontal slices (all types, then all logic, then all UI)
3. Never skip the anti-rationalization check
4. Never estimate time - estimate complexity (Low/Medium/High/Very High) and slice count
5. If a requirement is ambiguous, ask exactly one clarifying question before proceeding
