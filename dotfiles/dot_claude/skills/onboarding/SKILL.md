---
name: onboarding
description: Load the current project into context before work starts: checkout freshness, manifests, docs, structure, entry points, conventions and recent activity. Use when the user says "onboarding", "onboard", "get familiar", "learn the codebase", "understand this repo", or asks to study a service, a folder, another repo or the current PR before discussing it. The result is the agent's own understanding, not a document.
argument-hint: "[path | @subfolder | PR] [focus]"
allowed-tools: Read Glob Grep Bash(git *) Bash(gh pr *) Bash(find *) Bash(ls *) Agent
---

# Onboarding

Explore the project so later answers and edits rest on the current code. The output is a short confirmation. The understanding stays in context.

## Arguments

- A path or `@subfolder` limits every phase to that tree. An absolute path outside the working directory means onboard that repo instead.
- "PR", "the current PR" or a PR number means the scope is `gh pr diff` plus the files it touches.
- Free text after the scope is a focus ("how sessions and blob containers work", "the Obsidian services"). Answer it explicitly in the summary, and give it its own Explore agent when agents run.
- No argument: the whole repository.

## Phase 0: checkout freshness

1. `git fetch --quiet`. Skip when not a git repo or offline.
2. `git status -sb` for "behind N" on the current branch, and `git rev-list --count main..origin/main` (or `master`) for the default branch.
3. Clean tree and simply behind upstream: `git pull --ff-only`, then say what was pulled.
4. Local changes, diverged history, or a feature branch whose base is stale: pull nothing, state the staleness in the summary, and ask before going on.
5. Up to date: say nothing.

## Phase 1: identity

In one batch:

1. Shape: `git ls-files <scope> | head -200`, or `find` outside git.
2. Manifests that exist: `package.json`, `pnpm-workspace.yaml`, `turbo.json`, `pyproject.toml`, `requirements.txt`, `go.mod`, `Cargo.toml`, `Makefile`, `Justfile`, `Taskfile.yml`, `docker-compose.yml`, `Dockerfile`, `.env.example`.
3. Docs: `README.md`, `CLAUDE.md`, `ARCHITECTURE.md`, the `docs/` index.
4. Claude config: `.claude/settings.json`, `.claude/skills/`, `.claude/rules/`, `.claude/commands/`.
5. Recent activity: `git log --oneline -20`, `git log --oneline --since="1 week ago"`, `git branch -a`.

## Phase 2: architecture

For a scope under about 300 files, read it directly: entry points, core flow, data layer and external clients, config loading, test layout, build and lint commands.

For a larger scope, launch Explore agents (`subagent_type: "Explore"`, thoroughness "very thorough") in one message, one per dimension, plus one per major service in a monorepo with more than three:

1. Entry points and core flow: where the app starts, what it does, the core business modules.
2. Data layer and external dependencies: schemas, migrations, models, API clients, MCP servers, configuration and environment variables.
3. Patterns and conventions: directory layout, error handling, test layout, naming, build, lint and test commands.
4. The focus from the arguments, when there is one.

The agents report back into this conversation. Wait for every report before writing the summary. A turn that ends on "agents are running" is not finished.

## Summary

Under 10 lines, then stop:

```
Project: {name}
Purpose: {one sentence}
Stack: {languages, frameworks, key deps}
Structure: {how code is organized}
Entry: {main entry points}
Focus: {answer to the focus, when given}
Ready to work.
```

No architecture doc, no onboarding guide, no file-by-file listing.
