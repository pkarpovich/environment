# prompt-evals

Measured iteration for the prompts in `../dotfiles/tuna-prompts`, following Anthropic's
[prompt evaluations course](https://github.com/anthropics/courses/tree/master/prompt_evaluations):
concrete grading criteria, a fixed set of inputs, and a score you can compare between two versions
of a prompt instead of eyeballing the output.

Runner is [promptfoo](https://promptfoo.dev), which the course uses from lesson 5 on.

## Running

```fish
cd prompt-evals
mise run eval          # score every prompt version against the corpus
mise run view          # browse the run, diff the versions side by side
```

The API key goes in `prompt-evals/.env`, which mise loads and redacts:

```fish
echo 'ANTHROPIC_API_KEY=sk-ant-...' > prompt-evals/.env
```

Gitignored, together with every `cases.yaml`.

promptfoo runs through `npx` rather than as a mise tool: mise's npm backend refuses to install it,
because a transitive dependency (`@smithy/node-http-handler`) publishes 4.11.0 without the trust
evidence 4.10.0 had. The version is pinned in `.mise.toml` under `[vars]`.

## fix-ru

Every case runs through both versions of the prompt:

- `baseline` - `fix-ru/versions/baseline.md`, frozen. Replace it when a new version wins.
- `current` - `../dotfiles/tuna-prompts/fix-ru.md`, the live prompt Tuna loads.

`render.js` strips the YAML front matter and substitutes `{{input}}`, so the eval sends the model
exactly what Tuna sends it. The provider is `claude-sonnet-5` at temperature 0, matching
`dotfiles/tuna/config.toml`; grading runs on `claude-opus-5` so the model under test is not its own
judge.

### What gets graded

The four house-style rules are mechanical, so `asserts.js` checks them in code - no model, no
flakiness: no `ё`, no em/en dash, no period ending the message, first character keeps its case.
`textOnly` catches the other structural failure, an answer wrapped in quotes or prefaced with
"Вот исправленный текст".

The judgement call - did it repair the listed errors and leave everything else alone - goes to an
`llm-rubric` that receives the original message and the specific list of errors that case is about.
Six cases are already correct and assert character-identical output; rewriting valid text is the
failure mode this prompt exists to avoid, and it is the one a rubric alone tends to forgive.

### The corpus

`cases.yaml` comes out of Tuna's own clipboard history,
`~/Library/Application Support/Tuna/ClipboardHistory/history.sqlite` - the text that actually passes
through this prompt, with its real typos rather than invented ones. `payload_data` is JSON,
`{"text": ..., "type": "text"}`. Entries carrying "ё" or an em dash are worth skipping: neither is in
the author's own typing, so they mark text pasted from a model or another source.

The clipboard also holds a month of everything else copied on this machine, so curating by hand is
the point rather than an inconvenience. `cases.yaml` stays out of git; only the harness is committed.

Each case carries `must_fix`, a plain-language list of what that message got wrong, and a `must_fix`
starting with "nothing" also turns on a character-identity assert. Writing those lines is the actual
work: they turn "the output looks fine" into a criterion the grader can fail. One case is a real
before/after pair recovered from the clipboard and asserts an exact expected output.

## The loop

1. Run the eval, read the failures rather than the total.
2. Change **one** thing in the prompt.
3. Re-run. Keep the change if the score rose, revert if it did not.

Bundling two changes costs you the ability to attribute the result to either one.
