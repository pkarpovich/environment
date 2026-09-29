---
name: claudemd-audit
description: >
  Audit CLAUDE.md files against best practices.
  Analyzes length, structure, anti-patterns, and generates
  improvement recommendations with concrete suggestions.
  Invoke when user says "audit claude.md", "check claude.md",
  "review claude.md", "improve claude.md".
argument-hint: "[path/to/CLAUDE.md]"
metadata:
  version: "0.0.1"
---

# CLAUDE.md Audit Skill

Analyze a CLAUDE.md file against best practices and generate actionable improvement recommendations.

## Input

User provides a path to the CLAUDE.md file. If not provided, check `./CLAUDE.md` first, then `./.claude/CLAUDE.md`.

Read the target file using the Read tool before starting analysis.

## File Type Detection

Before running checks, determine the file type from its path:

- **Project root**: `./CLAUDE.md` or `./.claude/CLAUDE.md` at repository root
- **Subdirectory**: CLAUDE.md inside a service/package directory (e.g., `monolith/CLAUDE.md`)
- **User global**: `~/.claude/CLAUDE.md` -- personal preferences across all projects

This affects how certain dimensions are evaluated (noted in each dimension below).

## Analysis Dimensions

Run ALL checks below against the file content. For each dimension, record: status (pass/warn/fail), details, and recommendation if applicable.

### 1. Length and Size

- Determine exact line count from the Read tool output (last line number = total lines)
- Count instructions using these rules:
  - Each bullet or numbered item = 1 instruction
  - If a bullet contains conjunctions (and/or) joining distinct actions, count each action separately
  - Informational items (descriptions, URLs, tech stack listings) are not instructions -- only count imperatives and constraints
- Line thresholds (official Anthropic recommendation: "target under 200 lines"):
  - **Pass**: under 200 lines
  - **Warn**: 200-300 lines
  - **Fail**: over 300 lines
- Instruction count thresholds (heuristic, inspired by IFScale study on instruction-following degradation):
  - **Pass**: under 80 instructions
  - **Warn**: 80-150 instructions
  - **Fail**: over 150 instructions (LLM adherence degrades with instruction density -- exact thresholds are model-dependent)
- If over 200 lines, MUST recommend progressive disclosure with a concrete split proposal

### 2. WHAT-WHY-HOW Coverage

Check if the file covers all three dimensions:

- **WHAT**: tech stack, project structure, codebase map, service names
- **WHY**: project purpose, component goals, architectural reasoning
- **HOW**: build commands, test commands, verification steps, package manager, workflow

File type adjustments:
- **Subdirectory**: HOW may be partially delegated to root file. Check for build/test commands locally -- these should be present even in subdirectory files.
- **User global**: WHAT and WHY are not expected. Only check for HOW-relevant behavioral preferences.
- **Monorepo root**: HOW is typically delegated to subdirectory files via "See: service/CLAUDE.md" pointers. Check that delegation pointers exist rather than requiring inline commands.

Mark each as present/partial/missing/not-applicable. Quote the relevant sections found.

### 3. Instruction Specificity

Scan for vague instructions vs concrete ones:

- **Vague** (bad): "format code properly", "test your changes", "follow best practices", "write clean code", "handle errors appropriately"
- **Concrete** (good): "use 2-space indentation", "run `npm test` before committing", "use snake_case for database columns"

List all vague instructions found and suggest concrete replacements.

### 4. Emphasis Marker Inflation

Count instructions with emphasis markers: "IMPORTANT", "CRITICAL", "MUST", "NEVER", "ALWAYS" (case-insensitive).

- **Pass**: 0-3 emphasis markers
- **Warn**: 4-6 emphasis markers
- **Fail**: over 6 emphasis markers
- When over 3: recommend which ones to keep (most critical) and which to demote

### 5. Anti-Pattern Detection

Check for each of the 7 anti-patterns:

#### 5a. Linter Instructions
Instructions about code style that a linter/formatter should handle: indentation, trailing whitespace, semicolons, bracket style, import ordering. Recommend setting up a Claude Code `PostToolUse` hook with matcher `Edit|Write` that runs formatter/linter automatically after each file edit, presenting errors for Claude to fix rather than asking Claude to enforce style rules. LLMs are in-context learners -- if the codebase follows consistent patterns, Claude picks them up without being told.

#### 5b. Hotfix Accumulation
Narrow, task-specific instructions that only apply to rare scenarios. Signs: very specific file names in constraints, edge-case workarounds, one-off behavior corrections. Recommend moving to rules/ with path scoping or removing.

#### 5c. Auto-Generated Without Curation
Signs: generic/boilerplate content, obvious framework knowledge restated, content that looks machine-generated. Flag if detected.

#### 5d. Negative-Only Constraints
Instructions that say "don't do X" without providing an alternative. List each one and suggest adding alternatives.

#### 5e. Embedded File Content
Large code blocks, inline schemas, full configuration examples. If over 10 lines of embedded code/content, recommend extracting to a separate file with a path reference. Exception: directory tree blocks (showing project structure) up to 30 lines are acceptable and useful for code orientation -- do not flag these. Prefer pointers to copies -- use `path/to/file.ts:120-180` references to canonical sources instead of copied snippets that go stale.

#### 5f. Obvious Framework Knowledge
Instructions that restate what Claude already knows from training: how React hooks work, Express middleware patterns, standard Git workflow, common TypeScript features. Recommend removing.

#### 5g. Secrets and Credentials
Any API keys, connection strings, passwords, tokens in the file. Flag as CRITICAL security issue.

### 6. Universality and Relevance Risk

Claude Code wraps CLAUDE.md with a hidden system reminder: "this context may or may not be relevant to your tasks." When CLAUDE.md contains too many non-universal instructions, Claude may discount the entire file -- not just deprioritize, but outright ignore instructions it deems irrelevant.

