---
name: defuddle
description: Turn a web article, blog post, documentation page or release notes into clean markdown with a YAML header (title, author, published date, source, word count) through the public defuddle.md API, one curl. Use instead of WebFetch whenever a URL to readable prose comes up, said or not: "open <url>", "what does this article say", a bare link in chat, "what does <author> say about X". The text comes back verbatim, so quotes and dates survive. Not for .md or .txt URLs, PDFs and other binaries, JS-rendered apps, pages behind a login or Cloudflare, localhost, or GitHub blob pages (gh api).
allowed-tools: Bash(curl:*)
---

# defuddle

[defuddle.md](https://defuddle.md/) runs the [defuddle](https://github.com/kepano/defuddle) extractor against a URL and returns markdown with a frontmatter block. WebFetch returns a paraphrase through a model, this returns the article.

## Usage

Strip the scheme and prepend `defuddle.md/`:

```bash
curl -fsSL "https://defuddle.md/blog.cohix.network/code-agents-are-bad-at-software-architecture-for-now/"
```

```
---
title: "Code agents are bad at Software Architecture"
author: "Connor Hicks"
published: 2026-05-04T15:46:55.000Z
source: "https://blog.cohix.network/..."
word_count: 1333
---

<article as markdown>
```

`title` and `source` are always present. `author`, `site`, `published`, `domain`, `language`, `description` and `word_count` appear when the page exposes them.

A page over a couple of thousand words goes to a file in the scratchpad first. Read its headings with `grep -n '^#'`, then the sections the question needs, not the whole page:

```bash
curl -fsSL "https://defuddle.md/<host>/<path>" -o <scratchpad>/<slug>.md && grep -n '^#' <scratchpad>/<slug>.md
```

The default is to read and discuss. On "save", "archive" or "put into Obsidian", the file goes under the project (`.local/articles/<slug>.md`) and the reply names the path.

## When it will not work

defuddle is a server-side HTML extractor, not a browser:

- A JS-rendered page (a Next.js app without SSR, a React SPA, a dashboard) comes back near-empty or as a `<div id="root">` shell. Use `agent-browser open <url> && agent-browser snapshot -i` instead.
- A login wall returns the login page.
- A Cloudflare or bot-protection interstitial: say so, no retry loop.
- PDFs and other binaries: `curl -O` and the right tool.
- Already-markdown URLs (`.md`, raw GitHub, raw gist): WebFetch, defuddle would only re-wrap it.
- GitHub source pages: `gh api` or `gh search`, they carry the metadata.

A 4xx or 5xx from curl: fall back to WebFetch on the original URL and say in one sentence why defuddle did not work.
