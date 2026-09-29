#!/opt/homebrew/bin/fish
# @agt.name Recap this Claude session
# @agt.desc what the agent has been working on, read from its transcript
#
# Ported from the cookbook's claude-recap rather than copied: the recipe is zsh,
# and it spends half its length guessing which transcript belongs to the pane -
# a status-line hook writing a pane map, plus a fallback that slugs the working
# directory and takes the newest file. We already know the answer. cc-map holds
# the conversation id and the profile for every agterm session, so the transcript
# is one lookup, exact even for a session that moved into a worktree.
#
# Two entry points, one file: with no arguments it opens an overlay over the
# session and re-runs itself inside it with --render, because an overlay pty
# inherits none of $AGT_* and none of the PATH (every binary below is absolute).

set -l AGTERMCTL /opt/homebrew/bin/agtermctl
set -l JQ /opt/homebrew/bin/jq
set -l CLAUDE ~/.local/bin/claude
set -l MODEL claude-haiku-4-5-20251001
set -l MAX_DIGEST 120000   # ~30k tokens of transcript handed to the model
set -l TRIM 400            # per-reply cut: the outcome without the reasoning

if test "$argv[1]" != --render
    set -l sid (test -n "$AGT_SESSION_ID"; and echo $AGT_SESSION_ID; or echo active)
    exec $AGTERMCTL session overlay open (status filename)" --render $sid" \
        --size-percent 80 --background-color "#2e3a2e" --target $sid
end

set -l sid $argv[2]
set -l entry ~/.local/state/agterm/cc-map/$sid

function fail --argument-names msg
    printf '\n  %s\n\n' $msg
    read -n 1 -P "Press any key to close..." -l _key
    exit 0
end

test -f "$entry"; or fail "no cc-map entry for this session - has claude ever run here?"
set -l conv ($JQ -r '.conv // empty' $entry)
set -l cwd ($JQ -r '.cwd // empty' $entry)
test -n "$conv"; or fail "cc-map entry carries no conversation id"

