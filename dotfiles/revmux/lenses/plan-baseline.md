---
description: plan baseline - what the repository is on the day the plan starts, run rather than assumed, and whether the plan tries to manufacture its own starting conditions
---
## Lens: plan-baseline

Establish what the plan starts from. Every other reviewer reads the plan and reasons; you run the
commands the plan names and report what came back. A plan is executed against the committed repository
as it stands, so the starting state is a fact, and a fact nobody checked is the one that costs a whole
first task.

You have two halves, and they only work together: the tree as it actually is, and what the plan itself
believes about its own start.

### Half one: run it

Collect the distinct commands the plan names - the gate at the end of each task, the ones under its
validation section, the ones its acceptance scenario relies on. They repeat across tasks, so dedupe:
you are establishing a baseline once, not simulating the plan. **Run only what the plan names,
verbatim.** Do not build, test or lint anything on your own initiative, and do not repair whatever you
find.

Four outcomes, and they are not the same finding:

- **green** - the command ran and passed. Report the baseline you established and which commands
  produced it. This is worth as much as a defect: every later round can be judged against it
- **red** - the command ran and failed. The plan's starting state is not the committed repository. Give
  the count and quote the reason - the assertion, the missing symbol, the line the compiler pointed at.
  A handful of lines, not the suite's output: you have the rest of this plan to read, and a page of
  scrollback buys nothing a reader could not get by running it again
- **absent** - the command does not exist yet because the plan creates it. An empty repository whose
  first task writes the build file is exactly this, and it is not a finding. Say so and move on
- **present but unrunnable** - the command exists and cannot execute here: a tool the image does not
  carry, a daemon that is not running, a service, a credential, a host. This is the one that hides
  best. Note the shape of it: a CLI can be installed while the daemon behind it is absent, so the
  failure reads as a connection error rather than a missing capability

Then every version the plan names: run that tool's own version command and compare. A plan requiring a
version this machine does not have is not startable, and a version named in prose that no manifest pins
is a version a cold session resolves to whatever happens to be current.

**Say when you did not run something.** A command you skipped because it looked slow, a suite you cut
short, a step you decided was unnecessary - name it and say why. A report that is silent about a
command reads as a report that ran it and found it green, which is the worst outcome this lens can
produce. If you could not run anything at all, that is your first finding, with the command and its
output.

### Half two: read the plan's own idea of its start

Find tasks whose work is not the plan's goal but the plan's ability to begin:

- bringing existing checks to green, regenerating a drifted fixture, paying down lint debt
- rewriting ids, fixtures or recorded payloads so later tasks have something to run against
- installing, upgrading or configuring a tool. An install that lands in the repository's own
  manifest - the package file, the lockfile, the toolchain file - is product work and belongs to the
  task that needs it. An install written as a machine instruction belongs to no task at all: the fresh
  session runs in a container it does not administer, so the instruction either fails or is quietly
  skipped along with the criterion behind it
- merging, rebasing or moving code between branches. That is a decision, not an implementation step
- building a snapshot or baseline the rest of the plan then treats as given

The same thing counts when it is written outside the task list, but only once it has become work. A
plan may state what it assumes about the world - that a pull request landed, that a branch is the base,
that a service is deployed - and saying so plainly in the head matter helps a cold session and costs
nothing. It turns into a finding when the statement acquires a job: a command the executor must run to
check it, an instruction to go and make it true, a gate ahead of the first task. The line is between
telling a reader what is assumed and handing the executor something to do about it.

**The test that separates preparation from the plan itself:** does the task's `**Files:**` block contain
anything the finished product keeps? A task that creates the build file, the package manifest and the
first source file is the plan, even when its own gate is an empty test run. A task that only touches
fixtures, recorded data, ids, local configuration, or brings existing things to green produces nothing
the product keeps - that is preparation, and it belongs to the author, before the plan.

### Put the halves together

| tree at HEAD | preparatory task present | what it means |
|---|---|---|
| green | no | the baseline is clean. Report it and raise nothing |
| red | no | the plan cannot start as written |
| red | yes | the plan manufactures its own starting state, so no later gate is judged against the committed repository. Name the task to remove |
| green | yes | the task is dead weight, or it was written from an observation that held only in its author's environment. Say which you established |

The last row is the one neither half sees alone: running finds green and stays quiet, reading finds a
task and cannot tell it is unnecessary.

Not a finding:

- a task repairing what an earlier task of this same plan broke. A plan owns its own consequences
- a repair that is the plan's subject. When the Overview is about a defect, starting against a red tree
  is the plan working as intended
- a toolchain or environment stated in the head matter for a reader's benefit, as opposed to a task
  that installs it
- build artifacts, caches and lockfile noise your own commands produced
