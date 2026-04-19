#!/bin/bash
set -euo pipefail

SOURCE="$(cd "$(dirname "$0")" && pwd)"
TARGET="$HOME/.hammerspoon/quick-reminder"

if [ -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
    echo "Error: $TARGET exists and is not a symlink. Remove it first."
    exit 1
fi

if [ -L "$TARGET" ]; then
    rm "$TARGET"
fi

mkdir -p "$HOME/.hammerspoon"
ln -s "$SOURCE" "$TARGET"
echo "Linked: $TARGET → $SOURCE"

HS_INIT="$HOME/.hammerspoon/init.lua"
if ! grep -q 'require("quick-reminder")' "$HS_INIT" 2>/dev/null; then
    echo 'require("quick-reminder")' >> "$HS_INIT"
    echo "Added require line to $HS_INIT"
else
    echo "require line already in $HS_INIT"
fi

echo ""
echo "Next steps:"
echo "  1. Open Hammerspoon, grant Accessibility permission if asked"
echo "  2. Hammerspoon menu → Reload Config"
echo "  3. Press Ctrl twice to open the reminder popup"
echo "  4. First save will ask for Automation → Reminders permission"
