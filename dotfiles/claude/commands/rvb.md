---
allowed-tools: Bash(git symbolic-ref:*), Bash(git merge-base:*), Bash(git show-ref:*), Bash(git rev-parse:*)
description: revdiff review of current branch changes since divergence from default branch (excludes upstream changes)
---

## Branch divergence

- Default branch (origin/HEAD): !`git symbolic-ref refs/remotes/origin/HEAD --short 2>/dev/null | sed 's|origin/||'`
- Local main: !`git show-ref --verify --quiet refs/heads/main && echo main || true`
- Local master: !`git show-ref --verify --quiet refs/heads/master && echo master || true`
- Current HEAD: !`git rev-parse --short HEAD 2>/dev/null`

## Instructions

Launch a revdiff review showing only the changes made on the current branch since it diverged from the default branch — excluding any upstream changes that haven't been merged in. The review must include uncommitted/staged changes too.

Steps:
1. Pick the default branch: prefer `origin/HEAD` value above; if empty, fall back to local `main`, then `master`. If none exist, abort with a clear error.
2. Compute the merge-base: `git merge-base <default-branch> HEAD`.
3. Activate the `revdiff:revdiff` skill and invoke its launcher with the merge-base SHA as the single ref argument. Skip the skill's ref auto-detection step (Step 1 of its workflow) — the SHA above is the ref to use.
4. Process any annotations through the skill's normal workflow (classify, plan, fix, loop).
