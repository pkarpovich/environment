# gh-grep API Reference

## searchGitHub Parameters

### query (required)
Literal code pattern to search for. Use actual code that appears in files.

**Examples:**
- `useState(` - React hook usage
- `export function` - Function exports
- `import { Router }` - Specific imports
- `class.*extends Component` - Class patterns (with regex)

### --match-case (optional, default: off)
Enable case-sensitive matching.

```bash
--match-case
```

Use when searching for:
- Specific constant names (`API_KEY`, `MAX_RETRIES`)
- Case-sensitive identifiers

### --match-whole-words (optional, default: off)
Match complete words only.

```bash
--match-whole-words
```

Prevents partial matches. `use` won't match `useState`.

### --use-regexp (optional, default: off)
Enable regular expression patterns.

```bash
--use-regexp
```

Supports full regex syntax including:
- `.*` - Any characters
- `\s+` - Whitespace
- `(?s)` - Multiline matching (dot matches newlines)
- `[a-z]+` - Character classes

### --repo (optional)
Filter by repository name.

**Examples:**
```bash
--repo facebook/react      # Exact repository
--repo vercel/             # All vercel org repos
--repo microsoft/vscode    # Specific project
```

### --path (optional)
Filter by file path.

**Examples:**
```bash
--path src/components/     # Component files
--path /route.ts           # Route files at any level
--path README.md           # README files
--path .config             # Config files
```

### --language (optional)
Filter by programming language. Repeat or comma-separate.

**Common values:**
- TypeScript, TSX
- JavaScript, JSX
- Python
- Java
- Go
- Rust
- C, C++, C#
- Ruby
- PHP
- Markdown, YAML, JSON

```bash
--language TypeScript,TSX
--language Python
--language Go --language Rust   # repeat-form is also fine
```

## Regex Pattern Examples

### Multiline patterns
Prefix with `(?s)` for dot to match newlines:

```bash
# useEffect with cleanup
--query "(?s)useEffect\(\(\) => {.*return \(\) =>" --use-regexp

# try-catch with await
--query "(?s)try {.*await.*} catch" --use-regexp
```

### Flexible matching
```bash
# useState with any state name
--query "const \[.*\] = useState" --use-regexp

# Any hook usage
--query "use[A-Z][a-zA-Z]+\(" --use-regexp

# Import with destructuring
--query "import {.*} from" --use-regexp
```

### Specific patterns
```bash
# API endpoint definitions
--query "app\.(get|post|put|delete)\(" --use-regexp

# Environment variable access
--query "process\.env\.[A-Z_]+" --use-regexp

# React component props
--query "interface.*Props" --use-regexp
```

## Output Formats

| Format | Flag | Description |
|--------|------|-------------|
| text | `-o text` | Plain text (default) — concatenated snippet blocks |
| markdown | `-o markdown` | Each block wrapped in triple-backtick fence |
| json | `-o json` | Parsed `result` object, pretty-printed |
| raw | `-o raw` | Full raw JSON-RPC response |

## Timeout

Default 30 seconds. Adjust with:

```bash
-t 60
--timeout 60
```

## Error Handling

Exit codes:
- `0` — success
- `1` — MCP server returned an error
- `2` — HTTP / network / protocol error

Common issues:
- **Timeout**: increase `--timeout` or narrow search with filters
- **No results**: check pattern accuracy, try a broader search or different language
- **Too many irrelevant results**: add language/repo/path filters
