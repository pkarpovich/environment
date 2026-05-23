---
name: skill-finder
description: Find high-quality Claude Code skills for a topic by spawning parallel subagents that audit each candidate's AUTHOR (not the SKILL.md text, which is gameable in five minutes by a slop generator). Use whenever the user asks to find, search for, recommend, or pick a skill for a topic - phrases like "find me a skill for X", "find skill for X", "recommend a skill for X", "I need a skill that does X", "look for skills about X". Each candidate goes through prose-driven investigation across four signals (OSS contributions in the topic, repo context, external reputation, the care put into the author's own other repos), and you return the top 3 with categorical verdicts (real_expert / promising_unknown / skip), never numeric scores. Do NOT use for auditing the user's own existing skills (that's skill-audit) or creating a new skill from scratch (that's skill-creator).
---

# skill-finder

Help the user find quality Claude Code skills for a given topic. The signal-to-noise ratio on GitHub is bad: slop generators publish hundreds of ChatGPT-written SKILL.md files with polished frontmatter and zero substance. Filtering those out by reading the SKILL.md text does not work, because the text is exactly what the slop generator optimised. The only honest filter is investigating the AUTHOR - their other code, their history, their external footprint - and the signals there are too rich for a mechanical rubric. So this skill pushes the qualitative judgment into per-candidate subagents that go look and decide.

## Workflow

### Step 1: Clarify intent (skip if topic is already specific)

Before searching, decide whether the topic is precise enough. A topic is precise when it names a sub-domain plus an angle - e.g. "FastAPI websocket testing", "WatchKit to SwiftUI migration", "Postgres logical replication". Skip directly to Step 2.

A topic is broad when it is a one-word or two-word platform/language/tool name - "Python", "Apple Watch", "debugging", "Tailwind". Broad topics fan out across many disjoint niches; without narrowing, you waste subagent budget on candidates that the user did not want and lose signal on `topic_relevance` (a skill about WatchKit complications is `high` if the user wants complications and `low` if they want HealthKit workouts - you cannot tell which until you ask).

For broad topics, use `AskUserQuestion` to ask **one or two short questions max**:

1. **Sub-domain**, with 3-4 concrete options drawn from common niches inside the topic (for "watchOS": complications/Smart Stack, Watch Connectivity, SwiftUI for watchOS, HealthKit/workouts, code review). Multiple choice.
2. **Use case**, only if it is not already implied by the sub-domain answer (building from scratch / migrating / reviewing existing code / learning). Multiple choice.

After the answers come back, refine the topic string. "watchOS" becomes "watchOS complications and Smart Stack widgets" or "WatchKit to SwiftUI migration on watchOS". Use this refined string everywhere downstream - both in the gather queries (Step 2) and in the subagent prompts (Step 4), so the subagent can judge `topic_relevance` against what the user actually wants.

Do not ask more than two questions. If the user answered with "Other" and gave free text, take that at face value and proceed.

### Step 2: Gather candidates

For the (now refined) topic T, run two parallel searches.

**1a. Code search for SKILL.md files about T.** Use the `gh-grep` skill (it queries grep.app across GitHub). Search for files named `SKILL.md` that mention T.

**1b. Repo search by topic tag.** Hit the GitHub API directly:

```bash
gh api '/search/repositories?q=topic:claude-skill+<T>&per_page=30' \
  --jq '.items[] | {full_name, html_url, owner: .owner.login, description}'
gh api '/search/repositories?q=topic:agent-skill+<T>&per_page=30' \
  --jq '.items[] | {full_name, html_url, owner: .owner.login, description}'
gh api '/search/repositories?q=topic:claude-skills+<T>&per_page=30' \
  --jq '.items[] | {full_name, html_url, owner: .owner.login, description}'
```

Many authors do not tag their repos at all, which is why content search (1a) and topic search (1b) complement each other.

### Step 3: Dedupe and cap

Merge the two result sets. **One author = one candidate** - if an author has several SKILL.md files for the topic, pick the most directly relevant. After dedup, cap at 10 distinct authors.

If you have more than 10 after dedup, sample down to 10 - but do not try to "pick the best 10 by eyeballing description and stars". That is exactly the surface the slop generator optimised. Take the first 10 after sorting by some stable, non-quality key (alphabetical by owner name is fine). The deep audit decides quality, not you.

If you have 0 candidates after the two searches, stop and tell the user: "Found nothing for `<T>`. Try broader keywords." Do not fake results.

### Step 4: Fan out to the investigator subagent

For each of the (up to) 10 candidates, spawn one `skill-finder-investigator` subagent. **Send all Agent tool calls in a single message** so they run in parallel.

The subagent already knows what to do - its system prompt teaches it where to look, what counts as substance vs slop, and how to calibrate. You only need to tell it about THIS candidate. Pass exactly this as the `prompt` for each invocation, using the refined topic from Step 1:

```
Topic: <refined T>
Candidate: <candidate_url>
Author: <github_username>
```

The refined topic carries the user's actual intent (e.g. "watchOS complications and Smart Stack widgets"), so the subagent can mark `topic_relevance: low` for any candidate that addresses a different niche of the broader area.

Each subagent returns a JSON verdict:

```json
{
  "candidate_url": "https://github.com/...",
  "author": "username",
  "topic_relevance": "high" | "medium" | "low",
  "author_quality": "real_expert" | "promising_unknown" | "skip",
  "rationale": "2-3 sentences explaining the call",
  "key_signals": ["short evidence point 1", "..."],
  "red_flags": ["any concerns, or empty array"]
}
```

### Step 5: Aggregate and print the top 3

Drop everything with `author_quality = skip` or `topic_relevance = low`. Sort the remainder by **relevance first, then quality**: `high` relevance before `medium` (regardless of quality), and within each relevance tier, `real_expert` before `promising_unknown`.

Relevance is the outer key because the user asked for a skill ABOUT a topic. A `real_expert` skill that only tangentially touches the topic is less useful than a `promising_unknown` skill that addresses it directly. The expert's general-purpose material is usually already in official docs; the focused skill is the value-add. Quality still matters - it tiebreaks within each relevance bucket and filters out `skip` outright - but it does not override relevance.

Print the top 3:

```
1. <author>/<repo> - real_expert, high relevance
   <rationale prose from the subagent>
   Signals: <one-line summary of key_signals>
   <url>

2. ...
```

If after filtering you have 0 candidates left, say it honestly: "Checked N candidates, none passed the quality bar. Try different keywords or a broader topic."

Print only. Do not clone, do not write a watchlist file, do not offer to install. The user decides what to do next.

## Why this skill is shaped the way it is

These decisions look weird at a glance, so the reasoning lives here so a future reader does not "fix" them by mistake.

**No numeric scores.** A 1-10 score forces calibration across independent subagents that have no shared anchors. score=7 from one subagent does not mean the same thing as score=7 from another. Categorical verdicts (`real_expert` / `promising_unknown` / `skip`) carry honest signal without false precision.

**No mechanical prefilter at Step 2.** Every shallow signal (repo name, description, star count, file size, file line count) is text or vanity metric the slop generator controls. Filtering on those at the gathering step actively hurts: it favours polished marketing over substance. The only legitimate cut at this stage is dedup-by-author plus a cap to bound cost.

**Two-axis verdict, not one.** A famous Python expert's general "modern Python" skill is not the right answer for a "FastAPI websocket testing" query, even if the author is a real_expert. Separating `topic_relevance` from `author_quality` lets you reject "great author, wrong topic" and "right topic, weak author" with the same mechanism.

**`promising_unknown` is a first-class category.** Noname engineers with no blog and 12 followers but 6 well-maintained personal repos are exactly what the user often wants. They will never look like a `real_expert` by external signals. The category exists so the subagent does not have to choose between dishonestly labelling them as expert or dishonestly skipping them.

**The investigator subagent is a separate file.** The audit logic - where to look on GitHub, what counts as substance vs slop, calibration rules for noname-with-substance - lives in the `skill-finder-investigator` agent definition (under `.claude/agents/`), not in this SKILL.md. That keeps the main-agent context lean: this file is just orchestration, and the substance-vs-slop knowledge only loads inside the subagent that actually needs it.
