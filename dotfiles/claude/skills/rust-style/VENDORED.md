# Vendored from davidbarsky's Rust skills gist

This skill is a snapshot of `SKILL-2.md` from David Barsky's public gist of Rust-authoring Claude Code skills. David Barsky is a known rust-analyzer contributor (63+ merged PRs) and AWS engineer; his skills are general-purpose Rust language guidance, not project-specific.

- **Upstream**: https://gist.github.com/davidbarsky/8fae6dc45c294297db582378284bd1f2
- **Source file**: `SKILL-2.md`
- **Snapshot taken**: 2026-05-19
- **Gist revision SHA**: `191b2ee46088920de97d682561e2abd1edd64a42`

## Drift policy

This is a manual snapshot. Upstream changes do NOT auto-flow here. To re-pull all three sibling skills:

```bash
GID=8fae6dc45c294297db582378284bd1f2
declare -A MAP=([SKILL-1.md]=rustdoc [SKILL-2.md]=rust-style [SKILL-3.md]=rust-analyzer-ssr)
for src in SKILL-1.md SKILL-2.md SKILL-3.md; do
  dst=~/Projects/environment/dotfiles/claude/skills/${MAP[$src]}/SKILL.md
  gh api "gists/$GID" --jq ".files[\"$src\"].content" > "$dst"
done
# update the SHA / date lines in each sibling VENDORED.md
```
