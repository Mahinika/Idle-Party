---
name: multi-agent-review
description: "Review multi-agent system design: check coordination patterns, failure modes, and architecture decisions."
source: community
allowed-tools: "*"
user-invocable: true
---

# Multi-Agent System Review

Review a multi-agent system's architecture for correctness, efficiency, and resilience.

## STEP 1: UNDERSTAND THE SYSTEM

Parse $ARGUMENTS for the system to review. Analyze:

- Overall purpose and user-facing behavior
- Number of agents and their individual roles
- Communication topology (who talks to whom)
- Orchestration strategy (supervisor, pipeline, graph, swarm)
- Shared resources (tools, memory, state)

## STEP 2: REVIEW DESIGN

Evaluate the architecture against best practices:

### Agent Decomposition
- Does each agent have a clear, single responsibility?
- Are agents the right granularity (not too broad, not too narrow)?
- Could any agents be merged without losing clarity?
- Could any agents be split to reduce complexity?

### Communication
- Is the communication pattern appropriate for the task?
- Are messages well-structured and typed?
- Is there unnecessary chatter between agents?
- Can any communication be eliminated by restructuring?

### State Management
- Is shared state minimized and well-defined?
- Are there race conditions or consistency issues?
- Is state properly cleaned up between runs?

### Error Handling
- What happens when an individual agent fails?
- Is there graceful degradation?
- Are timeouts configured appropriately?
- Can the system recover from partial failures?

## STEP 3: IDENTIFY RISKS

Flag potential issues:

- **Single points of failure**: Agents that, if they fail, break everything
- **Infinite loops**: Circular agent dependencies or retry storms
- **Cost explosions**: Agents that could generate unbounded token usage
- **Quality bottlenecks**: Agents where errors propagate and amplify

## STEP 4: REPORT

Present findings with severity levels and specific recommendations for each issue.
