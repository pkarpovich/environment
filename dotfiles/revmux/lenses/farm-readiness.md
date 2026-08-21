---
description: whether a plan survives execution by ralphex — every task and review runs in a fresh session that sees only the plan, the committed repo and a progress log
---
## Lens: farm-readiness

The subject is an implementation plan, and the executor is ralphex: it runs every task and every review
in a **fresh session** whose whole world is the plan, the committed repo and a progress log. Nothing
this session knows, nothing in a chat, nothing on a developer's disk reaches it. Read the plan as that
session would and report what it could not resolve.

The failure is not a plan that reads badly. It is a plan that reads well and then sends each cold
session somewhere different, so the pieces stop fitting, or one that cannot converge because its
acceptance criterion is unverifiable from the plan and the repo alone.

Look for:

- a task that leaves a material implementation decision open — where two reasonable readings give
  different, incompatible or subtly wrong results. Name the decision, not the task's length
- a task that names an outcome and chains components with arrows, with no contract, no key signatures
  and no `**Files:**` block, so the session guesses which files to touch
- a hollow integration task ("integrate X", "configure Y") hiding a correctness-critical detail a cold
  session cannot rediscover: an isolation or tenancy setting, an ordering or locking requirement, an
  init order, a config trap
- an external source of truth: "read the upstream source", "match X 1:1", "achieve parity with",
  "port its tests", or "the reference implementation" for semantics that is not in this repo. The
  review loop cannot confirm parity it cannot see, so it never converges
- a reference bound to a session or a machine: `/tmp`, `$TMPDIR`, `/var/folders`, `/Users/<name>/...`,
  "the file I created earlier", an uncommitted artifact from a previous run
- finished implementation pasted in: full function bodies, worked-out algorithms with concrete control
  flow, complete file rewrites. Execution then collapses into copying a block, and no test-first cycle
  or refinement happens
- verification a task container cannot run: a command needing a service, a credential, a network host
  or a GUI the repo does not provide, or an acceptance criterion with no command behind it at all
- a code plan with no per-task code-quality gate, so conventions ride on skill-loading the executor
  does not guarantee
- missing non-goals where the area invites gold-plating, or a design that chose between alternatives
  and records neither the choice nor why — a cold session re-litigates or reverses it

Not a finding:

- a terse task whose contract lives in Technical Details and which has a `**Files:**` block. Judge by
  whether a decision is left open, never by word count
- scaffolding and boilerplate tasks, which need less than integration or algorithm tasks
- type signatures, struct field lists, config deltas and short shape examples — those are the contract
- a stable URL used to orient, as opposed to a spec the agent is told to mirror
- naming a dependency to install, which is not an external spec to read
