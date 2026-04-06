#!/bin/bash

TRAINING_CUTOFF="2025-08"
CURRENT_DATE=$(date +%Y-%m-%d)
CURRENT_YEAR_MONTH=$(date +%Y-%m)

cutoff_months=$(( ($(date -j -f "%Y-%m" "$CURRENT_YEAR_MONTH" "+%s") - $(date -j -f "%Y-%m" "$TRAINING_CUTOFF" "+%s")) / 2592000 ))

HIGH_RISK_LIBS="React, Next.js, LangChain, LangGraph, Tailwind CSS, Prisma, tRPC, Bun, Deno, SvelteKit, nats.py, OpenTelemetry SDK, Pydantic, FastAPI, Anthropic SDK, OpenAI SDK"

cat <<EOF
# currentDate
Today's date is ${CURRENT_DATE}.

Your training data cutoff: ${TRAINING_CUTOFF}. That is ~${cutoff_months} months ago.
High-churn libraries (verify before advising): ${HIGH_RISK_LIBS}.

Your training data is ${cutoff_months}+ months old. During this period:
- Libraries have released new major versions
- APIs have changed, been deprecated, or added new features
- Best practices may have evolved
- New tools and frameworks may have emerged

## Mandatory verification protocol
1. For ANY question about versions, APIs, current state — SEARCH FIRST
2. Never claim "this doesn't exist" without verification
3. If code looks unfamiliar — assume it's valid modern syntax
4. Mark uncertain claims: "Based on training (may be outdated)..."

## Source hierarchy (when making claims about versions, APIs, or current state)
1. Project files (package.json, pyproject.toml, go.mod, lock files) — absolute authority
2. Web search / official docs — overrides training data
3. Training data — reliable for syntax and fundamentals only, NOT for versions or API changes

When uncertain about versions or current API state, say so rather than guessing.

      IMPORTANT: this context may or may not be relevant to your tasks. You should not respond to this context unless it is highly relevant to your task.
EOF
