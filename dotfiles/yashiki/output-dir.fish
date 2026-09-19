#!/opt/homebrew/bin/fish
# output-dir.fish focus|send left|right
#
# yashiki's own output-focus/output-send walk the displays in sorted display-id
# order (core/state/display.rs: `display_ids.sort()`), and macOS hands out those
# ids by connection order, not by where the screen sits. So "next" lands on
# whichever display happens to have the next id, and the direction flips after
# a reconnect. This orders the displays by their x origin instead, picks the
# spatial neighbour, and reaches it by issuing however many next/prev steps
# that is in yashiki's id cycle - the only way to get there, since no command
# focuses a display by id or name.
set -l YASHIKI /opt/homebrew/bin/yashiki
set -l mode $argv[1]
set -l dir $argv[2]

set -l cmd
switch $mode
    case focus
        set cmd output-focus
    case send
        set cmd output-send
    case '*'
        exit 2
end
contains -- $dir left right; or exit 2

# "<id>: <name> [<w>x<h> @ (<x>,<y>)]<markers>"; a trailing * marks the focused display
set -l ids
set -l xs
set -l cur
for line in ($YASHIKI list-outputs)
    set -l m (string match -r '^(\d+): .* @ \((-?\d+),-?\d+\)\](.*)$' -- $line)
    test (count $m) -ge 3; or continue
    set -a ids $m[2]
    set -a xs $m[3]
    string match -q '*\**' -- $m[4]; and set cur $m[2]
end
set -l n (count $ids)
test $n -ge 2; or exit 0
test -n "$cur"; or exit 1

set -l spatial (for i in (seq $n); echo "$xs[$i] $ids[$i]"; end | sort -n | awk '{print $2}')
set -l cycle (printf '%s\n' $ids | sort -n)

set -l pos (contains -i -- $cur $spatial)
set -l t
switch $dir
    case right
        set t (math "$pos % $n + 1")
    case left
        set t (math "($pos - 2 + $n) % $n + 1")
end
set -l target $spatial[$t]

set -l ci (contains -i -- $cur $cycle)
set -l ti (contains -i -- $target $cycle)
set -l steps (math "($ti - $ci + $n) % $n")
test $steps -eq 0; and exit 0

if test (math "$steps * 2") -le $n
    for i in (seq $steps)
        $YASHIKI $cmd next
    end
else
    for i in (seq (math "$n - $steps"))
        $YASHIKI $cmd prev
    end
end
