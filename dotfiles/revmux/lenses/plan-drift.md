---
description: plan drift - what editing broke. A plan comes out of a template well formed and is then repaired round after round, and each repair lands in one place while the parts that agreed with it sit elsewhere
---
## Lens: plan-drift

A plan is not written once. It comes out of a template already carrying its sections and its task
anatomy, and then it is edited - a task inserted, a rule tightened, a finding repaired, a section added
by hand. Every edit lands in one place. The parts of the document that agreed with that place sit
elsewhere and are not updated with it.

That is your subject. Not whether the document matches a template - the template already gave it that,
and a project adds sections of its own freely. What you are looking for is **the places that no longer
agree with each other**, and the executor's reason for caring is direct: a fresh session reads the whole
plan and has no way to tell which of two contradicting passages is the newer one.

**Where prior rounds exist, start there.** Read what the previous round reported and what the plan now
says about it, then check each repair for the places it did not reach. A repair applied to one of two
twins is the most common damage there is and the hardest to see from inside the edit.

**On a first round there is often nothing here.** A plan fresh from the template is well formed by
construction. Reporting that it is well formed is the right answer; hunting for a defect to justify the
pass is not.

Look for:

- a task inserted or removed without the numbering following: a gap, a repeat, a `Task 0` where tasks
  begin at 1. Numbering that starts below the first task is the author saying out loud that the step
  happens before the plan, and whatever it holds belongs either in the plan as its first task or to the
  author, before it. An inserted `2.5` or `2a` is a deliberate late addition rather than damage
- a reference to a task that renumbering left behind: "see Task 4" pointing at what is now Task 5,
  "after the scaffolding task" when scaffolding was folded into another
- a list that enumerates tasks by number or by name - a carve-out, an exemption, an ordering note, a
  dependency table - and no longer matches the task list. These go stale on the first insertion and
  nothing else in the plan notices
- **a repair applied in one place and not in its twin.** The per-task gate and the acceptance task
  usually carry the same command; a Files block and the Technical Details it implements usually carry
  the same file list; a rule and its example usually carry the same shape. When a round fixed one, open
  the other
- a rule stated for every task that a later-added task cannot satisfy: a gate requiring a toolchain the
  new task runs before, a mandatory-tests rule against a task that changes no code. The carve-out that
  exists for this is itself a list by name - see above
- a block inside one task that no other task has. Tasks are heading, `**Files:**`, checkboxes, gate.
  Anything else was added by hand for one task, and it usually adds a stage: a command block sending the
  session to reconstruct a specification rather than write code. One sentence pointing at Technical
  Details is not a stage
- a checkbox outside a task - under Overview, Context, Solution Overview, Success criteria, or under
  Post-Completion, which is informational by definition. These arrive when a note is hand-added in the
  list style of its neighbours, and the executor counts them
- a section added by hand that repeats or contradicts one the template already provides
- a passage the plan repaired into contradiction: the same interaction, contract or invariant described
  two ways in two sections, where one of the two is what a round asked for

Not a finding:

- a project-specific section, however unusual, that contradicts nothing. Head matter is where a project
  puts what it needs, and difference from the template is not damage
- a section the template offers and this plan does not use, unless something in the plan refers to it
- a gate named once and referenced by tasks. Repeating the command in every checkbox is not required,
  and a bare "run tests" pointing at a gate that names it is complete
- a short task, a short checkbox, wording, heading capitalisation, or where a blank line sits
