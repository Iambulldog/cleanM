#!/usr/bin/env bash
# Packages a universal CleanM.app into dist/CleanM-<version>.zip.
#
#   ./scripts/release.sh                     → build + sign + (notarize if possible) + zip
#   PUBLISH=1 ./scripts/release.sh           → also tag v<version> and create the GitHub release
#   REQUIRE_NOTARIZATION=1 ./scripts/release.sh → fail instead of shipping an un-notarized build
#
# Notarization (one-time setup, see README "Notarization"):
#   1. A "Developer ID Application" certificate in your login keychain (paid Apple Developer Program).
#   2. Store notary credentials once:
#        xcrun notarytool store-credentials CleanM-notary --apple-id <you@example.com> --team-id <TEAMID>
#      (it prompts for an app-specific password from account.apple.com)
#   Override the profile name with NOTARY_PROFILE=<name>.
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
APP="build/CleanM.app"
NOTARY_PROFILE="${NOTARY_PROFILE:-CleanM-notary}"

if [[ "${PUBLISH:-0}" == "1" && -n "$(git status --porcelain)" ]]; then
  echo "✗ Working tree has uncommitted changes — commit before publishing." >&2
  exit 1
fi

UNIVERSAL=1 "$ROOT/scripts/build-app.sh"

mkdir -p dist
rm -f "$ZIP"

AUTHORITY="$(codesign -dvv "$APP" 2>&1 | sed -n 's/^Authority=//p' | head -1)"
NOTARIZED=0
if [[ "$AUTHORITY" == Developer\ ID\ Application:* ]]; then
  if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "▸ Submitting to Apple notary service (profile: $NOTARY_PROFILE)…"
    SUBMIT_ZIP="dist/.CleanM-notarize.zip"
    ditto -c -k --sequesterRsrc --keepParent "$APP" "$SUBMIT_ZIP"
    if xcrun notarytool submit "$SUBMIT_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait; then
      xcrun stapler staple "$APP"
      xcrun stapler validate "$APP"
      spctl --assess --type execute --verbose=2 "$APP"
      NOTARIZED=1
    else
      echo "✗ Notarization failed. See: xcrun notarytool log <submission-id> --keychain-profile $NOTARY_PROFILE" >&2
      rm -f "$SUBMIT_ZIP"
      exit 1
    fi
    rm -f "$SUBMIT_ZIP"
  else
    echo "• No notarytool profile \"$NOTARY_PROFILE\" — skipping notarization."
  fi
else
  echo "• Not signed with a Developer ID certificate — skipping notarization."
fi

if [[ "$NOTARIZED" != "1" && "${REQUIRE_NOTARIZATION:-0}" == "1" ]]; then
  echo "✗ REQUIRE_NOTARIZATION=1 but the app was not notarized." >&2
  exit 1
fi

ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
echo "✓ $ZIP (notarized: $([[ $NOTARIZED == 1 ]] && echo yes || echo no))"
echo "  sha256: $SHA"

if [[ "${PUBLISH:-0}" == "1" ]]; then
  NOTES="$(awk -v v="$VERSION" '
    $0 ~ "^## \\[?"v"\\]?" {found=1; next}
    found && /^## / {exit}
    found {print}' CHANGELOG.md)"
  if [[ "$NOTARIZED" == "1" ]]; then
    INSTALL_NOTE="Signed with Developer ID and notarized by Apple — just unzip and open."
  else
    INSTALL_NOTE="Not notarized: on first launch open System Settings → Privacy & Security → **Open Anyway**."
  fi
  git tag -a "$TAG" -m "CleanM $VERSION" 2>/dev/null || echo "• Tag $TAG already exists"
  git push origin "$TAG"
  BODY="${NOTES}

${INSTALL_NOTE}

**SHA-256** \`$SHA\`"
  if gh release view "$TAG" >/dev/null 2>&1; then
    gh release upload "$TAG" "$ZIP" --clobber
    gh release edit "$TAG" --notes "$BODY"
  else
    gh release create "$TAG" "$ZIP" --title "CleanM $VERSION" --notes "$BODY"
  fi
  echo "✓ Published $TAG"
fi
