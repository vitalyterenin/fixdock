#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Fixdock"
APP_PATH="${1:-$HOME/Applications/$APP_NAME.app}"
EXPECTED_BUNDLE_ID="local.vitalyterenin.Fixdock"

if [[ ! -d "$APP_PATH" ]]; then
    echo "error: Fixdock is not installed at $APP_PATH" >&2
    exit 1
fi

codesign --verify --deep --strict "$APP_PATH"

BUNDLE_ID="$(defaults read "$APP_PATH/Contents/Info" CFBundleIdentifier)"
DEVELOPMENT_REGION="$(defaults read "$APP_PATH/Contents/Info" CFBundleDevelopmentRegion)"

if [[ "$BUNDLE_ID" != "$EXPECTED_BUNDLE_ID" ]]; then
    echo "error: expected bundle ID $EXPECTED_BUNDLE_ID, got $BUNDLE_ID" >&2
    exit 1
fi

if [[ "$DEVELOPMENT_REGION" != "en" ]]; then
    echo "error: expected English development region, got $DEVELOPMENT_REGION" >&2
    exit 1
fi

echo "Verified $APP_PATH"
codesign --display --requirements - "$APP_PATH" 2>&1 | sed -n '/designated =>/p'
