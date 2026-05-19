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

The vendored `SKILL.md` uses em-dashes (`-`, `--`) in places where our project convention is ASCII hyphens. We intentionally do NOT rewrite them on import - keeping the file byte-identical to upstream makes future diff-and-merge cycles painless. The `skill-audit` warning for em-dashes on this skill is therefore expected and informational, not a real violation.

If upstream gets a `marketplace.json`, switch this skill to a proper plugin install and delete this directory.
