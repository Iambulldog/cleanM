#!/usr/bin/env bash
# Builds CleanM in release mode and assembles a signed (ad-hoc) CleanM.app bundle in ./build
#   CONFIG=debug ./scripts/build-app.sh   → debug build
#   UNIVERSAL=1 ./scripts/build-app.sh    → arm64 + x86_64 binary
#   SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" ./scripts/build-app.sh
#                                         → sign for distribution (hardened runtime + timestamp)
# Without SIGN_IDENTITY, a "Developer ID Application" certificate in the keychain is used
# automatically; if there is none, the app is ad-hoc signed (fine for local use).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${CONFIG:-release}"
APP_NAME="CleanM"
APP_DIR="$ROOT/build/$APP_NAME.app"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
# Build number = number of commits (falls back to 1 outside a git checkout).
BUILD_NUMBER="$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)"

if ! command -v swift >/dev/null 2>&1; then
  echo "✗ Swift not found. Install Xcode or run: xcode-select --install" >&2
  exit 1
fi

ARCH_FLAGS=()
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

echo "▸ Building $APP_NAME $VERSION ($BUILD_NUMBER) [$CONFIG]"
swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"

echo "▸ Assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"

PLIST="$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$PLIST"

if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)"
fi

if [[ -n "$SIGN_IDENTITY" && "$SIGN_IDENTITY" != "-" ]]; then
  echo "▸ Codesigning with: $SIGN_IDENTITY (hardened runtime)"
  codesign --force --options runtime --timestamp \
    --entitlements "$ROOT/Resources/CleanM.entitlements" \
    -s "$SIGN_IDENTITY" "$APP_DIR"
else
  echo "▸ Codesigning (ad-hoc — no Developer ID certificate found)"
  codesign --force -s - --options runtime \
    --entitlements "$ROOT/Resources/CleanM.entitlements" \
    "$APP_DIR"
fi

codesign --verify --strict --verbose=1 "$APP_DIR"
echo "✓ Built $APP_DIR (v$VERSION, build $BUILD_NUMBER)"
