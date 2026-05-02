---
name: deep-review
description: Multi-pass code review of branch changes against the default branch. Broad parallel sweep across quality, implementation, tests, simplification, and docs, with optional external (codex) second-opinion consultation. Reports findings only — does not modify code. Use when user asks for "deep review", "thorough review", "multi-pass review", "review my branch".
allowed-tools: Bash, Read, Grep, Glob, Task, AskUserQuestion, Skill
---

# Deep Review

Multi-pass code review of the current branch against the default branch. Runs a broad parallel sweep across distinct lenses, optionally consults an external reviewer for a second opinion, and returns a consolidated severity-grouped list of findings.

**This skill reports findings only. It does NOT modify code** — fixing is the user's call after the review.

## Workflow

```
0. Setup    → script returns default branch, baseline HEAD, diff stats
1. Sweep    → 5 parallel agents (quality / impl / tests / simpl / docs)
2. Present  → severity-grouped findings, ask whether to consult codex
3. Codex    → (optional) external second opinion, merged into findings
4. Report   → final consolidated list, hand off to user
```

## Phase 0: Setup

Run the scope-detection script:

```bash
~/.claude/skills/deep-review/scripts/detect-scope.sh
```

Output is `key=value` lines: `default_branch`, `baseline`, `files`, `additions`, `deletions`, `empty`, `huge`, `dirty`.

Pre-checks based on output:
- `empty=true` → tell user "no changes vs ${default_branch}", exit
- `dirty=true` → AskUserQuestion: review including uncommitted / stash first / cancel
- `huge=true` → AskUserQuestion: narrow scope / proceed anyway / cancel. Multi-pass on huge diffs blows the context budget and yields shallow findings

Print scope summary so user sees what's being reviewed: `+${additions}/-${deletions} across ${files} files vs ${default_branch}`.

## Phase 1: Broad Parallel Sweep

**Single Task tool call with 5 subagents in parallel.** Do NOT dispatch sequentially — parallelism is the point.

Each agent is `general-purpose` with the same diff context (`${default_branch}...HEAD`) but a distinct lens. Each is told to:
1. Read the diff and full files (not just the diff hunks) for context
2. Return findings in this format:
   ```
   [SEVERITY] file:line — finding
   ```
   where SEVERITY ∈ {critical, major, minor, suggestion}
3. Return literal `NO_FINDINGS` if nothing in their lens

### Agents

**Quality** — naming, idioms, style consistency with rest of codebase, dead code, comment quality, magic numbers.

**Implementation** — bugs, missing error handling, edge cases, race conditions, unsafe concurrency, security issues (SQL injection, XSS, command injection, secret leaks), incorrect API usage.

**Tests** — missing coverage on new code, assertions that always pass, tests that don't exercise the claimed behavior, integration vs unit balance, brittleness.

**Simplification** — over-engineering, premature abstraction (factories/registries with one impl), unnecessary indirection, code that could be inlined, parallel arrays that should be a struct.

**Docs** — missing godoc/docstrings on exported APIs, stale comments contradicting code, README/CHANGELOG updates needed for user-visible changes.

After all five return:
- Deduplicate findings (same `file:line` + similar message)
- Group by severity

## Phase 2: Present Findings, Ask About Codex

Show:
```
Phase 1 sweep complete:
  critical:   N
  major:      M
  minor:      P
  suggestion: Q

[critical/major listed in full]
[minor/suggestion: collapsed summary unless user expands]
```

AskUserQuestion:
```
question: "Also consult codex for a second opinion?"
header: "Codex"
options:
  - Yes (slow, 2-5 min — useful for catching what Claude missed)
  - No (skip, finalize report)
  - Show all findings first (expand minor/suggestion before deciding)
```

## Phase 3 (Optional): External Consultation

If user said yes, invoke `Skill(thinking-tools:ask-codex)` with prompt that includes:
- Current diff: `git diff ${default_branch}...HEAD`
- Brief context on what was reviewed in Phase 1
- Explicit ask: "Review for issues a Claude-based review might have missed: subtle bugs, security, performance, missed edge cases"

Merge codex findings into the existing list (deduplicate against Phase 1 results, mark codex-only findings with `[codex]` prefix so the source is clear).

## Phase 4: Report

Final consolidated output:

```
Deep Review Report
------------------
Scope:    +${additions}/-${deletions} across ${files} files vs ${default_branch}
Baseline: ${baseline}

Findings by severity:
  critical:   A   [list]
  major:      B   [list]
  minor:      C   [collapsed unless expanded]
  suggestion: D   [collapsed unless expanded]

Codex: invoked | skipped
```

Hand off to user. Suggest next-step skills if relevant (e.g., `/commit-draft` after they address findings), but do not act.

## Severity Definitions

| Severity | Definition |
|----------|-----------|
| `critical` | Security, data loss, broken core flow, failing tests, broken build |
| `major` | Bugs, missing error handling, race conditions, broken edge cases |
| `minor` | Style, naming, small simplifications |
| `suggestion` | Optional improvements, alternative approaches |

## Implementation Notes

**Parallel agents in one Task call** — Claude Code's Task tool runs subagents concurrently when invoked in a single message with multiple Task calls. Do not dispatch sequentially or you lose 5× wall time.

**No fixing** — this skill is intentionally read-only. If the user wants fixes, they review the report and ask for changes themselves (or invoke a fix-oriented skill). Mixing detection with auto-fixing complicates iteration semantics and surprises the user.

**Don't run on huge diffs** — multi-pass review on a 5000-line diff blows the context budget and produces shallow findings. The setup script flags `huge=true`; honor it.

**Codex is opt-in, not default** — it's slow (2-5 min) and not always needed. The user picks per-session.
