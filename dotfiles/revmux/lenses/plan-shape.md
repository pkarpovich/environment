---
description: plan shape - whether an implementation plan is built the way the plans beside it are built, and whether its tasks keep the anatomy the executor parses
---
## Lens: plan-shape

Judge the plan as a document. You are not reviewing the prose and not judging whether the design is
good - you are checking that this plan is built the way the ones before it were built, because a cold
session navigates by that shape and the executor parses part of it.

**Read two or three completed plans beside this one first**, from the same `plans/` directory. They are
the authority here, and they are more specific than anything written below. Where they and this text
disagree, they win: this text describes what plans look like generally, they describe what plans look
like here.

The backbone, in this order:

```
Overview            with ### Non-goals and ### Rejected alternatives under it
Skills to invoke
Context (from discovery)
Development Approach
Code-Quality Rules
Testing Strategy
Progress Tracking
Solution Overview
Technical Details
What Goes Where
Implementation Steps
Post-Completion
```

Ten of those come from the plan template itself. Two do not: `Skills to invoke` sits right after
Overview and `Code-Quality Rules` right after Development Approach, both placed there by the planning
rules `{{PROFILE}}` carries. Read those rules before judging either one - they say what the section is
for, and a section that is present but does not do its job is worth more than one that is absent.

Two of the twelve are furniture. `Progress Tracking` is template text repeated verbatim wherever it
appears, and `Testing Strategy` is furniture in a project whose test story is one command and
substantial in one where it is not. So **a missing section is a finding only when you can say what it
would have carried that is specific to this plan** - the command that runs the suite, the thing
standing in for an e2e tier, the conventions a cold session would otherwise invent. "Section X is
absent" is not a finding on its own; name the content that went missing with it, or leave it out.

The anatomy of a task, on the other hand, is fixed: a `### Task N:` heading, a `**Files:**` block, then
checkboxes, the last of which is the gate. A task grows no new stage.

Look for:

- a section whose absence costs something nameable, or one that has moved out of the order above
- `Non-goals` or `Rejected alternatives` missing from a plan that plainly chose between options or
  drew a boundary, or sitting somewhere other than near the top - under Overview or under Solution
  Overview, both are usual. These are where the decisions live, and a cold session that cannot see a
  decision re-litigates it
- a `Skills to invoke` section that is a bare list. It has to open by telling the session to load each
  skill and follow it: the executor guarantees only that the plan is read, it loads nothing itself, so
  a list of names reads as background and gets skipped along with every convention behind it
- a `Code-Quality Rules` section that summarises the skills' hard rules instead of carrying them, or
  that drops the per-task gate. The rules are copied verbatim from each named skill so a fresh session
  verifies against the text itself, and the gate is what makes it do so before ticking a box
- a block inside a task that is not `**Files:**` and not a checkbox - a fenced command block, a
  prerequisites list, a source-material section. Each adds a stage to the task, and the stage it adds
  is usually archaeology: the implementing session reconstructing a specification instead of writing
  code. The specification belongs in Technical Details; a task holds actions. One sentence of prose
  pointing at where the specification lives is not a new stage
- a checkbox that is not an action: one starting with read, look at, find, locate, port from, or
  carrying `sed`, `git show`, `git log` as its work. Every checkbox starts with a verb that changes
  something
- task numbering that skips, repeats, or still carries a template placeholder such as a literal
  `Task N` or `Task N-1`. An inserted `Task 2.5` or `Task 2a` is a deliberate late addition rather than
  a gap, and `### Iteration N:` is the same heading under another name
- no runnable validation anywhere: no section naming the commands and no task ending in one. The
  executor needs something to run when a task reports itself done, and a plan that names nothing leaves
  it to invent a check and to believe the answer
- a task that changes code and has no `**Files:**` block, or one whose block lists no path
- a checkbox anywhere outside a task heading - under Overview, Context, Solution Overview or Success
  criteria. The executor counts those and burns review iterations on them
- tests folded into an implementation checkbox rather than standing as their own items, or a task whose
  last checkbox is not the gate
- checkboxes under Post-Completion, which is informational by definition
- an internal reference that no longer resolves: "see Task 4" after the tasks were renumbered, a
  section named that the plan does not have

Not a finding:

- a missing section that would have held only the template's own words
- a project-specific section in the head matter, however unusual - a design reference, a toolchain
  note, closing notes, a statement of what the plan assumes about the world. Head matter is what a cold
  session reads once, and a project adds to it freely
- one sentence between `**Files:**` and the checkboxes pointing at Technical Details
- a short task, a task with three checkboxes, or a task whose contract lives in Technical Details.
  Shape is what you judge, never length
- wording, heading capitalisation, list style, or where a blank line sits
