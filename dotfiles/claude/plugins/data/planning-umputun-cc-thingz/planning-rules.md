# User-level planning rules

These rules extend the built-in `planning:plan-review` checklist and also flow into `planning:make` (plan creation) and `planning:exec` (task execution). They encode three failure modes Pavel has seen repeatedly when agents write or review plans.

## No implementation code inside the plan

The plan describes WHAT to build and HOW TO VERIFY it. The plan does NOT contain the finished implementation. Full function bodies, multi-line algorithmic code, complete file rewrites, and ready-to-paste blocks belong in the source tree (born during execution), not in the plan markdown.

Why this matters: when a plan ships with the implementation already written, the execution phase collapses into "copy this block into the file". No test-first cycle happens, no thinking happens, and any refinement the agent could have made during implementation is suppressed. The plan should give a target and tests; the code is born during execution.

**Flag as critical** when a task contains:

- Multi-line code blocks longer than ~5 lines that aren't pure type signatures or struct field declarations
- Complete function bodies with logic inside
- Full file rewrites pasted into the plan
- Worked-out algorithms with concrete variable names and control flow

**OK to keep in the plan**:

- Type signatures or function prototypes (`pub fn format_tsv(...) -> String`) to lock the public API contract
- Short illustrative snippets (under ~5 lines) demonstrating output shape or format examples
- CLI flag declarations or struct field lists
- Cargo.toml additions or config-file deltas

## No /tmp paths or session-scoped references

The plan must not reference paths or artefacts whose existence is bound to the current shell session. A fresh agent reading the plan a week later in a different worktree must still be able to follow it.

**Flag as critical** when the plan references:

- `/tmp/*`, `/var/run/*`, `/var/folders/*`, `$TMPDIR/*` (session-scoped)
- Absolute paths under `/Users/<name>/...` or `/home/<name>/...` (machine-specific; use repo-relative or `$HOME` if portability is the point)
- "the file I created earlier", "the document we discussed" without a real path that resolves in the repo
- Output files from previous sessions that are not committed

**OK**:

- Repo-relative paths (`src/output.rs`, `docs/adr/0001-foo.md`)
- Well-known stable URLs (GitHub repos, RFC links, vendor docs)
- `$HOME`-relative paths when the rule applies broadly (`$HOME/Obsidian/PK Workspace/`) and is portable across the user's machines

## Plan must declare relevant skills to invoke

For non-trivial plans, an explicit "Skills to invoke" section near the top tells the execution agent which skills to load before starting each task. Without it, the agent has to guess which skills are relevant; commonly it misses skills it should load.

**Flag as important** when the plan:

- Touches Rust files but does not mention rust-style, rustdoc, or rust-analyzer-ssr where applicable
- Touches the Obsidian vault (`~/Obsidian/PK Workspace/`) but does not mention obsidian-vault or ovq
- Writes new web-fetch logic but does not mention defuddle
- Creates a new skill but does not mention skill-audit
- Touches `.bru` files but does not mention bruq
- Runs a long agentic chain but does not mention which thinking-tools agents to use as fallbacks

**The Skills section format** (lift verbatim from the plan template):

```markdown
## Skills to invoke

- `rust-style` - all code under `src/` must follow it
- `skill-audit` - run after editing any `dotfiles/claude/skills/**/SKILL.md`
```

Each entry: skill name + one-line reason it is relevant for THIS plan.

## Verdict rule (applies to plan-review only)

When rendering the verdict, do not soften it. If the plan is incomplete, say so and list the specific gaps. Do not append "but you may want to proceed anyway" or "this is just my opinion, feel free to override". The user can override by inertia; the review's job is to give a clean signal, not to leave doors ajar.
