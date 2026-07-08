# User-level brainstorm rules

## Blindspot pass (mandatory before proposing approaches)

After the problem is understood but BEFORE proposing solution approaches (Phase 2), run one explicit pass over the territory:

1. **Inventory of what already exists.** Which mechanisms, infrastructure, and conventions already living in the project or homelab are relevant to this idea? Look in primary sources, not conversation memory: CLAUDE.md, memory files, grep over the repo, the env-var table, deploy configs. Present the findings to the user as a short list: "here is what already exists and could be reused - or conflict".
2. **Explicit not-knowings.** Name 2-4 things I do NOT know about the territory that could change the design (e.g. "I don't know what else is deployed on that host", "I don't know how X is configured on your side"). Ask directly - but only the design-shaping ones.
3. Only after that - approaches.

Why: the designer's unknown unknowns must surface BEFORE a solution is designed around their absence, not as a plan-review annotation. Real incidents: an entire polling-based wake mechanism was designed before the user remembered a NATS queue was already running on the target host; a container entrypoint change made it into a plan because existing file-delivery mechanisms (hardcoded binds, TUCLAW_EXTRA_MOUNTS, /mnt/git copies) were never inventoried first.

Guardrail: this is not a twenty-item checklist ritual. Keep it to one grep-backed inventory list plus 2-4 design-shaping questions; skip entirely for trivial brainstorms where the territory is fully visible in the conversation already.

## Verify territory claims live, do not theorize

Before reading any code for this brainstorm, confirm the checkout is current: `git fetch --quiet`, then check behind-counts (current branch vs upstream, local main vs origin). Clean tree + simple fast-forward -> pull and say so; anything murkier -> state the staleness and ask. A stale checkout silently poisons every code-read that follows - the design ends up shaped by last week's code.

Any "X currently works like Y" claim that shapes the design must be checked in-session before approaches are proposed: read the actual code/config, ssh to the actual host, run the actual query. The user's recurring test is literally "did we actually verify this? did you go to the server, or is this an assumption?" - design built on an unverified assumption fails that test every time. For behavior of EXTERNAL systems (a queue, an API, a library), prefer a web search or a 10-minute spike over reasoning from training memory; "have you tried googling it?" has been asked more than once.

## Root cause before design (for problem-triggered brainstorms)

When the brainstorm starts from a symptom ("X is broken", "X annoys me"), do not design around the symptom. First establish the root cause with evidence (logs, repro, code read), state it explicitly, and get the user's confirmation that THIS is the thing being solved. The most frequent correction across all past sessions is some form of "that fixes the symptom, not the problem itself" / "find the root of the problem" - a workaround proposed as a solution is rejected every single time, so do not spend design effort on one.

## Anchor the design on the user's real scenario

Early in Phase 1, elicit the ONE concrete real scenario the user will actually run (their exact workflow, their exact file, their exact topology - not a plausible generic case), write it into the design as the acceptance scenario, and aim every later verification at it. Recurring corrections show designs and tests drifting to architectural proxy cases: "what good is your check if it's nowhere near the use case", "that's not a real use case", "you took only the beginning of the file and drew conclusions from it". A proxy test that passes proves nothing the user cares about.
