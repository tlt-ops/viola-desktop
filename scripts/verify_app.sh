#!/bin/bash
# Static packaging and signature validation; does not launch or install the app.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "${1:-}" == "--help" ]]; then
    echo "Usage: ./scripts/verify_app.sh [path/to/viola终稿.app]"
    exit 0
fi
[[ $# -le 1 ]] || { echo "Expected at most one app path." >&2; exit 2; }
APP="${1:-$ROOT/build/viola终稿.app}"
PLIST="$APP/Contents/Info.plist"
plutil -lint "$PLIST"
check_field() {
    local actual
    actual="$(/usr/libexec/PlistBuddy -c "Print :$1" "$PLIST")"
    [[ "$actual" == "$2" ]] || { echo "Unexpected $1: $actual" >&2; exit 1; }
}
check_field CFBundleIdentifier local.viola.desktop.preview
check_field CFBundleExecutable ViolaDesktop
check_field CFBundleName viola终稿
check_field CFBundleDisplayName viola终稿
check_field CFBundleShortVersionString 0.2.50
check_field CFBundleVersion 51
check_field ViolaProfileDirectory ViolaDesktop-Preview
check_field LSMinimumSystemVersion 13.0
[[ -x "$APP/Contents/MacOS/ViolaDesktop" ]] || { echo "Executable is missing." >&2; exit 1; }
RESOURCE_DIR="$APP/Contents/Resources"
[[ -f "$RESOURCE_DIR/Characters/Viola/character.json" ]] || { echo "Character manifest is missing." >&2; exit 1; }
# Compare every resource byte, including art, manifests and laugh audio.
diff -qr "$ROOT/Sources/ViolaDesktop/Resources" "$RESOURCE_DIR"
codesign --verify --deep --strict --verbose=2 "$APP"
echo "PASS: app metadata, all bundled resource bytes, and ad-hoc signature"
