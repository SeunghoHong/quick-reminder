#!/bin/bash
set -euo pipefail

REPO="https://github.com/SeunghoHong/quick-reminder.git"
TARGET="$HOME/.hammerspoon/quick-reminder"
# Version to install: `QR_REF=v0.1.0 ...` or `bash -s -- v0.1.0`. Empty = main.
REF="${QR_REF:-${1:-}}"
SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"

mkdir -p "$HOME/.hammerspoon"

if [ -n "$SOURCE" ] && [ -f "$SOURCE/init.lua" ]; then
    # Local checkout: symlink it
    if [ -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
        echo "Error: $TARGET exists and is not a symlink. Run uninstall.sh first."
        exit 1
    fi
    [ -L "$TARGET" ] && rm "$TARGET"
    ln -s "$SOURCE" "$TARGET"
    echo "Linked: $TARGET → $SOURCE"
else
    # Remote install: clone or update
    if [ -L "$TARGET" ]; then
        echo "Error: $TARGET is a symlink to a local checkout. Run uninstall.sh first."
        exit 1
    fi
    if [ -d "$TARGET/.git" ]; then
        git -C "$TARGET" fetch --tags --prune origin
        if [ -n "$REF" ]; then
            git -C "$TARGET" checkout -q --detach "$REF"
        else
            git -C "$TARGET" checkout -q main
            git -C "$TARGET" merge --ff-only origin/main
        fi
        echo "Updated: $TARGET"
    elif [ -e "$TARGET" ]; then
        echo "Error: $TARGET exists and is not a git clone. Remove it first."
        exit 1
    else
        git clone ${REF:+--branch "$REF"} "$REPO" "$TARGET"
        echo "Cloned: $TARGET"
    fi
    echo "Version: $(git -C "$TARGET" describe --tags --always)"
fi

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
echo "  3. Press Shift+Space to open the reminder popup"
echo "  4. First save will ask for Automation → Reminders permission"
