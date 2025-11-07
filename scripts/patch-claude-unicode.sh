#!/bin/bash

# Find the Claude Code CLI file(s) in different possible locations
CLI_FILES=()

# Check NVM installations
for file in ~/.nvm/versions/node/v*/lib/node_modules/@anthropic-ai/claude-code/cli.js; do
    [ -f "$file" ] && CLI_FILES+=("$file")
done

# Check mise installations
for file in ~/.local/share/mise/installs/node/*/lib/node_modules/@anthropic-ai/claude-code/cli.js; do
    [ -f "$file" ] && CLI_FILES+=("$file")
done

# Check if any files were found
if [ ${#CLI_FILES[@]} -eq 0 ]; then
    echo "Error: No Claude Code CLI files found"
    echo ""
    echo "Searched in:"
    echo "  - ~/.nvm/versions/node/*/lib/node_modules/@anthropic-ai/claude-code/cli.js"
    echo "  - ~/.local/share/mise/installs/node/*/lib/node_modules/@anthropic-ai/claude-code/cli.js"
    exit 1
fi

echo "Found ${#CLI_FILES[@]} Claude Code installation(s)"
echo ""

PATCHED_COUNT=0
SKIPPED_COUNT=0

# Apply the fix to each file
for CLI_FILE in "${CLI_FILES[@]}"; do
    if [ -f "$CLI_FILE" ]; then
        # Check if already patched
        if grep -q 'return/\[\\p{L}\\p{N}_\]/u\.test(A)}isOverWhitespace()' "$CLI_FILE"; then
            echo "⊘ Already patched: $CLI_FILE"
            ((SKIPPED_COUNT++))
        else
            echo "→ Patching: $CLI_FILE"

            # Create backup only if it doesn't exist
            if [ ! -f "$CLI_FILE.backup" ]; then
                cp "$CLI_FILE" "$CLI_FILE.backup"
                echo "  Created backup: $CLI_FILE.backup"
            else
                echo "  Using existing backup: $CLI_FILE.backup"
            fi

            # Apply the Unicode word boundary fix
            perl -i -pe 's|return/\\w/\.test\(A\)\}isOverWhitespace\(\)|return/[\\p{L}\\p{N}_]/u.test(A)}isOverWhitespace()|' "$CLI_FILE"

            echo "  ✓ Patched successfully"
            ((PATCHED_COUNT++))
        fi
        echo ""
    fi
done

echo "════════════════════════════════════════════════════════════════"
echo "Summary: $PATCHED_COUNT patched, $SKIPPED_COUNT already patched"
echo "════════════════════════════════════════════════════════════════"

if [ $PATCHED_COUNT -gt 0 ]; then
    echo ""
    echo "⚠ Please restart Claude Code for changes to take effect!"
fi

echo ""
echo "To restore original version, run:"
for CLI_FILE in "${CLI_FILES[@]}"; do
    if [ -f "$CLI_FILE.backup" ]; then
        echo "  cp \"$CLI_FILE.backup\" \"$CLI_FILE\""
    fi
done

