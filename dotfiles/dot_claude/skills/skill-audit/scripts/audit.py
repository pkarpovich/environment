#!/usr/bin/env python3
import argparse
import os
import re
import sys
from pathlib import Path

NAME_RE = re.compile(r"^[a-z0-9-]{1,64}$")
EM_DASH = "—"
EN_DASH = "–"
CYRILLIC_RE = re.compile(r"[Ѐ-ӿ]")
FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n?(.*)$", re.S)
TRIGGER_RE = re.compile(
    r"\b(when|trigger|triggers|invoke|invoked|activate|activates|use this|use when|use it when|fires?|on request|user asks|user says)\b",
    re.I,
)

DESC_MAX = 1024
NAME_MAX = 64
BODY_MAX_LINES = 500
REF_TOC_THRESHOLD = 300


def parse_frontmatter(text):
    m = FRONTMATTER_RE.match(text)
    if not m:
        return None, text
    fm_text = m.group(1)
    body = m.group(2)
    fields = {}
    current_key = None
    current_chunks = []
    for line in fm_text.splitlines():
        m_key = re.match(r"^([a-zA-Z_][a-zA-Z0-9_-]*):\s*(.*)$", line)
        if m_key and not line.startswith((" ", "\t")):
            if current_key is not None:
                fields[current_key] = "\n".join(current_chunks).strip()
            current_key = m_key.group(1)
            current_chunks = [m_key.group(2)]
        else:
            current_chunks.append(line)
    if current_key is not None:
        fields[current_key] = "\n".join(current_chunks).strip()
    for k, v in list(fields.items()):
        if v.startswith((">", "|")):
            v = v[1:].lstrip("\n")
        v = re.sub(r"\s+", " ", v).strip()
        fields[k] = v
    return fields, body


def find_skill_dirs(root):
    root = Path(root).resolve()
    if (root / "SKILL.md").exists():
        return [root]
    out = []
    if root.is_dir():
        for p in sorted(root.iterdir()):
            if p.is_dir() and (p / "SKILL.md").exists():
                out.append(p)
    return out


def audit_skill(skill_dir):
    findings = []
    skill_dir = Path(skill_dir)
    skill_md = skill_dir / "SKILL.md"
    text = skill_md.read_text()
    fm, body = parse_frontmatter(text)

    def add(level, rule, message):
        findings.append({"level": level, "rule": rule, "message": message})

    if fm is None:
        add("fail", "frontmatter", "no YAML frontmatter block found at top of SKILL.md")
        return findings

    name = fm.get("name")
    if not name:
        add("fail", "name-required", "`name:` field missing from frontmatter")
    else:
        if not NAME_RE.match(name):
            add("fail", "name-format", f"`name: {name}` violates lowercase + digits + hyphens, max {NAME_MAX} chars")
        if name != skill_dir.name:
            add("warn", "name-dir-mismatch", f"`name: {name}` differs from directory `{skill_dir.name}`")

    desc = fm.get("description")
    if not desc:
        add("fail", "description-required", "`description:` field missing")
    else:
        if len(desc) > DESC_MAX:
            add("fail", "description-length", f"description is {len(desc)} chars (limit {DESC_MAX}); excess: {len(desc) - DESC_MAX}")
        if CYRILLIC_RE.search(desc):
            add("warn", "description-cyrillic", "description contains Cyrillic; usually bilingual trigger padding. The model recognises intent across languages, drop the duplicates.")
        if not TRIGGER_RE.search(desc):
            add("warn", "description-no-trigger", "description has no `when`/`trigger`/`use this when` language. Either the trigger story is missing, or this content is really an always-on rule that belongs in CLAUDE.md rather than a skill.")

    body_lines = body.count("\n") + (1 if body and not body.endswith("\n") else 0)
    if body_lines > BODY_MAX_LINES:
        add("warn", "body-length", f"SKILL.md body is {body_lines} lines (suggested max {BODY_MAX_LINES}); split detail into references/")

    if EM_DASH in text or EN_DASH in text:
        em = text.count(EM_DASH)
        en = text.count(EN_DASH)
        bits = []
        if em:
            bits.append(f"{em} em-dash")
        if en:
            bits.append(f"{en} en-dash")
        add("warn", "ascii-hyphens", f"{' / '.join(bits)} occurrence(s); project convention is ASCII `-` only")

    if "allowed-tools" in fm:
        at = fm["allowed-tools"].strip()
        if at and not re.match(r"^[A-Za-z0-9_(),:*\s./-]+$", at):
            add("warn", "allowed-tools-syntax", f"`allowed-tools` contains unexpected characters: {at!r}")

    refs_dir = skill_dir / "references"
    if refs_dir.is_dir():
        for ref in sorted(refs_dir.glob("*.md")):
            lines = ref.read_text().splitlines()
            if len(lines) > REF_TOC_THRESHOLD:
                head = "\n".join(lines[:20]).lower()
                has_toc = "table of contents" in head or head.count("## ") >= 3
                if not has_toc:
                    add("info", "reference-toc", f"`references/{ref.name}` is {len(lines)} lines but has no ToC near the top; consider adding one")

    return findings


def format_report(by_skill):
    lines = []
    total = {"fail": 0, "warn": 0, "info": 0}
    for skill, findings in by_skill:
        counts = {"fail": 0, "warn": 0, "info": 0}
        for f in findings:
            counts[f["level"]] += 1
            total[f["level"]] += 1
        if not findings:
            lines.append(f"## {skill} OK")
            lines.append("")
            continue
        lines.append(f"## {skill} {counts['fail']} fail / {counts['warn']} warn / {counts['info']} info")
        order = {"fail": 0, "warn": 1, "info": 2}
        for f in sorted(findings, key=lambda x: order[x["level"]]):
            lines.append(f"- **{f['level'].upper()}** `{f['rule']}` {f['message']}")
        lines.append("")
    summary = f"# Skill audit: {len(by_skill)} skill(s), {total['fail']} fail / {total['warn']} warn / {total['info']} info"
    return summary + "\n\n" + "\n".join(lines).rstrip() + "\n"


def main():
    ap = argparse.ArgumentParser(description="Audit Claude Code skill(s) against best practices.")
    ap.add_argument("path", nargs="?", default=".", help="path to a single skill dir, or a parent dir containing many skills")
    ap.add_argument("--json", action="store_true", help="emit JSON instead of markdown")
    args = ap.parse_args()

    skill_dirs = find_skill_dirs(args.path)
    if not skill_dirs:
        print(f"no SKILL.md found under {args.path}", file=sys.stderr)
        sys.exit(2)

    results = [(d.name, audit_skill(d)) for d in skill_dirs]

    if args.json:
        import json
        print(json.dumps([{"skill": n, "findings": f} for n, f in results], indent=2, ensure_ascii=False))
    else:
        print(format_report(results))

    any_fail = any(any(x["level"] == "fail" for x in f) for _, f in results)
    sys.exit(1 if any_fail else 0)


if __name__ == "__main__":
    main()
