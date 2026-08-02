#!/opt/homebrew/bin/fish
# @agt.name Name this session from its transcript
# @agt.desc two or three words about the latest work; pins the label
# @agt.name Restore the live session title -- --restore
# @agt.desc drop the pinned name so Claude's own title comes back
#
# Label a session the way a person would label a tab: read its transcript through
# cc-map and ask a small model for two or three words.
#
# The name describes the LATEST work, not the whole session: a tab label answers
# "what is happening here", and a long session drifts - this one started as a
# tmux migration and is now naming sessions. Re-run it when the topic moves.
#
# Renaming pins the label, so Claude's live title stops reaching the sidebar.
# That is reversible: --restore sends an empty name and auto-titling resumes.
# --dry-run prints the candidates and changes nothing.
set -l AGTERMCTL /opt/homebrew/bin/agtermctl
set -l JQ /opt/homebrew/bin/jq
set -l CLAUDE ~/.local/bin/claude
# sonnet, not haiku as in the recap: naming is one short judgement call about
# what the work IS, and haiku picked the loudest recent topic rather than the
# subject. CC_NAME_MODEL overrides it for comparisons.
set -l MODEL claude-sonnet-5
test -n "$CC_NAME_MODEL"; and set MODEL $CC_NAME_MODEL
set -l MAX_DIGEST 60000   # the tail is what the name should describe
set -l TRIM 300

set -l dry 0
set -l restore 0
set -l sid ""
for a in $argv
    switch $a
        case --dry-run
            set dry 1
        case --restore
            set restore 1
        case '*'
            set sid $a
    end
end
test -n "$sid"; or set sid $AGT_SESSION_ID

function fail --argument-names msg dry
    if test "$dry" = 1
        echo $msg >&2
    else
        /opt/homebrew/bin/agtermctl notify $msg --title "Name session" >/dev/null 2>&1
    end
    exit 1
end

test -n "$sid"; or fail "no session to name" $dry

if test $restore -eq 1
    $AGTERMCTL session rename "" --target $sid >/dev/null 2>&1
    exit 0
end

set -l entry ~/.local/state/agterm/cc-map/$sid
test -f $entry; or fail "no cc-map entry for this session" $dry
set -l conv ($JQ -r '.conv // empty' $entry)
test -n "$conv"; or fail "cc-map entry carries no conversation id" $dry
set -l cwd ($JQ -r '.cwd // empty' $entry)

set -l base ~/.claude
test ($JQ -r '.profile // "personal"' $entry) = work; and set base ~/.claude-work
set -l transcript $base/projects/*/$conv.jsonl
test (count $transcript) -gt 0; or fail "no transcript on disk for $conv" $dry

# no timestamps here, unlike the recap: a label needs the subject, not the when
set -l digest ($JQ -rj --argjson trim $TRIM '
    def strip: gsub("(?s)<system-reminder>.*?</system-reminder>"; "")
             | gsub("^[[:space:]]+|[[:space:]]+$"; "");
    if .type=="user" and (.message.content|type=="string") then
        (.message.content|strip) as $t
        | if ($t|length) == 0 or ($t|startswith("[Request interrupted")) then empty
          else "USER: " + $t + "\n" end
    elif .type=="assistant" and (.message.content|type=="array") then
        ((.message.content | map(select(.type=="text").text) | join(" ") | strip)) as $t
        | if ($t|length) == 0 then empty else "CLAUDE: " + $t[0:$trim] + "\n" end
    else empty end
' $transcript[1] 2>&1 | string collect)
string match -qr '^jq: error' -- $digest; and fail "digest failed: $digest" $dry
test -n "$digest"; or fail "transcript has no readable conversation" $dry
set digest (printf '%s' $digest | tail -c $MAX_DIGEST | string collect)

# the model writes in the language of its instructions unless told which one, so
# the user's own lines decide it here
set -l user_text (printf '%s' $digest | grep '^USER: ' | string collect)
set -l cyr (printf '%s' $user_text | LC_ALL=C tr -cd '\320\321' | wc -c | string trim)
set -l lat (printf '%s' $user_text | LC_ALL=C tr -cd 'a-zA-Z' | wc -c | string trim)
set -l lang english
test $cyr -gt (math "$lat / 4"); and set lang russian

set -l schema '{"type":"object","properties":{
  "name":{"type":"string"},
  "alternatives":{"type":"array","maxItems":3,"items":{"type":"string"}}},
  "required":["name","alternatives"]}'

set -l prompt "Below is a condensed Claude Code session transcript (oldest first) from $cwd.
Label this terminal session the way a person labels a tab.

Rules:
- describe the work in the MOST RECENT prompts, not where the session started
- two or three words, lowercase, no punctuation, no quotes
- name the work, not the tool in general: \"tmux migration\", not \"terminal setup\"
- write in $lang, but keep product names, commands, paths and flags exactly as
  they are spelled in the transcript - never transliterate them into $lang
- one idea per label: name the single thing being worked on, never two topics
  glued together (\"session renaming\", not \"recap and session renaming\")
- \"alternatives\" holds up to three other candidates, same rules

Transcript:
"

set -l out (printf '%s%s' "$prompt" "$digest" | MAX_THINKING_TOKENS=0 $CLAUDE -p \
    --model $MODEL --safe-mode --no-session-persistence --tools "" \
    --system-prompt "You label development sessions. Two or three words, lowercase, no punctuation." \
    --json-schema "$schema" 2>&1 | string collect)

printf '%s' $out | $JQ -e '.name' >/dev/null 2>&1; or fail "unexpected response: $out" $dry
set -l name (printf '%s' $out | $JQ -r '.name')

if test $dry -eq 1
    set -l current ($AGTERMCTL tree --json | $JQ -r --arg id $sid '.result.tree.workspaces[].sessions[] | select(.id==$id) | .name')
    echo "сейчас:    $current"
    echo "предложит: $name"
    printf '%s' $out | $JQ -r '.alternatives[]?' | sed 's/^/  ещё:     /'
    exit 0
end

$AGTERMCTL session rename $name --target $sid >/dev/null 2>&1
