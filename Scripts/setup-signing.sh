#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIGNING_IDENTITY="${FIXDOCK_CODE_SIGN_IDENTITY:-Fixdock Local Code Signing}"
LEGACY_SIGNING_DIR="$ROOT_DIR/../../Maintenance/Secrets/fixdock-code-signing"
DEFAULT_SIGNING_DIR="$HOME/Library/Application Support/Fixdock/Signing"

if [[ -n "${FIXDOCK_SIGNING_DIR:-}" ]]; then
    SIGNING_DIR="$FIXDOCK_SIGNING_DIR"
elif [[ -f "$LEGACY_SIGNING_DIR/fixdock-code-signing.keychain-db" ]]; then
    SIGNING_DIR="$LEGACY_SIGNING_DIR"
else
    SIGNING_DIR="$DEFAULT_SIGNING_DIR"
fi

KEYCHAIN_PATH="$SIGNING_DIR/fixdock-code-signing.keychain-db"
KEY_PATH="$SIGNING_DIR/fixdock-local-code-signing.key.pem"
CERT_PATH="$SIGNING_DIR/fixdock-local-code-signing.cert.pem"
KEYCHAIN_PASSWORD="${FIXDOCK_CODE_SIGN_KEYCHAIN_PASSWORD:-}"
OPENSSL_BIN="${FIXDOCK_OPENSSL_BIN:-/usr/bin/openssl}"

mkdir -p "$SIGNING_DIR"
chmod 700 "$SIGNING_DIR"

if [[ -f "$KEY_PATH" && ! -f "$CERT_PATH" ]] || [[ ! -f "$KEY_PATH" && -f "$CERT_PATH" ]]; then
    echo "error: the Fixdock signing key and certificate must either both exist or both be absent" >&2
    exit 1
fi

if [[ ! -f "$KEY_PATH" ]]; then
    "$OPENSSL_BIN" req -x509 -newkey rsa:3072 -sha256 -nodes \
        -keyout "$KEY_PATH" \
        -out "$CERT_PATH" \
        -days 3650 \
        -subj "/CN=$SIGNING_IDENTITY/O=Fixdock Local Installation" \
        -addext "basicConstraints=critical,CA:TRUE" \
        -addext "keyUsage=critical,digitalSignature,keyCertSign" \
        -addext "extendedKeyUsage=critical,codeSigning" >/dev/null 2>&1
    chmod 600 "$KEY_PATH" "$CERT_PATH"
fi

if [[ ! -f "$KEYCHAIN_PATH" ]]; then
    security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
fi

security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 300 "$KEYCHAIN_PATH"

if ! security find-certificate -c "$SIGNING_IDENTITY" "$KEYCHAIN_PATH" >/dev/null 2>&1; then
    P12_PASSWORD="$($OPENSSL_BIN rand -hex 24)"
    P12_PATH="$(mktemp "$SIGNING_DIR/.fixdock-signing.XXXXXX")"
    trap '[[ ! -e "$P12_PATH" ]] || /bin/unlink "$P12_PATH"' EXIT

    "$OPENSSL_BIN" pkcs12 -export \
        -inkey "$KEY_PATH" \
        -in "$CERT_PATH" \
        -name "$SIGNING_IDENTITY" \
        -out "$P12_PATH" \
        -passout "pass:$P12_PASSWORD" >/dev/null 2>&1
    security import "$P12_PATH" \
        -k "$KEYCHAIN_PATH" \
        -f pkcs12 \
        -P "$P12_PASSWORD" \
        -T /usr/bin/codesign >/dev/null
    security set-key-partition-list \
        -S apple-tool:,apple: \
        -s \
        -k "$KEYCHAIN_PASSWORD" \
        "$KEYCHAIN_PATH" >/dev/null

    /bin/unlink "$P12_PATH"
    trap - EXIT
fi

# build-app.sh supplies codesign --keychain explicitly. Never parse and rewrite
# the user's search list here: security's display output is not a path API.
# In particular, losing the login keychain hides browser Safe Storage entries.

chmod 600 "$KEYCHAIN_PATH"
printf '%s\n' "$KEYCHAIN_PATH"
