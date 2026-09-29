function wt --description "new worktree + agterm session: wt <feature name words...>"
    if test (count $argv) -eq 0
        echo "wt: usage: wt <feature-name>" >&2
        return 1
    end
    if not command -q gt; or not command -q agtermctl
        echo "wt: needs gt and agtermctl in PATH" >&2
        return 1
    end
    set -l root (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$root"
        echo "wt: not inside a git repository" >&2
        return 1
    end
    set -l project (path basename $root)
    set -l name (string join - $argv | string replace -ra '\s+' - | string trim -c -)

    gt $name -x true >/dev/null
    or begin
        echo "wt: gt failed to create worktree $name" >&2
        return 1
    end

    set -l wtpath ""
    set -l current ""
    for line in (git -C $root worktree list --porcelain)
        if string match -q 'worktree *' -- $line
            set current (string replace 'worktree ' '' -- $line)
        end
        if test "$line" = "branch refs/heads/$name"
            set wtpath $current
            break
        end
    end
    if test -z "$wtpath"
        echo "wt: worktree for branch $name not found" >&2
        return 1
    end

    agtermctl session new --cwd $wtpath --name $name --workspace-name $project --create-workspace
end

