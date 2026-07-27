function __ccz_close_tab --description "close a zellij tab by name, only after confirming focus actually landed on it (go-to-tab-name is a silent no-op for an unknown name, so a blind close-tab would kill whatever tab the user is looking at)"
    set -l want $argv[1]
    set -l zj $argv[2..]
    test -n "$want"; or return 1

    $zj action go-to-tab-name "$want" >/dev/null 2>&1
    set -l focused ($zj action dump-layout 2>/dev/null | awk '
        /^ *tab / && index($0, "focus=true") { if (match($0, /name="[^"]*"/)) print substr($0, RSTART+6, RLENGTH-7) }')
    test "$focused" = "$want"; or return 1
    $zj action close-tab >/dev/null 2>&1
end
