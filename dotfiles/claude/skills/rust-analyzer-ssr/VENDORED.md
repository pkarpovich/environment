# Vendored from davidbarsky's Rust skills gist

This skill is a snapshot of `SKILL-3.md` from David Barsky's public gist of Rust-authoring Claude Code skills. David Barsky is a known rust-analyzer contributor (63+ merged PRs) and AWS engineer; this particular skill is the most niche of the three because it covers `rust-analyzer`'s Structural Search and Replace (SSR), which only someone with rust-analyzer expertise tends to know exists.

- **Upstream**: https://gist.github.com/davidbarsky/8fae6dc45c294297db582378284bd1f2
- **Source file**: `SKILL-3.md`
- **Snapshot taken**: 2026-05-19
- **Gist revision SHA**: `191b2ee46088920de97d682561e2abd1edd64a42`

## Drift policy

This is a manual snapshot. Upstream changes do NOT auto-flow here. See the re-pull recipe in `dotfiles/claude/skills/rust-style/VENDORED.md`.

## Audit deltas (informational)

`skill-audit` reports two informational findings on this file that we intentionally do NOT fix, in order to keep byte-parity with upstream:

- `description-no-trigger`: the description says what the skill does but not "use when X". David's phrasing emphasises the capability. The skill still activates correctly because rust-analyzer SSR has no real overlap with other skills.
- `ascii-hyphens`: David uses em-dashes in places; project convention is ASCII `-`. Kept as-is so re-syncs from upstream remain diff-clean.
