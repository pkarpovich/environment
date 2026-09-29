function ccl --description "resume the Claude conversation recorded for the current agterm session (cc-map); falls back to the ccr picker"
    if not set -q AGTERM_SESSION_ID
        echo "ccl: not inside an agterm session" >&2
        return 1
    end

    set -l entry ~/.local/state/agterm/cc-map/$AGTERM_SESSION_ID
    set -l conv ""
    test -f $entry; and set conv (jq -r '.conv // empty' $entry)

    if test -z "$conv"
        echo "ccl: no recorded conversation for this session - opening the picker"
        ccr
        return
    end

    set -lx CLAUDE_CODE_NO_FLICKER 1
    test (jq -r '.profile // "personal"' $entry) = work; and set -lx CLAUDE_CONFIG_DIR ~/.claude-work
    claude --enable-auto-mode --resume $conv
end
