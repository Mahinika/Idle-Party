# ============================================================
# REPO AUDIT MASTER PROMPT
# ============================================================
#
# PURPOSE:
# Perform a complete repository-wide technical audit.
#
# IMPORTANT:
# This is an ANALYSIS task.
# DO NOT MODIFY CODE unless explicitly instructed later.
#
# ============================================================

You are a senior software architect, code auditor, performance engineer,
dependency analyst and refactoring specialist.

Your task is to perform a COMPLETE REPOSITORY AUDIT.

Do NOT immediately start changing code.

First build an accurate mental model of the entire repository.

The audit must cover:

1. Repository architecture
2. Dependency graph
3. Runtime integration
4. Dead code
5. Orphaned code
6. Broken integrations
7. Unused imports/exports
8. State/data flow
9. Duplicate functionality
10. Legacy/migrated systems
11. Performance hotspots
12. Allocation/GC hotspots
13. Algorithmic complexity
14. Excessive loops/scans
15. Architecture problems
16. Circular dependencies
17. Abstraction problems
18. God classes / God files
19. Tight coupling
20. Incorrect separation of responsibilities
21. Error handling
22. Async/concurrency risks
23. Resource leaks
24. Test coverage gaps
25. Configuration/data that is defined but never consumed
26. APIs that are defined but never used
27. Runtime paths that appear incomplete
28. Potential bugs discovered during the audit

============================================================
PHASE 0 — RULES
============================================================

ABSOLUTE RULES:

- Do NOT modify files.
- Do NOT refactor.
- Do NOT delete code.
- Do NOT rename symbols.
- Do NOT install dependencies.
- Do NOT generate replacement code unless specifically requested.
- Do NOT assume something is dead merely because it is not referenced
  in the current file.
- Do NOT assume something is unused merely because static search finds
  no direct call.
- Do NOT report guesses as facts.
- Distinguish FACT from INFERENCE.
- Use repository evidence whenever possible.
- Give file paths and line numbers for findings.
- Be conservative when classifying dead code.

IMPORTANT:

"NO REFERENCE FOUND"

does NOT automatically mean:

"DEAD CODE"

Before declaring something DEAD, investigate:

- imports
- exports
- part files
- inheritance
- interfaces
- mixins
- extensions
- factories
- dependency injection
- callbacks
- event systems
- listeners
- registration systems
- routing
- serialization
- reflection
- generated code
- annotations
- configuration
- plugins
- test-only usage
- build scripts
- code generation
- dynamic invocation
- framework conventions

If uncertainty remains:

classify as SUSPICIOUS instead of DEAD.

============================================================
PHASE 1 — REPOSITORY DISCOVERY
============================================================

Start by scanning the entire repository.

Identify:

- language(s)
- framework(s)
- package manager
- build system
- test framework
- entry points
- executable targets
- libraries/packages
- generated code
- configuration files
- CI/CD
- scripts
- assets
- database layer
- networking
- persistence
- state management
- UI
- rendering
- services
- domain logic
- utilities
- tests

Create a high-level repository map.

Example:

APP
 ├── UI
 ├── STATE
 ├── DOMAIN
 ├── SERVICES
 ├── DATA
 ├── NETWORK
 └── INFRASTRUCTURE

Do not invent architecture that does not exist.

Describe the actual architecture.

============================================================
PHASE 2 — ENTRY POINTS
============================================================

Identify every meaningful entry point.

Examples:

- main()
- application bootstrap
- CLI commands
- HTTP endpoints
- routes
- controllers
- event handlers
- background workers
- scheduled jobs
- game loop
- widget tree roots
- plugin entry points
- service initialization

For each entry point:

ENTRY
 ↓
SYSTEM
 ↓
DEPENDENCIES
 ↓
STATE
 ↓
OUTPUT

Trace the runtime path.

============================================================
PHASE 3 — DEPENDENCY GRAPH
============================================================

Build a dependency model.

Analyze:

A imports B
A calls B
A instantiates B
A extends B
A implements B
A listens to B
A emits event C
A depends on interface D

Identify:

- direct dependencies
- indirect dependencies
- circular dependencies
- highly connected modules
- dependency hotspots
- modules with excessive outgoing dependencies
- modules with excessive incoming dependencies

Pay particular attention to:

"central modules"

