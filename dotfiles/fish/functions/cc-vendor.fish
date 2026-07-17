function cc-vendor --description "Vendor selected CC plugins from ~/.claude into ~/.claude-work"
    set -l script_path ~/Projects/environment/scripts/cc_vendor.py
    if not test -f $script_path
        echo "Error: cc_vendor.py not found at $script_path"
        return 1
    end
    python3 $script_path $argv
end

