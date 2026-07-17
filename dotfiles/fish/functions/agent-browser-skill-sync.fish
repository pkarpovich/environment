function agent-browser-skill-sync --description "sync agent-browser bundled core skill from brew cellar to dotfiles"
    set -l src /opt/homebrew/opt/agent-browser/libexec/lib/node_modules/agent-browser/skill-data/core
    set -l dst ~/Projects/environment/dotfiles/claude/skills/agent-browser

    if not test -d $src
        echo "agent-browser-skill-sync: source not found at $src" >&2
        return 1
    end

    rsync -a --delete --exclude SKILL.md $src/ $dst/
    sed 's/^name: core$/name: agent-browser/' $src/SKILL.md > $dst/SKILL.md
    echo "✓ agent-browser skill synced"
end

