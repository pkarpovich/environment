function fa --description "pick a foster session and attach to it"
    set -l json (foster ls --json); or return
    set -l rows (printf '%s\n' $json | jq -r '.[] | [.name, .status, (.command // "")] | @tsv')
    test (count $rows) -gt 0; or return
    set -l pick (printf '%s\n' $rows | sk --delimiter \t --prompt 'attach> ')
    test -n "$pick"; or return
    foster attach (string split -m 1 \t -- $pick)[1]
end
