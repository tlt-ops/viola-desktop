#!/bin/bash
# Build from any working directory. No installed app or profile is changed.
set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
    echo "Usage: ./scripts/build_app.sh"
    echo "Builds an ad-hoc signed build/viola终稿.app for the current Mac architecture."
    exit 0
fi
[[ $# -eq 0 ]] || { echo "Unexpected argument; use --help." >&2; exit 2; }
[[ "$(uname -s)" == "Darwin" ]] || { echo "macOS is required." >&2; exit 1; }
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
RESOURCE_BUNDLE="$BIN_DIR/ViolaDesktop_ViolaDesktop.bundle"
[[ -x "$BIN_DIR/ViolaDesktop" && -d "$RESOURCE_BUNDLE/Resources" ]] || {
    echo "SwiftPM executable or resource bundle is missing." >&2; exit 1;
}
[[ ! -L "$ROOT/build" ]] || { echo "Refusing a symlink at build/." >&2; exit 1; }
mkdir -p "$ROOT/build"
STAGE="$(mktemp -d "$ROOT/build/.app-stage.XXXXXX")"
trap 'rmdir "$STAGE" 2>/dev/null || true' EXIT
APP="$STAGE/viola终稿.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/packaging/Info.plist" "$APP/Contents/Info.plist"
cp "$BIN_DIR/ViolaDesktop" "$APP/Contents/MacOS/ViolaDesktop"
# CharacterAssets prefers Bundle.main.resourceURL/Characters/Viola in an app.
# Put the entire resource tree in the standard, signable app resource location.
# SwiftPM's original bundle remains in .build for `swift run`.
ditto "$RESOURCE_BUNDLE/Resources" "$APP/Contents/Resources"
codesign --force --sign - --timestamp=none "$APP"
"$ROOT/scripts/verify_app.sh" "$APP"
OUTPUT="$ROOT/build/viola终稿.app"
[[ ! -L "$OUTPUT" ]] || { echo "Refusing a symlink at $OUTPUT." >&2; exit 1; }
# Keep a previous generated build as a rollback artifact; do not delete it.
if [[ -e "$OUTPUT" ]]; then
    PREVIOUS="$(mktemp -d "$ROOT/build/.previous-app.XXXXXX")"
    mv "$OUTPUT" "$PREVIOUS/viola终稿.app"
    echo "Previous build retained: $PREVIOUS/viola终稿.app"
fi
mv "$APP" "$OUTPUT"
echo "Built: $OUTPUT"
