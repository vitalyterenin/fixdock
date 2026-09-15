#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Fixdock"
CONFIGURATION="${CONFIGURATION:-release}"
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$BUILD_DIR/app/$APP_NAME.app"
EXECUTABLE="$BUILD_DIR/$CONFIGURATION/$APP_NAME"
SIGNING_IDENTITY="${FIXDOCK_CODE_SIGN_IDENTITY:-Fixdock Local Code Signing}"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "error: Fixdock can only be built on macOS" >&2
    exit 1
fi

for required_command in swift security codesign; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        echo "error: required command '$required_command' is unavailable; install Xcode Command Line Tools" >&2
        exit 1
    fi
done

if [[ -n "${FIXDOCK_CODE_SIGN_KEYCHAIN:-}" ]]; then
    SIGNING_KEYCHAIN="$FIXDOCK_CODE_SIGN_KEYCHAIN"
else
    SIGNING_KEYCHAIN="$("$ROOT_DIR/Scripts/setup-signing.sh")"
fi

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$ROOT_DIR/Packaging/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

security unlock-keychain -p "${FIXDOCK_CODE_SIGN_KEYCHAIN_PASSWORD:-}" "$SIGNING_KEYCHAIN"
SIGNING_CERTIFICATE_SHA1="$(
    security find-certificate -c "$SIGNING_IDENTITY" -Z "$SIGNING_KEYCHAIN" \
        | awk '/SHA-1 hash:/ { print $3; exit }'
)"

if [[ -z "$SIGNING_CERTIFICATE_SHA1" ]]; then
    echo "error: Fixdock signing certificate not found in $SIGNING_KEYCHAIN" >&2
    exit 1
fi

codesign --force --options runtime --sign "$SIGNING_CERTIFICATE_SHA1" --keychain "$SIGNING_KEYCHAIN" "$APP_DIR" >/dev/null

echo "$APP_DIR"
