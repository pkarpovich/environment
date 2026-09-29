function zw --description "open a VS Code-style .code-workspace in Zed (multi-root project); no arg - pick one from cwd"
    set -l file $argv[1]
    if test -z "$file"
        set -l candidates *.code-workspace
        if test (count $candidates) -eq 0
            echo "zw: no .code-workspace in current directory" >&2
            return 1
        else if test (count $candidates) -eq 1
            set file $candidates[1]
        else
            set file (printf '%s\n' $candidates | sk --height 30% --prompt="workspace> ")
            test -n "$file"; or return
        end
    end
    if not test -f "$file"
        echo "zw: $file not found" >&2
        return 1
    end

    set -l dir (path resolve (path dirname $file))
    set -l folders (grep -v '^\s*//' "$file" | perl -0pe 's/,(\s*[}\]])/$1/g' | jq -r '.folders[].path' 2>/dev/null)
    if test (count $folders) -eq 0
        echo "zw: no folders parsed from $file" >&2
        return 1
    end

    set -l paths
    for p in $folders
        set p (string replace -r '^~' $HOME -- $p)
        string match -q '/*' -- $p; and set -a paths $p; or set -a paths $dir/$p
    end
    zed $paths
end
