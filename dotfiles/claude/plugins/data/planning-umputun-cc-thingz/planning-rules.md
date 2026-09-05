# User-level planning rules

These rules extend the built-in `planning:plan-review` checklist and also flow into `planning:make` (plan creation) and `planning:exec` (task execution). They encode the failure modes Pavel has seen repeatedly when agents write or review plans.

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

## Tasks must be concrete, not headlines

Each task must specify the work well enough that a fresh execution session builds the intended thing without inventing the design. A task that only names an outcome and chains components (`implement ingest.go: upload -> parse -> write to the stores`) leaves the contract, the mechanism, the wiring, and the rationale to imagination - different sessions invent different, incompatible, or subtly-wrong designs, and across a plan the pieces stop fitting.

This is the complement of "No implementation code inside the plan": concreteness comes from the contract + the decisions + the Files block, in prose and signatures - NOT from pasting the finished implementation. The two rules meet in the middle - enough to remove ambiguity, not so much that the code is already written.

A concrete task pins, for the work it covers: WHAT (artifact + contract - a `**Files:**` block, key signatures, data shapes), HOW (the intended mechanism and decisions - sync vs async, idempotency, failure handling, and the non-obvious correct way for any tricky library or system: its gotchas, init order, config traps), WHERE (which interfaces it calls and who calls it), WHY (its purpose, so judgment calls align with intent).

Decisive test: are there material implementation decisions the task leaves to the agent, where different reasonable choices give different / incompatible / wrong results? If yes, it is under-specified.

**Flag as critical** when a task:

- States only an outcome and data-flow arrows, with no contract, decisions, or Files block
- Is a hollow integration task ("integrate / configure <library or system>") that hides a correctness-critical, non-obvious detail (a tenancy/isolation setting, an ordering or locking requirement, a score-combination step) a fresh agent cannot rediscover - it ships something subtly broken that still passes shallow tests
- Changes code but has no `**Files:**` block, so the session must guess which files to touch

**OK**:

- A terse task when its contract lives in Technical Details and it has a Files block - concise is fine, hollow is not; judge by the decisive test, not length
- Scaffolding or boilerplate tasks, which need less detail than integration or algorithm tasks

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

## No external source of truth or 1:1-with-external requirements

The plan is the source of truth for what to build. A fresh execution session has only the plan + the committed repo; it cannot reliably read an external repo or tool, and it cannot converge against a "match it exactly" target it cannot see. This sharpens the "stable URLs are OK" allowance above: a URL as a pointer for orientation is fine, but making an external codebase or tool the spec the agent must read and mirror is not.

Why this matters: each task and each review runs in a fresh session. A task that says "read the upstream source", "match library X 1:1", or "port its tests 1:1" sends every one of those sessions to re-fetch and re-audit something the plan never wrote down; the review loop cannot confirm "1:1" without the external source, so it never converges and burns hours.

**Flag as critical** when a task:

- Names an external repo, tool, or file as the thing to "read", "match 1:1", "achieve parity with", or "port tests from", while the needed behavior is not written into the plan
- Sets "1:1 / exact parity with <external>" as an acceptance criterion (unverifiable from plan + repo alone)
- Relies on "the reference implementation" or "the old implementation" for semantics when that code is not in this repo

**OK**:

- A stable URL as a pointer for orientation (not as a spec the agent must mirror)
- Adding a named package or library dependency (`go get github.com/...`, an npm package) - a dependency to install, not an external spec to read
- External semantics captured inline in the plan (rules, grammar, examples, exact cases written out), with the plan named as the source of truth

## State non-goals and rejected alternatives

A fresh session only knows what the plan says. Without explicit non-goals it gold-plates - adds retries, configurability, abstractions, or adjacent features nobody asked for. Without the rejected alternatives it "helpfully" re-introduces an approach that was already considered and ruled out, because it cannot see the reasoning.

