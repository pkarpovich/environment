function ccz --description "mirror agterm Claude sessions into zellij tabs (single-client: kills agterm-side TUIs first). Inside zellij - current session; outside - the single live one (or: ccz <session>). -o/--one: pick a single agterm session, mirror it into its own zellij session (name printed on stdout) and leave the rest running on the Mac"
    argparse o/one -- $argv; or return 1

    if not command -q agtermctl; or not command -q jq
        echo "ccz: needs agtermctl and jq (run on the agterm Mac)" >&2
        return 1
    end
    if set -q _flag_one; and not command -q sk
        echo "ccz: --one needs sk" >&2
        return 1
    end

    set -l map ~/.local/state/agterm/cc-map
    set -l tree (agtermctl tree --json | string collect)

    set -l mapped
    for f in $map/*
        test -f "$f"; and set -a mapped (path basename $f)
    end
    if test (count $mapped) -eq 0
        echo "ccz: no mapped agterm sessions to mirror" >&2
        return 1
    end

    # id + label in sidebar order; the leading number is the session's position,
    # the same one cmd+shift+<N> jumps to on the Mac (names alone repeat - a fork
    # and its parent share the Claude title)
    set -l mapped_json (printf '%s\n' $mapped | jq -Rsc 'split("\n") | map(select(length > 0))')
    set -l rows (printf '%s' $tree | jq -r --argjson mapped $mapped_json '
        [.result.tree.workspaces[] | .name as $w | .sessions[] | {id, name, ws: $w}]
        | to_entries
        | map(select(.value.id as $i | $mapped | index($i)))
        | .[] | "\(.value.id)\t\(.key + 1)  \(.value.name)  [\(.value.ws)]"')
    if test (count $rows) -eq 0
        echo "ccz: no mapped agterm sessions to mirror" >&2
        return 1
    end

    set -l entries
    for r in $rows
        set -a entries (string split -f1 \t $r)
    end

    if set -q _flag_one
        set -l picked (printf '%s\n' $rows | sk --height 50% --border --reverse --prompt="session> " --delimiter=\t --with-nth=2 | string split -f1 \t)
        test -n "$picked"; or return 1
        set entries $picked
    end

    set -l alive (zellij list-sessions --no-formatting 2>/dev/null | string match -rv 'EXITED' | string replace -r ' .*$' '')

    # ZELLIJ/ZELLIJ_SESSION_NAME can be inherited rather than real: agterm passes
    # its own environment to every session shell, so an agterm launched from a
    # zellij pane makes every pane under it look like it is inside zellij. Trust
    # the vars only when that session is actually alive.
    set -l zj zellij
    set -l zname $ZELLIJ_SESSION_NAME
    set -l created ""
    set -l inside 0
    if set -q ZELLIJ; and contains -- "$zname" $alive
        set inside 1
    end

    if test $inside -eq 0
        if test (count $argv) -ge 1
            set zname $argv[1]
        else if set -q _flag_one
            # one agent, one zellij session of its own: <project>-<id prefix>,
            # stable across trips so the next connect reattaches the same one
            set -l dir (jq -r '.cwd // empty' $map/$entries[1])
            test -n "$dir"; or set dir $HOME
            set created (string replace -ra '[^a-z0-9_.-]' '-' (string lower (path basename $dir)))-(string lower (string sub -l 4 $entries[1]))
            set zname $created
            zellij attach --create-background $created >/dev/null 2>&1
        else
            if test (count $alive) -eq 0
                echo "ccz: no live zellij session to fill - start/attach one first" >&2
                return 1
            end
            if test (count $alive) -gt 1
                echo "ccz: several zellij sessions ("(string join ', ' $alive)") - pick one: ccz <session>" >&2
                return 1
            end
            set zname $alive[1]
        end
        set zj zellij --session $zname
    end

    if set -q _flag_one
        # park only when that session really holds a live Claude on the Mac
        set -l fg (printf '%s' $tree | jq -r --arg id "$entries[1]" '[.result.tree.workspaces[].sessions[]] | .[] | select(.id == $id) | (.foreground // []) | join(" ")')
        if string match -q '*claude*' -- $fg
            ~/.config/agterm/scripts/cc-park.sh agterm $entries[1]; or return 1
        end
    else
        ~/.config/agterm/scripts/cc-park.sh agterm
        # replacing every mirrored session: drop all Claude tabs in one pass.
        # The flags stay in the pane's argv, unlike the conversation id, which a
        # resumed Claude drops when it rewrites its process title
        for t in ($zj action dump-layout 2>/dev/null | awk '
            /^ *tab / { if (t != "" && has) print t; t = ""; if (match($0, /name="[^"]*"/)) t = substr($0, RSTART+6, RLENGTH-7); has = 0 }
            index($0, "--enable-auto-mode") { has = 1 }
            END { if (t != "" && has) print t }')
            __ccz_close_tab "$t" $zj
        end
    end

    for id in $entries
        set -l f $map/$id
        set -l line (printf '%s' $tree | jq -r --arg id "$id" '[.result.tree.workspaces[].sessions[]] | .[] | select(.id == $id) | .name + "\t" + (.cwd // "")')
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

        set -l tabs ($zj action dump-layout 2>/dev/null | awk '/^ *tab / { if (match($0, /name="[^"]*"/)) print substr($0, RSTART+6, RLENGTH-7) }')

        # a tab this session already mirrors into is recycled, so re-picking a
        # session replaces its tab instead of opening a second client on the
        # same conversation (which makes Claude kill one of them)
        set -l prev (jq -r --arg z "$zname" 'select(.zsession == $z) | .ztab // empty' $f)
        if test -n "$prev"; and contains -- "$prev" $tabs
            __ccz_close_tab "$prev" $zj
            set tabs (string match -v -- "$prev" $tabs)
        end

        # tab names come from the Claude title and repeat across sessions (a fork
        # and its parent, two tabs in one project) - go-to-tab-name would then
        # target the wrong tab, so collisions get the session id as a suffix
        set -l tabname $name
        contains -- "$tabname" $tabs; and set tabname "$name "(string lower (string sub -l 4 $id))

        $zj action new-tab --name "$tabname" --cwd "$cwd" -- fish -c "cd "(string escape -- $cwd)"; and $cmd" >/dev/null

        set -l tmp (mktemp $map/.tmp.XXXXXX)
        and jq --arg z "$zname" --arg t "$tabname" '.zsession = $z | .ztab = $t' $f > $tmp
        and mv -f $tmp $f
    end

    test -n "$created"; and echo $created
    return 0
end
