function ccm --description "mirror agterm Claude sessions into tmux windows (single-client: kills agterm-side TUIs first). Inside tmux - current session; outside - the single live one (or: ccm <session>). -o/--one: pick a single agterm session, mirror it into its own tmux session (name printed on stdout) and leave the rest running on the Mac"
    argparse o/one -- $argv; or return 1

    if not command -q agtermctl; or not command -q jq
        echo "ccm: needs agtermctl and jq (run on the agterm Mac)" >&2
        return 1
    end
    if set -q _flag_one; and not command -q sk
        echo "ccm: --one needs sk" >&2
        return 1
    end

    set -l map ~/.local/state/agterm/cc-map
    set -l tree (agtermctl tree --json | string collect)

    set -l mapped
    for f in $map/*
        test -f "$f"; and set -a mapped (path basename $f)
    end
    if test (count $mapped) -eq 0
        echo "ccm: no mapped agterm sessions to mirror" >&2
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
        echo "ccm: no mapped agterm sessions to mirror" >&2
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

    set -l alive (tmux list-sessions -F '#{session_name}' 2>/dev/null)

    # $TMUX can be inherited rather than real: agterm passes its own environment
    # to every session shell, so an agterm launched from a tmux pane makes every
    # pane under it look like it is inside tmux. Trust it only when the session
    # it names is actually alive.
    set -l sess ""
    set -q TMUX; and set sess (tmux display-message -p '#{session_name}' 2>/dev/null)
    set -l inside 0
    contains -- "$sess" $alive; and set inside 1

    set -l created ""
    set -l dir ""

    if test $inside -eq 0
        if test (count $argv) -ge 1
            set sess $argv[1]
        else if set -q _flag_one
            # one agent, one tmux session of its own: <project>-<id prefix>,
            # stable across trips so the next connect reattaches the same one
            set dir (jq -r '.cwd // empty' $map/$entries[1])
            test -d "$dir"; or set dir $HOME
            set created (string replace -ra '[^a-z0-9_.-]' '-' (string lower (path basename $dir)))-(string lower (string sub -l 4 $entries[1]))
            set sess $created
            if not contains -- "$created" $alive
                # the shell window a new session is born with is kept on
                # purpose. With only the mirrored window in it, the session dies
                # the moment that window goes - recycled on the next --one, or
                # closed when Claude exits - and its death takes the tmux server,
                # the attached client and the terminal tab it lives in with it.
                tmux new-session -d -s $created -n shell -c $dir >/dev/null 2>&1
            end
        else
            if test (count $alive) -eq 0
                echo "ccm: no live tmux session to fill - start/attach one first" >&2
                return 1
            end
            if test (count $alive) -gt 1
                echo "ccm: several tmux sessions ("(string join ', ' $alive)") - pick one: ccm <session>" >&2
                return 1
            end
            set sess $alive[1]
        end
    end

    if set -q _flag_one
        # park only when that session really holds a live Claude on the Mac
        set -l fg (printf '%s' $tree | jq -r --arg id "$entries[1]" '[.result.tree.workspaces[].sessions[]] | .[] | select(.id == $id) | (.foreground // []) | join(" ")')
        if string match -q '*claude*' -- $fg
            ~/.config/agterm/scripts/cc-park.fish agterm $entries[1]; or return 1
        end
    else
        ~/.config/agterm/scripts/cc-park.fish agterm
        # replacing every mirrored session: drop all Claude windows in one pass.
        # The flags stay in the window's start command, unlike the conversation
        # id, which a resumed Claude drops when it rewrites its process title
        for line in (tmux list-panes -s -t $sess -F '#{window_id}|#{pane_start_command}' 2>/dev/null)
            string match -q '*--enable-auto-mode*' -- $line; or continue
            tmux kill-window -t (string split -m1 -f1 '|' -- $line) >/dev/null 2>&1
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

        # a window this session already mirrors into is recycled, so re-picking a
        # session replaces its window instead of opening a second client on the
        # same conversation (which makes Claude kill one of them). Window ids are
        # unique server-wide and never reused, so this targets exactly that one.
        set -l prev (jq -r --arg s "$sess" 'select(.tsession == $s) | .twindow // empty' $f)
        if test -n "$prev"; and contains -- "$prev" (tmux list-windows -t $sess -F '#{window_id}' 2>/dev/null)
            tmux kill-window -t $prev >/dev/null 2>&1
        end

        # window names come from the Claude title and repeat across sessions (a
        # fork and its parent, two windows in one project) - the id suffix is
        # what tells those rows apart in the status line and in choose-tree
        set -l wname $name
        contains -- "$wname" (tmux list-windows -t $sess -F '#{window_name}' 2>/dev/null)
        and set wname "$name "(string lower (string sub -l 4 $id))

        set -l wid (tmux new-window -t $sess: -n $wname -c $cwd -P -F '#{window_id}' -- fish -c $cmd)
        test -n "$wid"; or continue

        set -l tmp (mktemp $map/.tmp.XXXXXX)
        and jq --arg s "$sess" --arg w "$wid" '.tsession = $s | .twindow = $w' $f > $tmp
        and mv -f $tmp $f
    end

    # name and project directory of the session that was created, tab-separated:
    # the ssh menu cds into that directory before attaching, so the Moshi gateway
    # resolves the session to the project instead of $HOME
    test -n "$created"; and printf '%s\t%s\n' $created $dir
    return 0
end
