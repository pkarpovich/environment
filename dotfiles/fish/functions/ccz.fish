function ccz --description "mirror agterm Claude sessions into zellij tabs (single-client: kills agterm-side TUIs first). Inside zellij - current session; outside - the single live one (or: ccz <session>)"
    if not command -q agtermctl; or not command -q jq
        echo "ccz: needs agtermctl and jq (run on the agterm Mac)" >&2
        return 1
    end

    set -l zj zellij
    if not set -q ZELLIJ
        set -l alive (zellij list-sessions --no-formatting 2>/dev/null | string match -rv 'EXITED' | string replace -r ' .*$' '')
        if test (count $alive) -eq 0
            echo "ccz: no live zellij session to fill - start/attach one first" >&2
            return 1
        end
        set -l target $alive[1]
        if test (count $argv) -ge 1
            set target $argv[1]
        else if test (count $alive) -gt 1
            echo "ccz: several zellij sessions ("(string join ', ' $alive)") - pick one: ccz <session>" >&2
            return 1
        end
        set zj zellij --session $target
    end

    set -l map ~/.local/state/agterm/cc-map
    set -l tree (agtermctl tree --json | string collect)

    ~/.config/agterm/scripts/cc-park.sh agterm

    set -l stale ($zj action dump-layout 2>/dev/null | awk '
        /^ *tab / { if (t != "" && has) print t; t = ""; if (match($0, /name="[^"]*"/)) t = substr($0, RSTART+6, RLENGTH-7); has = 0 }
        /--enable-auto-mode/ { has = 1 }
        END { if (t != "" && has) print t }')
    for t in $stale
        $zj action go-to-tab-name "$t"
        $zj action close-tab
    end

    for f in $map/*
        test -f "$f"; or continue
        set -l id (path basename $f)
        set -l line (printf '%s' $tree | jq -r --arg id "$id" '[.result.tree.workspaces[].sessions[]] | .[] | select(.id == $id) | .name + "\t" + (.cwd // "")')
        test -n "$line"; or continue
        set -l parts (string split \t $line)
        set -l name $parts[1]
        set -l cwd $parts[2]
        set -l conv (jq -r '.conv // empty' $f)
        test -n "$conv"; or continue

        set -l map_cwd (jq -r '.cwd // empty' $f)
        test -d "$map_cwd"; and set cwd $map_cwd
        test -d "$cwd"; or set cwd $HOME

        set -l cmd "CLAUDE_CODE_NO_FLICKER=1 claude --enable-auto-mode --resume $conv"
        if test (jq -r '.profile // "personal"' $f) = work
            set cmd "CLAUDE_CONFIG_DIR=~/.claude-work $cmd"
        end

        $zj action new-tab --name "$name" --cwd "$cwd" -- fish -c "cd "(string escape -- $cwd)"; and $cmd" >/dev/null
    end
end
