#!/usr/bin/env python3
"""gh-grep: search code across GitHub via the grep.app MCP server."""

import argparse
import json
import sys
import urllib.error
import urllib.request

MCP_URL = "https://mcp.grep.app/"


def call_search(arguments: dict, timeout: int) -> dict:
    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {"name": "searchGitHub", "arguments": arguments},
    }
    req = urllib.request.Request(
        MCP_URL,
        data=json.dumps(payload).encode(),
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        body = resp.read().decode("utf-8", errors="replace")

    for line in body.splitlines():
        if line.startswith("data:"):
            return json.loads(line[5:].strip())
    raise RuntimeError(f"unexpected response: {body[:500]}")


def format_text(result: dict) -> str:
    return "\n\n".join(c.get("text", "") for c in result.get("content", []))


def format_markdown(result: dict) -> str:
    blocks = []
    for c in result.get("content", []):
        blocks.append("```\n" + c.get("text", "") + "\n```")
    return "\n\n".join(blocks)


def build_arguments(args: argparse.Namespace) -> dict:
    out: dict = {"query": args.query}
    if args.match_case:
        out["matchCase"] = True
    if args.match_whole_words:
        out["matchWholeWords"] = True
    if args.use_regexp:
        out["useRegexp"] = True
    if args.repo:
        out["repo"] = args.repo
    if args.path:
        out["path"] = args.path
    if args.language:
        langs = []
        for item in args.language:
            langs.extend(s.strip() for s in item.split(",") if s.strip())
        if langs:
            out["language"] = langs
    return out


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="gh-grep",
        description="Search code across public GitHub repos via grep.app.",
    )
    parser.add_argument("--query", required=True, help="literal code pattern (required)")
    parser.add_argument("--match-case", action="store_true", help="case-sensitive search")
    parser.add_argument("--match-whole-words", action="store_true", help="match whole words only")
    parser.add_argument("--use-regexp", action="store_true", help="interpret query as regex")
    parser.add_argument("--repo", help="filter by repository (e.g. facebook/react)")
    parser.add_argument("--path", help="filter by file path")
    parser.add_argument(
        "--language",
        action="append",
        help="filter by language; repeat or comma-separate (e.g. TypeScript,TSX)",
    )
    parser.add_argument(
        "-o",
        "--output",
        default="text",
        choices=["text", "markdown", "json", "raw"],
        help="output format (default: text)",
    )
    parser.add_argument(
        "-t",
        "--timeout",
        type=int,
        default=30,
        help="request timeout in seconds (default: 30)",
    )
    args = parser.parse_args()

    try:
        response = call_search(build_arguments(args), args.timeout)
    except urllib.error.HTTPError as e:
        print(f"HTTP error {e.code}: {e.reason}", file=sys.stderr)
        return 2
    except urllib.error.URLError as e:
        print(f"URL error: {e.reason}", file=sys.stderr)
        return 2
    except (RuntimeError, json.JSONDecodeError) as e:
        print(f"protocol error: {e}", file=sys.stderr)
        return 2

    if response.get("error"):
        print(f"MCP error: {json.dumps(response['error'])}", file=sys.stderr)
        return 1

    result = response.get("result", {})

    if args.output == "raw":
        print(json.dumps(response))
    elif args.output == "json":
        print(json.dumps(result, indent=2))
    elif args.output == "markdown":
        print(format_markdown(result))
    else:
        print(format_text(result))

    return 0


if __name__ == "__main__":
    sys.exit(main())