set -l base ~/.claude
test ($JQ -r '.profile // "personal"' $entry) = work; and set base ~/.claude-work
set -l transcript $base/projects/*/$conv.jsonl
test (count $transcript) -gt 0; or fail "no transcript on disk for $conv"
set transcript $transcript[1]

printf '  reading transcript ...\r'
set -l now (date +%s)

# an iso timestamp to a relative age, shared by the digest and the header
set -l ago_def 'def ago: (try ($now - (sub("\\\\.[0-9]+Z$"; "Z") | fromdateiso8601)) catch null)
       | if . == null then "?"
         elif . < 60 then "just now"
         elif . < 3600 then "\(./60|floor)m ago"
         elif . < 86400 then "\(./3600|floor)h ago"
         else "\(./86400|floor)d ago" end;'

# claude reports its own cwd, which is the worktree it moved into rather than the
# directory the pane sits in - report what the session actually worked on
set -l last_cwd ($JQ -r 'select(.cwd) | .cwd' $transcript 2>/dev/null | tail -1)
test -n "$last_cwd"; and set cwd $last_cwd
set -l last_ts ($JQ -r 'select(.timestamp) | .timestamp' $transcript 2>/dev/null | tail -1)
set -l last_age (printf '%s' "$last_ts" | $JQ -Rr --argjson now $now "$ago_def ago" 2>/dev/null)

# condense: human prompts in full, assistant replies trimmed, tool traffic dropped
set -l digest ($JQ -rj --argjson trim $TRIM --argjson now $now "$ago_def"'
    def strip: gsub("(?s)<system-reminder>.*?</system-reminder>"; "")
             | gsub("(?s)<local-command-caveat>.*?</local-command-caveat>"; "")
             | gsub("^[[:space:]]+|[[:space:]]+$"; "");

    if .type=="user" and (.message.content|type=="string") then
        (.message.content|strip) as $t
        | if ($t|length) == 0 or ($t|startswith("[Request interrupted")) then empty
          else "\n[" + (.timestamp // "" | ago) + "] USER: " + $t + "\n" end
    elif .type=="assistant" and (.message.content|type=="array") then
        ((.message.content | map(select(.type=="text").text) | join(" ") | strip)) as $t
        | if ($t|length) == 0 then empty else "CLAUDE: " + $t[0:$trim] + "\n" end
    else empty end
' $transcript 2>&1 | string collect)

string match -qr '^jq: error' -- $digest; and fail "digest failed: $digest"
test -n "$digest"; or fail "transcript has no readable conversation"
set digest (printf '%s' "$digest" | tail -c $MAX_DIGEST | string collect)

# The model follows the language of its own instructions unless told outright, so
# the language is decided here rather than asked for: count the user\'s own lines
# (cyrillic lead bytes against latin letters) and name the answer language below.
set -l user_text (printf '%s' "$digest" | grep '] USER: ' | string collect)
set -l cyr (printf '%s' "$user_text" | LC_ALL=C tr -cd '\320\321' | wc -c | string trim)
set -l lat (printf '%s' "$user_text" | LC_ALL=C tr -cd 'a-zA-Z' | wc -c | string trim)
set -l lang english
test $cyr -gt (math "$lat / 4"); and set lang russian

set -l prompt "Below is a condensed Claude Code session transcript (oldest first) from the directory $cwd.
Summarize what was worked on so the user can pick the task back up.

Each user prompt is tagged with how long ago it was sent, e.g. \"[3h ago] USER: ...\".

Rules:
- write \"title\" and \"detail\" in $lang. keep code, paths, commands, branch and product names
  exactly as they appear in the transcript
- split the session into distinct pieces of work, NEWEST FIRST, and cover ALL of it
- every distinct piece of work gets its own item - never merge unrelated work into one item, and
  never merge an investigation with the separate fix, review or merge that followed it
- 6 items maximum: if the session holds more, keep the 6 NEWEST and drop the older ones
- \"age\" is the tag of the most recent prompt in that group, without its square brackets
- \"title\" is at most 8 words
- \"detail\" is one sentence, at most 25 words, and never states the status
- \"status\" is judged from the WHOLE transcript, not from that group alone:
    done        the work reached a conclusion anywhere later - committed, merged, pushed, verified,
                or a question answered. ALSO done when a later group continues it and that concluded
    in progress no conclusion anywhere after it. normally only the newest group can be this
    blocked     it stopped on something unresolved and nothing after it resolved that
    abandoned   dropped with no conclusion and no later work on it
- when unsure between done and in progress, choose done
- \"age\" and \"status\" stay exactly as specified above, in english
- no markdown, no backticks, no quotes around names, lowercase prose throughout

Transcript:
"

set -l schema '{"type":"object","properties":{
  "items":{"type":"array","maxItems":6,"items":{"type":"object","properties":{
    "age":{"type":"string"},"title":{"type":"string"},"detail":{"type":"string"},
    "status":{"type":"string","enum":["done","in progress","blocked","abandoned"]}},
    "required":["age","title","detail","status"]}}},
  "required":["items"]}'

printf '  summarizing ...      \r'
# MAX_THINKING_TOKENS=0 turns a minute and a half into seconds - six one-line items
# need no reasoning budget. --safe-mode drops CLAUDE.md, rules, skills, plugins,
# hooks and MCP, leaving a few hundred tokens of harness context
set -l summary (printf '%s%s' "$prompt" "$digest" | MAX_THINKING_TOKENS=0 $CLAUDE -p \
    --model $MODEL --safe-mode --no-session-persistence --tools "" \
    --system-prompt "You summarize development session transcripts. Be terse and concrete. Write in lowercase prose. Write every title and detail in $lang. Never exceed a stated length limit." \
    --json-schema "$schema" 2>&1 | string collect)

printf '\033[2K'
printf '%s' "$summary" | $JQ -e '.items' >/dev/null 2>&1
or fail "unexpected response: $summary"

# tput, not $COLUMNS: fish only exports it for interactive shells, and the overlay
# runs this as a script - the panel is 80% of the pane, so the real width matters
set -l width (tput cols 2>/dev/null); or set width 100
test -n "$width"; or set width 100
test $width -gt 110; and set width 110
test $width -lt 46; and set width 46

clear
set_color --bold; printf '\n  claude recap'; set_color normal
set_color brblack; printf '  %s' $cwd
printf '  (last active %s)\n' $last_age
printf '  %s\n\n' (string repeat -n (math $width - 4) ─); set_color normal

# sorted here rather than trusting the model's "newest first" - it emits
# oldest-first often enough that the ordering has to be mechanical
printf '%s' "$summary" | $JQ -r '
    def secs: if test("just now") then 0
              elif test("[0-9]+ *m") then (capture("(?<n>[0-9]+) *m").n | tonumber) * 60
              elif test("[0-9]+ *h") then (capture("(?<n>[0-9]+) *h").n | tonumber) * 3600
              elif test("[0-9]+ *d") then (capture("(?<n>[0-9]+) *d").n | tonumber) * 86400
              else 9999999999 end;
    .items | map(.age |= gsub("[\\\\[\\\\]]"; "")) | sort_by(.age | secs)
    | .[] | [.age, .title, .detail, (.status // "")] | @tsv' |
while read -l -d \t age title detail st
    switch $st
        case done; set_color green
        case "in progress"; set_color yellow
        case blocked; set_color red
        case '*'; set_color brblack
    end
    printf '  %s' $age; set_color normal
    set_color brblack; printf ' — '; set_color --bold; printf '%s' $title; set_color normal
    switch $st
        case done; set_color green
        case "in progress"; set_color yellow
        case blocked; set_color red
        case '*'; set_color brblack
    end
    printf '  %s\n' $st; set_color normal
    printf '%s\n\n' $detail | fold -s -w (math $width - 8) | sed 's/^/      /'
end

read -n 1 -P "Press any key to close..." -l _key
