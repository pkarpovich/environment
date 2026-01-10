# Agent Design Patterns

## Table of Contents
- [Parallel Reports → Apply (Recommended)](#parallel-reports--apply-recommended)
- [Linear Pipeline](#linear-pipeline)
- [Parallel Analysis](#parallel-analysis)
- [Conditional Routing](#conditional-routing)
- [Loop with Validation](#loop-with-validation)
- [Tool-Heavy Worker](#tool-heavy-worker)
- [Sub-Agent Delegation](#sub-agent-delegation)

## Parallel Reports → Apply (Recommended)

Multiple analyzers produce REPORTS (not modifications), final node applies all changes.

**Use when:** Transforming or editing text/content with multiple concerns.

**Why this pattern:**
- Each analyzer focuses on ONE thing (single responsibility)
- No cascading errors from sequential modifications
- Final node has FULL context of all issues before making changes
- Original content preserved until the very end
- Reports are explicit and auditable

```
START → analyzeAspectA (report) → applyChanges → END
START → analyzeAspectB (report) ↗
```

**Key rules:**
1. Analysis nodes output REPORTS, never modify the original
2. Reports use structured format: what was found, where, suggested fix
3. Final node receives ALL reports and applies changes together
4. Set `defer: true` on final node to wait for all branches

**Example: Voice Transcription Cleaner**

```json
{
  "name": "Voice Review Cleaner",
  "description": "Cleans voice transcriptions using parallel analysis",
  "nodes": [
    {
      "id": "analyzeFillers",
      "name": "Analyze Fillers",
      "prompt": "Find all filler words in this voice transcription. Output a REPORT only:\n\n## Fillers Found\n1. \"[context]\" — \"[filler]\" is a verbal filler\n\nDo NOT clean the text. Only produce the report."
    },
    {
      "id": "analyzeRepetitions",
      "name": "Analyze Repetitions",
      "prompt": "Find unnecessary repetitions in this voice transcription. Output a REPORT only:\n\n## Repetitions Found\n1. \"[phrase]\" — suggestion: \"[cleaner version]\"\n\nDo NOT clean the text. Only produce the report."
    },
    {
      "id": "applyChanges",
      "name": "Apply Changes",
      "prompt": "Apply changes from BOTH reports (fillers and repetitions) to the original text.\n\nRules:\n- Remove fillers from the fillers report\n- Apply fixes from the repetitions report\n- Keep everything else EXACTLY as is\n- Do not rewrite beyond the reports\n\nOutput the cleaned text only.",
      "is_exit_node": true,
      "defer": true
    }
  ],
  "edges": [
    { "id": "e1", "source": "START", "target": "analyzeFillers" },
    { "id": "e2", "source": "START", "target": "analyzeRepetitions" },
    { "id": "e3", "source": "analyzeFillers", "target": "applyChanges" },
    { "id": "e4", "source": "analyzeRepetitions", "target": "applyChanges" },
    { "id": "e5", "source": "applyChanges", "target": "END" }
  ],
  "execution_plan": "graph TD\n    START([START]) --> analyzeFillers[Analyze Fillers]\n    START --> analyzeRepetitions[Analyze Repetitions]\n    analyzeFillers --> applyChanges[Apply Changes]\n    analyzeRepetitions --> applyChanges\n    applyChanges --> END([END])"
}
```

**Report formats vary by task:**

For text editing (fixes):
```
## Fillers Found
1. "[context]" — "[filler]" should be removed
```

For data extraction:
```
## Entities Extracted
- Name: "John Smith", Type: person
- Date: "2024-01-15", Type: date
```

For analysis:
```
## Tone Analysis
- Overall: professional
- Key observations: formal language, technical terms
```

The key is: reports describe WHAT was found, not HOW to present the final result.

## Linear Pipeline

Sequential processing where each step builds on the previous.

**Use when:** Tasks have natural sequential dependencies.

```
START → extractData → transformData → validateOutput → END
```

```json
{
  "nodes": [
    { "id": "extractData", "name": "Extract", "prompt": "Extract structured data from input. Store with set_state." },
    { "id": "transformData", "name": "Transform", "prompt": "Get extracted data with get_state. Apply transformations." },
    { "id": "validateOutput", "name": "Validate", "prompt": "Validate transformed data. Report issues.", "is_exit_node": true }
  ],
  "edges": [
    { "id": "e1", "source": "START", "target": "extractData" },
    { "id": "e2", "source": "extractData", "target": "transformData" },
    { "id": "e3", "source": "transformData", "target": "validateOutput" },
    { "id": "e4", "source": "validateOutput", "target": "END" }
  ]
}
```

## Parallel Analysis

Multiple independent analyses that merge at a synthesis node.

**Use when:** Different perspectives or analyses can run simultaneously.

**Key:** Set `defer: true` on the join node to wait for all branches.

```
START → branchA → synthesize → END
START → branchB ↗
```

```json
{
  "nodes": [
    { "id": "technicalReview", "name": "Technical Review", "prompt": "Analyze technical aspects. Store findings with set_state('technical', ...)." },
    { "id": "businessReview", "name": "Business Review", "prompt": "Analyze business impact. Store findings with set_state('business', ...)." },
    { "id": "synthesize", "name": "Synthesize", "prompt": "Combine technical and business findings from state.", "is_exit_node": true, "defer": true }
  ],
  "edges": [
    { "id": "e1", "source": "START", "target": "technicalReview" },
    { "id": "e2", "source": "START", "target": "businessReview" },
    { "id": "e3", "source": "technicalReview", "target": "synthesize" },
    { "id": "e4", "source": "businessReview", "target": "synthesize" },
    { "id": "e5", "source": "synthesize", "target": "END" }
  ]
}
```

## Conditional Routing

Dynamic path selection based on content analysis.

**Use when:** Different inputs require different processing paths.

```
START → classify → [condition] → pathA → END
                 → [condition] → pathB → END
```

```json
{
  "nodes": [
    { "id": "classify", "name": "Classify Input", "prompt": "Determine input type. Set state('inputType', 'typeA' or 'typeB')." },
    { "id": "handleTypeA", "name": "Handle Type A", "prompt": "Process type A input.", "is_exit_node": true },
    { "id": "handleTypeB", "name": "Handle Type B", "prompt": "Process type B input.", "is_exit_node": true }
  ],
  "edges": [
    { "id": "e1", "source": "START", "target": "classify" },
    { "id": "e2", "source": "classify", "target": "handleTypeA", "condition_prompt": "Is the input type A?" },
    { "id": "e3", "source": "classify", "target": "handleTypeB", "condition_prompt": "Is the input type B?" },
    { "id": "e4", "source": "handleTypeA", "target": "END" },
    { "id": "e5", "source": "handleTypeB", "target": "END" }
  ]
}
```

## Loop with Validation

Iterative refinement until quality threshold met.

**Use when:** Output quality needs verification with potential retry.

```
START → generate → validate → [valid?] → END
                           ↘ [invalid] → refine → validate
```

```json
{
  "nodes": [
    { "id": "generate", "name": "Generate", "prompt": "Create initial output. Store with set_state." },
    { "id": "validate", "name": "Validate", "prompt": "Check output quality. Set state('isValid', true/false) with issues." },
    { "id": "refine", "name": "Refine", "prompt": "Fix issues from validation. Update state with refined output." },
    { "id": "finalize", "name": "Finalize", "prompt": "Format final output for user.", "is_exit_node": true }
  ],
  "edges": [
    { "id": "e1", "source": "START", "target": "generate" },
    { "id": "e2", "source": "generate", "target": "validate" },
    { "id": "e3", "source": "validate", "target": "finalize", "condition_prompt": "Is the output valid and meets quality standards?" },
    { "id": "e4", "source": "validate", "target": "refine", "condition_prompt": "Does the output have issues that need fixing?" },
    { "id": "e5", "source": "refine", "target": "validate" },
    { "id": "e6", "source": "finalize", "target": "END" }
  ]
}
```

## Tool-Heavy Worker

Single node with multiple tool iterations.

**Use when:** Task requires multiple tool calls in sequence.

```json
{
  "nodes": [
    {
      "id": "researcher",
      "name": "Research Worker",
      "prompt": "Research the topic using available tools. Search, fetch content, extract data. Compile comprehensive findings.",
      "tools": [
        { "name": "web_search", "data_connection_id": "search-mcp-id" },
        { "name": "fetch_url", "data_connection_id": "search-mcp-id" }
      ],
      "max_iterations": 15,
      "is_exit_node": true
    }
  ],
  "edges": [
    { "id": "e1", "source": "START", "target": "researcher" },
    { "id": "e2", "source": "researcher", "target": "END" }
  ]
}
```

## Sub-Agent Delegation

Invoke nested agents for specialized tasks.

**Use when:** Complex subtasks benefit from dedicated agent logic.

```json
{
  "nodes": [
    {
      "id": "coordinator",
      "name": "Coordinator",
      "prompt": "Break down the task. Use call_sub_agent for specialized processing. Coordinate results.",
      "tools": [],
      "max_iterations": 10,
      "is_exit_node": true
    }
  ]
}
```

The `call_sub_agent` system tool accepts a full agent definition inline.

## Prompt Writing Tips

### State Management
```
Store intermediate results:
"After analysis, store findings with set_state('analysisResults', your_findings)."

Retrieve previous results:
"Get previous analysis with get_state(['analysisResults']) before proceeding."
```

### Output Specification
```
For reports: "Format output as a structured report with sections: Summary, Findings, Recommendations."

For data: "Output valid JSON with keys: 'result', 'confidence', 'metadata'."
```

### Tool Usage
```
Explicit tool guidance: "Use the search tool first to gather information, then the fetch tool for detailed content."

Iteration hints: "Continue searching until you have at least 3 relevant sources."
```

## Mermaid Diagram Syntax

Always include `execution_plan` with Mermaid graph:

```
graph TD
    START([START]) --> nodeId[Node Name]
    nodeId --> |condition| nextNode[Next Node]
    nextNode --> END([END])
```

- `([text])` - Rounded rectangle for START/END
- `[text]` - Rectangle for regular nodes
- `-->` - Arrow connection
- `|text|` - Edge label for conditions
