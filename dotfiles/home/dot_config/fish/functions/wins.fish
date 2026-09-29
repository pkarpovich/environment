function wins --description "yashiki: list all windows grouped by display + tag + layout mode (read-only diagnostic)"
    set -l script ~/Projects/environment/dotfiles/yashiki/wins.py
    if not command -q yashiki
        echo "wins: yashiki not in PATH" >&2
        return 1
    end
    if not test -f $script
        echo "wins: $script not found" >&2
        return 1
    end
    if command -q sk
        python3 $script | sk --no-sort --reverse --header-lines=1 --prompt="win> " >/dev/null
    else
        python3 $script
    end
end
