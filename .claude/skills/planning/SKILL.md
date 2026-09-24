---
name: planning
description: "Feature planning workflow: decompose requirements into tasks with acceptance criteria, identify risks, estimate complexity."
user-invocable: true
disable-model-invocation: false
model: sonnet
source: anthropic
allowed-tools: Read, Grep, Glob, Bash
---

# Feature Planning

Decomposes a feature or requirement into a structured implementation plan with clear tasks, acceptance criteria, and risk identification.

## STEP 1: UNDERSTAND THE REQUIREMENT

Read the feature description from $ARGUMENTS. Ask exactly one clarifying question if the requirement is ambiguous. Do not proceed with multiple open questions.

Identify:
- The core user problem being solved
- The acceptance criteria (what does "done" look like?)
- Any explicit constraints (performance, compatibility, deadlines)

## STEP 2: CODEBASE RECONNAISSANCE

Before planning implementation, understand the existing system:
- Read relevant files and identify patterns to follow
- Check for similar features already implemented
- Identify integration points (APIs, stores, event systems)
- Note any dependencies or shared types that need updating

## STEP 3: DECOMPOSE INTO TASKS

Break the feature into ordered, concrete tasks. Each task must be:
- Independently implementable (one logical unit of work)
- Testable (has a clear acceptance criterion)
- Sized for completion in a single session (not "implement auth system")

Format each task as:
```
[ ] Task N: [Name]
   AC: [What must be true when this task is complete]
   Files: [Files to create or modify]
```

## STEP 4: IDENTIFY RISKS

List specific risks for this feature:
- Technical risks (complexity, unknowns, performance concerns)
- Integration risks (breaking changes, shared code dependencies)
- Data risks (migrations, backward compatibility)

For each risk, propose a mitigation.

## STEP 5: ESTIMATE COMPLEXITY

Rate overall complexity: Low / Medium / High / Very High.
Justify the rating with 1-2 sentences.

## STEP 6: PRESENT THE PLAN

Output the complete plan. Ask for approval before implementation begins.

## ANTI-PATTERNS

- Planning without reading the existing codebase
- Tasks too large to complete in a session
- Acceptance criteria that can't be tested
- Ignoring integration risks
- Starting implementation before the plan is approved
