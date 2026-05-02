## Approach
- **Think before coding** - if task is unclear or has multiple interpretations, stop and ask. Surface assumptions explicitly instead of picking silently. If a simpler approach exists, say so and push back.
- **Simplicity first** - write minimum code that solves the problem. No features beyond what was asked, no abstractions for single-use code, no "configurability" that wasn't requested, no error handling for impossible scenarios. If 200 lines could be 50, rewrite.
- **Surgical changes** - every changed line traces directly to user request. Don't "improve" adjacent code, don't refactor what isn't broken, don't delete pre-existing dead code unless asked.
- **Goal-driven execution** - turn vague tasks into verifiable outcomes before starting:
  - "Fix bug" -> write a failing test that reproduces it, then make it pass.
  - "Add validation" -> write tests for invalid inputs first, then implement.
  - "Refactor X" -> ensure tests pass before and after, behavior unchanged.
  - Multi-step tasks -> state a brief plan with per-step verification.

## Code style
- No comments or docstrings (they rot and mislead) - use clear names instead. Exception: MCP tool definitions require docstrings.
- Early return pattern - check failure/edge cases first with `if not X: return`, main logic flows flat.
- Never inline arrow functions in React props - use `useCallback` or curried `(item) => () => handler(item)` for loops with args.
- Imports always at the top of the file, never inside functions or methods.

## Workflow
- **Check package.json / pyproject.toml / go.mod BEFORE implementing** - use installed libraries (React Query, react-hook-form, zod, etc.), never reimplement from scratch. Unused installed lib = code smell.
- Never commit or push without explicit user request (e.g. "commit this", "push", `/commit`).
- Never use `run_in_background` for TUI/interactive tools (revdiff, fzf) - stdout gets lost silently.
- Always use ASCII hyphen `-` in ALL content (chat, markdown, comments, commits, PRs) - no em/en dashes.

## Shell
User's interactive shell is **fish** (4.x, macOS). Claude Code's Bash tool itself runs commands in `/bin/zsh` - keep using zsh/POSIX syntax there, that is fine.
- Commands suggested in chat for the user to copy-paste -> **fish syntax** (`set -x VAR value`, `for x in (seq 1 5)`, `(cmd)` for substitution, `end` to close blocks, no `[[ ]]`, no `{1..5}`).
- Shell scripts written for the user to run -> default to `.fish` with fish syntax. Use `.sh` only if explicitly asked or the script targets CI / other systems.
- Commands you execute yourself via the Bash tool -> stay in zsh/POSIX, don't translate.

## Epistemic

### Source hierarchy
1. **Project files & user context** (HIGHEST) - package.json, pyproject.toml, go.mod, lock files. User-provided facts = ground truth. Unknown API = assume NEW.
2. **External tools & docs** - web search, fetched docs, MCP responses override training.
3. **Training data** (LOWEST) - reliable for syntax/logic, unreliable for versions/current state.

### Anti-hallucination
- Don't "correct" user code to older syntax you recognize.
- Don't claim "this doesn't exist" without verification.
- Don't silently downgrade modern patterns to legacy equivalents.
- Don't state version numbers from memory as facts.
- Unfamiliar code -> assume valid modern syntax.
- Uncertain existence -> search or ask.

### Version handling
1. Check project manifests FIRST.
2. Version specified -> use that version's API.
3. No version info -> ASK user.
4. User states version -> trust it, even if unfamiliar.

### Permission to say "I don't know"
Admitting uncertainty > confident hallucination. Say "not certain", "might have changed", "don't recognize this but assuming valid modern syntax" when appropriate.
