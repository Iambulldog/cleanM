#!/usr/bin/env bash
# Packages a universal CleanM.app into dist/CleanM-<version>.zip and prints its SHA-256.
#   ./scripts/release.sh           → build + zip
#   PUBLISH=1 ./scripts/release.sh → also tag v<version> and create a GitHub release (needs `gh`)
#
# Release checklist:
#   1. Bump VERSION (semantic versioning: MAJOR.MINOR.PATCH)
#   2. Add a section to CHANGELOG.md
#   3. Commit, then run PUBLISH=1 ./scripts/release.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="$(tr -d '[:space:]' < VERSION)"
TAG="v$VERSION"
ZIP="dist/CleanM-$VERSION.zip"

UNIVERSAL=1 "$ROOT/scripts/build-app.sh"

mkdir -p dist
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent build/CleanM.app "$ZIP"
SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
echo "✓ $ZIP"
echo "  sha256: $SHA"

if [[ "${PUBLISH:-0}" == "1" ]]; then
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "✗ Working tree has uncommitted changes — commit before publishing." >&2
    exit 1
  fi
  NOTES="$(awk -v v="$VERSION" '
    $0 ~ "^## \\[?"v"\\]?" {found=1; next}
    found && /^## / {exit}
    found {print}' CHANGELOG.md)"
  git tag -a "$TAG" -m "CleanM $VERSION" 2>/dev/null || echo "• Tag $TAG already exists"
  git push origin "$TAG"
  gh release create "$TAG" "$ZIP" --title "CleanM $VERSION" \
    --notes "${NOTES}

**SHA-256** \`$SHA\`"
  echo "✓ Published $TAG"
fi
