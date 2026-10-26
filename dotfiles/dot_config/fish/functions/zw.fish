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

    if string match -q '*://*' -- $folders[1]
        _zw_open_remote $folders
        return
    end

    set -l paths
    for p in $folders
        set p (string replace -r '^~' $HOME -- $p)
        string match -q '/*' -- $p; and set -a paths $p; or set -a paths $dir/$p
    end
    zed $paths
end

# Zed reuses a window for a local project but opens a new one for every ssh:// URL,
# and its CLI takes a single ssh:// path per call: the rest are added with -a.
# Remote worktrees are matched by the literal path, so a `~` path gets added twice: absolute paths only.
function _zw_open_remote
    set -l name (path basename $argv[1])
    _zw_focus_existing $name; and return
    zed -n $argv[1]
    for i in (seq 1 60)
        sleep 0.5
        _zw_window_for $name >/dev/null; and break
    end
    for url in $argv[2..]
        zed -a $url
    end
end

function _zw_focus_existing
    set -l hit (_zw_window_for $argv[1]); or return 1
    set -l parts (string split -m 2 ' ' -- $hit)
    yashiki tag-view $parts[1] --output $parts[2]
    # yashiki keeps the title it saw last, so the live title comes from System Events
    osascript -e "tell application \"System Events\" to tell process \"Zed\"
        set frontmost to true
        perform action \"AXRaise\" of (first window whose name contains \"$argv[1]\")
    end tell" >/dev/null
    return 0
end

function _zw_window_for
    # yashiki subscribe never exits on its own, so the snapshot is read by a process that kills it
    set -l hit (python3 -c '
import json, subprocess, sys
p = subprocess.Popen(["yashiki", "subscribe", "--snapshot", "--filter", "window"], stdout=subprocess.PIPE, text=True)
line = p.stdout.readline()
p.kill()
for w in json.loads(line)["windows"]:
    if w.get("app_id") == "dev.zed.Zed" and sys.argv[1] in w.get("title", ""):
        print(w["tags"], w["output_id"], w["title"])
        break
' $argv[1])
    test -n "$hit"; or return 1
    echo $hit
end
