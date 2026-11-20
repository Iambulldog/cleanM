#!/usr/bin/env bash
# Builds CleanM from source and installs it into /Applications (or ~/Applications if not writable).
#   ./scripts/install.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build-app.sh"

DEST="/Applications"
if [[ ! -w "$DEST" ]]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
fi

# Quit a running copy so it can be replaced.
osascript -e 'tell application id "com.iambulldog.CleanM" to quit' >/dev/null 2>&1 || true
sleep 1

rm -rf "$DEST/CleanM.app"
ditto "$ROOT/build/CleanM.app" "$DEST/CleanM.app"
xattr -dr com.apple.quarantine "$DEST/CleanM.app" 2>/dev/null || true

echo "✓ Installed to $DEST/CleanM.app"
open "$DEST/CleanM.app"
