function claude --description "agterm-aware Claude launcher: tags a fresh run with an explicit session id so agterm restore can resume it; flips a replayed --session-id of an existing conversation back to --resume"
    if not set -q AGTERM_SESSION_ID; or test "$AGTERM_PANE" != left
        command claude $argv
        return
    end

    if test (count $argv) -ge 2; and test "$argv[1]" = --session-id
        set -l sid (string lower $argv[2])
        set -l files ~/.claude/projects/*/$sid.jsonl ~/.claude-work/projects/*/$sid.jsonl
        if test (count $files) -gt 0
            set -lx CLAUDE_CODE_NO_FLICKER 1
            string match -q '*/.claude-work/*' $files[1]; and set -lx CLAUDE_CONFIG_DIR ~/.claude-work
            command claude --resume $sid $argv[3..]
            return
        end
        command claude $argv
        return
    end

    # agterm Live mode replays a forked pane's captured argv after a reboot, and
    # `--resume <parent> --fork-session` then mints a new fork of the parent instead
    # of the conversation this pane had: resume what cc-map recorded for the pane
    if contains -- --fork-session $argv
        set -l entry ~/.local/state/agterm/cc-map/$AGTERM_SESSION_ID
        set -l conv (jq -r '.conv // empty' $entry 2>/dev/null)
        set -l i (contains -i -- --resume $argv)
        test -n "$i"; and set -l j (math $i + 1)
        if test -n "$conv"; and test -n "$j"; and test "$conv" != "$argv[$j]"
            and test (count ~/.claude/projects/*/$conv.jsonl ~/.claude-work/projects/*/$conv.jsonl) -gt 0
            set -l rest (string match -v -- --fork-session $argv)
            set rest[$j] $conv
            command claude $rest
            return
        end
    end

    for a in $argv
        switch $a
            case -r --resume --session-id '--resume=*' '--session-id=*' -c --continue -p --print -v --version -h --help
                command claude $argv
                return
            case mcp update doctor config install migrate-installer setup-token agents auth auto-mode gateway plugin plugins project
                command claude $argv
                return
        end
    end

    command claude --session-id (uuidgen | string lower) $argv
end
