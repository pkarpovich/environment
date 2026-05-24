#!/usr/bin/env python3
"""Vendor Claude Code plugins from one CC profile into another via symlinks.

The work profile (CLAUDE_CONFIG_DIR=~/.claude-work) does not allow installing
plugins outside an allowlist. This tool copies (via symlinks) skills, agents,
commands, and hooks from already-installed plugins in ~/.claude into
~/.claude-work, so the same skills are available without going through the
plugin allowlist mechanism.

Manifest format (~/.claude-work/cc-vendor.txt):
    <marketplace>/<plugin>             - vendor the whole plugin
    <marketplace>/<plugin>:s1,s2,s3    - vendor only listed skills

Source: ~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/
        Version is read from ~/.claude/plugins/installed_plugins.json
        (i.e. always the version currently active in the personal profile).

Outputs:
    ~/.claude-work/skills/<skill>          -> symlink to plugin skill dir
    ~/.claude-work/agents/<name>.md        -> symlink to plugin agent file
    ~/.claude-work/commands/<name>.md      -> symlink to plugin command file
    ~/.claude-work/settings.local.json     -> generated, merged plugin hooks
                                              with ${CLAUDE_PLUGIN_ROOT} and
                                              ${CLAUDE_PLUGIN_DATA} expanded
    ~/.claude-work/.vendored-data/<plugin> -> CLAUDE_PLUGIN_DATA replacement
    ~/.claude-work/.vendored-state.json    -> what we created, for `clean`
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
PERSONAL_CC = HOME / ".claude"
WORK_CC = HOME / ".claude-work"
CACHE = PERSONAL_CC / "plugins" / "cache"
INSTALLED = PERSONAL_CC / "plugins" / "installed_plugins.json"
MANIFEST = WORK_CC / "cc-vendor.txt"
STATE = WORK_CC / ".vendored-state.json"
SETTINGS_LOCAL = WORK_CC / "settings.local.json"
DATA_ROOT = WORK_CC / ".vendored-data"

SUBDIRS_WITH_FILES = [("agents", ".md"), ("commands", ".md")]


def read_manifest() -> list[tuple[str, list[str] | None]]:
    if not MANIFEST.exists():
        return []
    entries: list[tuple[str, list[str] | None]] = []
    for raw in MANIFEST.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if ":" in line:
            plugin, skills_str = line.split(":", 1)
            skills: list[str] | None = [s.strip() for s in skills_str.split(",") if s.strip()]
        else:
            plugin, skills = line, None
        entries.append((plugin.strip(), skills))
    return entries


def write_manifest(plugins: list[str]) -> None:
    header = [
        "# vendored plugins for ~/.claude-work",
        "# format: <marketplace>/<plugin>          - whole plugin",
        "#         <marketplace>/<plugin>:s1,s2    - selected skills only",
        "",
    ]
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text("\n".join(header + plugins) + "\n")


def read_installed() -> dict:
    if not INSTALLED.exists():
        return {}
    return json.loads(INSTALLED.read_text()).get("plugins", {})


def installed_key(marketplace_plugin: str) -> str | None:
    if "/" not in marketplace_plugin:
        return None
    marketplace, plugin = marketplace_plugin.split("/", 1)
    return f"{plugin}@{marketplace}"


def plugin_source(marketplace_plugin: str) -> Path | None:
    """Find the cache directory for the active version of a plugin."""
    key = installed_key(marketplace_plugin)
    if key is None:
        return None
    entries = read_installed().get(key, [])
    if not entries:
        return None
    path = Path(entries[0]["installPath"])
    return path if path.exists() else None


def discover_available() -> list[str]:
    """All installed plugins as 'marketplace/plugin'."""
    result = []
    for key in read_installed():
        if "@" not in key:
            continue
        plugin, marketplace = key.split("@", 1)
        result.append(f"{marketplace}/{plugin}")
    return sorted(result)


def read_plugin_manifest(source: Path) -> dict:
    for candidate in (source / ".claude-plugin" / "plugin.json", source / "claude-code.json"):
        if candidate.exists():
            try:
                return json.loads(candidate.read_text())
            except json.JSONDecodeError:
                pass
    return {}


def resolve_subdir(source: Path, manifest: dict, key: str) -> Path:
    val = manifest.get(key)
    if isinstance(val, str):
        rel = val[2:] if val.startswith("./") else val
        return source / rel
    return source / key


def list_skills(skills_dir: Path) -> list[str]:
    if not skills_dir.exists():
        return []
    return sorted(p.name for p in skills_dir.iterdir() if p.is_dir())


def expand_vars(obj, plugin_root: Path, plugin_data: Path):
    """Recursively replace ${CLAUDE_PLUGIN_ROOT} and ${CLAUDE_PLUGIN_DATA}."""
    if isinstance(obj, str):
        return obj.replace("${CLAUDE_PLUGIN_ROOT}", str(plugin_root)).replace(
            "${CLAUDE_PLUGIN_DATA}", str(plugin_data)
        )
    if isinstance(obj, dict):
        return {k: expand_vars(v, plugin_root, plugin_data) for k, v in obj.items()}
    if isinstance(obj, list):
        return [expand_vars(x, plugin_root, plugin_data) for x in obj]
    return obj


def read_state() -> dict:
    if not STATE.exists():
        return {"links": [], "data_dirs": [], "settings_hash": None}
    return json.loads(STATE.read_text())


def write_state(state: dict) -> None:
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(state, indent=2) + "\n")


def file_hash(path: Path) -> str | None:
    if not path.exists():
        return None
    return hashlib.sha256(path.read_bytes()).hexdigest()


def create_symlink(link: Path, target: Path) -> bool:
    link.parent.mkdir(parents=True, exist_ok=True)
    if link.is_symlink():
        link.unlink()
    elif link.exists():
        print(f"    WARN: {link} exists as a real file/dir, skipping", file=sys.stderr)
        return False
    link.symlink_to(target)
    return True


def merge_hooks(dest: dict, src: dict) -> None:
    for event, items in src.items():
        dest.setdefault(event, []).extend(items)


def data_dir_for(plugin: str) -> Path:
    return DATA_ROOT / plugin.replace("/", "__")


# Subcommands ----------------------------------------------------------------


def cmd_status(_args) -> int:
    entries = read_manifest()
    state = read_state()
    print(f"manifest: {MANIFEST}")
    if entries:
        for plugin, skills in entries:
            src = plugin_source(plugin)
            mark = "ok" if src else "MISSING"
            extra = f" :{','.join(skills)}" if skills else ""
            ver = f" (v{src.name})" if src else ""
            print(f"  [{mark}] {plugin}{extra}{ver}")
    else:
        print("  (empty)")
    print()
    print(f"state: {STATE}")
    links = state.get("links", [])
    print(f"  symlinks: {len(links)}")
    broken = [l for l in links if not Path(l).is_symlink() or not Path(l).exists()]
    if broken:
        print(f"  BROKEN: {len(broken)} (run `cc-vendor apply` to refresh)")
        for b in broken[:5]:
            print(f"    {b}")
        if len(broken) > 5:
            print(f"    ... and {len(broken) - 5} more")
    if SETTINGS_LOCAL.exists():
        recorded = state.get("settings_hash")
        current = file_hash(SETTINGS_LOCAL)
        if recorded and recorded == current:
            print(f"  settings.local.json: managed (in sync)")
        elif recorded:
            print(f"  settings.local.json: MODIFIED outside this tool")
        else:
            print(f"  settings.local.json: present, not managed by us")
    return 0


def cmd_pick(_args) -> int:
    if not shutil.which("fzf"):
        print("error: fzf not installed", file=sys.stderr)
        return 1
    available = discover_available()
    if not available:
        print("error: no installed plugins found in personal profile", file=sys.stderr)
        return 1
    current = {p for p, _ in read_manifest()}
    lines = [f"{'*' if p in current else ' '} {p}" for p in available]
    header = "TAB to toggle, ENTER to confirm. Lines marked * are currently in the manifest."
    result = subprocess.run(
        ["fzf", "--multi", "--header", header, "--bind", "tab:toggle+down"],
        input="\n".join(lines),
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print("cancelled")
        return 0
    selected = [line[2:].strip() for line in result.stdout.splitlines() if line.strip()]
    write_manifest(selected)
    print(f"manifest updated: {len(selected)} plugins")
    print(f"  next: cc-vendor apply")
    return 0


def cmd_apply(_args) -> int:
    entries = read_manifest()
    if not entries:
        print("manifest empty - nothing to do")
        return 0

    state = read_state()
    if SETTINGS_LOCAL.exists():
        recorded = state.get("settings_hash")
        current = file_hash(SETTINGS_LOCAL)
        if recorded is not None and recorded != current:
            print(
                f"ERROR: {SETTINGS_LOCAL} was modified outside cc-vendor.\n"
                f"Move it aside or run `cc-vendor clean` (which keeps the file if modified) and retry.",
                file=sys.stderr,
            )
            return 1
        if recorded is None:
            print(
                f"ERROR: {SETTINGS_LOCAL} exists but was not created by cc-vendor.\n"
                f"Remove or rename it, then retry.",
                file=sys.stderr,
            )
            return 1

    for link_str in state.get("links", []):
        p = Path(link_str)
        if p.is_symlink():
            p.unlink()

    new_links: list[str] = []
    new_data_dirs: list[str] = []
    all_hooks: dict = {}

    for plugin, selected_skills in entries:
        source = plugin_source(plugin)
        if source is None:
            print(f"  skip {plugin}: not installed in personal profile", file=sys.stderr)
            continue
        print(f"  vendor {plugin} v{source.name}")

        manifest = read_plugin_manifest(source)
        skills_dir = resolve_subdir(source, manifest, "skills")
        available_skills = list_skills(skills_dir)
        target_skills = selected_skills if selected_skills is not None else available_skills
        for skill in target_skills:
            if skill not in available_skills:
                print(f"    skip skill {skill}: not in plugin", file=sys.stderr)
                continue
            link = WORK_CC / "skills" / skill
            if create_symlink(link, skills_dir / skill):
                new_links.append(str(link))

        for sub, ext in SUBDIRS_WITH_FILES:
            d = resolve_subdir(source, manifest, sub)
            if not d.exists():
                continue
            for item in sorted(d.iterdir()):
                if not (item.is_file() and item.suffix == ext):
                    continue
                link = WORK_CC / sub / item.name
                if create_symlink(link, item):
                    new_links.append(str(link))

        hooks_json = source / "hooks" / "hooks.json"
        if hooks_json.exists():
            plugin_data = data_dir_for(plugin)
            plugin_data.mkdir(parents=True, exist_ok=True)
            new_data_dirs.append(str(plugin_data))
            try:
                data = json.loads(hooks_json.read_text())
            except json.JSONDecodeError as e:
                print(f"    WARN: failed to parse {hooks_json}: {e}", file=sys.stderr)
                continue
            expanded = expand_vars(data, source, plugin_data)
            merge_hooks(all_hooks, expanded.get("hooks", {}))

    settings_hash: str | None = None
    if all_hooks:
        SETTINGS_LOCAL.parent.mkdir(parents=True, exist_ok=True)
        SETTINGS_LOCAL.write_text(json.dumps({"hooks": all_hooks}, indent=2) + "\n")
        settings_hash = file_hash(SETTINGS_LOCAL)
    else:
        if (
            SETTINGS_LOCAL.exists()
            and state.get("settings_hash") is not None
            and state.get("settings_hash") == file_hash(SETTINGS_LOCAL)
        ):
            SETTINGS_LOCAL.unlink()

    write_state({
        "links": new_links,
        "data_dirs": new_data_dirs,
        "settings_hash": settings_hash,
    })
    print(f"done: {len(new_links)} symlinks, hooks={'yes' if all_hooks else 'no'}")
    if all_hooks:
        print("  restart Claude Code in the work profile to pick up new hooks")
    return 0


def cmd_clean(_args) -> int:
    state = read_state()
    removed_links = 0
    for link_str in state.get("links", []):
        p = Path(link_str)
        if p.is_symlink():
            p.unlink()
            removed_links += 1

    settings_removed = False
    if SETTINGS_LOCAL.exists() and state.get("settings_hash"):
        if file_hash(SETTINGS_LOCAL) == state["settings_hash"]:
            SETTINGS_LOCAL.unlink()
            settings_removed = True
        else:
            print(
                f"WARN: {SETTINGS_LOCAL} was modified outside cc-vendor, not removing",
                file=sys.stderr,
            )

    for d_str in state.get("data_dirs", []):
        d = Path(d_str)
        if d.is_dir():
            shutil.rmtree(d)
    if DATA_ROOT.is_dir() and not any(DATA_ROOT.iterdir()):
        DATA_ROOT.rmdir()

    if STATE.exists():
        STATE.unlink()

    print(f"removed {removed_links} symlinks" + (", settings.local.json" if settings_removed else ""))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="cc-vendor",
        description="Vendor CC plugins from the personal profile into ~/.claude-work.",
    )
    sub = parser.add_subparsers(dest="cmd")
    sub.add_parser("status", help="show manifest and current state (default)")
    sub.add_parser("pick", help="interactively edit the manifest via fzf")
    sub.add_parser("apply", help="materialize manifest: symlinks + hooks")
    sub.add_parser("clean", help="remove everything we created")
    args = parser.parse_args()

    handlers = {"status": cmd_status, "pick": cmd_pick, "apply": cmd_apply, "clean": cmd_clean}
    return handlers[args.cmd or "status"](args)


if __name__ == "__main__":
    sys.exit(main())
