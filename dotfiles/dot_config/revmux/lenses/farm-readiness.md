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
- one checkbox carrying a subsystem while its neighbours carry edits. The task itself passes every
  other test - it has its `**Files:**` block, its tests as their own items, its gate last - and one
  line in it reads "build the payments service" or "add the caching layer" with nothing behind it.
  This hides better than a hollow task, because the detail around it makes the bare line read as
  deliberate brevity rather than as an unfinished thought, and a reviewer scoring the task as a whole
  calls it concrete. Judge each checkbox against the work its neighbours describe. A session ticks
  items, so an item whose work is a subsystem is either built undesigned or ticked after a tenth of it
- an external source of truth: "read the upstream source", "match X 1:1", "achieve parity with",
  "port its tests", or "the reference implementation" for semantics that is not in this repo. The
  review loop cannot confirm parity it cannot see, so it never converges
- a reference bound to a session or a machine: `/tmp`, `$TMPDIR`, `/var/folders`, `/Users/<name>/...`,
  "the file I created earlier", an uncommitted artifact from a previous run
- a reference that resolves only inside a conversation the cold session never saw: "as discussed",
  "as decided above", "per our chat", "the approach we agreed", "continue from the previous step's
  understanding". A plan citing its own earlier sections is not this - the whole plan is re-read every
  time; what breaks is a citation of context living neither in the plan nor in the repo
- an acceptance criterion no fresh reviewer can settle, so the review loop never declares itself done.
  Three shapes: a bar with no checkable definition - robust, clean, production-grade; a criterion that
  contradicts itself - match it exactly, adapting where needed; and verification with no finite end -
  exhaustively verify against, check everything. Review runs until it reports clean, so an unjudgeable
  bar produces a fresh objection every round and burns iterations without converging. A criterion is
  either a command whose output decides it or an unambiguous definition inside the plan
- finished implementation pasted in: full function bodies, worked-out algorithms with concrete control
  flow, complete file rewrites. Execution then collapses into copying a block, and no test-first cycle
  or refinement happens
- verification a task container cannot run: a command needing a service, a credential, a network host
  or a GUI the repo does not provide, or an acceptance criterion with no command behind it at all.
  The failure is quiet, which is what makes it worth hunting - nothing stops the task, the session
  substitutes a check it can run, records it, and the criterion ends up ticked without ever having been
  verified. Three shapes recur. A container daemon whose CLI is installed while the daemon is absent,
  so the command fails as a connection error and reads like a transient hiccup rather than a capability
  the image does not have. A tool the image does not carry and the repository's own toolchain file does
  not declare, which is dangerous indirectly: a make target shelling out to it looks runnable in the
  plan and is not. And a live system - a deployed stack, a real third-party account, production
  credentials. Anything the repository's own toolchain file installs, and anything needing only the
  repo plus its language toolchain, is the normal case and not a finding
- a code plan with no per-task code-quality gate, so conventions ride on skill-loading the executor
  does not guarantee
- missing non-goals where the area invites gold-plating, or a design that chose between alternatives
  and records neither the choice nor why — a cold session re-litigates or reverses it
- a note standing in for work its author could do now: a test described as fragile, a check described
  as skipped, a file described as needing regeneration. A limitation of the design belongs in the plan
  and should be named plainly; a defect the author can remove before the plan starts does not become a
  caveat by being written down, it becomes the first session's problem

Not a finding:

- a terse task, or a terse checkbox inside a detailed one, whose contract lives in Technical Details
  and which has a `**Files:**` block behind it. Judge by whether a decision is left open and by how
  much work the line stands for, never by word count
- scaffolding and boilerplate tasks, which need less than integration or algorithm tasks
- type signatures, struct field lists, config deltas and short shape examples — those are the contract
- a stable URL used to orient, as opposed to a spec the agent is told to mirror
- naming a dependency to install, which is not an external spec to read
