#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Fixdock"
OLD_APP_NAME="DockAnchor"
SOURCE_APP="$ROOT_DIR/.build/app/$APP_NAME.app"
DESTINATION_DIR="$HOME/Applications"
DESTINATION_APP="$DESTINATION_DIR/$APP_NAME.app"
OLD_DESTINATION_APP="$DESTINATION_DIR/$OLD_APP_NAME.app"

"$ROOT_DIR/Scripts/build-app.sh" >/dev/null

pkill -x "$APP_NAME" 2>/dev/null || true
pkill -x "$OLD_APP_NAME" 2>/dev/null || true
for _ in {1..50}; do
    if ! pgrep -x "$APP_NAME" >/dev/null && ! pgrep -x "$OLD_APP_NAME" >/dev/null; then
        break
    fi
    sleep 0.1
done

mkdir -p "$DESTINATION_DIR"
rm -rf "$DESTINATION_APP"
rm -rf "$OLD_DESTINATION_APP"
ditto "$SOURCE_APP" "$DESTINATION_APP"
xattr -dr com.apple.quarantine "$DESTINATION_APP" 2>/dev/null || true

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
    "$LSREGISTER" -u "$SOURCE_APP" >/dev/null 2>&1 || true
    "$LSREGISTER" -u "$OLD_DESTINATION_APP" >/dev/null 2>&1 || true
    "$LSREGISTER" -f "$DESTINATION_APP" >/dev/null 2>&1 || true
fi

rm -rf "$SOURCE_APP"

open -n "$DESTINATION_APP"

echo "$DESTINATION_APP"
