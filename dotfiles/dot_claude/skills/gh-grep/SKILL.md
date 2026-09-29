---
name: gh-grep
description: Search real-world code examples across millions of GitHub repositories using grep.app. This skill should be used when looking for implementation patterns, API usage examples, library integration patterns, or production code references. Supports literal code search, regex patterns, and filtering by language/repo/path.
---

# GitHub Grep

Search for real-world code examples across over a million public GitHub repositories via grep.app.

Base directory for this skill: `~/.claude/skills/gh-grep`

## When to Use

- Finding implementation patterns for unfamiliar APIs or libraries
- Looking for correct syntax, parameters, or configuration examples
- Discovering production-ready code examples and best practices
- Understanding how different libraries/frameworks work together

## Quick Start

Run the Python script (stdlib only, no deps):

```bash
python3 ~/.claude/skills/gh-grep/scripts/grep.py --query "<code-pattern>" [options]
```

## Core Options

| Option | Description |
|--------|-------------|
| `--query` | Literal code pattern (required) |
| `--match-case` | Case-sensitive search |
| `--match-whole-words` | Match whole words only |
| `--use-regexp` | Interpret query as regex |
| `--repo` | Filter by repository (e.g., `facebook/react`) |
| `--path` | Filter by file path (e.g., `src/components/`) |
| `--language` | Filter by language; repeat or comma-separate (e.g., `TypeScript,TSX`) |

## Global Options

- `-t, --timeout <seconds>`: Request timeout (default: 30)
- `-o, --output <format>`: Output format: `text` (default) | `markdown` | `json` | `raw`

## Search Patterns

**Important**: this tool searches for literal code patterns, not keywords.

Good searches:
- `useState(` - Find React useState usage
- `import React from` - Find React import statements
- `async function` - Find async function declarations

Bad searches:
- `react tutorial` - Keywords, not code
- `best practices` - Concepts, not patterns
- `how to use` - Questions, not code

For detailed pattern examples and regex usage, see `references/api_reference.md`.

## Common Examples

```bash
# Find authentication patterns
python3 ~/.claude/skills/gh-grep/scripts/grep.py \
  --query "getServerSession" --language "TypeScript,TSX"

# Find error boundary implementations
python3 ~/.claude/skills/gh-grep/scripts/grep.py \
  --query "ErrorBoundary" --language "TSX"

# Find useEffect cleanup with regex (multiline via (?s))
python3 ~/.claude/skills/gh-grep/scripts/grep.py \
  --query "(?s)useEffect\(\(\) => {.*removeEventListener" --use-regexp

# Find CORS handling in Flask
python3 ~/.claude/skills/gh-grep/scripts/grep.py \
  --query "CORS(" --match-case --language Python

# Search within a specific repository
python3 ~/.claude/skills/gh-grep/scripts/grep.py \
  --query "createContext" --repo facebook/react

# JSON output for programmatic use
python3 ~/.claude/skills/gh-grep/scripts/grep.py \
  --query "useState(" --language TypeScript -o json
```

## Requirements

- Python 3.8+ (stdlib only — no external packages)
- Network access to `https://mcp.grep.app/`

## Resources

- `scripts/grep.py` - Python CLI calling grep.app's MCP server
- `references/api_reference.md` - Detailed parameter documentation and regex patterns
