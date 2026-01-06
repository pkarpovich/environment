# Agentic Prompt Design for Claude 4.x

Specialized guidance for prompts that involve tool use, multi-step tasks, and autonomous workflows.

## Table of Contents

1. [Core Agentic Principles](#core-agentic-principles)
2. [Tool Usage Patterns](#tool-usage-patterns)
3. [Multi-Context Window Tasks](#multi-context-window-tasks)
4. [State Management](#state-management)
5. [Subagent Orchestration](#subagent-orchestration)
6. [Complete Agentic System Prompt](#complete-agentic-system-prompt)

---

## Core Agentic Principles

### 1. Action Bias

Claude 4.x needs explicit instruction to act vs analyze:

```xml
<default_to_action>
By default, implement changes rather than only suggesting them. If the user's intent is unclear, infer the most useful likely action and proceed, using tools to discover any missing details instead of guessing.
</default_to_action>
```

### 2. Investigation Before Action

Prevent hallucinations and wrong assumptions:

```xml
<investigate_before_answering>
ALWAYS read and understand relevant files before proposing code edits. Do not speculate about code you have not inspected. If the user references a specific file/path, you MUST open and inspect it before explaining or proposing fixes.
</investigate_before_answering>
```

### 3. Incremental Progress

For complex tasks, emphasize step-by-step work:

```xml
<incremental_approach>
Focus on incremental progress—make steady advances on a few things at a time rather than attempting everything at once. Track your progress and commit working changes before moving to the next step.
</incremental_approach>
```

---

## Tool Usage Patterns

### Parallel Tool Calls

Claude 4.x (especially Sonnet 4.5) is aggressive with parallel execution. Control this:

**Maximum parallelism:**
```xml
<use_parallel_tool_calls>
If you intend to call multiple tools and there are no dependencies between the calls, make all independent calls in parallel. When reading 3 files, run 3 tool calls in parallel. Never use placeholders or guess missing parameters.
</use_parallel_tool_calls>
```

**Reduced parallelism (for stability):**
```xml
<sequential_execution>
Execute operations sequentially with brief pauses between each step to ensure stability.
</sequential_execution>
```

### Tool Triggering

Claude Opus 4.5 is very responsive to system prompts. If you had aggressive language to prevent undertriggering, dial it back:

**Before (causes overtriggering in Opus 4.5):**
```
CRITICAL: You MUST use this tool when...
```

**After (balanced for Opus 4.5):**
```
Use this tool when...
```

### File Creation Control

Claude 4.x tends to create temporary files as scratchpads. Control this:

```xml
<file_hygiene>
If you create any temporary files, scripts, or helper files for iteration, clean up these files by removing them at the end of the task.
</file_hygiene>
```

---

## Multi-Context Window Tasks

For tasks that span multiple context windows, use these patterns:

### First Context Window Setup

```xml
<first_session_setup>
This is the first session of a multi-session task. Your priorities:
1. Write comprehensive tests in a structured format (tests.json)
2. Create setup scripts (init.sh) for environment initialization
3. Establish the framework and architecture
4. Document the task breakdown in progress.txt

Future sessions will iterate on this foundation.
</first_session_setup>
```

### Continuation Sessions

```xml
<continuation_session>
This is a continuation of a multi-session task. Before starting:
1. Run pwd to confirm your working directory
2. Review progress.txt, tests.json, and git logs
3. Run the test suite to understand current state
4. Continue from where the previous session left off

Do not redo completed work. Focus on the next incomplete item.
</continuation_session>
```

### Context Persistence

```xml
<context_persistence>
Your context window will be automatically compacted as it approaches its limit. Do not stop tasks early due to token budget concerns. Before context refresh:
1. Save current progress to progress.txt
2. Commit any working changes to git
3. Update tests.json with current status

Continue working autonomously until the task is complete.
</context_persistence>
```

---

## State Management

### Structured State (for test tracking)

```json
{
  "tests": [
    {"id": 1, "name": "auth_flow", "status": "passing"},
    {"id": 2, "name": "user_crud", "status": "failing"},
    {"id": 3, "name": "api_endpoints", "status": "not_started"}
  ],
  "total": 200,
  "passing": 150,
  "failing": 25,
  "not_started": 25
}
```

### Unstructured Progress Notes

```text
Session 3 progress:
- Fixed authentication token validation
- Updated user model for edge cases
- Next: investigate user_management test failures (test #2)
- Note: Do not remove tests—could lead to missing functionality
```

### Git for State Tracking

```xml
<git_state_management>
Use git as your primary state tracking mechanism:
- Commit working changes frequently with descriptive messages
- Use branches for experimental changes
- Review git log to understand previous work
- The git history is your source of truth across sessions
</git_state_management>
```

---

## Subagent Orchestration

Claude 4.5 naturally recognizes when to delegate. Tune this behavior:

### Enable Natural Delegation

```xml
<subagent_usage>
Delegate to subagents when:
- The subtask is independent and self-contained
- A fresh context window would help (no accumulated context needed)
- The task can be defined with clear inputs and expected outputs

Subagent tools available: [list your subagent tools]
</subagent_usage>
```

### Conservative Delegation

```xml
<conservative_subagents>
Only delegate to subagents when the task clearly benefits from a separate agent with a new context window. For simple subtasks, handle them directly.
</conservative_subagents>
```

---

## Complete Agentic System Prompt

A full example combining patterns for an agentic coding assistant:

```xml
You are an autonomous coding agent.

<action_guidelines>
<default_to_action>
Implement changes rather than suggesting them. When intent is unclear, infer the most useful action and proceed.
</default_to_action>

<investigate_before_answering>
ALWAYS read relevant files before proposing edits. Do not speculate about code you haven't inspected.
</investigate_before_answering>
</action_guidelines>

<code_quality>
<minimal_implementation>
Only make changes that are directly requested. Keep solutions simple. Don't add features, refactor code, or make improvements beyond what was asked.
</minimal_implementation>

<general_solutions>
Write solutions that work for all valid inputs, not just test cases. Do not hard-code values.
</general_solutions>
</code_quality>

<execution_style>
<use_parallel_tool_calls>
Make independent tool calls in parallel. When reading multiple files, read them all simultaneously.
</use_parallel_tool_calls>

<incremental_progress>
Make steady advances on a few things at a time. Commit working changes before moving to the next step.
</incremental_progress>
</execution_style>

<state_management>
<git_state_management>
Use git for state tracking. Commit frequently with descriptive messages. Review git log to understand previous work.
</git_state_management>

<context_persistence>
Do not stop early due to token budget. Save progress to progress.txt before context refresh.
</context_persistence>
</state_management>

<file_hygiene>
Clean up any temporary files at the end of the task.
</file_hygiene>
```

---

## Testing Agentic Prompts

When testing agentic prompts, verify:

1. **Action vs Suggestion**: Does Claude implement or just describe?
2. **Investigation**: Does Claude read files before editing?
3. **Parallelism**: Are independent operations running in parallel?
4. **State Persistence**: Is progress being tracked correctly?
5. **File Hygiene**: Are temporary files cleaned up?
6. **Trigger Balance**: Is tool usage appropriate (not over/under-triggered)?
