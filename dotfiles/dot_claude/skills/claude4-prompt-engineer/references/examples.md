# Before/After Prompt Transformations

Concrete examples of improving prompts for Claude 4.x models.

## Table of Contents

1. [Explicit Instructions](#explicit-instructions)
2. [Context Over Commands](#context-over-commands)
3. [Action vs Suggestion](#action-vs-suggestion)
4. [Format Control](#format-control)
5. [System Prompt Transformations](#system-prompt-transformations)

---

## Explicit Instructions

Claude 4.x follows instructions literally. Request "above and beyond" behavior explicitly.

### Dashboard Creation

**Before (vague):**
```
Create an analytics dashboard
```

**After (explicit):**
```
Create an analytics dashboard. Include as many relevant features and interactions as possible. Go beyond the basics to create a fully-featured implementation.
```

### Feature Implementation

**Before:**
```
Add a login form
```

**After:**
```
Add a login form with email/password fields, validation, error states, loading indicator, and "forgot password" link. Make it visually polished with smooth transitions.
```

### Code Review

**Before:**
```
Review this code
```

**After:**
```
Review this code for: security vulnerabilities, performance issues, edge cases, code style consistency. Provide specific line references and suggested fixes.
```

---

## Context Over Commands

Explain WHY, not just WHAT. Claude generalizes from explanations.

### Formatting Constraints

**Before (command):**
```
NEVER use ellipses
```

**After (context):**
```
Your response will be read aloud by a text-to-speech engine, so never use ellipses since the TTS engine will not know how to pronounce them.
```

### Length Constraints

**Before:**
```
Keep responses under 100 words
```

**After:**
```
This will be displayed on a mobile notification where space is limited. Keep responses under 100 words so users can read the full message without scrolling.
```

### Tone Constraints

**Before:**
```
Be formal
```

**After:**
```
This response will be sent as an official company communication to enterprise clients. Use formal business language appropriate for C-level executives.
```

---

## Action vs Suggestion

Claude 4.x interprets "can you suggest" literally. Be direct when you want action.

### Code Changes

**Before (Claude will only suggest):**
```
Can you suggest some changes to improve this function?
```

**After (Claude will implement):**
```
Change this function to improve its performance.
```

Or with specifics:
```
Refactor this function to use early returns and reduce nesting. Implement the changes.
```

### File Edits

**Before:**
```
What would you recommend changing in this config?
```

**After:**
```
Edit this config to fix the issues. Make the changes directly.
```

### Bug Fixes

**Before:**
```
Can you help me understand what's wrong with this code?
```

**After:**
```
Fix the bug in this code. Identify the issue and implement the solution.
```

---

## Format Control

Tell Claude what TO DO, not what NOT to do. Use XML tags for structure.

### Prose Output

**Before (negative instruction):**
```
Do not use markdown in your response
```

**After (positive instruction):**
```
Your response should be composed of smoothly flowing prose paragraphs.
```

Or with XML guidance:
```
Write your response in <prose> tags using flowing paragraphs without markdown formatting.
```

### Structured Output

**Before:**
```
Give me the analysis in a nice format
```

**After:**
```
Structure your analysis as:
<findings>
Main observations in prose paragraphs
</findings>
<recommendations>
Actionable next steps
</recommendations>
```

### JSON Output

**Before:**
```
Return JSON
```

**After:**
```
Return your response as valid JSON matching this schema:
{
  "status": "success" | "error",
  "data": { ... },
  "metadata": { "timestamp": "ISO8601" }
}
```

---

## System Prompt Transformations

Complete before/after examples of system prompt optimization.

### Customer Support Bot

**Before:**
```
You are a helpful customer support assistant. Be nice to customers and help them with their problems. Don't be rude.
```

**After:**
```
You are a customer support agent for Acme Corp.

<response_guidelines>
Acknowledge the customer's issue in your first sentence. Provide solutions in order of likelihood to resolve the issue. If you cannot resolve the issue, explain what information you need or offer to escalate.
</response_guidelines>

<tone>
Professional but warm. Use the customer's name when provided. Express empathy for frustration without being overly apologetic.
</tone>

<constraints>
Never share internal system details, pricing negotiations, or competitor comparisons. For billing disputes over $100, always offer to connect with a supervisor.
</constraints>
```

### Code Assistant

**Before:**
```
You are a coding assistant. Help users write good code. Follow best practices. Don't write buggy code.
```

**After:**
```
You are a senior software engineer assisting with code.

<default_to_action>
Implement changes rather than only suggesting them. When the user shares code with a problem, fix it directly.
</default_to_action>

<investigate_before_answering>
Always read relevant files before proposing edits. Do not speculate about code you haven't seen.
</investigate_before_answering>

<minimal_implementation>
Only make changes that are directly requested. A bug fix doesn't need surrounding code cleaned up. Keep solutions simple.
</minimal_implementation>

<code_style>
Match the existing codebase style. Use early returns. Prefer explicit over clever.
</code_style>
```

### Research Assistant

**Before:**
```
You are a research assistant. Find information and summarize it. Be accurate. Don't make things up.
```

**After:**
```
You are a research analyst with expertise in synthesizing information from multiple sources.

<structured_research>
When researching, develop competing hypotheses. Track confidence levels. Self-critique your approach. Update findings as new information emerges.
</structured_research>

<source_handling>
Verify claims across multiple sources. Note when sources conflict. Distinguish between facts, expert opinions, and speculation.
</source_handling>

<output_format>
Present findings in prose with inline citations. Conclude with confidence level (high/medium/low) and key uncertainties.
</output_format>

<no_hallucinations>
Never claim information without source verification. If uncertain, say "I found limited information on..." rather than speculating.
</no_hallucinations>
```

---

## Anti-Patterns to Avoid

### Vague Modifiers

**Bad:** "Be more detailed" / "Be less verbose"
**Good:** Specify exactly what details you want or word count range

### Negative Phrasing

**Bad:** "Don't use bullet points, don't be verbose, don't be generic"
**Good:** "Write in flowing prose paragraphs of 2-3 sentences each"

### Contradictory Instructions

**Bad:** "Be thorough but concise and comprehensive but brief"
**Good:** Pick one priority and specify it clearly

### Assuming Claude Knows Context

**Bad:** "Use our standard format"
**Good:** Include the format or reference where Claude can find it

### Over-emphasis

**Bad:** "CRITICAL: You MUST ALWAYS do X"
**Good:** "Do X when..." (Claude 4.x follows instructions without shouting)
