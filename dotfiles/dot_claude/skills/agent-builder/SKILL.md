---
name: agent-builder
description: Build multi-step LLM agents for the Continuum system. Use when creating agent definitions with nodes, edges, tools, and execution flows. Triggers on requests to "create an agent", "build a workflow", "design an agent graph", or when discussing Continuum agent architecture. Supports parallel execution, conditional routing, tool integration, and structured outputs.
---

# Continuum Agent Builder

Build agents as directed graphs where nodes are LLM steps and edges define execution flow.

## Quick Start

Minimal agent structure:
```json
{
  "id": "a1b2c3d4-e5f6-4789-abcd-1234567890ab",
  "name": "Agent Name",
  "description": "What this agent does",
  "generation_prompt": "Original user request",
  "response_format": { "type": 1, "payload": null },
  "nodes": [
    {
      "id": "b2c3d4e5-f6a7-4890-bcde-234567890abc",
      "name": "Process",
      "prompt": "Do the task.",
      "tools": [],
      "max_iterations": 3,
      "is_exit_node": true
    }
  ],
  "edges": [
    { "id": "c3d4e5f6-a7b8-4901-cdef-34567890abcd", "source": "START", "target": "b2c3d4e5-f6a7-4890-bcde-234567890abc", "condition_prompt": null },
    { "id": "d4e5f6a7-b8c9-4012-defa-4567890abcde", "source": "b2c3d4e5-f6a7-4890-bcde-234567890abc", "target": "END", "condition_prompt": null }
  ],
  "execution_plan": "graph TD\n    START([START]) --> process[Process]\n    process --> END([END])"
}
```

**Note:** Use UUIDs for all IDs, but keep execution_plan human-readable.

## Discovery Scripts

Before building an agent, discover available data connections and tools.

### List Data Connections
```bash
python scripts/fetch_data_connections.py [user_id]
```
Returns all configured MCP data connections with IDs needed for tool binding.

### List Available Tools
```bash
python scripts/fetch_tools.py [user_id] [connection_name_filter]
```
Returns tools from all connections, or filter by connection name/ID.

Example:
```bash
python scripts/fetch_tools.py 181084522 todoist
```

## Workflow

### 1. Understand Requirements
- What task does the agent perform?
- What inputs/outputs are expected?
- Run discovery scripts to see available tools/connections
- Does it need parallel processing or conditional logic?

### 2. Choose Pattern

**Recommended: Parallel Reports → Apply**

For content transformation tasks, use parallel analyzers that produce REPORTS (not modifications), then a final node applies all changes:

```
START → analyzeAspectA (report only) → applyChanges → END
START → analyzeAspectB (report only) ↗
```

Why: Each analyzer focuses on ONE thing, no cascading errors, final node has full context.

| Pattern | Use When |
|---------|----------|
| **Parallel Reports → Apply** | Transforming/editing content (recommended default) |
| Linear Pipeline | Sequential steps with dependencies |
| Conditional Routing | Different paths based on input |
| Loop with Validation | Iterative refinement needed |

See [patterns.md](references/patterns.md) for detailed examples.

### 3. Design Nodes
For each step:
- **id**: UUID format (`a1b2c3d4-e5f6-4789-abcd-1234567890ab`)
- **name**: Human-readable (`Analyze Data`)
- **prompt**: Clear instructions focused on outcomes, not tool mechanics
- **tools**: Only bindable tools with data_connection_id (system tools auto-available)
- **is_exit_node**: true for final user-facing node
- **defer**: true if waiting for parallel branches
- **max_iterations**: 1-10 based on expected tool calls

### 4. Connect Edges
- Start from `START`
- End at `END`
- Add `condition_prompt` for routing decisions (yes/no questions)
- Multiple edges from same source = parallel execution

### 5. Generate Mermaid
Create `execution_plan` showing the graph:
```
graph TD
    START([START]) --> nodeA[Node A]
    nodeA --> nodeB[Node B]
    nodeB --> END([END])
```

## Node Prompt Guidelines

### Prompt Writing Principles

**1. Positive Framing** — Say what TO DO, not what NOT to do
```
Bad:  "Don't include irrelevant details"
Good: "Focus only on [specific aspect]"
```

**2. Context Over Commands** — Explain WHY, not just WHAT
```
Bad:  "Output a report"
Good: "Output a report (this will be combined with other analyses in the final step)"
```

**3. Use XML for Complex Instructions**
```
<task>
Analyze fillers in the transcription
</task>

<output_format>
List each filler with surrounding context
</output_format>

<constraint>
Do NOT modify the original text
</constraint>
```

**4. Be Explicit About Scope** — Claude follows instructions literally
```
Bad:  "Clean the text"
Good: "Remove only the items identified in the reports. Keep everything else exactly as is."
```

### Report Nodes (for Parallel Reports pattern)

Analyzer nodes produce REPORTS, NOT modifications:

```
<task>
Find [issues] in the input
</task>

<output>
Structured report: what found, where, suggested fix
</output>

<constraint>
Do NOT modify the text. Only produce the report.
</constraint>
```

### Apply/Synthesize Node

Final node receives all reports:

```
<task>
Apply changes from ALL reports to the original
</task>

<rules>
- Apply each fix from the reports
- Keep everything else EXACTLY as is
- Do not add improvements beyond the reports
</rules>

<output>
The final result only
</output>
```

### Outcome-Focused Prompts

**Focus on WHAT to produce, not HOW to call tools.** Let the agent discover and use tools naturally.

```
Good: "Generate a deal intelligence report with:
       - Executive summary
       - Company profiles with key metrics
       - Contact list with roles"

Bad:  "Call the DSL generator sub-agent with call_sub_agent tool..."
```

### State Communication

Nodes share data via state tools (auto-available, don't mention in tools array):
```
"Analyze the input. Store results with set_state('analysis', your_findings)."

"Retrieve previous analysis with get_state(['analysis']). Build on those findings."
```

## Response Formats

### MARKDOWN (default)
```json
{ "type": 1, "payload": null }
```

### BLUEPRINT (structured)
```json
{
  "type": 2,
  "payload": {
    "format": "JSON",
    "output_schema": { /* JSON Schema */ },
    "rules": "Additional formatting rules"
  }
}
```

## References

- [Schema Reference](references/schema.md) - Complete JSON schema with all fields
- [Design Patterns](references/patterns.md) - Common agent architectures with examples
- [Tool Integration](references/tools.md) - System tools and MCP binding

## Validation Checklist

Before finalizing:
- [ ] All IDs are UUIDs (nodes, edges, data_connections)
- [ ] Every node has unique id
- [ ] Edges connect all nodes (no orphans)
- [ ] Path from START to END exists
- [ ] Exit node marked with `is_exit_node: true`
- [ ] Deferred nodes have multiple incoming edges
- [ ] Every tool has non-null data_connection_id (no system tools in tools array)
- [ ] For type 2 response_format, exit node has appropriate tool (call_sub_agent if delegating)
- [ ] Mermaid diagram matches edges (use human-readable names, not UUIDs)
- [ ] Prompts focus on outcomes, not tool mechanics
