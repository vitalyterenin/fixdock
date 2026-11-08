#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_args=(--scratch-path "${FIXDOCK_BUILD_DIR:-$HOME/Library/Developer/Fixdock/Build}" --arch arm64 --disable-xctest)
testing_plugin="$(dirname "$(xcrun --find swiftc)")/../lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [[ -f "$testing_plugin" ]]; then test_args+=(-Xswiftc -load-plugin-library -Xswiftc "$testing_plugin"); fi
swift test "${test_args[@]}"
python3 Scripts/test-signing-isolation.py
python3 -m unittest discover -s Tests -p 'test_*.py'
