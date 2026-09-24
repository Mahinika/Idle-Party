---
name: spec-driven-development
description: "PRD and specification writing: objectives, commands, structure, code style, testing strategy, and system boundaries."
user-invocable: true
disable-model-invocation: false
source: pandaos
allowed-tools: Read, Write, Glob, Grep
---

# Spec-Driven Development

Write a complete product/technical specification before implementation begins. The spec becomes the single source of truth for what to build, how to build it, and how to verify it.
## STEP 0: CONFIG

> Project paths and settings are available in your context from `.pandaos/config.yaml`. Use those values. If not present, use the defaults noted in each step.

## STEP 1: REQUIREMENTS GATHERING

From $ARGUMENTS, extract and organize requirements into three categories:

### Functional requirements (MUST):
- What the system must do - observable behaviors
- User-facing commands, inputs, and expected outputs
- State transitions and data flows

### Non-functional requirements (SHOULD):
- Performance targets (response time, throughput, memory)
- Compatibility constraints (platforms, browsers, versions)
- Security requirements (auth, data handling, validation)
- Accessibility requirements

### Boundaries (MUST NOT):
- What is explicitly out of scope
- What the system must NOT do (constraints, not just absence)
- Integration boundaries - what this system owns vs. delegates

If requirements are ambiguous, ask up to two clarifying questions. Do not fill gaps with assumptions.

## STEP 2: CODEBASE ANALYSIS

Before writing the spec, understand the existing system:

1. **Architecture**: What patterns does the codebase follow? (MVC, event-driven, layered, etc.)
2. **Conventions**: Read `.claude/rules/`, `CLAUDE.md`, and any style guides
3. **Adjacent features**: Find similar features and study their structure
4. **Type landscape**: Identify shared types this feature will interact with

Document findings as "Existing Patterns" in the spec - implementors need this context.

## STEP 3: WRITE THE SPECIFICATION

Create the spec document at `{specs_path}/{S-NNN}-{kebab-case-name}.md`:

```markdown
# S-NNN: [Feature Name]

## 1. Objective
[One paragraph: what problem this solves, for whom, and what success looks like]

## 2. User Stories
- As a [role], I want [action], so that [benefit]
- ...

## 3. Commands / API Surface
[For CLI tools, list commands. For APIs, list endpoints. For UI, list interactions.]

| Command / Action | Input | Output | Side Effects |
|-----------------|-------|--------|-------------|
| ... | ... | ... | ... |

## 4. Data Model
[Types, schemas, database tables. Use TypeScript interfaces or Zod schemas.]

## 5. System Structure
[File organization, module boundaries, dependency direction]

```
module-a/
  ├── types.ts      — shared types
  ├── service.ts    — business logic
  └── handler.ts    — API/IPC handler
```

## 6. Code Style & Patterns
[Conventions specific to this feature, derived from codebase analysis]

- Error handling: [Result pattern / exceptions / error codes]
- State management: [Zustand store / React context / server state]
- Communication: [HTTP / IPC / SSE / direct import]

## 7. Acceptance Criteria
[Numbered list of verifiable conditions]

1. Given [precondition], when [action], then [expected result]
2. ...

## 8. Testing Strategy
- Unit tests: [what to test, what to mock]
- Integration tests: [what boundaries to test across]
- Edge cases: [specific scenarios to cover]

## 9. Boundaries
- OUT OF SCOPE: [explicit exclusions]
- DEFERRED: [things that could be added later but are not part of this spec]
- CONSTRAINTS: [things the implementation must NOT do]

## 10. Open Questions
[Unresolved decisions that need input before implementation]
```

## STEP 4: ACCEPTANCE CRITERIA REFINEMENT

Review each acceptance criterion against these quality checks:

### Good acceptance criteria:
- **Specific**: "The search returns results within 200ms for up to 10,000 items"
- **Testable**: Can be verified with a concrete test case
- **Independent**: Does not depend on another AC to be meaningful
- **Complete**: Covers the happy path, error cases, and edge cases

### Anti-rationalization check:

| Shortcut | Why it fails |
|----------|-------------|
| "User can do X" (no error case) | What happens when X fails? AC must cover both paths |
| "System handles errors gracefully" | Vague. Specify: what error, what user sees, what system state |
| "Performance is acceptable" | Unverifiable. Specify: metric, threshold, measurement method |
| "Works like the existing feature" | The existing feature may have bugs. Spec the behavior explicitly |
| "See mockup for details" | Mockups are ambiguous. Extract every interaction into an AC |

## STEP 5: BOUNDARY VALIDATION

Verify the spec's boundaries are watertight:

1. **Input boundaries**: What happens with empty input? Maximum-length input? Invalid characters? Concurrent inputs?
2. **State boundaries**: What happens if the system is in an unexpected state? Mid-migration? Partially initialized?
3. **Integration boundaries**: What happens if an external dependency is down? Returns unexpected data? Times out?
4. **Permission boundaries**: What happens if the user lacks permissions? Has expired credentials?

Add any missing boundary conditions to the acceptance criteria.

## STEP 6: REVIEW AND FINALIZE

Present the spec for review. Highlight:
- Any open questions that block implementation
- Any requirements that could not be fully specified
- Dependencies on external decisions or systems

The spec is complete when every acceptance criterion is specific, testable, and covers both success and failure paths.

## BEHAVIORAL RULES

1. Never start implementation from a spec with open questions in critical areas
2. Never assume requirements - ask or flag as "ASSUMED: [assumption]" for review
3. Acceptance criteria are non-negotiable: if it cannot be tested, it is not a criterion
4. The spec must be readable by someone with no prior context about the feature
5. Update the spec when requirements change during implementation - it stays the source of truth
