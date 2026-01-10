# Continuum Agent JSON Schema

## Table of Contents
- [GraphDefinition](#graphdefinition)
- [AgentNode](#agentnode)
- [AgentEdge](#agentedge)
- [ToolBinding](#toolbinding)
- [AgentResponseFormat](#agentresponseformat)
- [Complete Example](#complete-example)

## GraphDefinition

Top-level agent structure:

```json
{
  "id": "unique-agent-id",
  "name": "Human Readable Name",
  "description": "What this agent does",
  "generation_prompt": "Original prompt used to generate this graph",
  "response_format": { "type": 1, "payload": null },
  "nodes": [],
  "edges": [],
  "execution_plan": "graph TD\n    START --> node1"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | string | No | Server-generated unique identifier |
| name | string | Yes | Human-readable agent name |
| description | string | No | Agent purpose description |
| generation_prompt | string | Yes | Original prompt for graph generation |
| response_format | AgentResponseFormat | Yes | Output format specification |
| nodes | AgentNode[] | Yes | List of workflow nodes |
| edges | AgentEdge[] | Yes | Connections between nodes |
| execution_plan | string | Yes | Mermaid diagram of workflow |

## AgentNode

Individual workflow step:

```json
{
  "id": "nodeId",
  "name": "Node Name",
  "prompt": "Instructions for this step...",
  "tools": [],
  "max_iterations": 10,
  "is_exit_node": false,
  "defer": false
}
```

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| id | string | Yes | - | Unique identifier (camelCase recommended) |
| name | string | Yes | - | Human-readable name |
| prompt | string | Yes | - | LLM instructions for this node |
| tools | ToolBinding[] | No | [] | MCP tools available to this node |
| max_iterations | int | No | 10 | Maximum tool call iterations |
| is_exit_node | bool | No | false | Marks final synthesis node |
| defer | bool | No | false | Wait for all parallel predecessors |

### Node ID Conventions
- Use camelCase: `analyzeData`, `generateReport`
- Be descriptive: `validateInput` not `step1`
- Keep short but meaningful

### Prompt Guidelines
- Be specific about the task
- Specify output format if needed
- Reference available tools explicitly
- Use state tools for data passing between nodes

## AgentEdge

Connection between nodes:

```json
{
  "id": "edge1",
  "source": "START",
  "target": "nodeId",
  "condition_prompt": null
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | string | Yes | Unique edge identifier |
| source | string | Yes | Source node ID or "START" |
| target | string | Yes | Target node ID or "END" |
| condition_prompt | string | null | No | Natural language condition for routing |

### Special Node IDs
- `START` - Entry point, always the source of first edges
- `END` - Exit point, always the target of final edges

### Conditional Routing
When `condition_prompt` is set, GameMaster evaluates it as a yes/no question:

```json
{
  "id": "checkValid",
  "source": "validateData",
  "target": "processData",
  "condition_prompt": "Is the data valid and complete?"
}
```

## ToolBinding

Tool reference for nodes:

```json
{
  "name": "tool_name",
  "description": "What this tool does",
  "data_connection_id": "connection-uuid"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | string | Yes | Exact MCP tool name |
| description | string | No | Tool purpose (for context) |
| data_connection_id | string | null | No | MCP connection providing the tool |

## AgentResponseFormat

Two format types available:

### MARKDOWN (type: 1)
Default format for text responses:
```json
{
  "type": 1,
  "payload": null
}
```

### BLUEPRINT (type: 2)
Structured output with schema validation:
```json
{
  "type": 2,
  "payload": {
    "format": "JSON",
    "output_schema": {
      "type": "object",
      "properties": {
        "title": { "type": "string" },
        "items": { "type": "array", "items": { "type": "string" } }
      },
      "required": ["title", "items"]
    },
    "rules": "Output must be valid JSON matching the schema"
  }
}
```

## Complete Example

Parallel analysis agent with deferred join:

```json
{
  "id": "data-analyzer-001",
  "name": "Data Analyzer",
  "description": "Analyzes data from multiple angles and synthesizes findings",
  "generation_prompt": "Analyze data with statistical and semantic analysis",
  "response_format": { "type": 1, "payload": null },
  "nodes": [
    {
      "id": "statisticalAnalysis",
      "name": "Statistical Analysis",
      "prompt": "Perform statistical analysis on the provided data. Calculate key metrics, identify outliers, and summarize distributions. Use set_state to store findings.",
      "tools": [],
      "max_iterations": 5
    },
    {
      "id": "semanticAnalysis",
      "name": "Semantic Analysis",
      "prompt": "Analyze the semantic content and meaning of the data. Identify themes, patterns, and relationships. Use set_state to store findings.",
      "tools": [],
      "max_iterations": 5
    },
    {
      "id": "synthesize",
      "name": "Synthesize Findings",
      "prompt": "Combine findings from both statistical and semantic analysis. Use get_state to retrieve previous findings. Create a comprehensive summary with actionable insights.",
      "tools": [],
      "max_iterations": 3,
      "is_exit_node": true,
      "defer": true
    }
  ],
  "edges": [
    { "id": "e1", "source": "START", "target": "statisticalAnalysis", "condition_prompt": null },
    { "id": "e2", "source": "START", "target": "semanticAnalysis", "condition_prompt": null },
    { "id": "e3", "source": "statisticalAnalysis", "target": "synthesize", "condition_prompt": null },
    { "id": "e4", "source": "semanticAnalysis", "target": "synthesize", "condition_prompt": null },
    { "id": "e5", "source": "synthesize", "target": "END", "condition_prompt": null }
  ],
  "execution_plan": "graph TD\n    START([START]) --> statisticalAnalysis[Statistical Analysis]\n    START --> semanticAnalysis[Semantic Analysis]\n    statisticalAnalysis --> synthesize[Synthesize Findings]\n    semanticAnalysis --> synthesize\n    synthesize --> END([END])"
}
```
