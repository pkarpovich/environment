# jq Recipes for Langfuse Traces

All recipes assume normalized JSON (run `scripts/normalize.sh` first).
Use `$FILE` as placeholder for the trace file path.

## Overview & Summary

### Trace metadata
```bash
jq '{id: .trace.id, name: .trace.name, latency: .trace.latency, environment: .trace.environment, tags: .trace.tags}' $FILE
```

### Observations count by type
```bash
jq '[.observations[] | .type] | group_by(.) | map({type: .[0], count: length})' $FILE
```

### Total cost summary
```bash
jq '[.observations[] | select(.totalCost > 0) | .totalCost] | add' $FILE
```

### Quick stats
```bash
jq '{
  trace_name: .trace.name,
  total_latency: .trace.latency,
  observations_count: (.observations | length),
  total_cost: ([.observations[] | .totalCost // 0] | add),
  models_used: ([.observations[] | select(.model) | .model] | unique)
}' $FILE
```

## Observations

### List all observations (summary)
```bash
jq '[.observations[] | {id: .id[0:8], name, type, latency, totalCost}]' $FILE
```

### Filter by type
```bash
jq '[.observations[] | select(.type == "GENERATION")]' $FILE
jq '[.observations[] | select(.type == "TOOL")]' $FILE
jq '[.observations[] | select(.type == "CHAIN")]' $FILE
```

### Hierarchy tree
```bash
jq '[.observations[] | {id: .id[0:8], parent: (.parentObservationId // "root")[0:8], name, type}]' $FILE
```

## Generations (LLM Calls)

### All generations with usage
```bash
jq '[.observations[] | select(.type == "GENERATION") | {
  name, model, latency,
  input_tokens: .usageDetails.input,
  output_tokens: .usageDetails.output,
  cost: .totalCost,
  tools_called: .toolCallNames
}]' $FILE
```

### Most expensive generation
```bash
jq '[.observations[] | select(.type == "GENERATION")] | sort_by(-.totalCost) | .[0] | {name, model, cost: .totalCost, tokens: .usageDetails}' $FILE
```

### Slowest generation
```bash
jq '[.observations[] | select(.type == "GENERATION")] | sort_by(-.latency) | .[0] | {name, model, latency, cost: .totalCost}' $FILE
```

### Token usage breakdown
```bash
jq '{
  total_input: ([.observations[] | .usageDetails.input // 0] | add),
  total_output: ([.observations[] | .usageDetails.output // 0] | add),
  cache_read: ([.observations[] | .usageDetails.cache_read_input_tokens // 0] | add),
  cache_creation: ([.observations[] | .usageDetails.cache_creation_input_tokens // 0] | add)
}' $FILE
```

## Tools

### All tool calls
```bash
jq '[.observations[] | select(.type == "TOOL") | {name, latency, parentId: .parentObservationId[0:8]}]' $FILE
```

### Tool call frequency
```bash
jq '[.observations[] | select(.type == "TOOL") | .name] | group_by(.) | map({tool: .[0], calls: length}) | sort_by(-.calls)' $FILE
```

## Deep Dive

### Get specific observation by ID prefix
```bash
jq '.observations[] | select(.id | startswith("IDPREFIX"))' $FILE
```

### Get observation input/output
```bash
jq '.observations[] | select(.id | startswith("IDPREFIX")) | {input, output}' $FILE
```

### Get trace input/output
```bash
jq '{input: .trace.input, output: .trace.output}' $FILE
```

## Timeline

### Chronological order
```bash
jq '[.observations[] | {name, type, start: .startTime, latency}] | sort_by(.start)' $FILE
```

## Errors & Issues

### Find failed observations
```bash
jq '[.observations[] | select(.level == "ERROR" or .statusMessage)] | map({name, type, level, statusMessage})' $FILE
```

### Long-running observations (>10s)
```bash
jq '[.observations[] | select(.latency > 10) | {name, type, latency}] | sort_by(-.latency)' $FILE
```

## Prompt Caching Analysis

### Cache effectiveness per generation
```bash
jq '[.observations[] | select(.type == "GENERATION") | {
  name,
  input_tokens: .usageDetails.input,
  cache_read: (.usageDetails.cache_read_input_tokens // 0),
  cache_creation: (.usageDetails.cache_creation_input_tokens // 0),
  cache_hit_pct: (if .usageDetails.input > 0 then ((.usageDetails.cache_read_input_tokens // 0) / .usageDetails.input * 100 | floor) else 0 end)
}]' $FILE
```

### Total cache savings
```bash
jq '{
  total_cache_read: ([.observations[] | .usageDetails.cache_read_input_tokens // 0] | add),
  total_cache_creation: ([.observations[] | .usageDetails.cache_creation_input_tokens // 0] | add),
  total_input: ([.observations[] | .usageDetails.input // 0] | add)
} | . + {cache_read_pct: (if .total_input > 0 then (.total_cache_read / .total_input * 100 | floor) else 0 end)}' $FILE
```

## Token Growth Analysis

### Input token growth between generations (detect context explosion)
```bash
jq '[.observations[] | select(.type == "GENERATION") | {
  name,
  start: .startTime,
  input: .usageDetails.input
}] | sort_by(.start) | to_entries | map({
  call: (.key + 1),
  input: .value.input,
  delta: (if .key > 0 then (.value.input - .[.key - 1].value.input) else 0 end)
})' $FILE
```

### Generations sorted by input tokens
```bash
jq '[.observations[] | select(.type == "GENERATION") | {name, input: .usageDetails.input, output: .usageDetails.output}] | sort_by(-.input)' $FILE
```

## Tool Argument Analysis

### Tool call argument sizes (find bloated calls)
```bash
jq '[.observations[] | select(.type == "GENERATION") | select(.toolCalls) | {
  name,
  tool_calls: [.toolCalls[] | {name: (.arguments | keys | join(",")), size: (.arguments | tostring | length)}]
}]' $FILE
```

### Largest tool call arguments
```bash
jq '[.observations[] | select(.type == "GENERATION") | .toolCalls[]? | {
  args_size: (.arguments | tostring | length),
  keys: (.arguments | keys)
}] | sort_by(-.args_size) | .[0:5]' $FILE
```

## Workflow Step Analysis

### Group observations by parent (workflow step)
```bash
jq '.observations | group_by(.parentObservationId) | map({
  parent: .[0].parentObservationId,
  children: [.[] | {name, type, latency}]
})' $FILE
```

### Find all operations under specific step
```bash
jq --arg parent "PARENT_ID_PREFIX" '[.observations[] | select(.parentObservationId | startswith($parent))]' $FILE
```

## Real Duration (from timestamps)

### Actual duration per observation
```bash
jq '[.observations[] | select(.type == "GENERATION") | {
  name,
  start: .startTime,
  end: .endTime,
  reported_latency: .latency
}] | sort_by(.start)' $FILE
```

### Timeline with gaps
```bash
jq '[.observations[] | {name, type, start: .startTime, end: .endTime}] | sort_by(.start)' $FILE
```
