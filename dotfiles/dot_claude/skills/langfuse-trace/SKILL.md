---
name: langfuse-trace
description: Analyze Langfuse trace JSON exports using jq queries. Use when user provides a Langfuse trace file (.json) for analysis, debugging agent behavior, checking token usage, or investigating tool calls. Triggers on phrases like "analyze trace", "check this langfuse", "debug agent run", or when user shares a trace JSON file path.
---

# Langfuse Trace Analyzer

Analyze Langfuse trace exports without loading entire files into context. Use jq for targeted extraction.

## Trace Structure

```
{
  "trace": {
    "id", "name", "input", "output",
    "latency", "environment", "tags",
    "sessionId", "userId", "metadata"
  },
  "observations": [
    {
      "id", "name", "type",           // GENERATION | TOOL | CHAIN | SPAN | EVENT
      "parentObservationId",          // hierarchy link
      "model", "modelParameters",     // for GENERATION
      "input", "output",
      "startTime", "endTime", "latency",
      "usageDetails": { "input", "output", "total", "cache_read_input_tokens", "cache_creation_input_tokens" },
      "costDetails": { "input", "output", "total" },
      "totalCost",
      "toolCalls", "toolCallNames"    // tools invoked by this generation
    }
  ]
}
```

## Workflow

### Step 1: Normalize the trace file

Langfuse exports contain triple-encoded JSON strings. Normalize first:

```bash
bash scripts/normalize.sh /path/to/trace.json
```

Output: `/tmp/langfuse-trace-normalized.json`

All subsequent jq queries use this normalized file.

### Step 2: Get overview

```bash
jq '{
  trace_name: .trace.name,
  total_latency: .trace.latency,
  observations_count: (.observations | length),
  total_cost: ([.observations[] | .totalCost // 0] | add),
  models_used: ([.observations[] | select(.model) | .model] | unique)
}' /tmp/langfuse-trace-normalized.json
```

### Step 3: Targeted analysis

Based on what user wants to investigate, use appropriate jq queries from `references/jq-recipes.md`.

Common analysis paths:
- **Cost analysis**: generations with usage, most expensive calls
- **Performance**: slowest observations, timeline
- **Debugging**: specific observation input/output, tool calls, errors
- **Structure**: hierarchy tree, observation types

## Key Observation Types

| Type | Purpose |
|------|---------|
| GENERATION | LLM call with tokens/cost |
| TOOL | Tool invocation |
| CHAIN | Workflow step (LangChain) |
| SPAN | Generic timed operation |
| EVENT | Discrete occurrence |

## Important Notes

### Latency field may be inaccurate
The `.latency` field can be misleading. For accurate duration, calculate from timestamps:
```bash
jq '.observations[] | {name, duration_sec: ((.endTime | fromdateiso8601?) - (.startTime | fromdateiso8601?) // .latency)}'
```

### LangChain traces show post-injection data
When using LangChain with dependency injection (e.g., `InjectedToolArg`), tool call arguments in traces contain **injected** values, not what the LLM actually sent. This is because Langfuse callbacks capture data after injection happens.

Example: If you see `state` in tool arguments but your schema doesn't include it - that's injection, not LLM output.

## Tips

- Use `jq -r` for raw string output (no quotes)
- Use `.id[0:8]` for readable ID prefixes
- Filter with `select(.type == "GENERATION")` before extracting fields
- Sort with `sort_by(-.latency)` for descending order

For complete jq recipes, see `references/jq-recipes.md`.
