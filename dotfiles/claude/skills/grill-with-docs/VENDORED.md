# Vendored from mattpocock/skills

This skill is a snapshot of Matt Pocock's `grill-with-docs` skill, copied into our dotfiles instead of installed through a Claude Code plugin marketplace. The upstream repo only ships a `plugin.json`, not a `marketplace.json`, so `claude plugin marketplace add` does not work today.

- **Upstream**: https://github.com/mattpocock/skills/tree/main/skills/engineering/grill-with-docs
- **Snapshot taken**: 2026-05-19
- **Upstream main at snapshot**: `67bce91`
- **Files vendored**: `SKILL.md`, `CONTEXT-FORMAT.md`, `ADR-FORMAT.md`

## Drift policy

This is a manual snapshot. Upstream changes do NOT auto-flow here. To pull a fresh copy:

```bash
SHA=$(gh api repos/mattpocock/skills/commits/main --jq '.sha' | cut -c1-7)
DST=~/Projects/environment/dotfiles/claude/skills/grill-with-docs
for f in SKILL.md CONTEXT-FORMAT.md ADR-FORMAT.md; do
  curl -fsSL "https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/grill-with-docs/$f" -o $DST/$f
done
# update the "Snapshot taken" + sha lines in this file
```

## Project convention deltas

The vendored `SKILL.md` uses em-dashes (`-`, `--`) in places where our project convention is ASCII hyphens. We intentionally do NOT rewrite them on import - keeping the file above the `<local-additions>` block byte-identical to upstream makes future diff-and-merge cycles painless. The `skill-audit` warning for em-dashes on this skill is therefore expected and informational, not a real violation.

## Local additions (not in upstream)

`SKILL.md` ends with a `<local-additions>` block that is NOT in mattpocock's upstream:

- **No soft endings on verdicts**: tells the model not to append safety-out phrases like "but you can revisit this later" when it has reached a verdict during grilling. Sourced from the pattern Umputun described on Radio-T 2026-05-09 (his PR review pipeline) and captured generically in `claude4-prompt-engineer/references/patterns.md` as `<no_soft_endings>`. Applied here to grill's verdict moments.

When re-syncing `SKILL.md` from upstream:

1. Pull the new upstream content (it overwrites ours).
2. Re-append the `<local-additions>` block from the previous local version (or copy the `<no_soft_endings>` block out of `claude4-prompt-engineer/references/patterns.md` and re-wrap).
3. Diff to confirm only the upstream portion changed.

If upstream gets a `marketplace.json`, switch this skill to a proper plugin install and figure out where to host the local addition (likely a sibling skill that wraps grill or extends it).
