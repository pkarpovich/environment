#!/usr/bin/env python3
"""context7: fetch up-to-date library documentation via the Context7 MCP server."""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request

MCP_URL = "https://mcp.context7.com/mcp"


def call_tool(tool_name: str, arguments: dict, timeout: int) -> dict:
    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {"name": tool_name, "arguments": arguments},
    }
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
    }
    api_key = os.environ.get("CONTEXT7_API_KEY")
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"

    req = urllib.request.Request(
        MCP_URL,
        data=json.dumps(payload).encode(),
        headers=headers,
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


def run(tool_name: str, arguments: dict, output: str, timeout: int) -> int:
    try:
        response = call_tool(tool_name, arguments, timeout)
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

    if output == "raw":
        print(json.dumps(response))
    elif output == "json":
        print(json.dumps(result, indent=2))
    else:
        print(format_text(result))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="ctx7",
        description="Query Context7 for up-to-date library documentation.",
    )
    parser.add_argument(
        "-o",
        "--output",
        default="text",
        choices=["text", "json", "raw"],
        help="output format (default: text)",
    )
    parser.add_argument(
        "-t",
        "--timeout",
        type=int,
        default=30,
        help="request timeout in seconds (default: 30)",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    resolve = sub.add_parser(
        "resolve",
        help="Resolve a library name to a Context7 library ID",
    )
    resolve.add_argument("library_name", help="library name (e.g. 'Next.js', 'Anthropic SDK')")
    resolve.add_argument("query", help="the question or task to rank libraries by")

    docs = sub.add_parser(
        "docs",
        help="Fetch documentation for a Context7 library ID",
    )
    docs.add_argument("library_id", help="e.g. '/vercel/next.js' or '/anthropics/anthropic-sdk-python'")
    docs.add_argument("query", help="specific question or topic to retrieve docs for")

    args = parser.parse_args()

    if args.cmd == "resolve":
        return run(
            "resolve-library-id",
            {"libraryName": args.library_name, "query": args.query},
            args.output,
            args.timeout,
        )
    if args.cmd == "docs":
        return run(
            "query-docs",
            {"libraryId": args.library_id, "query": args.query},
            args.output,
            args.timeout,
        )
    return 1


if __name__ == "__main__":
    sys.exit(main())
