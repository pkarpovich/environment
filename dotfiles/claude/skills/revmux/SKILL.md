---
name: revmux
description: Run a revmux multi-agent review in an agterm overlay and bring the report back into the session. Use for "revmux", "review this plan with revmux", "run revmux on", "revmux review", "audit this plan", "multi-agent review", "review with the panel". Creates the task round, writes the scope and goal the reviewers read, opens revmux in an overlay so the run is watchable, then reads the report and acts on the findings.
argument-hint: 'the subject to review: a plan path, a diff range, or a directory'
allowed-tools: [Bash, Read, Edit, Write, Grep, Glob]
---

# revmux review

revmux runs a roster of review agents against a subject, synthesizes their findings into one report,
and verifies each finding before it ships. The result is a file on disk, so the review can render in
an overlay while the session stays free to read the outcome afterwards.

## What this skill is for

The valuable part is not the invocation - it is `scope.md` and `goal.md`. Those two files are the
whole brief the reviewers get; a vague brief produces a review of whatever each agent found
interesting. Most of the work below is writing them.

## Step 0 - Preflight

```bash
which revmux && revmux --version
echo "session: ${AGTERM_SESSION_ID:-not in agterm}"
```

No revmux -> `brew install umputun/apps/revmux`. Keep the absolute path `which` printed; Step 4 needs
it.

This is the only cheap probe there is. A `revmux --task X --run Y` invocation **is** the review - it
spends the roster from the first second and writes into the round as it goes. Never call it with a
short timeout to "see if it works": a killed run leaves half-written artifacts, and the next run
refuses to write over them rather than blend two runs under one `manifest.json`. Recovering means
opening a fresh round and copying `input/` across.

## Step 1 - Choose the roster

```bash
revmux config | python3 -c "import json,sys; d=json.load(sys.stdin); print([p['name'] for p in d['profiles']]); print([l['name'] for l in d['lenses']])"
```

Profiles live in `~/.config/revmux/prompts/profiles`, lenses in `~/.config/revmux/lenses`, both linked
from `dotfiles/revmux/`.

- **`ralphex-plan`** - a plan about to be queued to the farm. Its `farm-readiness` lens asks whether a
  cold container session could build the intended thing and ever finish.
- **`comprehensive`** / **`focused`** / **`expert`** - bundled rosters for code.
- `--lenses=a,b` replaces the profile roster when a one-off cut is wanted instead of a profile.

## Step 2 - Create the round

Task name groups rounds on one subject; run name is the round. Number runs so re-reviews sort:
`01-initial`, `02-after-fix`.

```bash
cd <repo> && revmux new --task <task> --run 01-initial
```

It prints the paths for `scope.md`, `goal.md` and `context/`. Rounds land under `.revmux/tasks/`,
which is gitignored in this repo.

## Step 3 - Write the brief

**`scope.md` - what to read.** Name the subject and its size, say plainly whether it is a change or a
document that has not been built yet, and give the exact commands that open the surrounding code. A
reviewer that has to guess where the subject lives spends its budget guessing. End with what to
ignore: prose style, section ordering, header wording. "A task being short is not a finding" saves a
whole class of noise.

**`goal.md` - what correct means.** State the single question the round answers, then the conditions
that make the subject correct, as a list a reviewer can check one by one. Two lines matter more than
the rest:

- name the failure mode you actually fear, so an agent knows where to dig
- **"Finding nothing is a valid answer."** Without it the roster manufactures findings to look useful

`context/` takes extra files the reviewers should read verbatim. Leave it empty when the scope
commands already reach everything.

## Step 4 - Run it

The run takes minutes and shows a live TUI. The overlay exists so the user can watch it happen on
their own screen instead of staring at a silent tool call, so it is the default whenever
`AGTERM_SESSION_ID` is set:

```bash
cd <repo> && agtermctl session overlay open \
  "env 'PATH=$PATH' /opt/homebrew/bin/revmux --task <task> --run 01-initial --profile <profile> --markdown" \
  --follow --background-color '#1e2c3a' --target "$AGTERM_SESSION_ID"
sleep 3 && agtermctl tree --json | python3 -c "
import json,sys,os
me=os.environ['AGTERM_SESSION_ID'].lower()
def walk(n):
    if isinstance(n,dict):
        if n.get('id','').lower()==me: print('overlay:', n.get('overlay'))
        for v in n.values(): walk(v)
    elif isinstance(n,list):
        [walk(v) for v in n]
walk(json.load(sys.stdin)['result'])"
```

