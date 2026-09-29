---
name: context7
description: Fetch up-to-date, version-specific documentation and code examples for libraries via the Context7 platform. Use when you need authoritative API references, current syntax, or to verify a library behavior beyond your training cutoff. Especially valuable for fast-moving libraries (React, Next.js, Tailwind, FastAPI, Pydantic, LangChain, LangGraph, Anthropic SDK, OpenAI SDK, Bun, Deno, Prisma, tRPC, OpenTelemetry SDKs, etc.).
---

# Context7

Pull current docs for a library directly from the Context7 platform, with version-specific code examples. Counter to `gh-grep` (which finds real usage patterns), this skill returns curated official documentation.

Base directory for this skill: `~/.claude/skills/context7`

## When to Use

- User asks about a library API and you are uncertain about current syntax / versions
- You want to verify a claim against authoritative docs before recommending it
- Working with high-churn libraries that have evolved since the training cutoff
- Need a specific version's API (e.g. "Next.js 15 middleware", "Pydantic v2 validators")
- User explicitly says "use context7" or "fetch the docs"

Skip when the answer is trivial syntax (stdlib, well-known stable APIs) or the user is using gh-grep style "show me real usage" queries.

## Two-step flow

1. **Resolve the library ID** — Context7 needs a canonical ID like `/vercel/next.js` or `/anthropics/anthropic-sdk-python`. Use `resolve` to map a library name to its ID. Skip this step if the user provided a `/org/project` slug directly.
2. **Query the docs** — Use `docs` with the resolved ID and a *specific* question.

## Commands

```bash
# Step 1: resolve a library name to a Context7 ID
python3 ~/.claude/skills/context7/scripts/ctx7.py resolve "<libraryName>" "<query>"

# Step 2: fetch documentation by ID
python3 ~/.claude/skills/context7/scripts/ctx7.py docs "/org/project" "<specific question>"
```

Optional flags:

- `-o text|json|raw` — output format (default: text)
- `-t <seconds>` — timeout (default: 30)

## Examples

```bash
# Look up the Anthropic SDK
python3 ~/.claude/skills/context7/scripts/ctx7.py resolve "Anthropic SDK Python" "prompt caching"

# Fetch specific docs from a known ID
python3 ~/.claude/skills/context7/scripts/ctx7.py docs "/anthropics/anthropic-sdk-python" "prompt caching basic usage"

# Specific version
python3 ~/.claude/skills/context7/scripts/ctx7.py docs "/vercel/next.js/v15.0.0" "middleware authentication"
```

## Query quality tips

**Good queries** are specific and goal-shaped:

- "JWT auth middleware with cookies"
- "useEffect cleanup function with WebSocket"
- "prompt caching with system blocks"

**Bad queries** are too broad — they waste context budget:

- "auth"
- "hooks"
- "how to use"

## Library ID format

- Standard: `/org/project` (e.g. `/vercel/next.js`)
- Versioned: `/org/project/version` (e.g. `/vercel/next.js/v14.3.0-canary.87`)

If the user includes a `/org/project` slug or asks for a specific version, you can skip the resolve step.

## API key (optional)

The MCP endpoint works anonymously with per-IP rate limits. For higher limits, set:

```fish
set -gx CONTEXT7_API_KEY (your-key)
```

Get a free key at https://context7.com/dashboard. The script auto-uses it from the env var.

## Resources

- `scripts/ctx7.py` - Python CLI calling Context7's MCP server (stdlib only)
- Context7 docs: https://context7.com/docs
