#!/usr/bin/env bash
# Runs the test suite. With Command Line Tools only (no Xcode), SwiftPM doesn't load the
# Swift Testing macro plugin on its own, so point the compiler at it when it exists.
set -euo pipefail
cd "$(dirname "$0")/.."
PLUGINS="/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"
if [[ -d "$PLUGINS" ]] && ! xcode-select -p | grep -q Xcode.app; then
  exec swift test -Xswiftc -plugin-path -Xswiftc "$PLUGINS" "$@"
fi
exec swift test "$@"