**Launch detached, not with `--block`.** `--block` ties the run's life to the tool call: an
interrupt, or the harness's timeout, kills the call, which kills the overlay, which kills revmux
several minutes into a review. Without it the call returns at once and the run outlives it. The
`overlay: true` read-back above is better evidence than a launch exit status anyway - it is agterm's
own state rather than a guess about what appeared on screen.

**Tint it.** A full-pane overlay without `--background-color` just swaps the pane's contents, so
nothing on screen says "a tool is running here" - it reads as a flicker. `#1e2c3a` is this skill's
cool tint, deliberately the mirror of the warm `#3a2c1e` the agterm cookbook gives revdiff, so the
two never get confused mid-session.

**Two PATHs have to be right, not one.** The overlay runs its command with the app's GUI `PATH`
(`/usr/bin:/bin:/usr/sbin:/sbin:/Applications/agterm.app/Contents/MacOS` and nothing else):

- *the command itself* - a bare `revmux` is not found and dies instantly with **exit 127**, which
  reads exactly like "the overlay did not take" and is not. Give it the absolute path, quoted, the
  way the cookbook's `annotate-pane.py` does.
- *what revmux spawns* - it shells out to `claude` and `codex`, and they inherit that same stripped
  `PATH`. Fixing only the first hop moves the failure one level down: revmux starts, then dies with
  `start claude: exec: "claude": executable file not found in $PATH`. `env 'PATH=$PATH'` hands the
  session's own `PATH` to the whole tree. Keep the single quotes - `$PATH` here contains a directory
  with a space in it, and unquoted it splits and yields **exit 126**.

Reconstructing the environment instead of passing it through does not work here: `zsh -lc` finds
`revmux` and `codex` but not `claude`, which is a mise shim that a login shell does not resolve.

`--follow` switches the user to the overlay; drop it to run quietly on a session they are not looking
at. A detached launch needs no Bash timeout of its own, and `run_in_background` is still the wrong
tool - the TUI needs a real terminal, and Step 5 waits on the report file instead.

**If the overlay does not come up, diagnose before falling back.** `overlay: false` in the read-back,
or an empty `agents/*.jsonl` in the round, is a launch problem with a cause worth naming: the
round's `events.jsonl` carries revmux's own last words, and the two `PATH` traps above account for
most of them. Dropping to headless without reading that turns a one-line fix into a silent loss of
the thing the user asked for. Headless is correct
only when `AGTERM_SESSION_ID` is empty: same command without the `agtermctl` wrapper, plus `--no-tui`.

## Step 5 - Read the report

The overlay renders; it does not hand back stdout. The result is on disk either way:

```bash
cat .revmux/tasks/<task>/01-initial/report.md
```

`--markdown` writes `report.md`; without it the round yields `findings.json`. Both appear alongside
`manifest.json` (per-stage durations and models) and `events.jsonl`.

The launch already returned, so `report.md` will not be there yet. Wait for it rather than polling in
a tight loop, and tell the user you are waiting instead of going silent:

```bash
for i in $(seq 60); do [ -f .revmux/tasks/<task>/01-initial/report.md ] && break; sleep 15; done
tail -3 .revmux/tasks/<task>/01-initial/events.jsonl
```

`report.md` is written once, at the end, so there is no partial read. While waiting, `events.jsonl`
is the live progress feed - `agent_started`, `agent_progress`, `stage`, and `agent_degraded` with
revmux's own error text when something breaks.

**Never relaunch a round that is still running.** If the user closes the overlay mid-run, the round
keeps the artifacts it wrote and the next run refuses to reuse it - see Step 0. `claude run stopped:
context canceled` in `events.jsonl` means exactly that: somebody stopped it, not that it failed.

**Judge the review outcome by the file, not by the exit status** - this applies to a run that
actually started, and never excuses skipping the launch status in Step 4. revmux prints its result on
stdout and
progress on stderr, and documents no special exit code for "found something"; a report on disk with
findings in it is a successful run.

## Step 6 - Act

Findings carry a severity, the sources that raised them, the lenses that saw them, and a verdict from
the verification stage. Report them to the user grouped by severity, and quote the file and line each
one names. Then offer to apply the fixes - do not start editing the subject unprompted, especially
when the subject is a plan the user is still writing.

Re-review after fixes with a new run on the same task (`--run 02-after-fix`), so `revmux stats`
can compare rounds.

## Worth knowing before firing it

- **It is expensive.** That 236-line plan cost about 2.7M tokens across the roster, most of it in one
  agent. Reach for a smaller profile or `--lenses` when the subject is small.
- `--no-synthesis` / `--no-verify` cut stages when raw per-agent findings are what is wanted.
- `--min-confidence=N` drops low-confidence findings before they reach the report.
- `revmux cleanup --task <task>` removes a task and every round it holds; nothing prunes itself.
