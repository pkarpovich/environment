---
name: bruq
description: Execute Bruno .bru API requests via curl, or create new .bru files. Use when user asks to run, execute, or test an API request from a Bruno collection, references a .bru file, or wants to create a new Bruno request file.
---

# bruq

Convert and execute Bruno `.bru` files as curl commands, or create new `.bru` files.

## Execute Requests

```bash
eval "$(bruq <path-to-file.bru> -e <environment>)"
```

### Examples

**Run request:** `eval "$(bruq ./api/users/create.bru -e Local)"`

**With verbose:** `eval "$(bruq ./api/auth/login.bru -e Dev -v)"`

**Without env:** `eval "$(bruq ./api/health.bru)"`

### Options

- `-e, --env <NAME>` - Load variables from `environments/<NAME>.bru`
- `-v, --verbose` - Curl verbose output
- `-s, --silent` - Curl silent mode

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

## Finding Requests

```bash
find . -name "*.bru" -type f
```

Collections typically in `collections/` or `api/` directories.
