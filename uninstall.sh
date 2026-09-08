#!/bin/bash
set -euo pipefail

TARGET="$HOME/.hammerspoon/quick-reminder"
HS_INIT="$HOME/.hammerspoon/init.lua"

if [ -L "$TARGET" ]; then
    rm "$TARGET"
    echo "Removed symlink: $TARGET (source checkout kept)"
elif [ -d "$TARGET/.git" ]; then
    rm -rf "$TARGET"
    echo "Removed clone: $TARGET"
elif [ -e "$TARGET" ]; then
    echo "Error: $TARGET is neither a symlink nor a git clone. Remove it by hand."
    exit 1
else
    echo "Not installed: $TARGET"
fi

if [ -f "$HS_INIT" ] && grep -q 'require("quick-reminder")' "$HS_INIT"; then
    # grep exits 1 when nothing is left — that is the normal single-line case
    grep -v '^require("quick-reminder")$' "$HS_INIT" > "$HS_INIT.tmp" || [ $? -eq 1 ]
    mv "$HS_INIT.tmp" "$HS_INIT"
    echo "Removed require line from $HS_INIT"
fi

echo ""
echo "Hammerspoon menu → Reload Config to finish."
