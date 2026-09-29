#!/bin/bash

# Claude Opus 5, per the model comparison table: reliable knowledge and training data
# both end 2026-05. Other current models differ - Fable 5 and Sonnet 5 end 2026-01,
# Haiku 4.5 ends 2025-02 - so revisit this when the session model changes.
# https://platform.claude.com/docs/en/about-claude/models/overview
TRAINING_CUTOFF="2026-05"
CURRENT_YEAR_MONTH=$(date +%Y-%m)

cutoff_months=$(( ($(date -j -f "%Y-%m" "$CURRENT_YEAR_MONTH" "+%s") - $(date -j -f "%Y-%m" "$TRAINING_CUTOFF" "+%s")) / 2592000 ))

# Drawn from the repositories actually being worked on, not from a generic list. Two tests to
# earn a place here: the thing moves fast enough that six months makes advice wrong, and it is
# in the stack. Re-derive when the stack shifts rather than appending. Names only, never version
# numbers - a pinned number here goes stale exactly the way a hardcoded date does, and silently.
HIGH_RISK_LIBS="Anthropic SDK, Claude Agent SDK, MCP - the spec and mcp-go, Langfuse; Go itself, its stdlib and toolchain, plus OpenTelemetry Go, nats.go and JetStream; Rust itself, its editions and stdlib, plus tokio; Svelte, Vite, Vitest, Bun, TypeScript; FastAPI, Pydantic, OpenTelemetry Python; SwiftUI and the macOS SDK, Swift Testing"

cat <<EOF
# Training staleness

Your training data ends at ${TRAINING_CUTOFF}, which is ~${cutoff_months} months ago. In that time
libraries shipped major versions, APIs changed or were deprecated, and tools appeared that you have
never seen.

Search before advising on a version, an API surface or the current state of anything - and always for
these, where the churn is fastest: ${HIGH_RISK_LIBS}.

CLAUDE.md's Epistemic section carries the rest: the source hierarchy, what not to do when a version is
unknown, and permission to say you do not know. This block only tells you how stale you are.

      IMPORTANT: this context may or may not be relevant to your tasks. You should not respond to this context unless it is highly relevant to your task.
EOF
