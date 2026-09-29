---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git push:*), Bash(git log:*)
argument-hint: [optional context about changes]
description: Commit all changes with conventional commit message and push
---

## Current state
- Status: !`git status --short`
- Staged diff: !`git diff --cached`
- Unstaged diff: !`git diff`
- Recent commits for style reference: !`git log --oneline -5`

## User context (if provided)
$ARGUMENTS

## Instructions

Analyze ALL changed files (staged and unstaged) and create a single, focused commit following Conventional Commits v1.0.0:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Types**: feat, fix, docs, style, refactor, perf, test, build, chore, ci

**Rules**:
1. Stage all relevant changes with `git add`
2. Identify the PRIMARY purpose of these changes - what main problem are they solving?
3. Write a commit message focused on that main purpose, not listing every small change
4. If user provided context in $ARGUMENTS, incorporate their perspective on what matters
5. Description should be imperative mood, lowercase, no period at end
6. Body (if needed) explains WHY, not WHAT
7. After successful commit, push to the current branch

**Format for commit message**:
```
git commit -m "$(cat <<'EOF'
<type>(<scope>): <description>

<body if needed>
EOF
)"
```

Execute the commit and push now.
