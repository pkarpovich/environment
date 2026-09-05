---
name: ralphex-plan-audit
description: >-
  Audit a ralphex/farm implementation plan (docs/plans/*.md) for self-containment, task
  concreteness, and verification that can actually run in the task container, before
  running it through ralphex or queuing it on ralphex-farm.
  ralphex runs every task and review in a FRESH session that re-reads only the plan
  (plus the committed repo and a progress log), so anything that tells the agent to "go
  read elsewhere", "match 1:1 with an external codebase", or just names a big outcome
  without saying how to build it silently wastes huge effort and may never converge.
  Fans out parallel auditor agents that check the plan against rules from real farm
  failures and returns a farm-ready / fix-these verdict. Use whenever a ralphex plan was
  just written or is about to be executed or queued - "audit this plan", "check my plan
  before the farm", "is this plan farm-ready", "review the plan before ralphex", or
  right after /ralphex-plan or /planning:make and before creating a farm ticket. Do NOT
  use to create plans (that is ralphex-plan) or operate the farm (that is ralphex-farm).
---

# Ralphex Plan Audit

Quality gate for a ralphex plan, run after the plan is written and before ralphex (or
the farm) executes it. It spawns several auditor agents in parallel, each checking one
rule, and returns a `farm-ready` / `fix-these` verdict with concrete, located findings.

## Why these rules are load-bearing (the ralphex model)

ralphex does not keep one long-lived context. It executes a plan in phases, and each
unit runs as its own fresh agent session:

- **Task phase:** for each `### Task N:`, ralphex spawns a Claude session that re-reads
  the plan from scratch, does the task, runs the plan's validation commands, commits,
  and exits. The next task is a new session.
- **Review phases:** 5 parallel review subagents, then an external (codex) review loop,
  then 2 more agents - each a fresh subagent given the plan as context, each looping
  until it reports "clean".

The only state carried between sessions is **the plan + the committed repo + a progress
log**. The plan is the single durable spec every cold session reads, which is why the
plan must be both:

1. **Self-contained** - it must not send a session OUTSIDE the plan and repo for
   information it needs. If it does, every one of those many sessions has to fetch and
   re-derive that information, repeatedly, across task and review and loop iterations.
2. **Concrete** - each task must actually specify the work, not just name it. A fresh
   session has only the words on the page; if a task is a headline, the session invents
   the design, and different sessions invent different, incompatible, or wrong designs.

These are two faces of one principle: **the buildable spec must live in the plan** -
neither pointed at from outside (rule A1) nor left as a headline (rule A2). When a
plan's tasks are hollow it is usually because the real design lives only in the author's
head or a side document; writing it into the tasks is the fix (and is exactly what
"expand the plan into a reviewed spec" means).

A secondary consequence: because the review phases loop until clean, any acceptance
criterion a fresh reviewer cannot definitively judge keeps the loop finding "issues"
and burning iterations (rule A3).

There is a third, quieter failure that is neither about the spec nor the loop: those
sessions run **inside a task container**, not on the author's machine. A plan can be
perfectly self-contained and perfectly concrete and still name a verification the
container cannot perform. Nothing fails when that happens - the agent substitutes
whatever it can run, ticks the box, and the criterion is silently never checked
(rule A5).

## Inputs

- **Plan file:** the path if given; otherwise the newest `docs/plans/*.md` in the
  current repo. If several are plausible or none is found, list candidates and ask.
- **Target repo:** if the plan carries a `<!-- ralphex-farm ... -->` block, note its
  `repo`; otherwise assume the current repo. Auditors may inspect the repo to decide
  whether a reference is **in-repo** (fine - the checkout is available to every session)
  or **external** (the problem).

This skill reports only; it does not edit the plan. Offer to apply fixes if asked.

## Process

### Step 1 - Locate and read the plan

Resolve the plan file (above), read it in full, note its structure (`### Task N:`
blocks). Keep the full text - the auditor agents need it verbatim.

### Step 2 - Structural pre-check (cheap, deterministic)

Do these directly before spending agents:

- **S1 - validation exists.** The plan must give ralphex something to run after each
  task: a `## Validation Commands` section with real commands, and/or per-task items
  like "run `go test ./...`". Flag if there is no runnable validation anywhere.
- **S2 - checkbox hygiene.** `- [ ]` / `- [x]` checkboxes must appear **only** under
  `### Task N:` (or `### Iteration N:`) headers. Stray checkboxes under Overview /
  Context / Success criteria cause ralphex extra loop iterations - flag each with line.
- **S3 - task format.** Tasks use `### Task N:` (N may be `2.5`, `2a`); each code task
  has at least one explicit tests item and a final validation / "mark completed" step.

### Step 3 - Semantic fan-out (parallel auditor agents)

Launch one auditor subagent per rule (A1-A5) in parallel (Agent tool,
`subagent_type: general-purpose`). Give each: the **full plan text**, the target repo
path, its single rule's rubric (below), and the output contract. One rule per agent
keeps each focused and lets them run concurrently.

Per-agent prompt template:

```
You are auditing a ralphex implementation plan for one specific failure mode before it
runs unattended. Context you MUST internalize: ralphex executes each task and each
review in a FRESH agent session that re-reads only this plan + the committed repo + a
progress log. Nothing else carries over.

Target repo: <path> (references INTO this repo are fine; references OUTSIDE it, and
information the plan never writes down, are the problems this audit is about).

Your rule: <A-id and title>
<the rubric block for that rule, verbatim>

Plan under audit:
<full plan markdown>

Return ONLY findings for YOUR rule, as a JSON array. Each finding:
{ "rule": "<A-id>", "severity": "blocker|warning|nit",
  "location": "<section or Task N> - \"<short verbatim quote from the plan>\"",
  "problem": "<why this breaks a cold ralphex session or the review loop>",
  "fix": "<concrete rewrite>" }
If the plan is clean for your rule, return [].
```

Severity by ralphex impact, not style:

- **blocker** - a fresh session cannot build the right thing with only plan + repo, or
  the review loop cannot converge. Must fix before the farm.
- **warning** - likely wastes iterations or risks drift, but may still finish.
- **nit** - minor clarity issue.

### Step 4 - Aggregate and verdict

Merge S1-S3 + all agent findings. Dedupe overlaps (A1 and A2 often co-fire on the same
hollow line - keep one, note both rules). Then:

- **Any blocker -> `NOT FARM-READY`** - list blockers first; fix and re-audit before
  queuing.
- **No blockers -> `FARM-READY`** - list warnings/nits as optional improvements.

Report shape:

```
# Ralphex plan audit: <plan path>
Verdict: NOT FARM-READY (N blockers, M warnings) | FARM-READY (M warnings, K nits)

## Blockers
1. [A2 concreteness] Task 7 - "configure the graph store (external backend)"
   Why: hides the correctness-critical isolation setting; a cold session cannot
        rediscover it and ships a subtly broken store that passes shallow tests.
   Fix: specify the exact config, the isolation key, and the required init order inline.

## Warnings
...
## Nits
...
```

End with one line: what to change to flip the verdict to FARM-READY, or "ready to queue".

## Rubrics

Give each auditor exactly one block.

### A1 - Self-containment (the spec must be reachable)

Flag anything that makes a fresh session get information it NEEDS from OUTSIDE the plan
and the target repo:

- "read / see / refer to the source / repo / docs at <external>" - an external repo,
  URL, or another project not checked out in the target repo.
- an absolute or home path to a file not in the repo (`~/Downloads/design.md`,
  `/Users/.../notes.md`) - it exists only on the author's machine and will not be
  present in a cold or containerized run.
- "match / be 1:1 / parity with <external tool or codebase>" used as a goal or bar.
- "port <external>'s tests 1:1" / "mirror <external>'s behavior" when that behavior is
  not fully written into the plan.
- reliance on a spec that lives only outside: an upstream design, a chat thread, or
  "the old implementation" if it is not in this repo.

Decisive test: could a fresh agent, given ONLY this plan plus a checkout of the target
repo, finish the task without fetching anything else? If no -> blocker.

In-repo references are fine - the checkout is available to every session. The line is
external-to-the-repo. If external semantics are genuinely required, capture them in the
plan (rules, concrete examples, exact cases) and name the plan/repo as the source of
truth. A plan that BOTH captures the semantics inline AND still says "read the source /
match it 1:1" is contradictory, and agents follow the outward pointer - flag it.

Real failures that motivate this: a plan that demanded 1:1 parity with an external
repository turned every cold review session into a re-fetch-and-re-audit of that repo,
so the loop never converged and burned hours of repeated work; another plan's
authoritative design document sat in the author's Downloads folder, invisible to any
real run.

### A2 - Task concreteness (a task must be a buildable spec, not a headline)

A fresh session has only the plan. If a task names an outcome and chains components but
omits the design, the session has to INVENT the contract, the mechanism, the wiring,
and the rationale - and different reasonable inventions give different, incompatible, or
subtly wrong results. Across a multi-task plan the invented pieces then fail to fit.

Flag a task as under-specified ("ephemeral") when it states the noun and the data-flow
arrows but omits decisions a competent engineer would otherwise have to make up:

- **WHAT** - the concrete artifact and its contract: files, key function/type
  signatures, data shapes, inputs/outputs - not just a name.
- **HOW** - the behavior and the specific intended mechanism: flow, sync vs async,
  idempotency, error/failure handling, and the non-obvious correct way for any tricky
  library or system involved (its gotchas, required init order, config traps).
- **WHERE** - how it wires in: which interfaces it calls, who calls it, the boundaries.
- **WHY** - its purpose in the system, so the agent's judgment calls align with intent
  instead of being arbitrary.

Decisive test: "are there material implementation decisions here that the plan leaves to
the agent, where different reasonable choices produce different / incompatible / wrong
results?" If yes, it is under-specified.

The most dangerous case is a hollow integration task ("integrate / configure <library
or system>") that hides a correctness-critical, non-obvious detail (a tenancy/isolation
setting, an ordering or locking requirement, a score-combination step). A cold agent
cannot rediscover it, so it confidently builds something subtly broken that still passes
shallow tests; the failure surfaces only later.

Anti-example (ephemeral): "implement `ingest.py`: upload -> parse -> write to the index
+ the graph + the provenance store." Names a file and arrows; says nothing about whether
upload is synchronous or backgrounded, what the idempotency key is, what happens if one
store write fails, or how progress is tracked - all left to imagination.

Concrete version (same task): "upload writes an initial record with status=pending and
returns the id synchronously, then runs ingestion in a background task; id = hash(bytes)
is the idempotency key (re-upload is a no-op); the pipeline writes all stores
concurrently and sets status=error on any failure (no cross-store transaction - status
is the reconciliation signal); a job registry reports parse/index/done stages." One
intended design, nothing left to invent.

Note: concreteness is not verbosity. A short task can be concrete; a long one can still
be hollow. Judge by the decisive test, not length. Scaffolding/boilerplate tasks need
less; integration, orchestration, and algorithm tasks need the most.

### A3 - Unambiguous, convergent acceptance criteria

Flag criteria a fresh reviewer cannot definitively judge, so the review loop cannot
declare "done":

- contradictions: "1:1 with X but with <language>-specific divergences", "exactly match
  Y, adapt where needed".
- subjective bars with no checkable definition: "robust", "clean", "production-grade".
- "match an external reference" as the criterion (also A1).
- open-ended verification with no finite done-condition: "exhaustively verify against
  <large or external thing>", "check everything" - the loop never knows when to stop.

Because review loops until clean, an unjudgeable bar keeps surfacing "issues". Every
criterion should be a command whose output defines pass, or an unambiguous in-plan
definition. Fix: replace with concrete expected behavior, specific cases, or a command.

### A4 - No cross-session or carried-context assumptions

Flag references that only resolve in a conversation the cold session never saw:

- "as discussed / decided above / earlier", "per our chat", "the approach we agreed".
- "continue from the previous step's understanding" beyond what is committed or written.
- implicit ordering or state a fresh session at Task N cannot reconstruct from plan+repo.

Each task must stand alone given the plan and the repo state at that point. A plan
referencing its OWN earlier sections ("see Technical Details below") is fine - the whole
plan is re-read. Flag only reliance on context that is NOT in the plan or repo.

### A5 - Verification the run can actually execute

Validation commands and acceptance criteria are executed by a cold session inside the
**task container**, not on the author's machine. That container is deliberately narrow:
the repo at `/workspace`, a language toolchain, and the CLIs - no docker daemon, no
deployed stack, no third-party credentials, no access to private hosts.

The failure mode is quiet, which is what makes it worth auditing. A command the
container cannot run does not stop the task: the agent picks a substitute it can run,
records it, and moves on. The checkbox ends up ticked and the criterion was never
actually verified - and because the substitute is usually reasonable-sounding, nothing
downstream reads as suspicious.

Flag verification that needs something the container does not have:

- **the Docker daemon** - `docker build`, `docker buildx bake`, `docker compose config`
  or `up`, `docker run`, anything gated on `docker info`. Note the trap: the docker
  **CLI** is installed in the image, so this fails as a daemon connection error rather
  than "command not found", which reads like a transient environment hiccup instead of
  a permanent capability gap. The `docker compose` plugin is absent too, separately.
- **a tool the image does not carry and the repo's `.mise.toml` does not declare** -
  `pnpm` is the recurring one. Dangerous indirectly: a `make` target that shells out to
  a missing tool looks runnable in the plan and is not.
- **a live system** - a deployed stack, a real third-party account, a running broadcast,
  production credentials, a private network host.

Not a finding: anything mise installs from the repo's own `.mise.toml`, and anything
needing only the repo plus its language toolchain (`go test`, `gofmt`, `golangci-lint`,
unit and in-process integration tests). Those are the normal case and must not be
discouraged.

Fix, in order of preference: (1) replace it with an equivalent check that does run in
the container - parse the compose file rather than `docker compose config`, assert on
the Dockerfile's text rather than building it, cover the behavior with a test rather
than exercising the deployment; (2) if the criterion genuinely must stay, write the
fallback into the plan inline AND say the criterion is unverified, so the finished plan
does not read as fully checked.

Severity: **blocker** when the unrunnable command is the only evidence a task is
correct and the plan offers no fallback - the agent will improvise one silently.
**Warning** when the plan already states a fallback: the work still is not verified,
but the plan is honest about it and the gap is visible afterwards.

Real failures that motivate this, all from farm runs that reported success:

- a plan whose Docker acceptance checks were skipped twice in one run (`docker info`
  fails), and again in another where `docker buildx bake` never ran - both recorded as
  "⚠ docker unavailable" and accepted on the diff looking right;
- a plan asking for `docker compose config`, where the agent fell back to parsing the
  compose file with PyYAML - a syntax check standing in for a semantic one;
- a `make test-ui` criterion in a repo with no `pnpm` in the container: the agent ran
  the recipe's steps by hand via `npx pnpm@10`, a different major than the
  `packageManager: pnpm@11.1.1` the repo pins, and the make target itself was never
  exercised;
- live acceptance criteria needing a real broadcast, a credential and a deployed stack:
  not run at all, traced to the tests asserting the same behavior instead.

## Coordination with sibling skills

- **ralphex-plan** creates plans. **This skill** audits them. **ralphex-farm** queues
  and operates them. Run this between the other two.
- If the audit returns NOT FARM-READY, fix the plan (ralphex-plan conventions still
  apply) and re-run this audit before invoking ralphex-farm.
