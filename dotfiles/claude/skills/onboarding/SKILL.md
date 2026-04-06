---
name: onboarding
description: >
  Deep codebase exploration to fully understand the current project before starting work.
  Use this skill whenever the user says "onboarding", "onboard", "get familiar",
  "learn the codebase", "understand this repo", "context load", or at the start of
  a session when the user wants Claude to be fully prepared to work on the project.
  Also use when switching to an unfamiliar part of the codebase.
allowed-tools: Read Glob Grep Bash(git *) Bash(find *) Bash(ls *) Agent
---

# Project Onboarding

Deeply explore the current project so you are fully in context and ready to work.
This is not about generating a report — it is about you genuinely understanding
the codebase so that your subsequent answers and edits are accurate and informed.

## Phase 1: Project Identity

Run these in parallel to establish what the project is:

1. **File tree snapshot** — run `git ls-files | head -200` to see the full shape of the repo.
   If not a git repo, use `find . -not -path '*/.*' -type f | head -200`.

2. **Read project manifests** — look for and read whichever exist:
   - `package.json`, `pnpm-workspace.yaml`, `turbo.json` (JS/TS)
   - `pyproject.toml`, `setup.py`, `requirements.txt` (Python)
   - `go.mod`, `go.sum` (Go)
   - `Cargo.toml` (Rust)
   - `Makefile`, `Justfile`, `Taskfile.yml`
   - `docker-compose.yml`, `Dockerfile`
   - `.env.example`

3. **Read documentation** — `README.md`, `CLAUDE.md`, `ARCHITECTURE.md`, `docs/` index,
   or any top-level markdown that describes the project.

4. **Check Claude config** — read `.claude/CLAUDE.md`, `.claude/settings.json`,
   scan `.claude/commands/`, `.claude/skills/`, `.claude/rules/` if they exist.

## Phase 2: Architecture Deep Dive

Launch parallel Explore agents (subagent_type: "Explore", thoroughness: "very thorough")
to investigate these dimensions simultaneously:

### Agent 1: Entry Points and Core Flow
- Find main entry points (main.go, main.py, index.ts, cmd/*/main.go, src/app, etc.)
- Trace the primary execution flow — how does the app start, what does it do
- Identify the core business logic modules

### Agent 2: Data Layer and External Dependencies
- Database schemas, migrations, ORM models
- External API clients, MCP servers, third-party integrations
- Configuration loading, environment variables

### Agent 3: Project Patterns and Conventions
- Directory structure patterns (flat, layered, domain-driven)
- Error handling approach
- Testing patterns (unit, integration, e2e), test locations
- Naming conventions observed in the code
- Build, lint, and test commands

### Agent 4: Recent Activity
- Run `git log --oneline -20` to see recent commits
- Run `git log --oneline --since="1 week ago"` for this week's focus
- Check `git branch -a` for active branches
- Identify what areas of the codebase are actively being worked on
- Note any in-progress features or recent refactors

For monorepos: add an agent per major service/package if there are more than 3.

## Phase 3: Synthesize

After all agents complete, mentally organize what you learned:

- What this project does and why it exists
- Tech stack and key dependencies
- How the code is organized
- Main entry points and data flow
- Testing and build approach
- Any non-obvious conventions or gotchas

## Output

Keep it brief. Confirm you are ready with a short summary (5-10 lines max):

```
Project: {name}
Purpose: {one sentence}
Stack: {languages, frameworks, key deps}
Structure: {how code is organized}
Entry: {main entry points}
Ready to work.
```

Do not generate lengthy reports, architecture docs, or onboarding guides.
The goal is YOUR understanding, not documentation for the user.
