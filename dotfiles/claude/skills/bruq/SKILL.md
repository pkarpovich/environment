---
name: bruq
description: Execute Bruno .bru API requests via curl, or create new .bru files. Use when user asks to run, execute, or test an API request from a Bruno collection, references a .bru file, or wants to create a new Bruno request file.
allowed-tools:
  - Read
  - Bash(bruq:*)
  - Bash(ls:*)
  - Bash(find:*)
  - Bash(eval:*)
---

# bruq

Convert and execute Bruno `.bru` files as curl commands, or create new `.bru` files.

## Execute Requests

**CRITICAL: File paths must be on a single line with no line breaks inside quotes.**

```bash
BRU_FILE='<path-to-file.bru>'
eval "$(bruq "$BRU_FILE" -e <environment>)"
```

### Options

- `-e, --env <NAME>` - Load variables from `environments/<NAME>.bru` at collection root
- `-v, --verbose` - Curl verbose output
- `-s, --silent` - Curl silent mode

## Collection Structure

Bruno collections have this structure - **environments are always at the collection root** (same level as `bruno.json`):

```
collection-root/
├── bruno.json           # Collection marker - find this first!
├── environments/        # Environments are HERE, not in subfolders
│   ├── LOCAL.bru
│   ├── Dev.bru
│   └── Prod.bru
└── requests/            # Requests can be nested anywhere
    └── subfolder/
        └── request.bru
```

### Finding Files Efficiently

1. **Find collection root**: Look for `bruno.json` by traversing up from the .bru file
2. **Environments**: Always at `<collection-root>/environments/<NAME>.bru`
3. **List available environments**: `ls <collection-root>/environments/`

## Create .bru Files

For full syntax reference, see [references/bru-syntax.md](references/bru-syntax.md).

### Quick Reference

**GET request:**
```
meta {
  name: Get Users
  type: http
}

get {
  url: {{BASE_URL}}/users
}
```

**POST with JSON:**
```
meta {
  name: Create User
  type: http
}

post {
  url: {{BASE_URL}}/users
  body: json
}

headers {
  Authorization: Bearer {{TOKEN}}
}

body:json {
  {
    "name": "John",
    "email": "john@example.com"
  }
}
```

**Environment file** (`environments/Local.bru`):
```
vars {
  BASE_URL: https://api.example.com
  TOKEN: your-token
}
```
