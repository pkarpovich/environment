---
name: claude4-prompt-engineer
description: Expert prompt engineering for Claude 4.x models (Sonnet 4.5, Opus 4.5, Haiku 4.5). Use when creating system prompts, optimizing existing prompts, designing agentic workflows, or improving prompt effectiveness. Triggers on requests like "optimize this prompt", "write a system prompt", "improve these instructions", "create an agent prompt", or any task involving prompt design for Claude.
---

# Claude 4.x Prompt Engineering

## Core Principles

**1. Lead with an action verb, not a question.** The first line of a prompt carries the most weight. Start with `Write`, `Create`, `Generate`, `Analyze`, `Identify`, `Refactor`, etc. Replace "What should I eat?" with "Generate a one-day meal plan for an athlete that meets their dietary restrictions." Vague questions force the model to guess what shape of answer you want; action verbs collapse that ambiguity.

**2. Be explicit; context over commands.** Claude 4.x follows instructions literally, and it generalizes from explanations. Tell it WHY a constraint exists, not just WHAT to do. "Output is consumed by TTS, so avoid ellipses which TTS cannot pronounce" beats "Never use ellipses". A reason gives the model coverage for adjacent cases the rule did not anticipate.

**3. Two flavours of specificity: Output Guidelines + Process Steps.**
- **Output Guidelines** (always include) describe what the result should look like: length, structure, sections, fields, required attributes, tone.
- **Process Steps** (add for non-trivial tasks) describe how the model should think through the problem before answering: brainstorm options, weigh tradeoffs, consider alternatives, then decide. Use Process Steps for troubleshooting, multi-factor analysis, anything where a single-shot answer would skip important angles.

**4. Show, don't just tell.** Examples (few-shot) often beat extra paragraphs of instruction, especially for corner cases (sarcasm, ambiguous inputs), strict output formats, or specific style/tone. Wrap examples in XML (`<sample_input>` / `<ideal_output>`) and add a one-line note explaining WHY each example is good. See the few-shot pattern in `references/patterns.md`.

**5. XML structure with descriptive tag names.** When interpolating data or mixing content types (instructions + code + docs + records), wrap each section in XML. Use semantic names: `<athlete_info>`, `<sales_records>`, `<my_code>`, `<reference_docs>`. Avoid generic `<data>`, `<input>`, `<text>` because they tell the model nothing about what is inside.

**6. Positive framing.** Say what TO DO, not what NOT to do. "Write in flowing prose paragraphs" beats "Do not use bullet points". Negative instructions force the model to mentally hold the forbidden behaviour; positive ones give it a target.

**7. Match style.** Your prompt's own formatting (prose vs bullets, terse vs verbose, hedged vs decisive) influences the model's output style. Write the prompt in the register you want back.

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

### Step 3: Structure with XML (descriptive tag names)

For complex prompts, wrap sections in XML tags. Use semantic, descriptive names that tell the model what is inside the tag, not bag-of-content labels:

| Better | Worse |
|---|---|
| `<athlete_info>` | `<input>` |
| `<sales_records>` | `<data>` |
| `<my_code>` / `<reference_docs>` | both jammed together |
| `<example_review>` | `<text>` |

Common structural tags:

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

- [ ] First line is an instruction, not a question, and starts with an action verb
- [ ] No vague modifiers ("be detailed", "be concise" without specifics)
- [ ] No contradictions ("thorough but brief")
- [ ] No negative-only instructions (all "don't" have a "do instead")
- [ ] No assumed context (all needed info is provided or referenced)
- [ ] XML tags, if any, have descriptive names (not `<data>` / `<input>` / `<text>`)
- [ ] Output Guidelines are present; Process Steps are present if the task needs analysis
- [ ] At least one few-shot example if the task has corner cases or strict format
- [ ] No over-emphasis for Opus 4.5 (avoid "CRITICAL", "MUST", "ALWAYS" unless truly necessary)

### Step 6: Iterate with measurement

Do not trust gut feelings about prompt quality. The cycle is:

1. Define what "good output" means as concrete criteria.
2. Pick a handful (2-5) of representative inputs.
3. Run the current prompt against them, score outputs against the criteria (model-graded is fine; the model is harsher than humans).
4. Apply **one** engineering change at a time.
5. Re-score. Keep the change if it improved, revert if it did not.

The "one change at a time" rule is the discipline that makes the loop informative: bundle two changes together and you cannot attribute the result to either. See `references/iteration.md` for the full methodology.

Skip this loop for one-off prompts where the cost of a bad result is low. Use it for any prompt that will run repeatedly (system prompts for agents, skill descriptions, automated workflows).

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

### Few-Shot Examples (Show, Don't Just Tell)
```xml
<examples>
<example>
<sample_input>
[Concrete input that resembles what the model will see at runtime]
</sample_input>
<ideal_output>
[The response you would want for that input]
</ideal_output>
<why_this_is_good>
[One sentence explaining what makes this output correct: format, tone, judgment call, edge case it handles.]
</why_this_is_good>
</example>
<!-- repeat <example> for each corner case worth showing -->
</examples>
```

Use one-shot for a simple pattern, multi-shot to cover edge cases. Mine your highest-scoring outputs from Step 6 evaluations as ready-made examples.

## Reference Files

- **[patterns.md](references/patterns.md)** - Complete XML patterns library with copy-paste templates, plus Specificity and Few-Shot Examples sections
- **[examples.md](references/examples.md)** - Before/after transformations and full system prompt examples
- **[agentic.md](references/agentic.md)** - Multi-context window tasks, state management, subagent orchestration
- **[iteration.md](references/iteration.md)** - Eval-driven loop for measuring whether prompt changes actually help

## Model-Specific Notes

### Opus 4.5
- Very responsive to system prompts - dial back aggressive language
- Replace "CRITICAL: You MUST..." with "Use X when..."
- Excellent at parallel tool calls
- May over-engineer - use `<minimal_implementation>`

### Sonnet 4.5
- Aggressive parallelism - may need `<sequential_execution>` for stability
- Good balance of capability and efficiency
- Strong at following structured XML prompts

### Haiku 4.5
- Keep prompts concise - smaller context window
- Prioritize essential instructions
- Good for simple, well-defined tasks
