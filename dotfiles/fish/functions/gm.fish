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