that many unrelated systems depend on.

These may indicate architectural coupling.

============================================================
PHASE 4 — SYMBOL INVENTORY
============================================================

Inventory important symbols:

- classes
- enums
- functions
- methods
- constructors
- fields
- constants
- variables
- interfaces
- abstract classes
- mixins
- extensions
- typedefs
- factories
- services
- managers
- controllers
- repositories
- providers
- state objects

For each important symbol determine:

DEFINITION
 ↓
REFERENCES
 ↓
CALLERS
 ↓
CALLEES
 ↓
RUNTIME PATH

============================================================
PHASE 5 — DEAD CODE AUDIT
============================================================

Classify code into:

🟢 ACTIVE

Clearly used by the application.

🟡 ORPHANED

Implemented but apparently not connected to the active system.

🔴 DEAD

Strong evidence that it has no consumer anywhere in the repository.

🔵 INDIRECT

Used through a mechanism not obvious from direct references.

🟣 DUPLICATED

Functionality exists in multiple implementations.

🟠 SUSPICIOUS

Probably legacy, incomplete or obsolete, but evidence is insufficient.

For DEAD findings provide:

- symbol
- file
- line
- definition
- repository-wide search result
- why it is dead
- confidence

Confidence:

HIGH
MEDIUM
LOW

============================================================
PHASE 6 — ORPHANED FUNCTIONALITY
============================================================

Find code that is fully implemented but never reaches runtime.

Examples:

Ability exists
BUT
nothing triggers it.

Service exists
BUT
nothing registers it.

Event exists
BUT
nothing listens.

State exists
BUT
nothing reads it.

UI exists
BUT
no route reaches it.

Config exists
BUT
nothing consumes it.

For each:

WHAT EXISTS
WHAT SHOULD CONNECT IT
WHERE THE CHAIN BREAKS
LIKELY INTENTION

============================================================
PHASE 7 — BROKEN DATA FLOW
============================================================

Trace important data.

Examples:

INPUT
 ↓
VALIDATION
 ↓
STATE
 ↓
BUSINESS LOGIC
 ↓
OUTPUT

Look for:

- values written but never read
- values read but never written
- values overwritten before consumption
- default values that always remain default
- state that never changes
- state that changes but produces no observable effect
- data produced but never consumed
- data consumed from an obsolete source

Report:

WRITE-ONLY
READ-ONLY
UNUSED
BROKEN FLOW
SUSPICIOUS FLOW

============================================================
PHASE 8 — DUPLICATION AUDIT
============================================================

Find duplicated or overlapping functionality.

Look for:

- duplicate calculations
- duplicate validation
- duplicate state transitions
- duplicate target selection
- duplicate caching
- duplicate API wrappers
- duplicate formatting
- duplicate parsing
- duplicate business rules
- duplicate managers
- duplicate services
- duplicate rendering
- duplicate VFX/effects
- duplicate utility functions

Do not only look for identical code.

Also detect:

SEMANTIC DUPLICATION

where two different implementations accomplish essentially the same job.

For each:

SYSTEM A
SYSTEM B
SIMILARITY
WHICH IS ACTIVE
WHICH SHOULD PROBABLY BE CANONICAL

============================================================
PHASE 9 — LEGACY / MIGRATION AUDIT
============================================================

Search for evidence of previous implementations.

Common patterns:

old_
legacy_
deprecated
v1
v2
new
newSystem
migrated
compat
adapter
bridge
fallback
temporary
TODO
FIXME

But do not rely only on names.

Look for architectural migration patterns:

OLD SYSTEM
 ↓
NEW SYSTEM
 ↓
NEW SYSTEM ACTIVE
 ↓
OLD SYSTEM STILL PRESENT

Identify:

- abandoned migrations
- half-migrated systems
- compatibility layers no longer needed
- old APIs
- duplicated state models
- duplicate managers
- old render paths
- old combat paths
- obsolete data structures

============================================================
PHASE 10 — IMPORT / EXPORT AUDIT
============================================================

Find:

- unused imports
- unused exports
- files never imported
- exports never consumed
- suspicious wildcard exports
- circular imports
- unnecessary dependencies
- dependencies that exist only because of legacy code

Do not automatically classify public APIs as dead.

============================================================
PHASE 11 — PERFORMANCE AUDIT
============================================================

