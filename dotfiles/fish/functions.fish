function br --wraps=broot
    set -l cmd_file (mktemp)
    if broot --outcmd $cmd_file $argv
        read --local --null cmd < $cmd_file
        rm -f $cmd_file
        eval $cmd
    else
        set -l code $status
        rm -f $cmd_file
        return $code
    end
end

function fish_greeting
    yafetch
end

function y
	set tmp (mktemp -t "yazi-cwd.XXXXXX")
	yazi $argv --cwd-file="$tmp"
	if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
		builtin cd -- "$cwd"
	end
	rm -f -- "$tmp"
end

function gm
    if test (count $argv) -eq 0
        echo "Usage: gm <message>"
        return 1
    end

    set message $argv[1]

    set result (eval 'lumen draft --context "$message"')
    echo $result | pbcopy

    echo $result
end

function gmi
    if test (count $argv) -eq 0
        echo "Usage: gmi <message>"
        return 1
    end

    set result (eval gm $argv[1])
    git commit -m $result
    lazygit
end