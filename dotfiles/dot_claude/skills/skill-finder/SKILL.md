---
name: skill-finder
description: Find Claude Code skills for a topic by auditing each candidate's author in a parallel subagent, not the SKILL.md text, and return the top three with an install command. Use when asked to find, search for, recommend or pick a skill for a topic ("find me a skill for X", "is there a skill for X", "recommend a skill for X"). Not for auditing existing skills (skill-audit) or writing one (skill-creator).
---

# skill-finder

Published SKILL.md text is the one thing a slop generator optimizes, so it does not separate good skills from bad. The author's record does. This skill gathers candidates, hands each author to a `skill-finder-investigator` subagent, and ranks the verdicts.

## 1. Narrow the topic

A topic that names a sub-domain and an angle ("FastAPI websocket testing", "WatchKit to SwiftUI migration") is ready. A one- or two-word topic ("Python", "Apple Watch", "Tailwind") spans many niches, and a candidate's relevance cannot be judged without knowing which.

For a broad topic, ask one open question in plain text, for example "watchOS covers complications, Watch Connectivity, HealthKit workouts and SwiftUI layout. Which part, and are you building, migrating or reviewing?" No AskUserQuestion and no option list. Take the answer at face value, fold it into the topic string, and use that string in every later step.

## 2. Gather candidates

Run the three searches, in parallel, with the narrowed topic as `T`:

- skills.sh registry, the source most installs come from:

  ```bash
  curl -fsS "https://skills.sh/api/search?q=<T>" | jq -r '.skills[] | "\(.source)\t\(.skillId)\t\(.installs)"'
  ```

- GitHub code search for `SKILL.md` files mentioning `T`, through the `gh-grep` skill.
- GitHub topic tags:

  ```bash
  for tag in claude-skill agent-skill claude-skills; do
    gh api "/search/repositories?q=topic:$tag+<T>&per_page=30" --jq '.items[] | "\(.full_name)\t\(.owner.login)\t\(.description)"'
  done
  ```

Many authors tag nothing, so the three overlap only partly.

## 3. Dedupe and cap

One author is one candidate. When an author has several skills for the topic, keep the most direct one. Cap at 10 authors.

Over 10, cut to 10 by a key that carries no quality signal, alphabetical by owner. Stars, descriptions, install counts and file sizes are the surface the slop generator controls, the audit decides quality.

Zero candidates: say "Found nothing for `<T>`, try broader keywords" and stop.

## 4. Audit in parallel

Spawn one `skill-finder-investigator` subagent per candidate, all in one message. The agent knows where to look and how to calibrate. The prompt is three lines:

```
Topic: <T>
Candidate: <url>
Author: <github login>
```

Each returns:

```json
{
  "candidate_url": "https://github.com/...",
  "author": "login",
  "topic_relevance": "high" | "medium" | "low",
  "author_quality": "real_expert" | "promising_unknown" | "skip",
  "rationale": "2-3 sentences",
  "key_signals": ["..."],
  "red_flags": ["..."]
}
```

Verdicts are categorical. A numeric score from independent subagents has no shared scale.

## 5. Rank and report

Drop `author_quality: skip` and `topic_relevance: low`. Sort by relevance first (`high` before `medium`), then by quality (`real_expert` before `promising_unknown`). The user asked for a skill about the topic, so a focused skill by an unknown outranks a tangential one by an expert. `promising_unknown` is a real tier: six maintained repos and no blog is often exactly what is wanted.

Print the top three, nothing else:

```
1. <owner>/<repo> <skill-name> - real_expert, high relevance
   <rationale>
   Signals: <key_signals in one line>
   <url>
   npx skills add <owner>/<repo> -g -a claude-code -a zed -y -s <skill-name>
```

The install line follows the skills lock convention in `~/.agents` (two agents, so the CLI symlinks instead of copying). Print it, do not run it. No cloning, no watchlist file.

Zero left after filtering: "Checked N candidates, none passed the quality bar. Try different keywords or a broader topic."
