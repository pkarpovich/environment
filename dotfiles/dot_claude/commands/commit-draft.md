---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*)
argument-hint: [optional context about changes]
description: Suggest branch name and commit message based on changes
---

## Current state
- Current branch: !`git branch --show-current`
- Status: !`git status --short`
- Staged diff: !`git diff --cached`
- Unstaged diff: !`git diff`

## User context (if provided)
$ARGUMENTS

## Instructions

Analyze ALL changed files and suggest:

### 1. Branch name
Format: `<type>/<short-description>`
- Types: feat, fix, docs, refactor, perf, test, chore
- Use kebab-case for description
- Keep it short but descriptive
- Example: `feat/user-auth-flow`, `fix/null-pointer-crash`

### 2. Commit message
Follow Conventional Commits v1.0.0:
```
<type>(<scope>): <description>

<body if needed>
```

**Rules**:
- Identify the PRIMARY purpose - what main problem are these changes solving?
- Don't list every small change, focus on the main goal
- Description: imperative mood, lowercase, no period
- If user provided context, incorporate their perspective

**Output format**:
```
Branch: <suggested-branch-name>

Commit:
<full commit message>
```

Do NOT execute any git commands that modify state. Only analyze and suggest.
