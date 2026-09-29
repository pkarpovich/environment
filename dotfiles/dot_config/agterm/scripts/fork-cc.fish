#!/opt/homebrew/bin/fish
# @agt.name Fork this Claude conversation
# @agt.desc new session below this one, both copies continue independently
# Fork this session's Claude conversation into a new session right after it:
# same directory, `claude --resume <conv> --fork-session`, so both copies continue
# independently. Needs a cc-map entry for the source session (written by cc-map-hook).
set -l AGTERMCTL /opt/homebrew/bin/agtermctl
set -l JQ /opt/homebrew/bin/jq
set -l MAP ~/.local/state/agterm/cc-map

set -l entry $MAP/$AGT_SESSION_ID
set -l conv ""
test -n "$AGT_SESSION_ID"; and test -f $entry; and set conv ($JQ -r '.conv // empty' $entry)
if test -z "$conv"
    $AGTERMCTL notify "no Claude conversation mapped to this session" --title fork-cc
    exit 0
end

set -l cwd ($JQ -r '.cwd // empty' $entry)
test -d "$cwd"; or set cwd $AGT_SESSION_PWD

# no --name: it would pin the label and block the live Claude title from
# ever showing; the auto name (basename, then the title) takes over instead
set -l new ($AGTERMCTL session new --cwd $cwd --after $AGT_SESSION_ID); or exit 1

set -l resume "CLAUDE_CODE_NO_FLICKER=1 claude --enable-auto-mode --resume $conv"
test ($JQ -r '.profile // "personal"' $entry) = work; and set resume "CLAUDE_CONFIG_DIR=~/.claude-work $resume"

# seed the new session's map entry and restore pin with the PARENT conversation:
# the fork's own transcript exists only after its first message, so until the
# cc-map hook re-points them a restart resumes the parent instead of replaying
# --fork-session (which mints a fresh copy on every launch)
set -l tmp (mktemp $MAP/.tmp.XXXXXX)
and $JQ --arg cwd $cwd '.cwd = $cwd | .ts = (now | floor)' $entry > $tmp
and mv -f $tmp $MAP/$new
$AGTERMCTL session restore "$resume" --target $new >/dev/null 2>&1

sleep 1.2
printf '%s\n' "$resume --fork-session" | $AGTERMCTL session type --stdin --target $new
