function gmi
    if test (count $argv) -eq 0
        echo "Usage: gmi <message>"
        return 1
    end

    set result (eval gm $argv[1])
    git commit -m $result
    lazygit
end

