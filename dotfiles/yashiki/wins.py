#!/usr/bin/env python3

import json
import subprocess
import sys

TAGS = range(1, 11)
MODE_WIDTH = 9


def snapshot():
    proc = subprocess.Popen(
        ["yashiki", "subscribe", "--snapshot", "--filter", "window,display"],
        stdout=subprocess.PIPE,
        text=True,
    )
    try:
        line = proc.stdout.readline()
    finally:
        proc.kill()
        proc.wait()
    if not line.strip():
        print("wins: empty snapshot from yashiki", file=sys.stderr)
        sys.exit(1)
    return json.loads(line)


_layout_cache = {}


def layout_for(output_id, mask):
    if not mask:
        return "-"
    key = (output_id, mask)
    if key not in _layout_cache:
        try:
            r = subprocess.run(
                ["yashiki", "layout-get", "--tags", str(mask), "--output", str(output_id)],
                capture_output=True,
                text=True,
                timeout=2,
            )
            _layout_cache[key] = r.stdout.strip() or "-"
        except Exception:
            _layout_cache[key] = "-"
    return _layout_cache[key]


def short_display(name):
    if name.startswith("Built-in"):
        return "Built-in"
    return name.replace("DELL ", "")


def clean(text):
    return (text or "").strip("‎‏").strip()


def main():
    data = snapshot()
    displays = {d["id"]: d for d in data.get("displays", [])}
    focused_display = data.get("focused_display_id")

    rows = []
    for w in data.get("windows", []):
        out = w.get("output_id")
        mask = w.get("tags", 0)
        app = clean(w.get("app_name", "?"))
        title = clean(w.get("title"))
        marker = "*" if w.get("is_focused") else ""
        extra = []
        if w.get("is_floating"):
            extra.append("float")
        if w.get("is_fullscreen"):
            extra.append("fullscreen")
        if extra:
            title = f"{title} [{', '.join(extra)}]".strip()

        tags_on = [n for n in TAGS if mask & (1 << (n - 1))] or [0]
        for n in tags_on:
            bit = 1 << (n - 1) if n else 0
            rows.append({
                "dname": short_display(displays.get(out, {}).get("name", str(out))),
                "dfocused": out == focused_display,
                "tag": n,
                "mode": layout_for(out, bit),
                "marker": marker,
                "app": app,
                "title": title,
            })

    if not rows:
        print("no managed windows", file=sys.stderr)
        return

    rows.sort(key=lambda r: (not r["dfocused"], r["dname"], r["tag"], r["app"].lower(), r["title"].lower()))

    dw = max([len(r["dname"]) for r in rows] + [len("DISPLAY")])
    aw = max([len(r["app"]) for r in rows] + [len("APP")])

    print(f'{"DISPLAY":<{dw}}  {"TG":>2}  {"MODE":<{MODE_WIDTH}} {"F":<1} {"APP":<{aw}}  TITLE')
    for r in rows:
        tag = str(r["tag"]) if r["tag"] else "-"
        print(f'{r["dname"]:<{dw}}  {tag:>2}  {r["mode"]:<{MODE_WIDTH}} {r["marker"]:<1} {r["app"]:<{aw}}  {r["title"]}')


if __name__ == "__main__":
    main()
