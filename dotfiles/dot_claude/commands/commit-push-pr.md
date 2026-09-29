---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git push:*), Bash(git log:*), Bash(git branch:*), Bash(git checkout:*), Bash(git commit:*), Bash(gh pr:*)
argument-hint: [optional context about changes]
description: Commit all changes, push, and create a PR
---

## Current state
- Current branch: !`git branch --show-current`
- Default branch: !`git remote show origin | grep 'HEAD branch' | cut -d' ' -f5`
- Status: !`git status --short`
- Staged diff: !`git diff --cached`
- Unstaged diff: !`git diff`
- Recent commits for style reference: !`git log --oneline -5`
- Commits not on default branch: !`git log origin/HEAD..HEAD --oneline 2>/dev/null || echo "new branch"`

## User context (if provided)
$ARGUMENTS

## Instructions

1. **Create branch** (if current branch == default branch):
   - First decide the commit message (type/scope/description per Conventional Commits)
   - Create branch name from commit: `<type>/<short-description>` (e.g., `feat/add-user-auth`, `fix/login-redirect`)
   - Run `git checkout -b <branch-name>`

2. **Commit** (if there are uncommitted changes):
   - Stage all relevant changes with `git add`
   - Create commit following Conventional Commits v1.0.0
   - Focus on PRIMARY purpose, not listing every change
   - Format: `<type>(<scope>): <description>`

3. **Push**:
   - Push to current branch (create upstream if needed with `-u`)

4. **Create PR**:
   - Use `gh pr create`
   - Title: same as main commit message (or summary if multiple commits)
   - Body format:
   ```
   ## Summary
   <1-3 bullet points about what this PR does>

   ## Test plan
   <how to verify these changes>
   ```

Execute all steps. Return the PR URL at the end.