Capture both near the top (Overview or Solution Overview):
- **Non-goals** - the narrow boundary of this change ("v1: JSON output only, no retry, no stream-json mode"). Anything outside is explicitly later or never.
- **Rejected alternatives** - the obvious approach NOT taken, plus one line of why ("native pass-through rejected because it bypasses the PTY/transcript path").

This reasoning lives in the plan and in the PR description - it does NOT get transcribed into the code. A plan that pins WHY per task gives the executor a lot of prose with nowhere obvious to put it, and it lands as comments on every new symbol and as fresh paragraphs in CLAUDE.md. The code keeps only what the language skill's comment rule allows: a WHY that a reader of that file cannot recover without it.

**Flag as important** when:

- A plan touches an area with obvious adjacent features or a tempting larger refactor but states no non-goals, so scope is unbounded
- The design clearly chose between alternatives but records neither the choice nor why, inviting a cold session to re-litigate or reverse it

## Plan must declare relevant skills to invoke

For non-trivial plans, an explicit "Skills to invoke" section near the top tells the execution agent which skills to load before starting each task. Without it, the agent has to guess which skills are relevant; commonly it misses skills it should load.

**Flag as important** when the plan:

- Touches Rust files but does not mention rust-style, rustdoc, or rust-analyzer-ssr where applicable
- Touches Go files but does not mention the `go` skill (its signature/visibility/structure conventions)
- Touches the Obsidian vault (`~/Obsidian/PK Workspace/`) but does not mention obsidian-vault or ovq
- Writes new web-fetch logic but does not mention defuddle
- Creates a new skill but does not mention skill-audit
- Touches `.bru` files but does not mention bruq
- Runs a long agentic chain but does not mention which thinking-tools agents to use as fallbacks

**The Skills section format** - place it near the top (right after Overview) and phrase it as a directive, not a list. The executor (ralphex) guarantees only that the plan is read; it does NOT auto-load skills, so the agent must invoke them itself - a bare list reads as informational and gets ignored.

```markdown
## Skills to invoke

Load each skill below with the Skill tool and follow its conventions before implementing any task in this plan.

- `go` - signature / visibility / structure conventions for all Go code in this service
- `rust-style` - all code under `src/` must follow it
- `skill-audit` - run after editing any `dotfiles/claude/skills/**/SKILL.md`
```

Each entry: skill name + one-line reason it is relevant for THIS plan. The leading directive line is the load-bearing part - a cold task session needs to be told to actually load and apply the skills, not just see their names.

## Materialize the skills' hard rules into a Code-Quality gate

A "Skills to invoke" directive alone is not enough: the executor does not force skill-loading, and the conventions a linter cannot catch (signature budgets, methods-vs-helpers, visibility discipline) are exactly what then gets skipped. Put them in the plan, in-band, as a per-task gate.

While creating the plan, for each language skill listed in "Skills to invoke": read that skill's SKILL.md, find its `## Hard rules` block, and copy it verbatim into a plan section titled `## Code-Quality Rules (verify before marking each task complete)`.

- One sub-section per language for a multi-language plan (Go from the `go` skill, Python from the `python` skill, etc.).
- Keep the per-task gate from the skill (formatter/lint/tests green + the grep checks) - it is the load-bearing part: a cold task session must verify against it before marking any `[x]`.
- These supplement the project's CLAUDE.md/AGENTS.md.
- Place the section after Development Approach so every fresh task iteration re-reads it.

**Flag as critical** when a code plan declares skills but has no `## Code-Quality Rules` section materializing their `## Hard rules` - the conventions then ride on unguaranteed skill-loading and go unenforced per task.

## Verdict rule (applies to plan-review only)

When rendering the verdict, do not soften it. If the plan is incomplete, say so and list the specific gaps. Do not append "but you may want to proceed anyway" or "this is just my opinion, feel free to override". The user can override by inertia; the review's job is to give a clean signal, not to leave doors ajar.
