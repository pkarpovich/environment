---
name: defuddle
description: Convert any web article, blog post, documentation page, or release-notes URL into clean markdown with a YAML metadata block (title, author, site, published date, source URL, word count) via the public defuddle.md HTTP API — just `curl https://defuddle.md/<url-without-scheme>`. Use this INSTEAD of WebFetch whenever the user shares a URL that points at readable prose, even if they did not explicitly say "extract", "clean up", or "summarize" — e.g. "посмотри https://...", "что в этой статье", "открой <url>", "read this blog post", a bare URL pasted into chat, or "what does <author> say about X" with a link. WebFetch summarizes the page through an LLM and drops the metadata, so quotes drift and the publication date is lost; defuddle returns the article text verbatim, which matters when the user wants to discuss, cite, or archive what was written. SKIP this skill (use WebFetch or another tool instead) when the URL ends in `.md` / `.txt` (already plain), `.pdf` / `.png` / other binary, is a JS-rendered SPA or dashboard (defuddle cannot run JS), is behind authentication or a Cloudflare interstitial, points at localhost or a private network, or is a GitHub blob URL (prefer `gh api` for those).
allowed-tools: Bash(curl:*)
---

# defuddle

Public HTTP service ([defuddle.md](https://defuddle.md/)) that runs the [defuddle](https://github.com/kepano/defuddle) extractor against a remote URL and returns clean markdown with a YAML frontmatter block.

## Usage

Strip the scheme from the URL and prepend `defuddle.md/`:

```bash
curl -fsSL "https://defuddle.md/<host>/<path>"
```

Example:

```bash
curl -fsSL "https://defuddle.md/blog.cohix.network/code-agents-are-bad-at-software-architecture-for-now/"
```

Returns:

```
---
title: "Code agents are bad at Software Architecture"
author: "Connor Hicks"
published: 2026-05-04T15:46:55.000Z
source: "https://blog.cohix.network/..."
word_count: 1333
---

<body of the article as markdown>
```

The frontmatter typically includes `title`, `author`, `site`, `published`, `source`, `domain`, `language`, `description`, `word_count` — fields the upstream HTML did not expose are simply absent, so do not rely on any one being present beyond `title` and `source`.

## Why prefer this over WebFetch

WebFetch fetches the page and then asks an internal model to answer a prompt about it — so the output is a paraphrase, not the article. That is fine when you only need "what is this page about", but it is wrong when:

- You need to quote the author verbatim.
- The publication date matters (e.g. checking whether a claim is recent).
- The user wants to archive or save the article (markdown + frontmatter is the right shape for Obsidian, a note vault, or a podcast prep folder).
- The page is long and you want to scan headings / structure rather than read a summary.

In those cases reach for defuddle first.

## When defuddle will not help

Defuddle is a server-side HTML extractor, not a browser. It cannot deal with:

- **JS-rendered pages**: a Next.js app without SSR, a React SPA, a dashboard. The response will be near-empty or a `<div id="root">` shell. Switch to `agent-browser open <url> && agent-browser snapshot -i` (or `agent-browser get text body`).
- **Authentication walls**: the server will return a login page instead of the article.
- **Cloudflare / bot-protection interstitials**: tell the user; do not retry in a tight loop.
- **PDFs and other binary content**: download directly with `curl -O` and feed to the right tool.
- **Already-markdown URLs** (`.md`, raw GitHub, gist raw, etc.): `WebFetch` is enough — defuddle would only re-wrap it.
- **GitHub source pages**: use `gh api` or `gh search` instead — those carry richer metadata than the rendered HTML.

If `curl` returns 4xx/5xx, fall back to `WebFetch` on the original URL and say one short sentence about why defuddle did not work, so the user can pattern-match next time.

## Output handling

By default just read the response into context and continue the conversation — the user almost always wants you to discuss or summarize the article, not save it. If the user asks to save / archive / "положи в obsidian" / similar, write the response to a file under the relevant project directory (`.local/articles/<slug>.md` is a reasonable default for ad-hoc storage) and report the path.

## Token math

For typical articles defuddle output is ~30-50% of the raw HTML and similar in size to a WebFetch summary — but the text is unmodified, so quotes survive.
