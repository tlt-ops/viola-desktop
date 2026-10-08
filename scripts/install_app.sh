#!/bin/bash
# Copy to a per-user Applications folder by default. Never replace an app.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "${1:-}" == "--help" ]]; then
    echo "Usage: ./scripts/install_app.sh [destination-directory]"
    echo "Default: ~/Applications. Refuses to overwrite an existing viola终稿.app."
    echo "Does not launch the app or change its Application Support profile."
    exit 0
fi
[[ $# -le 1 ]] || { echo "Expected at most one destination directory." >&2; exit 2; }
SOURCE="$ROOT/build/viola终稿.app"
"$ROOT/scripts/verify_app.sh" "$SOURCE"
DESTINATION="${1:-$HOME/Applications}"
mkdir -p "$DESTINATION"
DESTINATION="$(cd "$DESTINATION" && pwd)"
TARGET="$DESTINATION/viola终稿.app"
[[ ! -e "$TARGET" && ! -L "$TARGET" ]] || {
    echo "Already exists: $TARGET" >&2
    echo "Choose another destination directory; no files were replaced." >&2
    exit 1
}
STAGE="$(mktemp -d "$DESTINATION/.viola-install.XXXXXX")"
trap 'rmdir "$STAGE" 2>/dev/null || true' EXIT
ditto "$SOURCE" "$STAGE/viola终稿.app"
"$ROOT/scripts/verify_app.sh" "$STAGE/viola终稿.app"
# -n also protects an application created at the destination during the copy.
mv -n "$STAGE/viola终稿.app" "$DESTINATION/"
[[ ! -e "$STAGE/viola终稿.app" ]] || { echo "Destination appeared during installation; nothing replaced." >&2; exit 1; }
echo "Installed: $TARGET"