File type adjustments:
- **Subdirectory/User global**: skip this check -- these files are scoped by definition. Mark as N/A.
- **Project root / Monorepo root**: run full check below. Note: service listings and reference information in a monorepo root ARE universal (every developer needs to know what services exist) -- do not flag them as domain-specific.

For root files:
- Identify instructions that apply only to specific domains (e.g., DB-only, frontend-only, release-only, specific-service-only)
- Check if the file contains step-by-step procedures (release workflows, migration steps, deployment guides). These belong in custom skills (`.claude/skills/`) or separate docs, not in CLAUDE.md. CLAUDE.md is for persistent universal guidelines.
- Estimate what percentage of instructions are universal across typical tasks in the project
- **Pass**: >80% of instructions are universal
- **Warn**: noticeable domain-specific clusters in root file
- **Fail**: root file dominated by specialized guidance or procedural content
- When domain-specific content found: recommend relocating to `.claude/rules/*.md` with `paths:` frontmatter or to `docs/` for lazy loading

### 7. Progressive Disclosure Opportunities

If file is over 100 lines or fails the universality check, analyze content clusters and propose a split:

- Identify logical groups of instructions (by topic/domain)
- Propose a directory structure for satellite files
- Specify what stays in root CLAUDE.md (universal, cross-cutting concerns)
- Specify what moves to `.claude/rules/*.md` (path-scoped rules)
- Specify what moves to `docs/` or similar (reference material)
- Show which rules can use path-scoped frontmatter

Example output format:
```
Proposed structure:
  CLAUDE.md (keep ~60 lines)
    - project overview (WHAT/WHY)
    - build/test commands (HOW)
    - universal conventions

  .claude/rules/api.md (paths: src/api/**)
    - API-specific conventions
    - endpoint patterns

  .claude/rules/frontend.md (paths: src/components/**)
    - component conventions
    - styling rules

  docs/architecture.md (reference, lazy-load)
    - detailed service descriptions
    - data flow diagrams
```

### 8. @-Import Analysis

If file uses `@path` imports:

- List all @-imported files
- Read each imported file to determine its actual size (lines/tokens)
- Check for nested @-imports in imported files (Claude Code resolves recursively up to 5 levels deep). Warn if nesting approaches the limit or if cycles exist.
- Warn about eager loading token cost -- all @-imported content loads at startup, consuming tokens on every session
- For imports over 50 lines, recommend switching to plain path references for lazy loading ("See `docs/guide.md`" without @ prefix -- Claude reads on demand)
- Report total eager token cost of all imports combined

### 9. Monorepo Structure Check

If the project appears to be a monorepo (multiple services/packages):

- Check if there are subdirectory CLAUDE.md files
- Check if root file is lightweight enough (under 200 lines per official Anthropic guidance)
- Recommend hierarchical organization if not present
- Check that root file contains only universally applicable content (service listings and reference info count as universal)
- Check if `CLAUDE.local.md` is used for personal project-specific overrides (should be gitignored)
- For large monorepos with many ancestor CLAUDE.md files: recommend `claudeMdExcludes` setting in `.claude/settings.json` to skip irrelevant ancestor files

### 10. Content Freshness Indicators

Look for signs of stale content:

- References to deprecated tools/versions
- TODO/FIXME comments
- Commented-out instructions
- Contradictory instructions (two rules that conflict)

### 11. Peripheral Placement Check

Critical instructions should be at the beginning or end of the file (primacy/recency bias). Check if the most important instructions (build commands, critical constraints) are buried in the middle.

## Output Format

Present results as a structured markdown report:

```markdown
# CLAUDE.md Audit Report

**File**: <path>
**Lines**: N | **Est. instructions**: N

## Summary

<2-3 sentence overall assessment>

**Audit metrics**: [PASS] N | [WARN] N | [FAIL] N
**Adherence risk**: Low / Medium / High

Adherence risk rules:
- **High**: Length or instruction count FAIL, OR secrets detected, OR universality FAIL, OR 3+ dimensions at FAIL level. Warn: "Claude Code wraps CLAUDE.md with a relevance filter -- at this size/density, Claude may ignore instructions entirely."
- **Medium**: any FAIL in non-critical dimensions, OR 2+ dimensions at WARN level
- **Low**: no FAIL, at most 1 WARN

## Findings Overview

| # | Dimension | Status | Key Issue |
|---|-----------|--------|-----------|
| 1 | Length and Size | [PASS/WARN/FAIL] | <brief> |
| 2 | WHAT-WHY-HOW | [PASS/WARN/FAIL] | <brief> |
| ... | ... | ... | ... |

## Detailed Findings

### [PASS/WARN/FAIL] 1. Length and Size
<findings -- keep PASS sections to 1-2 lines, expand WARN/FAIL with evidence and recommendations>

### [PASS/WARN/FAIL] 2. WHAT-WHY-HOW Coverage
<findings>

... (all 11 dimensions)

## Recommendations (Priority Order)

### Critical (fix now)
1. <recommendation with concrete action>

### Important (fix soon)
1. <recommendation with concrete action>

### Nice to Have
1. <recommendation with concrete action>

## Proposed Improvements

<If progressive disclosure is recommended, show the full proposed structure>

<If specific rewrites are suggested, show before/after examples>
```

Use these status icons (text only, no emoji):
- **[PASS]** - meets best practices
- **[WARN]** - room for improvement
- **[FAIL]** - needs attention

## Key Principles

- Be specific: every recommendation must include a concrete action
- Be constructive: don't just criticize, show how to improve
- Prioritize: order recommendations by impact
- Show examples: include before/after for suggested rewrites
- Respect existing structure: build on what's already good
- Consider the project context: monorepo vs single app matters
