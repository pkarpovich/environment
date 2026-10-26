function ft --description "pick a task from the project's .zed/tasks.json and start it under foster"
    set -l json (foster task --json); or return
    set -l rows (printf '%s\n' $json | jq -r '.[] | [.name, (if .needs then "\(.label)  (needs \(.needs), Zed only)" else .label end), .command, (.needs // "")] | @tsv')
    test (count $rows) -gt 0; or return
    set -l pick (printf '%s\n' $rows | sk --delimiter \t --with-nth 2,3 --prompt 'task> ')
    test -n "$pick"; or return
    set -l f (string split \t -- $pick)
    if test -n "$f[4]"
        echo "ft: $f[1] needs $f[4], start it from Zed" >&2
        return 1
    end
    foster task $f[1]
end
