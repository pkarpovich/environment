# Prompt Patterns for Claude 4.x

Ready-to-use XML patterns extracted from official Claude 4.x best practices.

## Table of Contents

1. [Specificity](#specificity)
2. [Few-Shot Examples](#few-shot-examples)
3. [Action Control](#action-control)
4. [Tool Usage](#tool-usage)
5. [Output Formatting](#output-formatting)
6. [Code Quality](#code-quality)
7. [Research & Exploration](#research--exploration)
8. [Context Management](#context-management)

---

## Specificity

Specificity comes in two flavours. Output Guidelines describe what the result should look like; Process Steps describe how the model should think through the problem before answering. Always include Output Guidelines. Add Process Steps for tasks that benefit from multi-angle analysis (troubleshooting, decisions, anything where a single-shot answer skips important factors).

### Output Guidelines

```xml
<output_requirements>
The output must include:
- [Element 1, with specific constraint: format, count, units]
- [Element 2]
- [Element 3]
Length: [bound, e.g. "under 1000 words" or "three paragraphs"]
Tone: [e.g. "professional but informal"]
Format: [e.g. "markdown with H2 section headers"]
</output_requirements>
```

### Process Steps

```xml
<process>
Work through the problem in this order before giving the final answer:
1. [First diagnostic step, e.g. "list all candidate causes"]
2. [Second step, e.g. "rank them by likelihood given the evidence"]
3. [Third step, e.g. "for the top candidate, propose a verification test"]
4. [Final synthesis, e.g. "recommend the next concrete action"]
</process>
```

---

## Few-Shot Examples

Few-shot examples often outperform extra paragraphs of instruction for: corner cases (sarcasm, ambiguity), strict output formats (JSON shapes, fixed templates), specific style/tone, and judgment-call situations. Wrap each example in nested XML and add a one-line note explaining why the output is good.

### Single example (one-shot)

```xml
<examples>
<example>
<sample_input>
[Concrete input resembling runtime data]
</sample_input>
<ideal_output>
[The response you want for that input]
</ideal_output>
<why_this_is_good>
[One sentence: what makes this output correct, what edge case it covers.]
</why_this_is_good>
</example>
</examples>
```

### Multiple examples (multi-shot, edge cases)

```xml
<examples>
<example>
<sample_input>Great game tonight!</sample_input>
<ideal_output>Positive</ideal_output>
<why_this_is_good>Straightforward positive sentiment, no ambiguity.</why_this_is_good>
</example>

<example>
<sample_input>Oh yeah, I really needed a flight delay tonight! Excellent!</sample_input>
<ideal_output>Negative</ideal_output>
<why_this_is_good>Surface words look positive but tone is sarcastic; treat sarcastic praise as negative.</why_this_is_good>
</example>
</examples>
```

### Mining examples from evaluations

When iterating with measurement (see `iteration.md`), take your highest-scoring outputs and lift them into the prompt as few-shot examples. This makes the prompt self-reinforcing: the model sees concrete proof of what "great" looks like for the specific task.

---

## Action Control

### Proactive Action (Default to Implementation)

Use when Claude should implement changes rather than just suggest them.

```xml
<default_to_action>
By default, implement changes rather than only suggesting them. If the user's intent is unclear, infer the most useful likely action and proceed, using tools to discover any missing details instead of guessing. Try to infer the user's intent about whether a tool call (e.g., file edit or read) is intended or not, and act accordingly.
</default_to_action>
```

### Conservative Action (Research First)

Use when Claude should analyze before acting.

```xml
<do_not_act_before_instructions>
Do not jump into implementation or change files unless clearly instructed to make changes. When the user's intent is ambiguous, default to providing information, doing research, and providing recommendations rather than taking action. Only proceed with edits, modifications, or implementations when the user explicitly requests them.
</do_not_act_before_instructions>
```

---

## Tool Usage

### Parallel Tool Calls

Use to maximize efficiency with independent operations.

```xml
<use_parallel_tool_calls>
If you intend to call multiple tools and there are no dependencies between the tool calls, make all of the independent tool calls in parallel. Prioritize calling tools simultaneously whenever the actions can be done in parallel rather than sequentially. For example, when reading 3 files, run 3 tool calls in parallel to read all 3 files into context at the same time. Maximize use of parallel tool calls where possible to increase speed and efficiency. However, if some tool calls depend on previous calls to inform dependent values like the parameters, do NOT call these tools in parallel and instead call them sequentially. Never use placeholders or guess missing parameters in tool calls.
</use_parallel_tool_calls>
```

### Sequential Execution

Use when stability is critical or operations have side effects.

```xml
<sequential_execution>
Execute operations sequentially with brief pauses between each step to ensure stability.
</sequential_execution>
```

### Subagent Conservation

Use to prevent over-delegation to subagents.

```xml
<conservative_subagents>
Only delegate to subagents when the task clearly benefits from a separate agent with a new context window.
</conservative_subagents>
```

---

## Output Formatting

### Minimize Markdown

Use when output will be read as plain text or by TTS.

```xml
<avoid_excessive_markdown_and_bullet_points>
When writing reports, documents, technical explanations, analyses, or any long-form content, write in clear, flowing prose using complete paragraphs and sentences. Use standard paragraph breaks for organization and reserve markdown primarily for `inline code`, code blocks, and simple headings.

DO NOT use ordered lists (1. ...) or unordered lists (*) unless: a) you're presenting truly discrete items where a list format is the best option, or b) the user explicitly requests a list or ranking.

Instead of listing items with bullets or numbers, incorporate them naturally into sentences. Your goal is readable, flowing text that guides the reader naturally through ideas rather than fragmenting information into isolated points.
</avoid_excessive_markdown_and_bullet_points>
```

### Progress Reporting

Use when visibility into Claude's work process is needed.

```xml
<progress_updates>
After completing a task that involves tool use, provide a quick summary of the work you've done.
</progress_updates>
```

---

## Code Quality

### Prevent Over-Engineering

Use when Claude tends to add unnecessary complexity.

```xml
<minimal_implementation>
Avoid over-engineering. Only make changes that are directly requested or clearly necessary. Keep solutions simple and focused.

Don't add features, refactor code, or make "improvements" beyond what was asked. A bug fix doesn't need surrounding code cleaned up. A simple feature doesn't need extra configurability.

Don't add error handling, fallbacks, or validation for scenarios that can't happen. Trust internal code and framework guarantees. Only validate at system boundaries (user input, external APIs). Don't use backwards-compatibility shims when you can just change the code.

Don't create helpers, utilities, or abstractions for one-time operations. Don't design for hypothetical future requirements. The right amount of complexity is the minimum needed for the current task. Reuse existing abstractions where possible and follow the DRY principle.
</minimal_implementation>
```

### General Solutions (Prevent Hardcoding)

Use when Claude focuses too much on passing tests.

```xml
<general_solutions>
Write a high-quality, general-purpose solution using standard tools available. Do not create helper scripts or workarounds. Implement a solution that works correctly for all valid inputs, not just test cases. Do not hard-code values or create solutions that only work for specific test inputs.

Focus on understanding the problem requirements and implementing the correct algorithm. Tests are there to verify correctness, not to define the solution. If the task is unreasonable or tests are incorrect, inform me rather than working around them.
</general_solutions>
```

### Code Exploration First

Use when Claude makes assumptions without reading code.

```xml
<investigate_before_answering>
ALWAYS read and understand relevant files before proposing code edits. Do not speculate about code you have not inspected. If the user references a specific file/path, you MUST open and inspect it before explaining or proposing fixes. Be rigorous and persistent in searching code for key facts. Thoroughly review the style, conventions, and abstractions of the codebase before implementing new features.
</investigate_before_answering>
```

### Prevent Hallucinations

Use for grounded, accurate responses about code.

```xml
<no_hallucinations>
Never speculate about code you have not opened. If the user references a specific file, you MUST read the file before answering. Make sure to investigate and read relevant files BEFORE answering questions about the codebase. Never make any claims about code before investigating unless you are certain of the correct answer.
</no_hallucinations>
```

---

## Research & Exploration

### Structured Research

Use for complex information gathering tasks.

```xml
<structured_research>
Search for this information in a structured way. As you gather data, develop several competing hypotheses. Track your confidence levels in your progress notes to improve calibration. Regularly self-critique your approach and plan. Update a hypothesis tree or research notes file to persist information and provide transparency. Break down this complex research task systematically.
</structured_research>
```

---

## Context Management

### Long-Running Tasks

Use for tasks that may span multiple context windows.

```xml
<context_persistence>
Your context window will be automatically compacted as it approaches its limit, allowing you to continue working indefinitely from where you left off. Therefore, do not stop tasks early due to token budget concerns. As you approach your token budget limit, save your current progress and state to memory before the context window refreshes. Always be as persistent and autonomous as possible and complete tasks fully, even if the end of your budget is approaching. Never artificially stop any task early regardless of the context remaining.
</context_persistence>
```

### Efficient Context Usage

Use to encourage complete work before moving on.

```xml
<use_full_context>
This is a very long task, so it may be beneficial to plan out your work clearly. It's encouraged to spend your entire output context working on the task - just make sure you don't run out of context with significant uncommitted work. Continue working systematically until you have completed this task.
</use_full_context>
```

---

## Combining Patterns

Patterns can be combined. Example for agentic coding:

```xml
<agentic_coding_guidelines>
<investigate_before_answering>
ALWAYS read relevant files before proposing edits. Do not speculate about code you haven't inspected.
</investigate_before_answering>

<minimal_implementation>
Only make changes that are directly requested. Keep solutions simple and focused.
</minimal_implementation>

<use_parallel_tool_calls>
Make independent tool calls in parallel to maximize efficiency.
</use_parallel_tool_calls>
</agentic_coding_guidelines>
```
