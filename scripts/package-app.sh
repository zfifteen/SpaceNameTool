#!/usr/bin/env bash
# Build SpaceNameTool into a drag-installable .app (NFR-4 / NFR-5 path).
# SIP-safe: hardened runtime entitlements only; no injection entitlements.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIGURATION="${CONFIGURATION:-release}"
APP_NAME="SpaceNameTool"
DIST="$ROOT/dist"
APP="$DIST/${APP_NAME}.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Building ($CONFIGURATION)…"
swift build -c "$CONFIGURATION"

BIN="$(swift build -c "$CONFIGURATION" --show-bin-path)/${APP_NAME}"
if [[ ! -x "$BIN" ]]; then
  echo "error: binary not found at $BIN" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"
cp "$BIN" "$MACOS/${APP_NAME}"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
# Placeholder icon-free bundle; optional assets can land in Resources later.
cp "$ROOT/SpaceNameTool.entitlements" "$RESOURCES/SpaceNameTool.entitlements"

# Ad-hoc or Developer ID sign when identity is available.
ENTITLEMENTS="$ROOT/SpaceNameTool.entitlements"
if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  echo "codesign with identity: $CODESIGN_IDENTITY"
  codesign --force --options runtime --entitlements "$ENTITLEMENTS" --sign "$CODESIGN_IDENTITY" "$APP"
elif security find-identity -v -p codesigning 2>/dev/null | grep -q "Developer ID Application"; then
  IDENTITY="$(security find-identity -v -p codesigning | awk -F'\"' '/Developer ID Application/ {print $2; exit}')"
  echo "codesign with detected identity: $IDENTITY"
  codesign --force --options runtime --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP"
else
  echo "codesign ad-hoc (no Developer ID identity found)"
  codesign --force --options runtime --entitlements "$ENTITLEMENTS" --sign - "$APP"
fi

echo "Built: $APP"
echo "Install: drag to /Applications"
echo "Optional notarization: see docs/PACKAGING.md (requires Apple notary credentials)."

# Optional notary if profile set
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  echo "Submitting for notarization with profile $NOTARY_PROFILE…"
  ditto -c -k --keepParent "$APP" "$DIST/${APP_NAME}.zip"
  xcrun notarytool submit "$DIST/${APP_NAME}.zip" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  echo "Notarized and stapled."
fi