Analyze runtime performance.

Focus especially on hot paths:

- frame loops
- game loops
- render loops
- update loops
- network loops
- database queries
- event handlers
- repeated state updates
- animation updates
- physics
- collision
- AI
- pathfinding
- sorting
- filtering
- serialization

Identify:

O(n)
O(n²)
O(n³)
O(n*m)
recursive complexity
repeated scans
nested searches

Look for:

- loops inside loops
- repeated searches
- repeated sorting
- repeated filtering
- repeated pathfinding
- repeated distance calculations
- repeated serialization
- repeated parsing
- unnecessary recomputation

For every hotspot explain:

CURRENT COMPLEXITY
EXPECTED INPUT SIZE
WHY IT MATTERS
POSSIBLE OPTIMIZATION

Do not optimize prematurely.

============================================================
PHASE 12 — MEMORY / ALLOCATION AUDIT
============================================================

Look for allocations inside hot paths.

Examples:

- new lists
- spread operators
- map/filter/toList
- temporary objects
- closures
- strings
- JSON serialization
- copies
- immutable state copies
- repeated collection creation

Identify possible:

GC pressure
allocation spikes
memory churn
large temporary structures

Distinguish:

LOW IMPACT
MEDIUM IMPACT
HIGH IMPACT

============================================================
PHASE 13 — CACHING AUDIT
============================================================

Identify expensive calculations repeated unnecessarily.

Look for values that could potentially be cached:

- target selection
- pathfinding
- distances
- lookup tables
- parsed data
- configuration
- computed state
- derived values

Do not automatically recommend caching.

Consider:

- invalidation
- memory cost
- correctness
- update frequency

============================================================
PHASE 14 — ARCHITECTURE AUDIT
============================================================

Evaluate:

SEPARATION OF CONCERNS

Does one class/module do too many unrelated things?

Identify:

- God classes
- God files
- oversized managers
- mixed UI/business logic
- mixed persistence/business logic
- mixed rendering/gameplay logic
- excessive static state
- hidden global state
- tight coupling
- inappropriate inheritance
- excessive abstraction
- leaky abstractions

Also identify healthy architectural boundaries.

Do NOT recommend abstraction merely for abstraction's sake.

============================================================
PHASE 15 — COUPLING / COHESION
============================================================

Find modules that:

- know too much about each other
- depend on implementation details
- mutate each other's state
- require many parameters
- expose internal structures
- have high fan-in
- have high fan-out

Identify:

HIGH COUPLING
LOW COHESION
GOOD BOUNDARIES

============================================================
PHASE 16 — STATE MANAGEMENT AUDIT
============================================================

If the repository contains state management:

Trace:

STATE CREATION
 ↓
STATE UPDATE
 ↓
STATE CONSUMPTION
 ↓
UI / RUNTIME EFFECT

Look for:

- redundant state
- derived state stored unnecessarily
- stale state
- duplicated state
- state synchronization problems
- mutation hidden behind immutable APIs
- state updated too frequently
- state updates that trigger unnecessary rebuilds/renders

============================================================
PHASE 17 — ERROR HANDLING
============================================================

Identify:

- swallowed exceptions
- empty catch blocks
- overly broad exception handling
- ignored futures/promises
- missing error propagation
- silent failures
- inconsistent error handling
- impossible states not guarded

Classify:

BUG RISK
MAINTENANCE RISK
LOW RISK

============================================================
PHASE 18 — ASYNC / CONCURRENCY
============================================================

If applicable, inspect:

- async/await
- futures/promises
- streams
- isolates/workers
- threads
- locks
- shared mutable state
- cancellation
- race conditions

Look for:

- unawaited async operations
- duplicate requests
- race conditions
- stale callbacks
- memory leaks through listeners
- tasks that cannot be cancelled
- concurrency assumptions

============================================================
PHASE 19 — TEST AUDIT
============================================================

Analyze tests.

Identify:

- important systems without tests
- dead tests
- tests that reference obsolete APIs
- duplicated tests
- missing edge cases
- integration paths without coverage
- performance-sensitive code without tests

Do not judge coverage purely by percentage.

Focus on risk.

============================================================
PHASE 20 — CONFIGURATION / DATA AUDIT
============================================================

Find:

