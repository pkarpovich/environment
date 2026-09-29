# Tool Integration Guide

## Table of Contents
- [System Tools](#system-tools)
- [MCP Tools](#mcp-tools)
- [Tool Binding](#tool-binding)

## Tool Categories

### System Tools (Auto-Available)

**Never include in node tools array** - automatically available to all nodes:

### get_state(keys)
Read values from shared state.
```
get_state(['key1', 'key2'])
→ Returns: {"key1": "value1", "key2": "value2"}
```

### set_state(key, value)
Store value in shared state for other nodes.
```
set_state('analysisResults', {"findings": [...], "score": 0.85})
→ Stored and accessible by subsequent nodes
```

### set_state_filtered(key, value)
Store with LLM filtering for large responses. Use for API responses that need summarization.

### list_state_keys()
Enumerate all available state keys.
```
list_state_keys()
→ Returns: ["inputData", "step1Results", "validationStatus"]
```

### get_chat_history()
Access conversation history before current execution.

### call_sub_agent(user_question, agent_def)
Invoke a nested agent. Can use inline definition or reference via data_connection.

**Important:** When used with type 2 data_connection (sub-agent reference), this becomes a **bindable tool** that requires explicit binding in node tools array.

## Bindable Tools

Tools that **must be included in node tools array** with `data_connection_id`:

### MCP Tools

External tools provided by MCP (Model Context Protocol) servers via data connections.

### Tool Discovery
Before designing an agent, identify available tools:
1. Check data_connections in execution request
2. Each connection provides tools with specific names
3. Tools must be explicitly bound to nodes that need them

### Common MCP Tool Categories

**Search & Fetch:**
- `web_search` - Search the web
- `fetch_url` - Retrieve URL content
- `scrape_page` - Extract structured data from pages

**File Operations:**
- `read_file` - Read file contents
- `write_file` - Write to files
- `list_directory` - List directory contents

**Database:**
- `query` - Execute database queries
- `insert` - Insert records
- `update` - Update records

**API Integrations:**
- Custom tools specific to connected services
- Check MCP server documentation for available tools

## Tool Binding

Bind MCP tools to nodes that need them:

```json
{
  "id": "fetchData",
  "name": "Fetch Data",
  "prompt": "Use the search tool to find relevant information, then fetch detailed content.",
  "tools": [
    {
      "name": "web_search",
      "description": "Search the web for information",
      "data_connection_id": "search-connection-uuid"
    },
    {
      "name": "fetch_url",
      "description": "Fetch content from a URL",
      "data_connection_id": "search-connection-uuid"
    }
  ],
  "max_iterations": 10
}
```

### Binding Rules

1. **Exact name match** - Tool name must match MCP tool name exactly
2. **Non-null data_connection_id** - Every tool binding requires valid UUID, never null
3. **Node scope** - Tools only available in nodes where bound
4. **No system tools** - Never include set_state, get_state, list_state_keys in tools array
5. **Sub-agent binding** - `call_sub_agent` with type 2 connection requires explicit binding

### max_iterations

Controls tool call budget per node:
- Default: 10
- Simple tasks: 3-5
- Research tasks: 10-15
- Complex multi-tool: 15-20

Each tool call counts as one iteration. Node stops when:
- LLM decides task complete
- max_iterations reached
- Error threshold exceeded

## Prompt Integration

Reference tools explicitly in node prompts:

**Good:**
```
"Search for recent news about the topic using web_search.
For each relevant result, use fetch_url to get full content.
Summarize findings and store with set_state('research', summary)."
```

**Avoid:**
```
"Research the topic and save results."
```

Be specific about:
- Which tools to use
- In what order
- What to do with results
- Where to store output

## Response Format & Exit Node

The exit node tools must align with response_format:

| Response Format | Exit Node Tools |
|-----------------|-----------------|
| Type 1 (markdown) | Empty `[]` - node synthesizes text directly |
| Type 2 (structured) | Requires tool to produce output (e.g., `call_sub_agent` for delegation) |

**Example for structured output:**
```json
{
  "response_format": { "type": 2, "payload": { "format": "json" } },
  "nodes": [
    {
      "id": "exit-node-uuid",
      "name": "Generate Report",
      "prompt": "Generate a report with title, summary, and findings sections.",
      "tools": [
        { "name": "call_sub_agent", "data_connection_id": "dsl-generator-uuid" }
      ],
      "is_exit_node": true
    }
  ]
}
```
