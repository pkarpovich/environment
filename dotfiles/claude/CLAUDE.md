- Avoid all comments and pydocs/docstrings in code (they rot and mislead); exception: MCP tool definitions require docstrings for tool descriptions. Use clear variable/function names instead
- Use early return pattern - check failure/edge cases first with 'if not X: return', then main logic flows flat without nesting
- Never use inline arrow functions in props - use useCallback for event handlers, or curried pattern (item) => () => handler(item) for loops with args
- **ALWAYS check package.json (JS/TS), pyproject.toml (Python), go.mod (Go), or equivalent before implementing** - use installed libraries instead of reimplementing from scratch. Examples: use React Query for data fetching not manual fetch+useState, use react-hook-form not manual form state, use zod for validation not custom validators. If a library is installed but not used, that's a code smell indicating previous implementations should be refactored
- Never run code, builds, or tests to verify changes - instead ask user to run them and share results. User prefers to execute commands themselves (npm run build, pytest, python scripts, etc.)
- **NEVER commit or push without explicit user request** - only run git commit/push when the user explicitly asks (e.g., "commit this", "push", or uses /commit skill)
- Always place imports at the top of the file, never inside functions or methods

## Epistemic rules

### Source hierarchy (priority of truth)
1. **Project files & user context** (HIGHEST): package.json, pyproject.toml, go.mod, lock files are authoritative. User-provided facts = ground truth. Unknown feature/API = assume NEW, not error
2. **External tools & documentation**: web search, fetched docs, MCP responses override training data
3. **Training data** (LOWEST): reliable for syntax/logic, unreliable for versions/APIs/current state

### Anti-hallucination
- Do NOT "correct" user code to older syntax you're familiar with
- Do NOT claim "this doesn't exist" without verification
- Do NOT silently downgrade modern patterns to legacy equivalents
- Do NOT state version numbers from memory as facts
- Unfamiliar code → assume valid modern syntax
- Uncertain existence → search or ask user
- Stating versions → mark as unverified from training

### Version handling
1. Check project files (package.json, pyproject.toml, go.mod) FIRST
2. Version specified → use THAT version's API
3. No version info → ASK user
4. User states version → trust it, even if unfamiliar

### Permission to say "I don't know"
Admitting uncertainty is better than confident hallucination. Say "I'm not certain", "this might have changed", "I don't recognize this but assuming it's valid modern syntax" when appropriate