- configuration values never consumed
- environment variables never read
- feature flags never checked
- enum values never handled
- JSON fields never consumed
- database fields never used
- assets never referenced
- routes never reachable
- localization keys never used

Again:

Do not classify dynamic systems as dead without evidence.

============================================================
PHASE 21 — RUNTIME GRAPH
============================================================

For the major systems create a conceptual runtime graph.

Example:

USER
 ↓
UI
 ↓
CONTROLLER
 ↓
SERVICE
 ↓
DOMAIN
 ↓
STATE
 ↓
RENDERER

For game systems:

INPUT
 ↓
GAME LOOP
 ↓
AI
 ↓
TARGETING
 ↓
ABILITY
 ↓
DAMAGE
 ↓
STATE
 ↓
VFX
 ↓
UI

Mark:

🟢 working path
🟡 suspicious path
🔴 broken path

============================================================
PHASE 22 — PRIORITIZATION
============================================================

Every finding must receive:

SEVERITY:

P0 — Critical
P1 — High
P2 — Medium
P3 — Low

CATEGORY:

DEAD_CODE
ORPHANED
BROKEN_INTEGRATION
DUPLICATION
PERFORMANCE
MEMORY
ARCHITECTURE
COUPLING
STATE
ERROR_HANDLING
ASYNC
TESTING
CONFIGURATION
LEGACY

CONFIDENCE:

HIGH
MEDIUM
LOW

============================================================
FINAL REPORT
============================================================

Produce the final report in this exact structure:

# REPOSITORY AUDIT

## 1. Executive Summary

Give a concise overview.

Include:

Files analyzed:
Systems identified:
Critical findings:
High findings:
Dead code candidates:
Orphaned systems:
Broken integrations:
Performance hotspots:
Duplicate systems:
Architecture concerns:

---

# 2. Repository Architecture

Show the actual architecture.

---

# 3. Runtime / Dependency Map

Show the most important dependency and runtime relationships.

---

# 4. 🔴 DEAD CODE

| Severity | Symbol | File | Line | Evidence | Confidence |
|---|---|---|---:|---|---|

Only include high-confidence dead code here.

---

# 5. 🟡 ORPHANED CODE

| Severity | Symbol/System | File | Missing Connection | Likely Purpose | Confidence |
|---|---|---|---|---|---|

---

# 6. 🔴 BROKEN INTEGRATIONS

For every broken chain:

EXISTS
 ↓
EXISTS
 ↓
❌ BREAK

Explain exactly where it breaks.

---

# 7. 🟣 DUPLICATED FUNCTIONALITY

| System A | System B | Overlap | Active One | Recommendation |
|---|---|---|---|---|

---

# 8. 🟠 LEGACY / MIGRATION

List old systems that appear to have been replaced.

---

# 9. ⚡ PERFORMANCE

Rank the biggest performance risks.

For each include:

Location
Hot path
Complexity
Why expensive
Estimated impact
Potential solution

---

# 10. 🧠 MEMORY / GC

List allocation hotspots.

---

# 11. 🏗️ ARCHITECTURE

List:

God classes
God files
High coupling
Low cohesion
Poor boundaries
Over-abstractions
Global state

---

# 12. 🔄 DATA / STATE FLOW

Identify broken or suspicious data flow.

---

# 13. 📦 IMPORT / EXPORT

List dependency problems.

---

# 14. 🧪 TESTING

List high-risk untested systems.

---

# 15. ⚠️ POTENTIAL BUGS

Only include issues discovered during the audit.

Do not speculate without evidence.

---

# 16. 🧹 CLEANUP PLAN

Create a prioritized plan:

P0
P1
P2
P3

Do NOT make the changes.

---

# 17. TOP 20 ACTIONS

Give the 20 most valuable improvements in order.

For each:

1. Problem
2. Why it matters
3. Files affected
4. Risk
5. Expected benefit

============================================================
FINAL SAFETY CHECK
============================================================

Before finishing:

1. Verify all DEAD findings.
2. Check part files.
3. Check generated code.
4. Check indirect references.
5. Check tests.
6. Check registrations/factories.
7. Check callbacks/events.
8. Check configuration.
9. Distinguish evidence from inference.
10. Do not recommend deletion when confidence is low.

DO NOT MODIFY THE REPOSITORY.

Return only the completed audit report.
