---
name: claude4-prompt-engineer
description: Expert prompt engineering for Claude 4.x models (Sonnet 4.5, Opus 4.5, Haiku 4.5). Use when creating system prompts, optimizing existing prompts, designing agentic workflows, or improving prompt effectiveness. Triggers on requests like "optimize this prompt", "write a system prompt", "improve these instructions", "create an agent prompt", or any task involving prompt design for Claude.
---

# Claude 4.x Prompt Engineering

## Core Principles

**1. Be Explicit** — Claude 4.x follows instructions literally. Request "above and beyond" behavior explicitly.

**2. Context Over Commands** — Explain WHY, not just WHAT. Claude generalizes from explanations.

**3. Positive Framing** — Say what TO DO, not what NOT to do.

**4. XML Structure** — Use XML tags for complex instructions. Claude responds well to structured prompts.

**5. Match Style** — Your prompt's formatting influences Claude's output formatting.

## Workflow

### Step 1: Identify Prompt Type

| Type | Characteristics | Reference |
|------|-----------------|-----------|
| **System Prompt** | Sets assistant personality, constraints, capabilities | [examples.md](references/examples.md) |
| **Agentic Prompt** | Tool use, multi-step tasks, autonomous work | [agentic.md](references/agentic.md) |
| **Optimization** | Improving existing prompt that underperforms | [examples.md](references/examples.md) |

### Step 2: Apply Core Transformations

**Transform vague → explicit:**
```
Before: "Create a dashboard"
After:  "Create a dashboard with filtering, sorting, and export. Include interactive charts and responsive design."
```

**Transform commands → context:**
```
Before: "NEVER use ellipses"
After:  "Output will be read by TTS, so avoid ellipses which TTS cannot pronounce."
```

**Transform negative → positive:**
```
Before: "Don't use bullet points"
After:  "Write in flowing prose paragraphs"
```

### Step 3: Structure with XML

For complex prompts, wrap sections in XML tags:

```xml
<role>
Define who Claude is and their expertise
</role>

<guidelines>
Behavioral guidelines and approach
</guidelines>

<constraints>
Hard limits and requirements
</constraints>

<output_format>
Expected structure of responses
</output_format>
```

### Step 4: Add Relevant Patterns

Select patterns from [patterns.md](references/patterns.md) based on needs:

- **Action control**: `<default_to_action>` or `<do_not_act_before_instructions>`
- **Tool usage**: `<use_parallel_tool_calls>` or `<sequential_execution>`
- **Code quality**: `<minimal_implementation>`, `<investigate_before_answering>`
- **Output**: `<avoid_excessive_markdown_and_bullet_points>`

### Step 5: Validate

Check the prompt against:

- [ ] No vague modifiers ("be detailed", "be concise" without specifics)
- [ ] No contradictions ("thorough but brief")
- [ ] No negative-only instructions (all "don't" have a "do instead")
- [ ] No assumed context (all needed info is provided or referenced)
- [ ] No over-emphasis for Opus 4.5 (avoid "CRITICAL", "MUST", "ALWAYS" unless truly necessary)

## Quick Patterns

### Make Claude Act (Not Just Suggest)
```xml
<default_to_action>
Implement changes rather than suggesting them. If intent is unclear, infer the most useful action and proceed.
</default_to_action>
```

### Prevent Over-Engineering
```xml
<minimal_implementation>
Only make changes directly requested. Keep solutions simple. Don't add features or refactor beyond the ask.
</minimal_implementation>
```

### Force Investigation First
```xml
<investigate_before_answering>
ALWAYS read relevant files before proposing edits. Do not speculate about code you haven't inspected.
</investigate_before_answering>
```

### Control Output Format
```xml
<output_style>
Write in flowing prose paragraphs. Reserve markdown for code blocks and simple headings only.
</output_style>
```

## Reference Files

- **[patterns.md](references/patterns.md)** — Complete XML patterns library with copy-paste templates
- **[examples.md](references/examples.md)** — Before/after transformations and full system prompt examples
- **[agentic.md](references/agentic.md)** — Multi-context window tasks, state management, subagent orchestration

## Model-Specific Notes

### Opus 4.5
- Very responsive to system prompts — dial back aggressive language
- Replace "CRITICAL: You MUST..." with "Use X when..."
- Excellent at parallel tool calls
- May over-engineer — use `<minimal_implementation>`

### Sonnet 4.5
- Aggressive parallelism — may need `<sequential_execution>` for stability
- Good balance of capability and efficiency
- Strong at following structured XML prompts

### Haiku 4.5
- Keep prompts concise — smaller context window
- Prioritize essential instructions
- Good for simple, well-defined tasks
